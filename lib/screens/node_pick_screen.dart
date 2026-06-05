import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/gateway_presets.dart';
import '../models/node_config.dart';
import '../providers/app_state.dart';
import '../services/raft_api_service.dart';

/// 服务器选择（§5.6）
class NodePickScreen extends StatefulWidget {
  const NodePickScreen({super.key});

  @override
  State<NodePickScreen> createState() => _NodePickScreenState();
}

class _NodePickScreenState extends State<NodePickScreen> {
  List<NodeConfig> _nodes = [];
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    _nodes = GatewayPresets.defaultNodes();
    WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
  }

  Future<void> _probe() async {
    setState(() => _probing = true);
    final updated = <NodeConfig>[];
    for (final n in _nodes) {
      final ok = await RaftApiService(n).healthCheck();
      updated.add(n.copyWith(status: ok ? 'online' : 'offline'));
    }
    if (mounted) {
      setState(() {
        _nodes = updated;
        _probing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择服务器'),
        actions: [
          IconButton(
            icon: _probing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _probing ? null : _probe,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _nodes.length,
        itemBuilder: (context, i) {
          final n = _nodes[i];
          return ListTile(
            title: Text(n.name),
            subtitle: Text(n.apiUrl),
            trailing: Text(
              n.status,
              style: TextStyle(color: n.status == 'online' ? Colors.green : Colors.grey),
            ),
            onTap: () async {
              await context.read<AppState>().setNode(n);
              if (context.mounted) context.pop();
            },
          );
        },
      ),
    );
  }
}
