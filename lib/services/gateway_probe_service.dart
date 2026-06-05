import '../config/gateway_presets.dart';
import '../models/node_config.dart';
import '../models/node_probe_result.dart';
import 'gateway_ping.dart';
import 'node_config_service.dart';

class GatewayProbeService {
  static Future<NodeConfig> probeOne(NodeConfig node) async {
    if (node.id == 'local') {
      return node.copyWith(status: 'offline', clearLatency: true);
    }
    final result = await GatewayPing.ping(node.apiUrl);
    return node.copyWith(
      status: result.online ? 'online' : 'offline',
      latencyMs: result.latencyMs,
      clearLatency: !result.online,
    );
  }

  /// 只测当前节点，不批量扫全部网关
  static Future<NodeConfig?> ensureOnline(NodeConfig current) async {
    final probed = await probeOne(current);
    if (probed.status == 'online') {
      await NodeConfigService.saveCurrentNode(probed);
      return probed;
    }
    return null;
  }
}
