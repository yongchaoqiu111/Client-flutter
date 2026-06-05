import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/gateway_presets.dart';
import '../models/node_config.dart';
import '../providers/app_state.dart';

/// 服务器选择：点选后只测一次当前地址
class NodePickScreen extends StatefulWidget {
  const NodePickScreen({super.key});

  @override
  State<NodePickScreen> createState() => _NodePickScreenState();
}

class _NodePickScreenState extends State<NodePickScreen> {
  List<NodeConfig> _nodes = GatewayPresets.defaultNodes().where((n) => n.id != 'local').toList();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('选择服务器')),
      body: ListView.builder(
        itemCount: _nodes.length,
        itemBuilder: (context, i) {
          final n = _nodes[i];
          return ListTile(
            title: Text(n.name),
            subtitle: Text(n.apiUrl),
            trailing: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            onTap: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await context.read<AppState>().setNode(n, refreshData: false);
                      final state = context.read<AppState>();
                      if (state.address != null) {
                        await state.refreshAll(allowNodeSwitch: false);
                      }
                      if (context.mounted) context.pop();
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          );
        },
      ),
    );
  }
}
