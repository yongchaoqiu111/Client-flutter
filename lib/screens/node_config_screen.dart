import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/node_config.dart';
import '../providers/app_state.dart';
import '../services/node_config_service.dart';

/// 服务器连接设置（前端布局方案 §5.5、§5.6）
class NodeConfigScreen extends StatefulWidget {
  const NodeConfigScreen({super.key});

  @override
  State<NodeConfigScreen> createState() => _NodeConfigScreenState();
}

class _NodeConfigScreenState extends State<NodeConfigScreen> {
  List<NodeConfig> _nodes = [];
  final _apiCtrl = TextEditingController();
  final _wsCtrl = TextEditingController();
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final nodes = await NodeConfigService.loadNodes();
    final current = await NodeConfigService.loadCurrentNode();
    setState(() {
      _nodes = nodes;
      _apiCtrl.text = current.apiUrl;
      _wsCtrl.text = current.wsUrl;
    });
  }

  Future<void> _testAndSave() async {
    setState(() => _testing = true);
    final node = NodeConfig(
      id: 'custom',
      name: '自定义节点',
      apiUrl: _apiCtrl.text.trim(),
      wsUrl: _wsCtrl.text.trim(),
    );
    await context.read<AppState>().setNode(node);
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已连接: ${context.read<AppState>().node?.status}')),
    );
  }

  Future<void> _useNode(NodeConfig node) async {
    await context.read<AppState>().setNode(node);
    setState(() {
      _apiCtrl.text = node.apiUrl;
      _wsCtrl.text = node.wsUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('服务器连接设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _apiCtrl,
            decoration: const InputDecoration(labelText: 'HTTP API 地址'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _wsCtrl,
            decoration: const InputDecoration(labelText: 'WebSocket (WSS) 地址'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _testing ? null : _testAndSave,
            child: Text(_testing ? '测试中…' : '测试并保存'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/me/nodes/pick'),
            child: const Text('从预设列表选择服务器'),
          ),
          const SizedBox(height: 24),
          const Text('节点列表', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._nodes.map((n) {
            final online = n.status == 'online';
            return ListTile(
              title: Text(n.name),
              subtitle: Text('${n.apiUrl}\n延迟/状态: ${n.status}'),
              trailing: Icon(online ? Icons.circle : Icons.circle_outlined,
                  color: online ? Colors.green : Colors.grey, size: 12),
              onTap: () => _useNode(n),
            );
          }),
        ],
      ),
    );
  }
}
