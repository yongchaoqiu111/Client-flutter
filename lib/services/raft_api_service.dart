import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../models/dashboard_data.dart';
import '../models/node_config.dart';
import '../models/node_probe_result.dart';
import '../models/queue_order.dart';
import '../models/queue_tier.dart';
import '../models/reservoir.dart';
import 'gateway_http_client.dart';
import 'gateway_ping.dart';
import 'network_debug.dart';
import 'signature_service.dart';

class RaftApiService {
  RaftApiService(this._node);

  static const _timeout = Duration(seconds: 10);
  static const _commandTimeout = Duration(seconds: 30);

  http.Client get _client => IOClient(HttpClient());

  NodeConfig _node;

  NodeConfig get node => _node;

  void updateNode(NodeConfig node) {
    _node = node;
  }

  String get _base => _node.apiUrl.replaceAll(RegExp(r'/+$'), '');

  Future<http.Response> _get(String path) => _request(
        (client, url) => client.get(url),
        path,
      );

  Future<http.Response> _post(String path, Map<String, dynamic> body) => _request(
        (client, url) => client.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
        path,
      );

  Future<http.Response> _request(
    Future<http.Response> Function(http.Client client, Uri url) call,
    String path,
  ) async {
    final url = Uri.parse('$_base$path');
    try {
      return await call(_client, url).timeout(_timeout);
    } catch (e) {
      NetworkDebug.log('API', 'GET/POST $path 域名失败: $e');
      if (!GatewayHttpClient.isRetriableError(e)) rethrow;
      final ipBase = GatewayHttpClient.ipBaseFor(_base);
      if (ipBase == null) rethrow;
      NetworkDebug.log('API', 'GET/POST $path 改 IP $ipBase');
      final ipClient = IOClient(GatewayHttpClient.createIpDirectClient());
      try {
        return await call(ipClient, Uri.parse('$ipBase$path')).timeout(_timeout);
      } finally {
        ipClient.close();
      }
    }
  }

  Future<NodeProbeResult> probeHealth() => GatewayPing.ping(_base);

  Future<bool> healthCheck() async => (await GatewayPing.ping(_base)).online;

  Future<ReservoirStatus> fetchReservoir() async {
    final res = await _get('/api/reservoir');
    if (res.statusCode != 200) throw Exception('获取蓄水池失败');
    return ReservoirStatus.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<List<QueueTier>> fetchTiers() async {
    final res = await _get('/api/tiers');
    if (res.statusCode != 200) throw Exception('获取档位失败');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final tiers = body['tiers'] as List<dynamic>? ?? [];
    return tiers
        .map((e) => QueueTier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchUser(String address) async {
    final res = await _get('/api/user/$address');
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body.containsKey('error')) return null;
    return body;
  }

  Future<void> submitSignedCommand(Map<String, dynamic> signedBody) async {
    final res = await _post('/api/command', signedBody);
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? '提交失败');
    }
  }

  Future<void> submitCommand(Map<String, dynamic> command, {String? signerAddress}) async {
    if (signerAddress != null) {
      final signed = SignatureService.signCommand(
        userAddress: signerAddress,
        command: command,
      );
      return submitSignedCommand(signed);
    }
    final res = await _post('/api/command', command);
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? '提交失败');
    }
  }

  Future<void> registerUser({
    required String userAddress,
    String? parentAddress,
  }) async {
    await submitCommand(
      {
        'type': 'REGISTER_USER',
        'userAddress': userAddress,
        'parentAddress': parentAddress,
      },
      signerAddress: userAddress,
    );
  }

  Future<String> queueOrder({
    required String userAddress,
    required int amount,
    required int ticketCost,
    String? tierId,
    String? tierName,
    num? expectedExit,
  }) async {
    final orderId = 'ord_${DateTime.now().millisecondsSinceEpoch}';
    await submitCommand(
      {
        'type': 'QUEUE_ORDER',
        'orderId': orderId,
        'userAddress': userAddress,
        'amount': amount,
        'ticketCost': ticketCost,
        'tierId': tierId,
        'tierName': tierName,
        'expectedExit': expectedExit,
      },
      signerAddress: userAddress,
    );
    return orderId;
  }

  Future<void> confirmOrderPayment({
    required String userAddress,
    required String orderId,
    String? txHash,
  }) async {
    await submitCommand(
      {
        'type': 'CONFIRM_PAYMENT',
        'userAddress': userAddress,
        'orderId': orderId,
        'txHash': txHash ?? 'local_confirm_${DateTime.now().millisecondsSinceEpoch}',
      },
      signerAddress: userAddress,
    );
  }

  Future<Map<String, dynamic>> ticketQuote() async {
    final res = await _get('/api/ticket/quote');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// 创建待支付购票单，等 listener 查波场到账后 CONFIRM_TICKET_PAYMENT
  static bool isTreasuryConfigured(String? treasury) {
    if (treasury == null || treasury.isEmpty) return false;
    final t = treasury.trim().toUpperCase();
    return t.startsWith('T') && !t.contains('PLACEHOLDER');
  }

  Future<Map<String, dynamic>?> fetchLatestPendingTicketPurchase(String userAddress) async {
    final res = await _get('/api/user/$userAddress/ticket-purchase/pending');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body.containsKey('error')) return null;
    return body;
  }

  Future<Map<String, dynamic>> createTicketPurchase({
    required String userAddress,
    required int qty,
    required String payMode,
    String? treasuryHint,
  }) async {
    if (!isTreasuryConfigured(treasuryHint)) {
      throw Exception(
        '服务端收款地址未配置（当前为占位符）。\n'
        '请在服务器 deploy/.env 设置 TREASURY_ADDRESS 并重新部署 node1。',
      );
    }

    final signed = SignatureService.signCommand(
      userAddress: userAddress,
      command: {
        'type': 'BUY_TICKET',
        'userAddress': userAddress,
        'amount': qty,
        'payMode': payMode,
      },
    );
    NetworkDebug.log('API', 'BUY_TICKET payMode=$payMode qty=$qty');
    final res = await _post('/api/command', signed).timeout(
      _commandTimeout,
      onTimeout: () => throw Exception('创建购票单超时（${ _commandTimeout.inSeconds}s），请检查节点连接'),
    );
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? '创建购票单失败');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    Map<String, dynamic>? purchase = body['purchase'] as Map<String, dynamic>?;
    purchase ??= await fetchLatestPendingTicketPurchase(userAddress);
    if (purchase == null || purchase.containsKey('error')) {
      throw Exception(
        '服务端未返回购票单。请确认 book26.top 已部署最新 WSS-server（含 pending 购票与 TREASURY_ADDRESS）。',
      );
    }
    if (!isTreasuryConfigured(purchase['treasury'] as String?)) {
      throw Exception('购票单收款地址无效，请检查服务器 TREASURY_ADDRESS 环境变量');
    }
    return purchase;
  }

  Future<Map<String, dynamic>?> fetchTicketPurchase(String id) async {
    final res = await _get('/api/ticket/purchase/$id');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body.containsKey('error')) return null;
    return body;
  }

  /// 本机转账后上报 txHash，服务端按付款方+收款方+金额验链
  Future<Map<String, dynamic>> reportTicketTx({
    required String purchaseId,
    required String userAddress,
    required String txHash,
  }) async {
    final res = await _post(
      '/api/ticket/purchase/$purchaseId/report-tx',
      {'purchaseId': purchaseId, 'userAddress': userAddress, 'txHash': txHash},
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || body['success'] != true) {
      throw Exception(body['error'] ?? '上报转账失败');
    }
    return body;
  }

  Future<DashboardData> fetchDashboard(String address) async {
    final res = await _get('/api/user/$address/dashboard');
    return DashboardData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<QueueOrder>> fetchOrders(String address) async {
    final res = await _get('/api/user/$address/orders');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['orders'] as List<dynamic>? ?? [];
    return list.map((e) => QueueOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<QueueOrder?> fetchOrder(String id) async {
    final res = await _get('/api/order/$id');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body.containsKey('error')) return null;
    return QueueOrder.fromJson(body);
  }

  Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    final res = await _get('/api/announcements');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['announcements'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> fetchNetwork(String address) async {
    final res = await _get('/api/user/$address/network');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchPerformance(String address) async {
    final res = await _get('/api/user/$address/performance');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchBurnRewards(String address) async {
    final res = await _get('/api/user/$address/burn-rewards');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchPendingPayments() async {
    final res = await _get('/api/payments/pending');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> dailyCheckin(String userAddress) async {
    await submitCommand(
      {'type': 'DAILY_CHECKIN', 'userAddress': userAddress},
      signerAddress: userAddress,
    );
  }

  Future<void> submitThankLetter(String userAddress, {String? content}) async {
    await submitCommand(
      {
        'type': 'SUBMIT_THANK_LETTER',
        'userAddress': userAddress,
        'content': content ?? '',
      },
      signerAddress: userAddress,
    );
  }
}
