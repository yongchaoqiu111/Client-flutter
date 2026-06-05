import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/pin_dialog.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadOrderDetail(widget.orderId);
  }

  Future<void> _pay() async {
    final o = context.read<AppState>().selectedOrder;
    if (o == null || o.status != 'waiting_payment') return;
    if (!await showPayPinDialog(context)) return;

    setState(() => _paying = true);
    try {
      final state = context.read<AppState>();
      final tx = await state.payOrderOnChain(
        orderId: o.id,
        payAmount: o.payAmount ?? o.amount,
        treasury: o.payeeAddress,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('支付已确认 tx: ${tx.substring(0, 12)}…')),
      );
      await state.loadOrderDetail(widget.orderId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = context.watch<AppState>().selectedOrder;
    final demo = context.watch<AppState>().demoPayments;

    return Scaffold(
      appBar: AppBar(title: const Text('订单详情')),
      body: o == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<AppState>().loadOrderDetail(widget.orderId),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('状态: ${o.statusLabel}', style: const TextStyle(fontSize: 18)),
                          Text('档位: ${o.tierName.isNotEmpty ? o.tierName : "排单"}'),
                          Text('排单金额: ${o.amount} TRX'),
                          Text('消耗券: ${o.ticketCost} 张'),
                          if (o.txHash != null)
                            Text('Tx: ${o.txHash}', style: const TextStyle(fontSize: 12)),
                          if (o.status == 'exiting' || o.status == 'exited') ...[
                            const SizedBox(height: 12),
                            Text('出场进度 ${((o.exitProgress) * 100).toStringAsFixed(0)}%'),
                            LinearProgressIndicator(value: o.exitProgress),
                            if (o.exitPaidTotal != null) Text('已发放 ${o.exitPaidTotal} TRX'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (o.status == 'queued') ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('已入池排队', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan)),
                            const SizedBox(height: 8),
                            Text('地址: ${o.userAddress}', style: const TextStyle(fontSize: 12)),
                            Text('已付排单券: ${o.ticketCost} 张'),
                            Text('预约档位: ${o.amount} TRX'),
                            if (o.poolContributed != null)
                              Text('资金池已计入: +${o.poolContributed} TRX'),
                            if (o.queuedAtText != null) Text('预约时间: ${o.queuedAtText}'),
                            if (o.queuedContentHash != null)
                              Text(
                                '存证哈希: ${o.queuedContentHash!.substring(0, 16)}…',
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
                              ),
                            const SizedBox(height: 8),
                            const Text(
                              '排单券已扣、档位金额已计入资金池。\n'
                              '资金池满额后系统匹配收款方，本页将显示应付地址与金额。',
                              style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (o.status == 'waiting_payment') ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('支付信息（已匹配）', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('收款地址: ${o.payeeAddress ?? "—"}'),
                            Text('应付金额: ${o.payAmount ?? o.amount} TRX'),
                            Text(demo ? '模式: 演示支付（本地哈希）' : '模式: 链上转账'),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _paying ? null : _pay,
                              child: _paying
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('二级密码确认并支付'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
