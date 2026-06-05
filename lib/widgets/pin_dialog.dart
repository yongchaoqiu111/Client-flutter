import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pin_service.dart';

Future<bool> showPayPinDialog(BuildContext context) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('请输入二级密码确认支付'),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        obscureText: true,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: '6 位数字密码',
          counterText: '',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            final valid = await PinService.verify(ctrl.text);
            if (!valid) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('密码错误')),
              );
              return;
            }
            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('确认支付'),
        ),
      ],
    ),
  );
  return ok == true;
}
