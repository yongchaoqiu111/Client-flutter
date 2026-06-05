import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/dashboard_data.dart';
import '../models/podcast_episode.dart';
import '../models/node_config.dart';
import '../models/queue_order.dart';
import '../models/queue_tier.dart';
import '../models/reservoir.dart';
import '../models/node_probe_result.dart';
import '../models/wallet_account.dart';
import '../config/chat_config.dart';
import '../config/payment_config.dart';
import '../config/queue_tiers_presets.dart';
import '../models/chat_send_result.dart';
import '../services/chat_moderation_service.dart';
import '../services/anchor_verify_service.dart';
import '../services/app_settings_service.dart';
import '../services/chain_rpc_service.dart';
import '../services/chain_transfer_service.dart';
import '../services/gateway_ping.dart';
import '../services/gateway_probe_service.dart';
import '../services/network_debug.dart';
import '../services/node_config_service.dart';
import '../services/raft_api_service.dart';
import '../services/wallet_service.dart';
import '../services/ws_service.dart';
import '../services/ximalaya_feed_service.dart';
import '../utils/wallet_derive.dart';

class AppState extends ChangeNotifier {
  NodeConfig? _node;
  RaftApiService? _api;
  final WsService ws = WsService();
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  static const _maxChatMessages = 500;

  WalletAccount? _wallet;
  double? _nativeBalance;
  String? _referralCode;
  Map<String, dynamic>? _user;
  ReservoirStatus? _reservoir;
  List<QueueTier> _tiers = QueueTiersPresets.defaultTiers;
  DashboardData? _dashboard;
  List<QueueOrder> _orders = [];
  QueueOrder? _selectedOrder;
  List<Map<String, dynamic>> _announcements = [];
  Map<String, dynamic>? _ticketQuote;
  String? _lastWsEvent;
  final List<ChatMessage> _chatMessages = [];
  DateTime? _lastChatSentAt;
  bool _loading = false;
  String? _error;
  String? _lastCreatedMnemonic;
  int _shellTabIndex = 0;
  Map<String, dynamic>? _network;
  Map<String, dynamic>? _performance;
  Map<String, dynamic>? _burnRewards;
  AnchorStatus? _anchorStatus;
  bool _demoPayments = PaymentConfig.demoPaymentsDefault;
  PodcastAlbum? _podcastAlbum;
  bool _podcastLoading = false;
  String? _podcastError;

  NodeConfig? get node => _node;
  RaftApiService? get api => _api;
  WalletAccount? get wallet => _wallet;
  String? get address => _wallet?.address;
  String? get chain => _wallet?.chain;
  String? get referralCode => _referralCode;
  Map<String, dynamic>? get user => _user;
  ReservoirStatus? get reservoir => _reservoir;
  List<QueueTier> get tiers => _tiers;
  DashboardData? get dashboard => _dashboard;
  List<QueueOrder> get orders => _orders;
  QueueOrder? get selectedOrder => _selectedOrder;
  List<Map<String, dynamic>> get announcements => _announcements;
  Map<String, dynamic>? get ticketQuote => _ticketQuote;
  String? get lastCreatedMnemonic => _lastCreatedMnemonic;
  String? get lastWsEvent => _lastWsEvent;
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  List<ChatMessage> get officialChatMessages =>
      _chatMessages.where((m) => m.room == ChatConfig.officialRoom).toList();
  int get chatCooldownSeconds => ChatModerationService.cooldownRemaining(_lastChatSentAt);
  bool get canSendChat => chatCooldownSeconds <= 0;
  bool get wsConnected => ws.isConnected;
  String? get wsLastError => ws.lastError;
  String get networkDebugText => NetworkDebug.recentText;
  bool get loading => _loading;
  String? get error => _error;
  double? get nativeBalance => _nativeBalance;
  int get shellTabIndex => _shellTabIndex;
  Map<String, dynamic>? get network => _network;
  Map<String, dynamic>? get performance => _performance;
  Map<String, dynamic>? get burnRewards => _burnRewards;
  AnchorStatus? get anchorStatus => _anchorStatus;
  bool get demoPayments => _demoPayments;
  PodcastAlbum? get podcastAlbum => _podcastAlbum;
  bool get podcastLoading => _podcastLoading;
  String? get podcastError => _podcastError;

  Future<void> loadPodcastFeed({bool force = false}) async {
    if (_podcastAlbum != null && !force) return;
    if (_podcastLoading) return;
    _podcastLoading = true;
    _podcastError = null;
    notifyListeners();
    try {
      _podcastAlbum = await XimalayaFeedService.fetchAlbum();
    } catch (e) {
      _podcastError = '播客加载失败: $e';
    } finally {
      _podcastLoading = false;
      notifyListeners();
    }
  }

  void setShellTab(int index) {
    _shellTabIndex = index;
    notifyListeners();
  }

  int get ticketBalance => _dashboard?.ticketBalance ?? (_user?['ticketBalance'] as num?)?.toInt() ?? 0;

  String get balanceLabel {
    if (_wallet == null) return '—';
    final unit = _wallet!.chain == 'TRON' ? 'TRX' : 'BNB';
    return '${(_nativeBalance ?? 0).toStringAsFixed(2)} $unit';
  }

  Future<void> bootstrap() async {
    _setLoading(true);
    try {
      _demoPayments = await AppSettingsService.isDemoPayments();
      _node = await NodeConfigService.loadCurrentNode();
      _api = RaftApiService(_node!);
      await WalletService.enforceSingleWallet();
      await reloadWallet(skipBalance: true);
    } catch (e) {
      _error = _friendlyNetworkError(e);
    } finally {
      _setLoading(false);
    }
    // 网络同步放后台，避免启动页一直转圈
    unawaited(_syncNetworkInBackground());
  }

  Future<void> _syncNetworkInBackground() async {
    NetworkDebug.log('Boot', '后台网络同步开始 node=${_node?.apiUrl}');
    try {
      final online = await _ensureOnlineNode().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          NetworkDebug.log('Boot', 'HTTP 测速超时 10s');
          return false;
        },
      );
      if (!online) {
        _error ??= 'HTTP不通: ${GatewayPing.lastDetail ?? "见节点设置诊断日志"}';
        NetworkDebug.log('Boot', 'HTTP 测速未通过');
      } else {
        _error = null;
        NetworkDebug.log('Boot', 'HTTP 测速通过');
      }
      await _connectWs();
      await _loadPublicData();
      if (_wallet != null) {
        await refreshAll(allowNodeSwitch: false);
      }
      notifyListeners();
    } catch (e, st) {
      NetworkDebug.log('Boot', '异常: $e');
      NetworkDebug.log('Boot', 'stack: ${st.toString().split('\n').take(2).join(' | ')}');
      _error ??= _friendlyNetworkError(e);
      notifyListeners();
    }
  }

  void clearNetworkDebug() {
    NetworkDebug.clear();
    notifyListeners();
  }

  /// 无需登录也可拉取的公共数据
  Future<void> _loadPublicData() async {
    if (_api == null) return;
    try {
      _reservoir = await _api!.fetchReservoir();
    } catch (_) {}
    try {
      _announcements = await _api!.fetchAnnouncements();
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> _ensureOnlineNode() async {
    if (_node == null) return false;
    final online = await GatewayProbeService.ensureOnline(_node!);
    if (online == null) return false;
    _node = online;
    _api = RaftApiService(_node!);
    notifyListeners();
    return true;
  }

  static String _friendlyNetworkError(Object e) {
    final msg = e.toString();
    if (msg.contains('Stack Overflow') || msg.contains('StackOverflow')) {
      return '节点连接失败：网络模块异常，请安装最新版 App 后重试';
    }
    if (msg.contains('Failed host lookup') ||
        msg.contains('No address associated with hostname') ||
        msg.contains('SocketException') ||
        msg.contains('Network is unreachable')) {
      return '节点连接失败：手机无法解析 book26.top（DNS 问题），请换 4G/5G 网络或到「我的→节点设置」重试';
    }
    if (msg.length > 120) {
      return '节点连接失败：${msg.substring(0, 120)}…';
    }
    return '节点连接失败：$msg';
  }

  Future<void> reloadWallet({bool skipBalance = false}) async {
    _wallet = await WalletService.getActiveAccount();
    _referralCode = _wallet != null ? _wallet!.address.substring(0, 8) : null;
    if (_wallet != null && !skipBalance) {
      try {
        _nativeBalance = await ChainRpcService.getBalance(_wallet!.chain, _wallet!.address)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        _nativeBalance = null;
      }
    } else {
      _nativeBalance = null;
    }
    notifyListeners();
  }

  Future<String> createWallet({String? parentHint, String chain = 'TRON'}) async {
    final derived = WalletDerive.createNew(chain);
    final mnemonic = derived['mnemonic']!;
    _lastCreatedMnemonic = mnemonic;
    await WalletService.importWallet(mnemonic: mnemonic, chain: chain);
    await AppSettingsService.setMnemonicBackupPending(true);
    await reloadWallet(skipBalance: true);
    _registerOnChainInBackground(
      parentAddress: parentHint?.isNotEmpty == true ? parentHint : null,
    );
    return mnemonic;
  }

  Future<void> importWallet(String mnemonic, {String chain = 'TRON'}) async {
    await WalletService.importWallet(mnemonic: mnemonic, chain: chain);
    _lastCreatedMnemonic = null;
    await AppSettingsService.setMnemonicBackupPending(false);
    await reloadWallet(skipBalance: true);
    _registerOnChainInBackground();
    notifyListeners();
  }

  void _registerOnChainInBackground({String? parentAddress}) {
    Future(() async {
      try {
        await _registerOnChain(parentAddress: parentAddress);
      } catch (_) {}
    });
  }

  Future<NodeProbeResult> probeNode(NodeConfig node) async {
    try {
      return await GatewayPing.ping(node.apiUrl).timeout(
        const Duration(seconds: 8),
        onTimeout: () => const NodeProbeResult(online: false),
      );
    } catch (_) {
      return const NodeProbeResult(online: false);
    }
  }

  Future<String> probeNodeError(NodeConfig node) => GatewayPing.pingOrError(node.apiUrl);

  Future<bool> testNodeConnection(NodeConfig node) async => (await probeNode(node)).online;

  Future<void> setNode(
    NodeConfig node, {
    bool refreshData = true,
    bool skipTest = false,
  }) async {
    NodeProbeResult probe;
    if (skipTest) {
      probe = NodeProbeResult(online: node.status == 'online', latencyMs: node.latencyMs);
    } else {
      probe = await probeNode(node);
    }
    _node = node.copyWith(
      status: probe.online ? 'online' : 'offline',
      latencyMs: probe.latencyMs,
      clearLatency: !probe.online,
    );
    _api = RaftApiService(_node!);
    await NodeConfigService.saveCurrentNode(_node!);
    try {
      await _connectWs();
    } catch (_) {}
    notifyListeners();
    if (refreshData && address != null) {
      await refreshAll(allowNodeSwitch: false);
    }
  }

  Future<void> _registerOnChain({String? parentAddress}) async {
    if (_api == null || address == null) return;
    await _api!.registerUser(userAddress: address!, parentAddress: parentAddress);
  }

  Future<void> refreshAll({bool allowNodeSwitch = true}) async {
    if (_api == null || address == null) return;
    _error = null;
    try {
      final ok = await _api!.healthCheck().timeout(const Duration(seconds: 8));
      _node = _node?.copyWith(status: ok ? 'online' : 'offline');
      if (!ok) {
        _error = '节点连接失败：请检查网络，或到「我的 → 节点设置」切换服务器';
        notifyListeners();
        return;
      }
      try {
        final remote = await _api!.fetchTiers();
        if (remote.isNotEmpty) _tiers = remote;
      } catch (_) {}
      _reservoir = await _api!.fetchReservoir();
      _announcements = await _api!.fetchAnnouncements();
      _dashboard = await _api!.fetchDashboard(address!);
      _user = await _api!.fetchUser(address!);
      _orders = await _api!.fetchOrders(address!);
      _network = await _api!.fetchNetwork(address!);
      _performance = await _api!.fetchPerformance(address!);
      _burnRewards = await _api!.fetchBurnRewards(address!);
      try {
        _anchorStatus = await AnchorVerifyService.fetchStatus(_node!);
      } catch (_) {
        _anchorStatus = null;
      }
      if (_wallet != null) {
        try {
          _nativeBalance = await ChainRpcService.getBalance(_wallet!.chain, _wallet!.address);
        } catch (_) {}
      }
    } catch (e) {
      _error = _friendlyNetworkError(e);
    }
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_api == null || address == null) return;
    _user = await _api!.fetchUser(address!);
    notifyListeners();
  }

  /// 排单页下拉刷新：只更新用户/订单数据，档位用内置预算
  Future<void> refreshUserAndOrders() async {
    if (_api == null || address == null) return;
    _error = null;
    try {
      final ok = await _api!.healthCheck().timeout(const Duration(seconds: 5));
      if (!ok) {
        _error = '节点离线，档位仍可查看，提交排单请先连接节点';
        notifyListeners();
        return;
      }
      _dashboard = await _api!.fetchDashboard(address!);
      _user = await _api!.fetchUser(address!);
      _performance = await _api!.fetchPerformance(address!);
      _orders = await _api!.fetchOrders(address!);
    } catch (e) {
      _error = _friendlyNetworkError(e);
    }
    notifyListeners();
  }

  Future<void> loadOrders() async {
    if (_api == null || address == null) return;
    _orders = await _api!.fetchOrders(address!);
    notifyListeners();
  }

  Future<void> loadOrderDetail(String id) async {
    if (_api == null) return;
    _selectedOrder = await _api!.fetchOrder(id);
    notifyListeners();
  }

  Future<void> loadTicketQuote() async {
    if (_api == null) return;
    _ticketQuote = await _api!.ticketQuote();
    notifyListeners();
  }

  Future<String> submitQueueOrder(QueueTier tier) async {
    if (_api == null || address == null) throw Exception('请先创建钱包');
    return _api!.queueOrder(
      userAddress: address!,
      amount: tier.amount,
      ticketCost: tier.ticketCost,
      tierId: tier.id,
      tierName: tier.name,
      expectedExit: tier.exitAmount,
    );
  }

  Future<void> confirmOrderPayment(String orderId, {String? txHash}) async {
    if (_api == null || address == null) return;
    await _api!.confirmOrderPayment(
      userAddress: address!,
      orderId: orderId,
      txHash: txHash,
    );
    await refreshAll();
  }

  Future<String> payOrderOnChain({
    required String orderId,
    required num payAmount,
    String? treasury,
  }) async {
    if (_api == null || _wallet == null || _node == null) {
      throw Exception('未就绪');
    }
    final ok = await AnchorVerifyService.verifyBeforePayment(_node!);
    if (!ok) {
      throw Exception('存证未就绪：请确认 Raft 节点已产生事件');
    }
    final to = treasury ?? PaymentConfig.treasuryAddress;
    final txHash = await ChainTransferService.sendPayment(
      chain: _wallet!.chain,
      fromAddress: _wallet!.address,
      toAddress: to,
      amount: payAmount.toDouble(),
      demoMode: _demoPayments,
    );
    await confirmOrderPayment(orderId, txHash: txHash);
    return txHash;
  }

  Future<void> setDemoPayments(bool value) async {
    _demoPayments = value;
    await AppSettingsService.setDemoPayments(value);
    notifyListeners();
  }

  Future<void> dailyCheckin() async {
    if (_api == null || address == null) return;
    await _api!.dailyCheckin(address!);
    await refreshAll();
  }

  Future<void> submitThankLetter({String? content}) async {
    if (_api == null || address == null) return;
    await _api!.submitThankLetter(address!, content: content);
    await refreshAll();
  }

  Future<void> loadBurnRewards() async {
    if (_api == null || address == null) return;
    _burnRewards = await _api!.fetchBurnRewards(address!);
    notifyListeners();
  }

  /// payMode: self=本机转账 | friend=朋友代付二维码
  Future<Map<String, dynamic>> createTicketPurchase(int qty, {required String payMode}) async {
    if (_api == null || address == null) throw Exception('未登录');
    final treasury = _ticketQuote?['treasury'] as String?;
    return _api!.createTicketPurchase(
      userAddress: address!,
      qty: qty,
      payMode: payMode,
      treasuryHint: treasury,
    );
  }

  bool get isTicketTreasuryReady =>
      RaftApiService.isTreasuryConfigured(_ticketQuote?['treasury'] as String?);

  /// 本机购票：钱包签名转账 → 上报 txHash → 服务端验付款方/收款方/金额
  Future<String> payTicketFromDevice(Map<String, dynamic> purchase) async {
    if (_api == null || _wallet == null || address == null) throw Exception('未就绪');
    final purchaseId = purchase['id'] as String;
    final treasury = purchase['treasury'] as String? ?? PaymentConfig.treasuryAddress;
    final amount = (purchase['payAmount'] as num).toDouble();

    final txHash = await ChainTransferService.sendPayment(
      chain: _wallet!.chain,
      fromAddress: _wallet!.address,
      toAddress: treasury,
      amount: amount,
      demoMode: _demoPayments,
    );

    try {
      await reportTicketTxRetry(purchaseId, txHash);
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('链上交易未找到') && !msg.contains('未找到')) rethrow;
    }
    return txHash;
  }

  Future<void> reportTicketTxRetry(String purchaseId, String txHash) async {
    if (_api == null || address == null) return;
    await _api!.reportTicketTx(
      purchaseId: purchaseId,
      userAddress: address!,
      txHash: txHash,
    );
    await refreshAll();
  }

  Future<Map<String, dynamic>?> fetchTicketPurchase(String id) async {
    if (_api == null) return null;
    return _api!.fetchTicketPurchase(id);
  }

  /// 轮询购票单直到 confirmed 或购票单 expiresAt 到期
  Future<bool> waitTicketPurchaseConfirmed(
    String purchaseId, {
    Duration? interval,
    DateTime? deadline,
  }) async {
    final purchase0 = await fetchTicketPurchase(purchaseId);
    final pollMs = (purchase0?['pollIntervalMs'] as num?)?.toInt() ??
        PaymentConfig.pollInterval.inMilliseconds;
    final waitInterval = interval ?? Duration(milliseconds: pollMs);
    final end = deadline ??
        DateTime.fromMillisecondsSinceEpoch(
          (purchase0?['expiresAt'] as num?)?.toInt() ??
              DateTime.now().add(PaymentConfig.paymentTimeout).millisecondsSinceEpoch,
        );

    while (DateTime.now().isBefore(end)) {
      final purchase = await fetchTicketPurchase(purchaseId);
      if (purchase?['status'] == 'confirmed') {
        await refreshAll();
        return true;
      }
      if (purchase?['status'] == 'expired') return false;
      await Future.delayed(waitInterval);
    }
    return false;
  }

  bool canQueueTier(QueueTier tier) => tierEligibilityGap(tier) == null;

  /// 资格不足时返回原因文案；满足条件返回 null
  String? tierEligibilityGap(QueueTier tier) {
    final direct = (_performance?['directCount'] as num?)?.toInt() ??
        (_user?['directCount'] as num?)?.toInt() ??
        0;
    final middle = (_performance?['middleTierCount'] as num?)?.toInt() ?? 0;
    final large = (_performance?['largeTierCount'] as num?)?.toInt() ?? 0;
    switch (tier.eligibility) {
      case 'none':
        return null;
      case 'direct_referral_10':
        if (direct >= 10) return null;
        return '资格不足：需直推 10 人，当前 $direct 人';
      case '10_middle_tier':
        if (middle >= 10) return null;
        return '资格不足：需 10 个中额下级，当前 $middle 人';
      case '10_large_tier':
        if (large >= 10) return null;
        return '资格不足：需 10 个大额下级，当前 $large 人';
      default:
        return '资格不足';
    }
  }

  Future<void> ensureWsConnected() async {
    if (ws.isConnected || _node == null) return;
    await _connectWs();
  }

  /// 诊断用：单独测 WSS（不改变当前保存的节点）
  Future<bool> testWs(NodeConfig node) async {
    NetworkDebug.log('UI', '开始 WSS 诊断 ${node.wsUrl}');
    final ok = await ws.connect(node);
    NetworkDebug.log('UI', ok ? 'WSS 诊断通过' : 'WSS 诊断失败: ${ws.lastError}');
    notifyListeners();
    return ok;
  }

  Future<void> _connectWs() async {
    if (_node == null) {
      NetworkDebug.log('WSS', '跳过：未配置节点');
      return;
    }
    await _wsSub?.cancel();
    _wsSub = ws.onMessage.listen(_dispatchWsMessage);
    final ok = await ws.connect(_node!);
    NetworkDebug.log('WSS', ok ? 'AppState 连接成功' : 'AppState 连接失败: ${ws.lastError}');
    notifyListeners();
  }

  /// 统一 WSS 分发：任何页面打开前消息已写入 AppState，各页只读数组
  void _dispatchWsMessage(Map<String, dynamic> msg) {
    _lastWsEvent = msg['type']?.toString();
    final type = msg['type']?.toString();

    if (type == 'notification') {
      final topic = msg['topic']?.toString();
      final data = msg['data'];
      switch (topic) {
        case 'reservoir_updates':
          if (data is Map<String, dynamic>) {
            _reservoir = ReservoirStatus.fromJson(data);
          }
          break;
        case 'chat_hall':
        case 'chat_messages':
          _ingestChatPayload(data);
          break;
      }
    } else if (type == 'chat_message' || type == 'chat_broadcast') {
      _ingestChatPayload(msg);
    } else if (type == 'chat_rejected') {
      _error = msg['reason']?.toString();
    }

    notifyListeners();
  }

  void _ingestChatPayload(dynamic payload) {
    if (payload == null) return;
    if (payload is List) {
      for (final item in payload) {
        if (item is Map<String, dynamic>) _appendChatMessage(item);
      }
      return;
    }
    if (payload is Map<String, dynamic>) {
      _appendChatMessage(payload);
    }
  }

  void _appendChatMessage(Map<String, dynamic> json) {
    final msg = ChatMessage.fromJson(json);
    if (msg.content.isEmpty) return;
    if (!ChatModerationService.shouldDisplay(msg.content)) return;
    if (_chatMessages.any((m) => m.id == msg.id)) return;
    _chatMessages.add(msg);
    if (_chatMessages.length > _maxChatMessages) {
      _chatMessages.removeRange(0, _chatMessages.length - _maxChatMessages);
    }
  }

  ChatSendResult sendChatMessage(String content, {String room = ChatConfig.officialRoom}) {
    final check = ChatModerationService.validateSend(
      content: content,
      lastSentAt: _lastChatSentAt,
    );
    if (!check.ok) {
      notifyListeners();
      return check;
    }

    final text = content.trim();
    _lastChatSentAt = DateTime.now();
    ws.sendChat(room: room, content: text, sender: address);
    _appendChatMessage({
      'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
      'room': room,
      'sender': address ?? '我',
      'content': text,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    notifyListeners();
    return ChatSendResult.success();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    ws.dispose();
    super.dispose();
  }
}
