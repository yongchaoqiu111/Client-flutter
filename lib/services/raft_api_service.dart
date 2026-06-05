import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dashboard_data.dart';
import '../models/node_config.dart';
import '../models/queue_order.dart';
import '../models/queue_tier.dart';
import '../models/reservoir.dart';
import 'signature_service.dart';

class RaftApiService {
  RaftApiService(this._node);

  NodeConfig _node;

  NodeConfig get node => _node;

  void updateNode(NodeConfig node) {
    _node = node;
  }

  String get _base => _node.apiUrl.replaceAll(RegExp(r'/+$'), '');

  Future<bool> healthCheck() async {
    try {
      final uri = Uri.parse('$_base/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      try {
        final res = await http
            .get(Uri.parse('$_base/api/status'))
            .timeout(const Duration(seconds: 3));
        return res.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
  }

  Future<ReservoirStatus> fetchReservoir() async {
    final res = await http.get(Uri.parse('$_base/api/reservoir'));
    if (res.statusCode != 200) throw Exception('获取蓄水池失败');
    return ReservoirStatus.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<List<QueueTier>> fetchTiers() async {
    final res = await http.get(Uri.parse('$_base/api/tiers'));
    if (res.statusCode != 200) throw Exception('获取档位失败');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final tiers = body['tiers'] as List<dynamic>? ?? [];
    return tiers
        .map((e) => QueueTier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchUser(String address) async {
    final res = await http.get(Uri.parse('$_base/api/user/$address'));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body.containsKey('error')) return null;
    return body;
  }

  Future<void> submitSignedCommand(Map<String, dynamic> signedBody) async {
    final res = await http.post(
      Uri.parse('$_base/api/command'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(signedBody),
    );
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
    final res = await http.post(
      Uri.parse('$_base/api/command'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(command),
    );
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
    required num payAmount,
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
        'payAmount': payAmount,
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
    final res = await http.get(Uri.parse('$_base/api/ticket/quote'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<DashboardData> fetchDashboard(String address) async {
    final res = await http.get(Uri.parse('$_base/api/user/$address/dashboard'));
    return DashboardData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<QueueOrder>> fetchOrders(String address) async {
    final res = await http.get(Uri.parse('$_base/api/user/$address/orders'));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['orders'] as List<dynamic>? ?? [];
    return list.map((e) => QueueOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<QueueOrder?> fetchOrder(String id) async {
    final res = await http.get(Uri.parse('$_base/api/order/$id'));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body.containsKey('error')) return null;
    return QueueOrder.fromJson(body);
  }

  Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    final res = await http.get(Uri.parse('$_base/api/announcements'));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['announcements'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> fetchNetwork(String address) async {
    final res = await http.get(Uri.parse('$_base/api/user/$address/network'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchPerformance(String address) async {
    final res = await http.get(Uri.parse('$_base/api/user/$address/performance'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchBurnRewards(String address) async {
    final res = await http.get(Uri.parse('$_base/api/user/$address/burn-rewards'));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchPendingPayments() async {
    final res = await http.get(Uri.parse('$_base/api/payments/pending'));
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
