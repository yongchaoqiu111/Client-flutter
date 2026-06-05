import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallet_account.dart';

/// 本地钱包元数据（每账户仅一个钱包地址）
class WalletStorage {
  static const _walletsKey = 'mmm_wallets_v1';
  static const _activeKey = 'mmm_active_wallet_v1';
  static const _transactionsKey = 'mmm_transactions_v1';

  static Future<List<WalletAccount>> loadWallets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_walletsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => WalletAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 保存唯一钱包（替换旧地址，不追加）
  static Future<void> saveWallet(WalletAccount account) async {
    await replaceAllWallets([account]);
    await setActiveWallet(account.address, account.chain);
  }

  static Future<void> replaceAllWallets(List<WalletAccount> wallets) async {
    final prefs = await SharedPreferences.getInstance();
    final single = wallets.isEmpty ? <WalletAccount>[] : [wallets.last];
    await prefs.setString(
      _walletsKey,
      jsonEncode(single.map((w) => w.toJson()).toList()),
    );
  }

  static Future<void> deleteWallet(String address, String chain) async {
    final wallets = await loadWallets();
    wallets.removeWhere((w) => w.address == address && w.chain == chain);
    await replaceAllWallets(wallets);
  }

  static Future<void> setActiveWallet(String? address, String? chain) async {
    final prefs = await SharedPreferences.getInstance();
    if (address == null || chain == null) {
      await prefs.remove(_activeKey);
      return;
    }
    await prefs.setString(_activeKey, jsonEncode({'address': address, 'chain': chain}));
  }

  static Future<WalletAccount?> getActiveWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeKey);
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final wallets = await loadWallets();
    for (final w in wallets) {
      if (w.address == m['address'] && w.chain == m['chain']) return w;
    }
    if (wallets.isNotEmpty) return wallets.first;
    return null;
  }

  static Future<List<Map<String, dynamic>>> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_transactionsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> addTransaction(Map<String, dynamic> tx) async {
    final list = await loadTransactions();
    list.insert(0, {...tx, 'at': DateTime.now().millisecondsSinceEpoch});
    final prefs = await SharedPreferences.getInstance();
    final trimmed = list.take(200).toList();
    await prefs.setString(_transactionsKey, jsonEncode(trimmed));
  }
}
