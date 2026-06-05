import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class WalletSetupScreen extends StatefulWidget {
  const WalletSetupScreen({super.key});

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  final _referralCtrl = TextEditingController();
  final _mnemonicCtrl = TextEditingController();
  bool _importMode = false;
  String _chain = 'TRON';

  Future<void> _create() async {
    final state = context.read<AppState>();
    final mnemonic = await state.createWallet(
      parentHint: _referralCtrl.text.trim(),
      chain: _chain,
    );
    if (!mounted) return;
    context.go('/mnemonic-backup', extra: mnemonic);
  }

  Future<void> _import() async {
    final state = context.read<AppState>();
    await state.importWallet(_mnemonicCtrl.text.trim(), chain: _chain);
    if (!mounted) return;
    context.go('/pin-setup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('钱包设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '私钥仅保存在本设备，不上传任何服务器',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'TRON', label: Text('波场 TRON')),
              ButtonSegment(value: 'BSC', label: Text('BSC')),
            ],
            selected: {_chain},
            onSelectionChanged: (s) => setState(() => _chain = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _referralCtrl,
            decoration: const InputDecoration(labelText: '推荐人地址（可选）'),
          ),
          if (_importMode) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _mnemonicCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '助记词'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _importMode ? _import : _create,
            child: Text(_importMode ? '导入钱包' : '创建新钱包'),
          ),
          TextButton(
            onPressed: () => setState(() => _importMode = !_importMode),
            child: Text(_importMode ? '改为创建钱包' : '已有助记词？导入'),
          ),
        ],
      ),
    );
  }
}
