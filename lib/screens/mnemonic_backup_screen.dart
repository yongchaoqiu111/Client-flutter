import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/app_settings_service.dart';
import '../services/wallet_service.dart';
import '../services/wallet_secrets.dart';

class MnemonicBackupScreen extends StatefulWidget {
  const MnemonicBackupScreen({required this.mnemonic, super.key});

  final String mnemonic;

  @override
  State<MnemonicBackupScreen> createState() => _MnemonicBackupScreenState();
}

class _MnemonicBackupScreenState extends State<MnemonicBackupScreen> {
  final _verifyCtrl = TextEditingController();
  bool _revealed = false;
  String _mnemonic = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMnemonic();
  }

  Future<void> _loadMnemonic() async {
    if (widget.mnemonic.isNotEmpty) {
      setState(() {
        _mnemonic = widget.mnemonic;
        _loading = false;
      });
      return;
    }
    final account = await WalletService.getActiveAccount();
    if (account != null) {
      final m = await WalletSecrets.loadMnemonic(account.chain, account.address);
      if (m != null && m.isNotEmpty) {
        setState(() {
          _mnemonic = m;
          _loading = false;
        });
        return;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_mnemonic.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('备份助记词')),
        body: const Center(child: Text('无法加载助记词，请重新创建钱包')),
      );
    }
    final words = _mnemonic.split(' ');
    return Scaffold(
      appBar: AppBar(title: const Text('备份助记词')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('请抄写助记词并妥善保管，丢失无法找回', style: TextStyle(color: Colors.orange)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _revealed
                  ? Text(words.join('  '))
                  : const Text('点击下方按钮显示助记词'),
            ),
          ),
          TextButton(onPressed: () => setState(() => _revealed = true), child: const Text('显示助记词')),
          const SizedBox(height: 24),
          const Text('验证备份（输入第 3 个单词）'),
          TextField(controller: _verifyCtrl, decoration: const InputDecoration(hintText: '第 3 个词')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              if (words.length >= 3 && _verifyCtrl.text.trim() == words[2]) {
                await AppSettingsService.setMnemonicBackupPending(false);
                if (!context.mounted) return;
                context.go('/pin-setup');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('验证失败，请检查')),
                );
              }
            },
            child: const Text('验证并继续'),
          ),
        ],
      ),
    );
  }
}
