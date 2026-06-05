import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

/// 网络诊断日志面板（直接显示在 App 里，不用连电脑看 logcat）
class NetworkDebugPanel extends StatelessWidget {
  const NetworkDebugPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.watch<AppState>().networkDebugText;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('网络诊断日志', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.read<AppState>().clearNetworkDebug(),
                  child: const Text('清空'),
                ),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('日志已复制，可发给我')),
                    );
                  },
                  child: const Text('复制'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '测试后这里会显示 HTTP / WSS 每一步成功或失败原因',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
