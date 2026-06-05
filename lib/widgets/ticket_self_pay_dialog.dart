import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/payment_config.dart';
import '../providers/app_state.dart';

/// 本机转账后等待验链到账（按付款方+收款方+整数金额，不靠随机尾数）
Future<bool> showTicketSelfPayDialog(
  BuildContext context, {
  required Map<String, dynamic> purchase,
  required String txHash,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _TicketSelfPayDialog(purchase: purchase, txHash: txHash),
  ).then((v) => v == true);
}

class _TicketSelfPayDialog extends StatefulWidget {
  const _TicketSelfPayDialog({required this.purchase, required this.txHash});

  final Map<String, dynamic> purchase;
  final String txHash;

  @override
  State<_TicketSelfPayDialog> createState() => _TicketSelfPayDialogState();
}

class _TicketSelfPayDialogState extends State<_TicketSelfPayDialog> {
  String _status = '转账已提交，正在验链…';
  bool _confirmed = false;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  Future<void> _poll() async {
    final state = context.read<AppState>();
    final purchaseId = widget.purchase['id'] as String;
    final pollMs = (widget.purchase['pollIntervalMs'] as num?)?.toInt() ??
        PaymentConfig.pollInterval.inMilliseconds;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      (widget.purchase['expiresAt'] as num?)?.toInt() ??
          DateTime.now().add(PaymentConfig.paymentTimeout).millisecondsSinceEpoch,
    );

    var count = 0;
    while (mounted && !_confirmed && !_timedOut) {
      if (DateTime.now().isAfter(expiresAt)) {
        setState(() {
          _timedOut = true;
          _status = '查询超时，请稍后在购票页刷新余额';
        });
        return;
      }
      count += 1;
      setState(() => _status = '第 $count 次验链到账…');

      final p = await state.fetchTicketPurchase(purchaseId);
      if (!mounted) return;
      if (p?['status'] == 'confirmed') {
        await state.refreshAll();
        if (!mounted) return;
        setState(() {
          _confirmed = true;
          _status = '购票成功，排单券已到账';
        });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
        return;
      }

      if (count == 1 && widget.txHash.startsWith('demo_')) {
        try {
          await state.reportTicketTxRetry(purchaseId, widget.txHash);
        } catch (_) {}
      }

      await Future.delayed(Duration(milliseconds: pollMs));
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.purchase['payAmount'];
    return AlertDialog(
      title: Text(_confirmed ? '支付成功' : '本机转账确认中'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$amount TRX',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2DD4BF)),
          ),
          const SizedBox(height: 8),
          const Text(
            '已用本机钱包发起转账。系统按「你的钱包 → 收款地址 → 到账金额」验链，'
            '燃料费另扣，不影响到账金额。',
            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text('Tx: ${widget.txHash}', style: const TextStyle(fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 12),
          if (!_confirmed && !_timedOut)
            Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Expanded(child: Text(_status, style: const TextStyle(fontSize: 12))),
              ],
            )
          else
            Text(_status, style: TextStyle(fontSize: 12, color: _timedOut ? Colors.orange : Colors.green)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _confirmed),
          child: Text(_confirmed ? '完成' : '稍后查看'),
        ),
      ],
    );
  }
}
