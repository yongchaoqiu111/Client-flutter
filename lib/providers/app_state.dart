import 'package:flutter/foundation.dart';

import '../models/dashboard_data.dart';
import '../models/node_config.dart';
import '../models/queue_order.dart';
import '../models/queue_tier.dart';
import '../models/reservoir.dart';
import '../models/wallet_account.dart';
import '../config/payment_config.dart';
import '../services/anchor_verify_service.dart';
import '../services/app_settings_service.dart';
import '../services/chain_rpc_service.dart';
import '../services/chain_transfer_service.dart';
import '../services/node_config_service.dart';
import '../services/raft_api_service.dart';
import '../services/wallet_service.dart';
import '../services/ws_service.dart';
import '../utils/wallet_derive.dart';

class AppState extends ChangeNotifier {
  NodeConfig? _node;
  RaftApiService? _api;
  final WsService ws = WsService();

  WalletAccount? _wallet;
  double? _nativeBalance;
  String? _referralCode;
  Map<String, dynamic>? _user;
  ReservoirStatus? _reservoir;
  List<QueueTier> _tiers = [];
  DashboardData? _dashboard;
  List<QueueOrder> _orders = [];
  QueueOrder? _selectedOrder;
  List<Map<String, dynamic>> _announcements = [];
  Map<String, dynamic>? _ticketQuote;
  String? _lastWsEvent;
  bool _loading = false;
  String? _error;
  String? _lastCreatedMnemonic;
  int _shellTabIndex = 0;
  Map<String, dynamic>? _network;
  Map<String, dynamic>? _performance;
  Map<String, dynamic>? _burnRewards;
  AnchorStatus? _anchorStatus;
  bool _demoPayments = PaymentConfig.demoPaymentsDefault;

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
  bool get loading => _loading;
  String? get error => _error;
  double? get nativeBalance => _nativeBalance;
  int get shellTabIndex => _shellTabIndex;
  Map<String, dynamic>? get network => _network;
  Map<String, dynamic>? get performance => _performance;
  Map<String, dynamic>? get burnRewards => _burnRewards;
  AnchorStatus? get anchorStatus => _anchorStatus;
  bool get demoPayments => _demoPayments;

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
      await reloadWallet();
      if (_wallet != null) {
        await refreshAll();
        await _connectWs();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reloadWallet() async {
    _wallet = await WalletService.getActiveAccount();
    _referralCode = _wallet != null ? _wallet!.address.substring(0, 8) : null;
    if (_wallet != null) {
      try {
        _nativeBalance = await ChainRpcService.getBalance(_wallet!.chain, _wallet!.address);
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
    _lastCreatedMnemonic = derived['mnemonic'];
    await WalletService.importWallet(mnemonic: derived['mnemonic']!, chain: chain);
    await reloadWallet();
    await _registerOnChain(parentAddress: parentHint?.isNotEmpty == true ? parentHint : null);
    return derived['mnemonic']!;
  }

  Future<void> importWallet(String mnemonic, {String chain = 'TRON'}) async {
    await WalletService.importWallet(mnemonic: mnemonic, chain: chain);
    _lastCreatedMnemonic = null;
    await reloadWallet();
    await _registerOnChain();
    notifyListeners();
  }

  Future<void> setNode(NodeConfig node) async {
    _node = node;
    _api = RaftApiService(node);
    await NodeConfigService.saveCurrentNode(node);
    await refreshAll();
    await _connectWs();
    notifyListeners();
  }

  Future<void> _registerOnChain({String? parentAddress}) async {
    if (_api == null || address == null) return;
    try {
      await _api!.registerUser(userAddress: address!, parentAddress: parentAddress);
    } catch (_) {}
    await refreshUser();
  }

  Future<void> refreshAll() async {
    if (_api == null || address == null) return;
    _error = null;
    try {
      final ok = await _api!.healthCheck();
      _node = _node?.copyWith(status: ok ? 'online' : 'offline');
      _tiers = await _api!.fetchTiers();
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
      _error = '节点连接失败: $e';
    }
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_api == null || address == null) return;
    _user = await _api!.fetchUser(address!);
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
    final payAmount = tier.amount + (DateTime.now().millisecond % 100) / 100;
    return _api!.queueOrder(
      userAddress: address!,
      amount: tier.amount,
      ticketCost: tier.ticketCost,
      payAmount: payAmount,
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

  Future<void> buyTickets(int qty) async {
    if (_api == null || address == null) throw Exception('未登录');
    await _api!.ticketQuote();
    await _api!.submitCommand(
      {
        'type': 'BUY_TICKET',
        'userAddress': address!,
        'amount': qty,
        'txHash': 'local_${DateTime.now().millisecondsSinceEpoch}',
      },
      signerAddress: address,
    );
    await refreshAll();
  }

  bool canQueueTier(QueueTier tier) {
    final direct = (_user?['directCount'] as num?)?.toInt() ?? 0;
    switch (tier.eligibility) {
      case 'none':
        return true;
      case 'direct_referral_10':
        return direct >= 10;
      default:
        return true;
    }
  }

  Future<void> _connectWs() async {
    if (_node == null) return;
    ws.removeListener(_onWs);
    ws.addListener(_onWs);
    try {
      await ws.connect(_node!);
      ws.subscribeReservoir();
    } catch (_) {}
  }

  void _onWs(Map<String, dynamic> msg) {
    _lastWsEvent = msg['type']?.toString();
    if (msg['type'] == 'notification' && msg['topic'] == 'reservoir_updates') {
      _reservoir = ReservoirStatus.fromJson(msg['data'] as Map<String, dynamic>);
    }
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    ws.disconnect();
    super.dispose();
  }
}
