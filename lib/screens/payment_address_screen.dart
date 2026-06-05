import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentAddressScreen extends StatefulWidget {
  const PaymentAddressScreen({super.key});

  @override
  State<PaymentAddressScreen> createState() => _PaymentAddressScreenState();
}

class _PaymentAddressScreenState extends State<PaymentAddressScreen> {
  static const _key = 'mmm_payment_address';
  static const _changesKey = 'mmm_payment_changes';
  String _address = 'TREASURY_MULTISIG_PLACEHOLDER';
  int _changesLeft = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _address = p.getString(_key) ?? _address;
      _changesLeft = p.getInt(_changesKey) ?? 1;
    });
  }

  Future<void> _change() async {
    if (_changesLeft <= 0) return;
    final ctrl = TextEditingController(text: _address);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('更换收款地址'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: '新地址')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (ok != true) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, ctrl.text.trim());
    await p.setInt(_changesKey, _changesLeft - 1);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收款账户')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('当前收款账户', style: TextStyle(fontWeight: FontWeight.bold)),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_address))),
            Text('剩余更换次数: $_changesLeft', style: const TextStyle(color: Colors.orange)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _changesLeft > 0 ? _change : null,
              child: const Text('更换收款地址'),
            ),
            const Text('设置后需多签确认（生产环境）', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
