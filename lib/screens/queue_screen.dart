import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/queue_tiers_presets.dart';
import '../models/queue_tier.dart';
import '../providers/app_state.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tiers = state.tiers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('排单商城'),
        actions: [
          TextButton(onPressed: () => context.push('/order/my'), child: const Text('我的订单')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshUserAndOrders(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '排单券余额：${state.ticketBalance} 张 · 票价 ${QueueTiersPresets.ticketPriceTrx} TRX/张',
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 4),
            const Text(
              '档位金额已内置，无需联网即可选档；提交排单时才连接节点',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.push('/pool/queue'),
              child: const Text('链上排单（买券即排队 · 方案A）'),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(state.error!, style: const TextStyle(color: Colors.orange, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            ...tiers.map((tier) => _TierCard(tier: tier)),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier});

  final QueueTier tier;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final gap = state.tierEligibilityGap(tier);
    final ok = gap == null;
    final rate = (tier.profitRate * 100).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tier.name, style: Theme.of(context).textTheme.titleMedium),
            Text('排单 ${tier.amount} TRX → 出场 ${tier.exitAmount} TRX（收益 $rate%）'),
            Text(
              '消耗排单券 ${tier.ticketCost} 张 · ${tier.eligibilityLabel}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (gap != null)
              Text(gap, style: const TextStyle(color: Colors.orange, fontSize: 12)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: ok ? () => context.push('/order/confirm', extra: tier) : null,
              child: const Text('立即排单'),
            ),
          ],
        ),
      ),
    );
  }
}
