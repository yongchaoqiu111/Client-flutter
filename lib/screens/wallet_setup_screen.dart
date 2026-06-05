import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/referral_qr.dart';

class WalletSetupScreen extends StatefulWidget {
  const WalletSetupScreen({this.importMode = false, super.key});

  final bool importMode;

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  final _referralCtrl = TextEditingController();
  final _mnemonicCtrl = TextEditingController();
  late bool _importMode;
  bool _busy = false;
  String _chain = 'TRON';

  @override
  void initState() {
    super.initState();
    _importMode = widget.importMode;
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      final parent = ReferralQr.parseParent(_referralCtrl.text) ?? _referralCtrl.text.trim();
      final mnemonic = await state.createWallet(
        parentHint: parent.isEmpty ? null : parent,
        chain: _chain,
      );
      if (!mounted) return;
      context.go('/mnemonic-backup', extra: mnemonic);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      await state.importWallet(_mnemonicCtrl.text.trim(), chain: _chain);
      if (!mounted) return;
      context.go('/pin-setup');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_importMode ? '导入钱包' : '创建钱包')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '私钥仅保存在本设备，不上传任何服务器',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                _importMode
                    ? '输入助记词恢复钱包，无需联网'
                    : '创建钱包无需联网，注册节点将在后台进行',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'TRON', label: Text('波场 TRON')),
                  ButtonSegment(value: 'BSC', label: Text('BSC')),
                ],
                selected: {_chain},
                onSelectionChanged: _busy ? null : (s) => setState(() => _chain = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referralCtrl,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: '推荐人地址（可选）'),
              ),
              if (_importMode) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _mnemonicCtrl,
                  enabled: !_busy,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '助记词'),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : (_importMode ? _import : _create),
                child: Text(_importMode ? '导入钱包' : '创建新钱包'),
              ),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _importMode = !_importMode),
                child: Text(_importMode ? '改为创建钱包' : '已有助记词？导入'),
              ),
            ],
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
