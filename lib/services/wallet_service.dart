import '../models/wallet_account.dart';
import '../utils/wallet_derive.dart';
import 'wallet_secrets.dart';
import 'wallet_storage.dart';

/// 本地单钱包门面：每账户仅绑定一个链上地址
class WalletService {
  static Future<WalletAccount?> getActiveAccount() async {
    await enforceSingleWallet();
    return WalletStorage.getActiveWallet();
  }

  static Future<String?> getActiveAddress() async {
    final a = await getActiveAccount();
    return a?.address;
  }

  static Future<List<WalletAccount>> listWallets() async {
    await enforceSingleWallet();
    return WalletStorage.loadWallets();
  }

  /// 旧版多钱包数据迁移：仅保留当前激活钱包
  static Future<void> enforceSingleWallet() async {
    final wallets = await WalletStorage.loadWallets();
    if (wallets.length <= 1) return;

    final active = await WalletStorage.getActiveWallet();
    final keep = active ?? wallets.last;
    for (final w in wallets) {
      if (w.address != keep.address || w.chain != keep.chain) {
        await WalletSecrets.delete(w.chain, w.address);
      }
    }
    await WalletStorage.saveWallet(keep);
  }

  static Future<WalletAccount> createWallet({String chain = 'TRON', String? label}) async {
    await _clearExisting();
    final derived = WalletDerive.createNew(chain);
    final account = WalletAccount(
      address: derived['address']!,
      chain: derived['chain']!,
      label: label ?? '${derived['chain']} 钱包',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await WalletSecrets.save(
      chain: account.chain,
      address: account.address,
      mnemonic: derived['mnemonic']!,
      privateKey: derived['privateKey'],
    );
    await WalletStorage.saveWallet(account);
    return account;
  }

  static Future<WalletAccount> importWallet({
    required String mnemonic,
    String chain = 'TRON',
    String? label,
  }) async {
    await _clearExisting();
    final derived = WalletDerive.fromMnemonic(mnemonic, chain);
    final account = WalletAccount(
      address: derived['address']!,
      chain: derived['chain']!,
      label: label,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await WalletSecrets.save(
      chain: account.chain,
      address: account.address,
      mnemonic: mnemonic.trim(),
      privateKey: derived['privateKey'],
    );
    await WalletStorage.saveWallet(account);
    return account;
  }

  static Future<void> removeWallet(WalletAccount account) async {
    await WalletSecrets.delete(account.chain, account.address);
    await WalletStorage.deleteWallet(account.address, account.chain);
    await WalletStorage.setActiveWallet(null, null);
  }

  static Future<void> clearAll() async {
    final wallets = await WalletStorage.loadWallets();
    for (final w in wallets) {
      await WalletSecrets.delete(w.chain, w.address);
    }
    await WalletStorage.replaceAllWallets([]);
    await WalletStorage.setActiveWallet(null, null);
  }

  static Future<void> _clearExisting() async {
    final wallets = await WalletStorage.loadWallets();
    for (final w in wallets) {
      await WalletSecrets.delete(w.chain, w.address);
    }
    await WalletStorage.replaceAllWallets([]);
    await WalletStorage.setActiveWallet(null, null);
  }

  /// 兼容旧 API
  static Future<Map<String, String>?> loadWallet() async {
    final a = await getActiveAccount();
    if (a == null) return null;
    return {'address': a.address, 'chain': a.chain};
  }
}
