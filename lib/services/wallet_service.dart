import '../models/wallet_account.dart';
import '../utils/wallet_derive.dart';
import 'wallet_secrets.dart';
import 'wallet_storage.dart';

/// 本地多链钱包门面（pmsj 能力 minus 云备份 / minus 服务端 wallet API）
class WalletService {
  static Future<WalletAccount?> getActiveAccount() => WalletStorage.getActiveWallet();

  static Future<String?> getActiveAddress() async {
    final a = await getActiveAccount();
    return a?.address;
  }

  static Future<List<WalletAccount>> listWallets() => WalletStorage.loadWallets();

  static Future<WalletAccount> createWallet({String chain = 'TRON', String? label}) async {
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
    await WalletStorage.setActiveWallet(account.address, account.chain);
    return account;
  }

  static Future<WalletAccount> importWallet({
    required String mnemonic,
    String chain = 'TRON',
    String? label,
  }) async {
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
    await WalletStorage.setActiveWallet(account.address, account.chain);
    return account;
  }

  static Future<void> switchWallet(WalletAccount account) async {
    await WalletStorage.setActiveWallet(account.address, account.chain);
  }

  static Future<void> removeWallet(WalletAccount account) async {
    await WalletSecrets.delete(account.chain, account.address);
    await WalletStorage.deleteWallet(account.address, account.chain);
    final active = await getActiveAccount();
    if (active?.address == account.address && active?.chain == account.chain) {
      final rest = await listWallets();
      if (rest.isNotEmpty) {
        await switchWallet(rest.first);
      } else {
        await WalletStorage.setActiveWallet(null, null);
      }
    }
  }

  static Future<void> clearAll() async {
    final wallets = await listWallets();
    for (final w in wallets) {
      await WalletSecrets.delete(w.chain, w.address);
      await WalletStorage.deleteWallet(w.address, w.chain);
    }
    await WalletStorage.setActiveWallet(null, null);
  }

  /// 兼容旧 API
  static Future<Map<String, String>?> loadWallet() async {
    final a = await getActiveAccount();
    if (a == null) return null;
    return {'address': a.address, 'chain': a.chain};
  }
}
