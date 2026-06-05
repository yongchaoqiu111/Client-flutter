import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = context.watch<AppState>().burnRewards ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text('烧伤奖励')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadBurnRewards(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('单笔奖励 ${b['burnBonusAmount'] ?? 50} TRX'),
                    Text('可提取门槛 ${b['minWithdraw'] ?? 1300} TRX'),
                    Text('当前收益余额 ${b['rewardBalance'] ?? 0} TRX'),
                    Text(
                      (b['withdrawable'] as num? ?? 0) > 0 ? '已达提取门槛' : '未达提取门槛',
                      style: TextStyle(color: (b['withdrawable'] as num? ?? 0) > 0 ? Colors.green : Colors.orange),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('奖励记录', style: TextStyle(fontWeight: FontWeight.bold)),
            ...((b['records'] as List<dynamic>? ?? []).map((r) {
              final m = r as Map<String, dynamic>;
              return ListTile(
                title: Text('来自 ${m['child']?.toString().substring(0, 8) ?? "—"}…'),
                subtitle: Text('订单 ${m['orderId']}'),
                trailing: Text('+${m['amount']} TRX'),
              );
            })),
            if ((b['records'] as List?)?.isEmpty ?? true)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('暂无烧伤记录。直推用户排单支付确认后，上家可获得奖励。'),
              ),
          ],
        ),
      ),
    );
  }
}
