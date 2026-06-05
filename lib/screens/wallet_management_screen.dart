import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/wallet_account.dart';
import '../providers/app_state.dart';
import '../services/chain_rpc_service.dart';
import '../services/wallet_secrets.dart';
import '../services/wallet_service.dart';

/// 钱包管理（借鉴 pmsj WalletManagementPage，无云备份）
class WalletManagementScreen extends StatefulWidget {
  const WalletManagementScreen({super.key});

  @override
  State<WalletManagementScreen> createState() => _WalletManagementScreenState();
}

class _WalletManagementScreenState extends State<WalletManagementScreen> {
  List<WalletAccount> _wallets = [];
  WalletAccount? _active;
  final _balanceMap = <String, double>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    _wallets = await WalletService.listWallets();
    _active = await WalletService.getActiveAccount();
    for (final w in _wallets) {
      try {
        _balanceMap['${w.chain}:${w.address}'] =
            await ChainRpcService.getBalance(w.chain, w.address);
      } catch (_) {
        _balanceMap['${w.chain}:${w.address}'] = 0;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create(String chain) async {
    await WalletService.createWallet(chain: chain);
    await context.read<AppState>().reloadWallet();
    await _reload();
  }

  Future<void> _import(String chain) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('导入 $chain 钱包'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '12/24 个英文助记词'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('导入')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await WalletService.importWallet(mnemonic: ctrl.text, chain: chain);
      await context.read<AppState>().reloadWallet();
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _showMnemonic(WalletAccount account) async {
    final words = await WalletSecrets.loadMnemonic(account.chain, account.address);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('助记词（请勿截图外传）'),
        content: SelectableText(words ?? '未找到'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('钱包管理'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _create,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'TRON', child: Text('创建 TRON 钱包')),
              const PopupMenuItem(value: 'BSC', child: Text('创建 BSC 钱包')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('私钥与助记词仅在本机安全存储，无云备份', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                if (_wallets.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('暂无钱包，请创建或导入'),
                    ),
                  ),
                ..._wallets.map(_walletTile),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: () => _import('TRON'), child: const Text('导入 TRON 助记词')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => _import('BSC'), child: const Text('导入 BSC 助记词')),
              ],
            ),
    );
  }

  Widget _walletTile(WalletAccount w) {
    final isActive = _active?.address == w.address && _active?.chain == w.chain;
    final bal = _balanceMap['${w.chain}:${w.address}'] ?? 0;
    final unit = w.chain == 'TRON' ? 'TRX' : 'BNB';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(w.label ?? w.chain, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  const Chip(label: Text('当前', style: TextStyle(fontSize: 10)), padding: EdgeInsets.zero),
                ],
              ],
            ),
            Text(w.address, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            Text('余额: ${bal.toStringAsFixed(4)} $unit', style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => Clipboard.setData(ClipboardData(text: w.address)),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code, size: 18),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      content: QrImageView(data: w.address, size: 200),
                    ),
                  ),
                ),
                TextButton(onPressed: () => _showMnemonic(w), child: const Text('查看助记词')),
                if (!isActive)
                  TextButton(
                    onPressed: () async {
                      await WalletService.switchWallet(w);
                      await context.read<AppState>().reloadWallet();
                      await _reload();
                    },
                    child: const Text('切换'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
