import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 助记词/私钥仅存安全区（无云备份、不上传业务服务器）
class WalletSecrets {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String _key(String chain, String address) => 'mmm_secret_${chain}_$address';

  static Future<void> save({
    required String chain,
    required String address,
    required String mnemonic,
    String? privateKey,
  }) async {
    await _storage.write(
      key: _key(chain, address),
      value: mnemonic,
    );
    if (privateKey != null) {
      await _storage.write(
        key: '${_key(chain, address)}_pk',
        value: privateKey,
      );
    }
  }

  static Future<String?> loadMnemonic(String chain, String address) =>
      _storage.read(key: _key(chain, address));

  static Future<String?> loadPrivateKey(String chain, String address) =>
      _storage.read(key: '${_key(chain, address)}_pk');

  static Future<void> delete(String chain, String address) async {
    await _storage.delete(key: _key(chain, address));
    await _storage.delete(key: '${_key(chain, address)}_pk');
  }

  static Future<void> clearAll() => _storage.deleteAll();
}
