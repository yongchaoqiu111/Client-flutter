import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/network_debug.dart';

/// 排查日志面板：聊天/WSS/HTTP 全链路，可复制发给技术支持
class NetworkDebugPanel extends StatefulWidget {
  const NetworkDebugPanel({
    super.key,
    this.title = '排查日志',
    this.hint = '发送消息、刷新、连接 WSS 时会自动记录；点「复制」可发给我分析',
    this.initiallyExpanded = false,
    this.compact = false,
  });

  final String title;
  final String hint;
  final bool initiallyExpanded;
  final bool compact;

  @override
  State<NetworkDebugPanel> createState() => _NetworkDebugPanelState();
}

class _NetworkDebugPanelState extends State<NetworkDebugPanel> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final text = context.watch<AppState>().networkDebugText;
    final count = NetworkDebug.count;

    if (widget.compact) {
      return ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        onExpansionChanged: (v) => setState(() => _expanded = v),
        title: Text(
          '${widget.title} ($count 条)',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: _expanded ? null : Text(widget.hint, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        children: [_logBody(context, text)],
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${widget.title} ($count)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                TextButton(onPressed: () => context.read<AppState>().clearNetworkDebug(), child: const Text('清空')),
                TextButton(onPressed: () => _copy(context, text), child: const Text('复制')),
              ],
            ),
            Text(widget.hint, style: const TextStyle(color: Colors.white54, fontSize: 10, height: 1.35)),
            const SizedBox(height: 6),
            _logBox(text),
          ],
        ),
      ),
    );
  }

  Widget _logBody(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.hint, style: const TextStyle(fontSize: 10, color: Colors.white54))),
              TextButton(onPressed: () => context.read<AppState>().clearNetworkDebug(), child: const Text('清空')),
              TextButton(onPressed: () => _copy(context, text), child: const Text('复制')),
            ],
          ),
          _logBox(text),
        ],
      ),
    );
  }

  Widget _logBox(String text) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3A5A)),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, height: 1.4),
        ),
      ),
    );
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('排查日志已复制，可粘贴发给我')),
    );
  }
}
