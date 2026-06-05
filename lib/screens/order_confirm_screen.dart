import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/payment_config.dart';
import '../models/queue_tier.dart';
import '../providers/app_state.dart';
import '../widgets/pin_dialog.dart';

class OrderConfirmScreen extends StatefulWidget {
  const OrderConfirmScreen({required this.tier, super.key});

  final QueueTier tier;

  @override
  State<OrderConfirmScreen> createState() => _OrderConfirmScreenState();
}

class _OrderConfirmScreenState extends State<OrderConfirmScreen> {
  bool _submitting = false;
  bool _paying = false;
  String? _orderId;
  late final num _payAmount;
  bool? _anchorOk;

  @override
  void initState() {
    super.initState();
    _payAmount = widget.tier.amount + (DateTime.now().millisecond % 100) / 100;
    _loadAnchor();
  }

  Future<void> _loadAnchor() async {
    final s = context.read<AppState>().anchorStatus;
    setState(() => _anchorOk = s?.verified ?? false);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final id = await context.read<AppState>().submitQueueOrder(widget.tier);
      setState(() => _orderId = id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pay() async {
    if (_orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先提交排单')));
      return;
    }
    if (!await showPayPinDialog(context)) return;
    setState(() => _paying = true);
    try {
      final state = context.read<AppState>();
      final tx = await state.payOrderOnChain(
        orderId: _orderId!,
        payAmount: _payAmount,
        treasury: PaymentConfig.treasuryAddress,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('支付已确认 tx: ${tx.substring(0, 12)}…')));
      context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final demo = context.watch<AppState>().demoPayments;
    final anchor = context.watch<AppState>().anchorStatus;

    return Scaffold(
      appBar: AppBar(title: const Text('确认订单')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${tier.name} (${tier.amount} TRX)'),
                  Text('消耗券 ${tier.ticketCost} 张'),
                  Text('预期出场 ${tier.exitAmount} TRX'),
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
                  const Text('支付信息', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('收款: ${PaymentConfig.treasuryAddress}'),
                  Text('金额: $_payAmount TRX'),
                  Text(demo ? '模式: 演示支付（本地哈希）' : '模式: 链上转账（BSC 可用）'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: (_paying || _orderId == null) ? null : _pay,
                    child: _paying
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('二级密码确认并支付'),
                  ),
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
                  const Text('存证验证', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    anchor != null && anchor.verified
                        ? 'Merkle 根 ${anchor.merkleRoot?.substring(0, 14) ?? "—"}… · ${anchor.recordCount} 条事件'
                        : '等待 Raft 事件（提交排单后可用）',
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  if (_anchorOk == false)
                    const Text('打币前需共识事件存证', style: TextStyle(color: Colors.orange, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('提交排单到共识节点'),
          ),
        ],
      ),
    );
  }
}
