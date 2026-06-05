import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/pin_service.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();

  Future<void> _save() async {
    if (_pin.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次输入不一致')));
      return;
    }
    await PinService.setPin(_pin.text);
    if (!mounted) return;
    context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置二级密码')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('转账/支付时使用，仅保存在本机', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 20),
            TextField(
              controller: _pin,
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '6 位支付密码'),
            ),
            TextField(
              controller: _confirm,
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '确认密码'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('完成')),
          ],
        ),
      ),
    );
  }
}
