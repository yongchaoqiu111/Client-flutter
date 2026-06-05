import '../models/node_config.dart';

/// 设计文档 §8.3：客户端内置多网关域名，自动测速切换
class GatewayPresets {
  static List<NodeConfig> defaultNodes() {
    const host = '127.0.0.1';
    return [
      NodeConfig(
        id: 'gateway',
        name: '本地网关',
        apiUrl: 'http://$host:8443',
        wsUrl: 'ws://$host:8443/ws',
        status: 'unknown',
      ),
      NodeConfig(
        id: 'node1',
        name: '共识节点 1',
        apiUrl: 'http://$host:3001',
        wsUrl: 'ws://$host:3001',
        status: 'unknown',
      ),
      NodeConfig(
        id: 'node2',
        name: '共识节点 2',
        apiUrl: 'http://$host:3002',
        wsUrl: 'ws://$host:3002',
        status: 'unknown',
      ),
      NodeConfig(
        id: 'node3',
        name: '共识节点 3',
        apiUrl: 'http://$host:3003',
        wsUrl: 'ws://$host:3003',
        status: 'unknown',
      ),
    ];
  }

  /// 生产环境从 CDN 拉取域名列表（§8.4）
  static Future<List<NodeConfig>> fetchRemoteDomainList(Uri configUrl) async {
    // TODO: GET domains.json → 解析为 NodeConfig 列表
    return defaultNodes();
  }
}
