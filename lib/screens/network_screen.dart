import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AppState>().dashboard;
    final net = context.watch<AppState>().network;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的团队'),
        actions: [
          TextButton(
            onPressed: () => context.push('/network/assessment'),
            child: const Text('考核详情'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refreshAll(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _miniStat('团队', '${d?.teamCount ?? net?['teamCount'] ?? 0}'),
                _miniStat('一代', '${net?['gen1Count'] ?? 0}'),
                _miniStat('二代', '${net?['gen2Count'] ?? 0}'),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('团队考核（今日）', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('打卡率 ${d?.checkinRate ?? 0}%'),
                    Text('感谢信 ${d?.thankRate ?? 0}%'),
                    Text('等级 ${d?.assessmentLevel ?? '—'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('今日排单券价格'),
                trailing: Text('${d?.ticketPriceToday ?? 100} TRX/张'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  net?['treeText'] as String? ?? '暂无下级',
                  style: const TextStyle(fontFamily: 'monospace', height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
