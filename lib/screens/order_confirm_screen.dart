import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/queue_tier.dart';
import '../providers/app_state.dart';

/// 确认排单意向：仅扣排单券、提交排队，不展示收款账户（匹配后才有支付信息）
class OrderConfirmScreen extends StatefulWidget {
  const OrderConfirmScreen({required this.tier, super.key});

  final QueueTier tier;

  @override
  State<OrderConfirmScreen> createState() => _OrderConfirmScreenState();
}

class _OrderConfirmScreenState extends State<OrderConfirmScreen> {
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final state = context.read<AppState>();
      if (state.ticketBalance < widget.tier.ticketCost) {
        throw Exception('排单券不足，请先购买');
      }
      final id = await state.submitQueueOrder(widget.tier);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已提交：${widget.tier.amount} TRX 已计入资金池，等待匹配支付信息')),
      );
      context.go('/order/$id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final tickets = context.watch<AppState>().ticketBalance;
    final reservoir = context.watch<AppState>().reservoir;
    final canSubmit = tickets >= tier.ticketCost;

    return Scaffold(
      appBar: AppBar(title: const Text('确认排单意向')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${tier.name} (${tier.amount} TRX)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('消耗排单券 ${tier.ticketCost} 张（当前余额 $tickets 张）'),
                  Text('预期出场 ${tier.exitAmount} TRX'),
                  Text('收益率 ${(tier.profitRate * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('流程说明', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    '1. 本页提交排单意向，扣除排单券\n'
                    '2. 系统记录存证哈希：您的地址、扣券数、档位金额、预约时间\n'
                    '3. 档位金额立即计入资金池（如 3000 TRX 则池内 +3000）\n'
                    '4. 资金池满额后匹配收款方，详情页才显示应付地址与金额\n'
                    '5. 匹配成功后再进行链上支付',
                    style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
                  ),
                  if (reservoir != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '当前蓄水池：${reservoir.currentAmount.toStringAsFixed(0)} / '
                      '${reservoir.currentTarget.toStringAsFixed(0)} TRX',
                      style: const TextStyle(fontSize: 12, color: Colors.cyan),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!canSubmit) ...[
            const SizedBox(height: 12),
            const Text('排单券不足，请先购买', style: TextStyle(color: Colors.orange)),
            TextButton(onPressed: () => context.push('/ticket'), child: const Text('去购买排单券')),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_submitting || !canSubmit) ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('确认提交排单意向'),
          ),
        ],
      ),
    );
  }
}
