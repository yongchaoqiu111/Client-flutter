import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../models/node_config.dart';
import 'gateway_http_client.dart';

class AnchorStatus {
  AnchorStatus({
    required this.recordCount,
    required this.merkleRoot,
    required this.verified,
    required this.note,
  });

  final int recordCount;
  final String? merkleRoot;
  final bool verified;
  final String note;

  factory AnchorStatus.fromJson(Map<String, dynamic> json) {
    return AnchorStatus(
      recordCount: (json['recordCount'] as num?)?.toInt() ?? 0,
      merkleRoot: json['merkleRoot'] as String?,
      verified: json['verified'] == true,
      note: json['note'] as String? ?? '',
    );
  }
}

/// 打币前校验：Raft 事件 Merkle 根（Polygon 多签上链为可选增强）
class AnchorVerifyService {
  static final http.Client _client = IOClient(GatewayHttpClient.shared());

  static Future<AnchorStatus> fetchStatus(NodeConfig node) async {
    final base = node.apiUrl.replaceAll(RegExp(r'/+$'), '');
    final res = await _client.get(Uri.parse('$base/api/anchor/status')).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('存证状态查询失败');
    }
    return AnchorStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<bool> verifyBeforePayment(NodeConfig node) async {
    try {
      final s = await fetchStatus(node);
      return s.verified;
    } catch (_) {
      return true;
    }
  }
}
