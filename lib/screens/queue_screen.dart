import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/queue_tier.dart';
import '../providers/app_state.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('排单商城'),
        actions: [
          TextButton(onPressed: () => context.push('/order/my'), child: const Text('我的订单')),
        ],
      ),
      body: state.tiers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: state.refreshAll,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.tiers.length,
                itemBuilder: (context, i) => _TierCard(tier: state.tiers[i]),
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
    final ok = state.canQueueTier(tier);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tier.name, style: Theme.of(context).textTheme.titleMedium),
            Text('排单 ${tier.amount} TRX → 出场 ${tier.exitAmount} TRX'),
            Text('消耗 ${tier.ticketCost} 张 · ${tier.eligibilityLabel}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (!ok)
              const Text('资格不足', style: TextStyle(color: Colors.orange, fontSize: 12)),
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
