import '../models/node_config.dart';

/// 设计文档 §8.3：客户端内置多网关域名，自动测速切换
class GatewayPresets {
  /// 生产默认双域名
  static const productionDomains = ['book26.top', 'news16.top'];

  static NodeConfig gatewayForDomain(String domain, {String? label}) {
    final host = domain.replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/+$'), '');
    return NodeConfig(
      id: host.replaceAll('.', '_'),
      name: label ?? host,
      apiUrl: 'https://$host',
      wsUrl: 'wss://$host/ws',
      status: 'unknown',
    );
  }

  static List<NodeConfig> defaultNodes() {
    return [
      gatewayForDomain(productionDomains[0], label: '网关 A · book26'),
      gatewayForDomain(productionDomains[1], label: '网关 B · news16'),
      NodeConfig(
        id: 'local',
        name: '本地开发',
        apiUrl: 'http://127.0.0.1:8443',
        wsUrl: 'ws://127.0.0.1:8443/ws',
        status: 'unknown',
      ),
    ];
  }

  /// 从任一在线网关拉取域名列表，失败则用内置默认
  static Future<List<NodeConfig>> fetchRemoteDomainList([String? seedApi]) async {
    return defaultNodes().where((n) => n.id != 'local').toList();
  }
}
