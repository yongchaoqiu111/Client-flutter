import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_theme.dart';
import '../config/payment_config.dart';
import '../providers/app_state.dart';
import '../utils/referral_qr.dart';

/// 朋友代付：展示唯一金额 + 收款二维码（另一台手机扫码）
Future<bool> showTicketPaymentDialog(
  BuildContext context, {
  required Map<String, dynamic> purchase,
}) async {
  final purchaseId = purchase['id'] as String;
  final payAmount = purchase['payAmount'];
  final qty = purchase['amount'];
  final treasury = purchase['treasury'] as String? ?? '—';
  final pollMs = (purchase['pollIntervalMs'] as num?)?.toInt() ??
      PaymentConfig.pollInterval.inMilliseconds;
  final expiresAtMs = (purchase['expiresAt'] as num?)?.toInt() ??
      DateTime.now().add(PaymentConfig.paymentTimeout).millisecondsSinceEpoch;
  final timeoutHours = (purchase['paymentTimeoutHours'] as num?)?.toInt() ??
      PaymentConfig.paymentTimeoutHours;
  final payAmountNum = payAmount is num ? payAmount : num.tryParse('$payAmount') ?? 0;
  final qrData = treasury.startsWith('T')
      ? ReferralQr.tronPaymentQr(treasury, payAmountNum)
      : treasury;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _TicketPaymentDialog(
        purchaseId: purchaseId,
        payAmount: payAmount,
        payAmountDisplay: _formatPayAmount(payAmountNum),
        qty: qty,
        treasury: treasury,
        qrData: qrData,
        pollInterval: Duration(milliseconds: pollMs),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
        paymentTimeoutHours: timeoutHours,
      ),
    ),
  ).then((v) => v == true);
}

String _formatPayAmount(num v) {
  final s = v.toStringAsFixed(4);
  return s.replaceAll(RegExp(r'\.?0+$'), '');
}

class _TicketPaymentDialog extends StatefulWidget {
  const _TicketPaymentDialog({
    required this.purchaseId,
    required this.payAmount,
    required this.payAmountDisplay,
    required this.qty,
    required this.treasury,
    required this.qrData,
    required this.pollInterval,
    required this.expiresAt,
    required this.paymentTimeoutHours,
  });

  final String purchaseId;
  final dynamic payAmount;
  final String payAmountDisplay;
  final dynamic qty;
  final String treasury;
  final String qrData;
  final Duration pollInterval;
  final DateTime expiresAt;
  final int paymentTimeoutHours;

  @override
  State<_TicketPaymentDialog> createState() => _TicketPaymentDialogState();
}

class _TicketPaymentDialogState extends State<_TicketPaymentDialog> {
  String _status = '请扫码或转账，金额必须完全一致';
  int _pollCount = 0;
  bool _polling = false;
  bool _timedOut = false;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  String _formatRemaining(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _startPolling() async {
    if (_polling) return;
    _polling = true;
    final state = context.read<AppState>();
    final pollSec = widget.pollInterval.inSeconds;

    while (mounted && !_timedOut && !_confirmed) {
      final remaining = widget.expiresAt.difference(DateTime.now());
      if (remaining.isNegative || remaining == Duration.zero) {
        setState(() {
          _timedOut = true;
          _status = '已超过 ${widget.paymentTimeoutHours} 小时，购票单已失效';
        });
        return;
      }

      setState(() {
        _pollCount += 1;
        _status = '第 $_pollCount 次查账（每 ${pollSec}s）· 剩余 ${_formatRemaining(remaining)}';
      });

      final purchase = await state.fetchTicketPurchase(widget.purchaseId);
      if (!mounted) return;

      if (purchase?['status'] == 'confirmed') {
        _confirmed = true;
        await state.refreshAll();
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }
      if (purchase?['status'] == 'expired') {
        setState(() {
          _timedOut = true;
          _status = '购票单已超时失效，请重新下单';
        });
        return;
      }

      await Future.delayed(widget.pollInterval);
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制$label')));
  }

  @override
  Widget build(BuildContext context) {
    final pollSec = widget.pollInterval.inSeconds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _confirmed ? '支付成功' : (_timedOut ? '查询已结束' : '朋友代付'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.payAmountDisplay} TRX',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2DD4BF),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '购买 ${widget.qty} 张 · 金额含唯一尾数，请勿四舍五入',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            if (!_timedOut && widget.treasury.startsWith('T'))
              Center(
                child: Material(
                  color: Colors.white,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: QrImageView(
                      data: widget.qrData,
                      version: QrVersions.auto,
                      size: 220,
                      gapless: true,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                      dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SelectableText(
              widget.treasury,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              '请让好友用另一台手机的波场钱包扫码支付。\n'
              '系统按「唯一金额 + 收款地址」认账，付款方可为任意钱包。\n'
              '每 $pollSec 秒查账一次，总时限 ${widget.paymentTimeoutHours} 小时。',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.45),
            ),
            const SizedBox(height: 12),
            if (!_timedOut && !_confirmed)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_status, style: const TextStyle(fontSize: 12))),
                ],
              )
            else
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _timedOut ? Colors.orange : Colors.green),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_timedOut) ...[
                  TextButton(
                    onPressed: () => _copy(widget.payAmountDisplay, '金额'),
                    child: const Text('复制金额'),
                  ),
                  TextButton(
                    onPressed: () => _copy(widget.treasury, '地址'),
                    child: const Text('复制地址'),
                  ),
                ],
                TextButton(
                  onPressed: () => Navigator.pop(context, _confirmed),
                  child: Text(_timedOut ? '关闭' : '稍后查看'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
