import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wallet_account.dart';
import '../widgets/referral_qr_dialog.dart';
import '../services/chain_rpc_service.dart';
import '../services/wallet_secrets.dart';
import '../services/wallet_service.dart';

/// 钱包管理：每账户仅一个钱包地址
class WalletManagementScreen extends StatefulWidget {
  const WalletManagementScreen({super.key});

  @override
  State<WalletManagementScreen> createState() => _WalletManagementScreenState();
}

class _WalletManagementScreenState extends State<WalletManagementScreen> {
  WalletAccount? _wallet;
  double? _balance;
  bool _balanceLoading = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final wallet = await WalletService.getActiveAccount();
    if (!mounted) return;
    setState(() {
      _wallet = wallet;
      _balance = null;
      _balanceLoading = wallet != null;
    });
    if (wallet == null) return;
    _loadBalance(wallet);
  }

  Future<void> _loadBalance(WalletAccount wallet) async {
    try {
      final bal = await ChainRpcService.getBalance(wallet.chain, wallet.address);
      if (mounted) setState(() => _balance = bal);
    } catch (_) {
      if (mounted) setState(() => _balance = 0);
    } finally {
      if (mounted) setState(() => _balanceLoading = false);
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
    final w = _wallet;
    final unit = w?.chain == 'TRON' ? 'TRX' : 'BNB';

    return Scaffold(
      appBar: AppBar(title: const Text('钱包管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '每个账户仅绑定一个钱包地址，注册时创建，不可新增多个',
            style: TextStyle(color: Colors.white54, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (w == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('暂无钱包，请完成注册流程创建'),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.label ?? w.chain, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(w.address, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 6),
                    if (_balanceLoading)
                      const Text('余额查询中…', style: TextStyle(color: Colors.white54))
                    else
                      Text(
                        '余额: ${(_balance ?? 0).toStringAsFixed(4)} $unit',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () => Clipboard.setData(ClipboardData(text: w.address)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code, size: 18),
                          onPressed: () => showReferralQrDialog(
                            context,
                            address: w.address,
                            title: '钱包推荐码',
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showMnemonic(w),
                          child: const Text('查看助记词'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          tooltip: '刷新余额',
                          onPressed: _balanceLoading
                              ? null
                              : () {
                                  setState(() => _balanceLoading = true);
                                  _loadBalance(w);
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
