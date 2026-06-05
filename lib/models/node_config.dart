class NodeConfig {
  NodeConfig({
    required this.id,
    required this.name,
    required this.apiUrl,
    required this.wsUrl,
    this.status = 'unknown',
  });

  final String id;
  final String name;
  final String apiUrl;
  final String wsUrl;
  final String status;

  factory NodeConfig.fromJson(Map<String, dynamic> json) {
    return NodeConfig(
      id: json['id'] as String? ?? 'node1',
      name: json['name'] as String? ?? '节点',
      apiUrl: json['apiUrl'] as String? ?? '',
      wsUrl: json['wsUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'apiUrl': apiUrl,
        'wsUrl': wsUrl,
        'status': status,
      };

  NodeConfig copyWith({String? status}) {
    return NodeConfig(
      id: id,
      name: name,
      apiUrl: apiUrl,
      wsUrl: wsUrl,
      status: status ?? this.status,
    );
  }

  static NodeConfig defaultGateway() {
    return NodeConfig(
      id: 'gateway',
      name: '默认网关',
      apiUrl: 'http://127.0.0.1:8443',
      wsUrl: 'ws://127.0.0.1:8443/ws',
      status: 'online',
    );
  }
}
