class NodeConfig {
  NodeConfig({
    required this.id,
    required this.name,
    required this.apiUrl,
    required this.wsUrl,
    this.status = 'unknown',
    this.latencyMs,
  });

  final String id;
  final String name;
  final String apiUrl;
  final String wsUrl;
  final String status;
  final int? latencyMs;

  factory NodeConfig.fromJson(Map<String, dynamic> json) {
    return NodeConfig(
      id: json['id'] as String? ?? 'node1',
      name: json['name'] as String? ?? '节点',
      apiUrl: json['apiUrl'] as String? ?? '',
      wsUrl: json['wsUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      latencyMs: (json['latencyMs'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'apiUrl': apiUrl,
        'wsUrl': wsUrl,
        'status': status,
        if (latencyMs != null) 'latencyMs': latencyMs,
      };

  String get displayStatus {
    switch (status) {
      case 'probing':
        return '检测中…';
      case 'online':
        if (latencyMs != null) return '在线 · ${latencyMs}ms';
        return '在线';
      case 'offline':
        return '离线';
      default:
        return '未知';
    }
  }

  NodeConfig copyWith({String? status, int? latencyMs, bool clearLatency = false}) {
    return NodeConfig(
      id: id,
      name: name,
      apiUrl: apiUrl,
      wsUrl: wsUrl,
      status: status ?? this.status,
      latencyMs: clearLatency ? null : (latencyMs ?? this.latencyMs),
    );
  }

  static NodeConfig defaultGateway() {
    return NodeConfig(
      id: 'book26_top',
      name: '网关 A · book26',
      apiUrl: 'https://book26.top',
      wsUrl: 'wss://book26.top/ws',
      status: 'unknown',
    );
  }
}
