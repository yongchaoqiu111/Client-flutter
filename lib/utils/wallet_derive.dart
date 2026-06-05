import 'dart:typed_data';

import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:pointycastle/export.dart';
import 'package:web3dart/credentials.dart';

/// BIP44 派生（pmsj wallet_core：TRON 195，ETH/BSC 60）
class WalletDerive {
  static const tronPath = "m/44'/195'/0'/0/0";
  static const bscPath = "m/44'/60'/0'/0/0";

  static Map<String, String> fromMnemonic(String mnemonic, String chain) {
    final words = mnemonic.trim();
    if (!bip39.validateMnemonic(words)) {
      throw Exception('助记词无效');
    }
    final seed = bip39.mnemonicToSeed(words);
    final root = bip32.BIP32.fromSeed(seed);
    switch (chain.toUpperCase()) {
      case 'TRON':
        return _tronWallet(root);
      case 'BSC':
        return _evmWallet(root, bscPath);
      default:
        throw Exception('不支持的链: $chain');
    }
  }

  static Map<String, String> createNew(String chain) {
    final mnemonic = bip39.generateMnemonic();
    final w = fromMnemonic(mnemonic, chain);
    return {...w, 'mnemonic': mnemonic};
  }

  static Map<String, String> _tronWallet(bip32.BIP32 root) {
    final child = root.derivePath(tronPath);
    final pk = child.privateKey!;
    final privateHex = _bytesToHex(pk);
    final address = _privateKeyToTronAddress(pk);
    return {
      'address': address,
      'privateKey': privateHex,
      'chain': 'TRON',
    };
  }

  static Map<String, String> _evmWallet(bip32.BIP32 root, String path) {
    final child = root.derivePath(path);
    final pk = child.privateKey!;
    final privateHex = _bytesToHex(pk);
    final creds = EthPrivateKey.fromHex(privateHex);
    return {
      'address': creds.address.hex,
      'privateKey': privateHex,
      'chain': 'BSC',
    };
  }

  static String _privateKeyToTronAddress(Uint8List privateKey) {
    final domain = ECDomainParameters('secp256k1');
    final d = _bytesToBigInt(privateKey);
    final Q = domain.G * d;
    final x = _bigIntTo32(Q!.x!.toBigInteger()!);
    final y = _bigIntTo32(Q.y!.toBigInteger()!);
    final pub = Uint8List.fromList([0x04, ...x, ...y]);
    final keccak = KeccakDigest(256);
    final hash = keccak.process(pub.sublist(1));
    final addr20 = hash.sublist(12);
    final payload = Uint8List.fromList([0x41, ...addr20]);
    return bs58check.encode(payload);
  }

  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var r = BigInt.zero;
    for (final b in bytes) {
      r = (r << 8) + BigInt.from(b);
    }
    return r;
  }

  static Uint8List _bigIntTo32(BigInt n) {
    final hex = n.toRadixString(16).padLeft(64, '0');
    return Uint8List.fromList(List.generate(32, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
  }
}
