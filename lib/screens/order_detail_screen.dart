import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadOrderDetail(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    final o = context.watch<AppState>().selectedOrder;
    return Scaffold(
      appBar: AppBar(title: const Text('订单详情')),
      body: o == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('状态: ${o.statusLabel}', style: const TextStyle(fontSize: 18)),
                        Text('金额: ${o.amount} TRX'),
                        Text('应付: ${o.payAmount ?? o.amount} TRX'),
                        Text('消耗券: ${o.ticketCost}'),
                        if (o.txHash != null) Text('Tx: ${o.txHash}', style: const TextStyle(fontSize: 12)),
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
              ],
            ),
    );
  }
}
