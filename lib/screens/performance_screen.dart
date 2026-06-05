import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AppState>().dashboard;
    final p = context.watch<AppState>().performance ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text('我的业绩')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refreshAll(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(title: const Text('团队人数'), trailing: Text('${p['teamCount'] ?? d?.teamCount ?? 0}')),
            ListTile(title: const Text('直推人数'), trailing: Text('${p['directCount'] ?? 0}')),
            ListTile(title: const Text('累积收益'), trailing: Text('${p['rewardBalance'] ?? d?.rewardBalance ?? 0} TRX')),
            ListTile(title: const Text('排单券余额'), trailing: Text('${p['ticketBalance'] ?? d?.ticketBalance ?? 0} 张')),
            ListTile(title: const Text('订单数'), trailing: Text('${p['orderCount'] ?? 0}')),
            ListTile(title: const Text('排单总金额'), trailing: Text('${p['totalQueuedAmount'] ?? 0} TRX')),
            ListTile(title: const Text('已出场金额'), trailing: Text('${p['totalExitedAmount'] ?? 0} TRX')),
            ListTile(title: const Text('烧伤奖励累计'), trailing: Text('${p['burnBonusTotal'] ?? 0} TRX')),
          ],
        ),
      ),
    );
  }
}
