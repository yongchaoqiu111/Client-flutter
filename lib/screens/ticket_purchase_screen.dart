import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/payment_config.dart';
import '../providers/app_state.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/ticket_payment_dialog.dart';
import '../widgets/ticket_self_pay_confirm_dialog.dart';
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

  Future<void> _runSelfPurchase() async {
    final state = context.read<AppState>();
    final quote = state.ticketQuote;
    final treasury = quote?['treasury'] as String? ?? '';
    final basePrice = (quote?['basePrice'] as num?) ?? 100;
    final amount = (basePrice * _qty).toDouble();
    final from = state.address;
    final chain = state.chain ?? 'TRON';

    if (from == null || from.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先创建或导入钱包')));
      return;
    }

    final confirmed = await showTicketSelfPayConfirmDialog(
      context,
      fromAddress: from,
      toAddress: treasury,
      amount: amount,
      chain: chain,
      qty: _qty,
      demoMode: false,
    );
    if (!confirmed || !context.mounted) return;

    if (!await showPayPinDialog(context)) return;

    setState(() => _busy = true);
    try {
      final purchase = await state.createTicketPurchase(_qty, payMode: 'self');
      if (!context.mounted) return;
      final txHash = await state.payTicketFromDevice(purchase);
      if (!context.mounted) return;
      final ok = await showTicketSelfPayDialog(context, purchase: purchase, txHash: txHash);
      if (!context.mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('购票成功，排单券已到账')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runFriendPurchase() async {
    setState(() => _busy = true);
    final state = context.read<AppState>();
    try {
      final purchase = await state.createTicketPurchase(_qty, payMode: 'friend');
      if (!context.mounted) return;
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
                  const SizedBox(height: 8),
                  Text(
                    state.address != null && state.address!.isNotEmpty
                        ? '用哪个地址购买，就用哪个地址排单。本机转账将记在当前钱包：'
                        ' ${state.address!.substring(0, 6)}…${state.address!.substring(state.address!.length - 4)}；'
                        '朋友代付则记在实际转账的钱包地址。'
                        : '用哪个地址购买，就用哪个地址排单。本机转账记当前钱包；朋友代付记实际付款地址。',
                    style: const TextStyle(fontSize: 12, color: Colors.cyanAccent, height: 1.45),
                  ),
                  if (!state.isTicketTreasuryReady) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '⚠ 收款地址未就绪（服务端 TREASURY_ADDRESS 未生效），暂无法购票/出二维码',
                      style: TextStyle(fontSize: 12, color: Colors.orange, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '直接购买 → 先确认转账信息 → 二级密码 → 本机转账；朋友代付 → 直接出二维码。\n'
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
            onPressed: (_busy || !state.isTicketTreasuryReady) ? null : _runSelfPurchase,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('直接购买（本机转账）'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: (_busy || !state.isTicketTreasuryReady) ? null : _runFriendPurchase,
            child: const Text('朋友代付（扫码支付）'),
          ),
        ],
      ),
    );
  }
}
