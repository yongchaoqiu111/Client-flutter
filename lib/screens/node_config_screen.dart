import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/gateway_presets.dart';
import '../models/node_config.dart';
import '../providers/app_state.dart';
import '../services/gateway_probe_service.dart';
import '../services/gateway_ping.dart';
import '../services/network_debug.dart';
import '../services/node_config_service.dart';
import '../widgets/network_debug_panel.dart';

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
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiCtrl.dispose();
    _wsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await NodeConfigService.loadNodes();
    final defaults = GatewayPresets.defaultNodes().where((n) => n.id != 'local').toList();
    final nodes = <NodeConfig>[
      ...defaults,
      ...saved.where((s) => !defaults.any((d) => d.id == s.id)),
    ];
    final current = await NodeConfigService.loadCurrentNode();
    if (!mounted) return;
    setState(() {
      _nodes = nodes;
      _apiCtrl.text = current.apiUrl;
      _wsCtrl.text = current.wsUrl;
    });
  }

  Future<void> _probeCurrentInput() async {
    final api = _apiCtrl.text.trim();
    if (api.isEmpty || !mounted) return;
    setState(() => _probing = true);
    final node = _buildNodeFromInput();
    final probed = await GatewayProbeService.probeOne(node);
    if (!mounted) return;
    setState(() {
      _probing = false;
      _nodes = _nodes.map((n) {
        if (n.apiUrl == probed.apiUrl) return probed;
        return n;
      }).toList();
    });
  }

  NodeConfig _buildNodeFromInput() {
    return NodeConfig(
      id: 'custom',
      name: '自定义节点',
      apiUrl: _apiCtrl.text.trim(),
      wsUrl: _wsCtrl.text.trim(),
    );
  }

  Future<void> _testAndSave() async {
    final api = _apiCtrl.text.trim();
    final ws = _wsCtrl.text.trim();
    if (api.isEmpty || ws.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写 HTTP 与 WebSocket 地址')),
      );
      return;
    }

    setState(() => _testing = true);
    try {
      final node = _buildNodeFromInput();
      final state = context.read<AppState>();
      NetworkDebug.log('UI', '═══ 用户点击「测试并保存」═══');
      NetworkDebug.log('UI', 'HTTP=${node.apiUrl} WSS=${node.wsUrl}');

      final probe = await state.probeNode(node);
      final wsOk = await state.testWs(node);
      if (!mounted) return;

      final summary = StringBuffer()
        ..write(probe.online ? 'HTTP✓ ${probe.latencyMs}ms' : 'HTTP✗ ${GatewayPing.lastDetail ?? ""}')
        ..write(' | ')
        ..write(wsOk ? 'WSS✓' : 'WSS✗ ${state.wsLastError ?? ""}');
      NetworkDebug.log('UI', '结果: $summary');

      if (probe.online) {
        final saved = node.copyWith(status: 'online', latencyMs: probe.latencyMs);
        await state.setNode(saved, refreshData: false, skipTest: true);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary.toString()),
          duration: const Duration(seconds: 6),
        ),
      );
      if (probe.online && state.address != null) {
        state.refreshAll(allowNodeSwitch: false);
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _useNode(NodeConfig node) async {
    await context.read<AppState>().setNode(node, refreshData: false);
    if (!mounted) return;
    setState(() {
      _apiCtrl.text = node.apiUrl;
      _wsCtrl.text = node.wsUrl;
    });
    final state = context.read<AppState>();
    if (state.address != null) {
      state.refreshAll(allowNodeSwitch: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _testing || _probing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器连接设置'),
        actions: [
          IconButton(
            icon: _probing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: busy ? null : _probeCurrentInput,
            tooltip: '测试当前地址',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _apiCtrl,
            enabled: !_testing,
            decoration: const InputDecoration(labelText: 'HTTP API 地址'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _wsCtrl,
            enabled: !_testing,
            decoration: const InputDecoration(labelText: 'WebSocket (WSS) 地址'),
          ),
          const SizedBox(height: 8),
          const Text(
            '点「测试并保存」会依次测 HTTP 首页 + WSS，详细步骤见下方诊断日志',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _testing ? null : _testAndSave,
            child: Text(_testing ? '测试中…' : '测试并保存'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: busy ? null : () => context.push('/me/nodes/pick'),
            child: const Text('从预设列表选择服务器'),
          ),
          const SizedBox(height: 16),
          const NetworkDebugPanel(),
          const SizedBox(height: 24),
          const Text('节点列表', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._nodes.map((n) {
            final online = n.status == 'online';
            return ListTile(
              title: Text(n.name),
              subtitle: Text('${n.apiUrl}\n延迟/状态: ${n.displayStatus}'),
              trailing: Icon(
                n.status == 'probing'
                    ? Icons.hourglass_empty
                    : (online ? Icons.circle : Icons.circle_outlined),
                color: n.status == 'probing'
                    ? Colors.orange
                    : (online ? Colors.green : Colors.grey),
                size: 12,
              ),
              onTap: busy ? null : () => _useNode(n),
            );
          }),
        ],
      ),
    );
  }
}
