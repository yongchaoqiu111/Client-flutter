import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/chain_rpc_service.dart';

/// 本机转账前确认：收款地址、转账金额、燃料费 → 确定后再验二级密码
Future<bool> showTicketSelfPayConfirmDialog(
  BuildContext context, {
  required String fromAddress,
  required String toAddress,
  required double amount,
  required String chain,
  required int qty,
  bool demoMode = false,
}) async {
  TransferFeeEstimate fee;
  try {
    fee = await ChainRpcService.estimateTransferFee(chain, fromAddress);
  } catch (_) {
    fee = _fallbackFee(chain);
  }

  if (!context.mounted) return false;
  final unit = chain.toUpperCase() == 'TRON' ? 'TRX' : 'BNB';

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('确认转账信息'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('购买 $qty 张排单券', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _row('付款钱包', fromAddress),
            const SizedBox(height: 8),
            _row('收款地址', toAddress),
            const SizedBox(height: 12),
            Text(
              '${amount.toStringAsFixed(0)} $unit',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2DD4BF)),
            ),
            const Text('转账金额（整数）', style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 8),
            Text('燃料费：${fee.label}', style: const TextStyle(fontSize: 14)),
            if (fee.bandwidth != null) ...[
              const SizedBox(height: 4),
              Text(
                '实时带宽（TronGrid）：总可用 ${fee.bandwidth!.totalAvailableBp} BP · '
                '免费剩余 ${fee.bandwidth!.freeRemainingBp} · 质押剩余 ${fee.bandwidth!.stakedRemainingBp}',
                style: const TextStyle(fontSize: 11, color: Colors.white54, height: 1.4),
              ),
            ],
            if (fee.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(fee.note, style: const TextStyle(fontSize: 11, color: Colors.white54, height: 1.4)),
              ),
            if (demoMode) ...[
              const SizedBox(height: 10),
              const Text(
                '当前为演示支付模式，不会广播真实链上交易。',
                style: TextStyle(fontSize: 11, color: Colors.orange, height: 1.4),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              '确认后将要求输入二级密码，然后发起转账。',
              style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: toAddress));
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('已复制收款地址')));
          },
          child: const Text('复制地址'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('确认转账'),
        ),
      ],
    ),
  ).then((v) => v == true);
}

TransferFeeEstimate _fallbackFee(String chain) {
  return chain.toUpperCase() == 'TRON'
      ? const TransferFeeEstimate(fee: 0.3, label: '约 0.3 TRX', note: '')
      : const TransferFeeEstimate(fee: 0.00025, label: '约 0.00025 BNB', note: '');
}

Widget _row(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
      SelectableText(value, style: const TextStyle(fontSize: 12, height: 1.35)),
    ],
  );
}
