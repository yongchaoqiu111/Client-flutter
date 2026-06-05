import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/payment_config.dart';
import '../providers/app_state.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/ticket_payment_dialog.dart';
import '../widgets/ticket_self_pay_dialog.dart';

class TicketPurchaseScreen extends StatefulWidget {
  const TicketPurchaseScreen({super.key});

  @override
  State<TicketPurchaseScreen> createState() => _TicketPurchaseScreenState();
}

class _TicketPurchaseScreenState extends State<TicketPurchaseScreen> {
  int _qty = 1;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().loadTicketQuote();
  }

  Future<void> _runPurchase(String payMode) async {
    // 仅本机转账需二级密码；朋友代付不付款，只生成代付单+二维码
    if (payMode == 'self' && !await showPayPinDialog(context)) return;
    setState(() => _busy = true);
    final state = context.read<AppState>();
    try {
      final purchase = await state.createTicketPurchase(_qty, payMode: payMode);
      if (!context.mounted) return;

      if (payMode == 'self') {
        final txHash = await state.payTicketFromDevice(purchase);
        if (!context.mounted) return;
        final ok = await showTicketSelfPayDialog(context, purchase: purchase, txHash: txHash);
        if (!context.mounted) return;
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('购票成功，排单券已到账')),
          );
        }
      } else {
        final ok = await showTicketPaymentDialog(context, purchase: purchase);
        if (!context.mounted) return;
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('购票成功，排单券已到账')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('代付单已创建，好友转账后将自动加券')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final quote = state.ticketQuote;
    final basePrice = quote?['basePrice'] ?? 100;
    final selfPay = (basePrice as num) * _qty;
    final pollSec = ((quote?['pollIntervalMs'] as num?)?.toInt() ?? PaymentConfig.pollInterval.inMilliseconds) ~/ 1000;
    final timeoutHours = (quote?['paymentTimeoutHours'] as num?)?.toInt() ?? PaymentConfig.paymentTimeoutHours;

    return Scaffold(
      appBar: AppBar(title: const Text('购买排单券')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('基准价 $basePrice TRX/张'),
                  Text('本机转账：${selfPay.toStringAsFixed(0)} TRX（整数，按钱包+收款+到账验链）'),
                  Text('朋友代付：含唯一尾数金额 + 二维码', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                  Text('收款: ${quote?['treasury'] ?? '—'}', style: const TextStyle(fontSize: 12)),
                  if (!state.isTicketTreasuryReady) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '⚠ 收款地址未就绪（服务端 TREASURY_ADDRESS 未生效），暂无法购票/出二维码',
                      style: TextStyle(fontSize: 12, color: Colors.orange, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '直接购买 → 验二级密码后本机转账；朋友代付 → 直接出金额与二维码。\n'
                    '查账每 $pollSec 秒，总时限 $timeoutHours 小时。',
                    style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              const Text('购买数量'),
              const Spacer(),
              IconButton(
                onPressed: _busy ? null : () => setState(() => _qty = (_qty - 1).clamp(1, 999)),
                icon: const Icon(Icons.remove),
              ),
              Text('$_qty'),
              IconButton(
                onPressed: _busy ? null : () => setState(() => _qty++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: (_busy || !state.isTicketTreasuryReady) ? null : () => _runPurchase('self'),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('直接购买（本机转账）'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: (_busy || !state.isTicketTreasuryReady) ? null : () => _runPurchase('friend'),
            child: const Text('朋友代付（扫码支付）'),
          ),
        ],
      ),
    );
  }
}
