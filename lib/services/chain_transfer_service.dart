import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

import '../config/chain_config.dart';
import '../config/payment_config.dart';
import '../services/wallet_secrets.dart';

/// 本地签名转账（借鉴 pmsj：私钥不出设备）
class ChainTransferService {
  static Future<String> sendPayment({
    required String chain,
    required String fromAddress,
    required String toAddress,
    required double amount,
    bool demoMode = PaymentConfig.demoPaymentsDefault,
  }) async {
    if (demoMode) {
      final payload = utf8.encode('$chain:$fromAddress:$toAddress:$amount:${DateTime.now().millisecondsSinceEpoch}');
      return 'demo_${sha256.convert(payload).toString().substring(0, 32)}';
    }

    final pk = await WalletSecrets.loadPrivateKey(chain, fromAddress);
    if (pk == null || pk.isEmpty) {
      throw Exception('未找到本地私钥，请使用演示模式或重新导入钱包');
    }

    if (chain.toUpperCase() == 'BSC') {
      return _sendBsc(privateKeyHex: pk, toAddress: toAddress, amountBnb: amount);
    }
    if (chain.toUpperCase() == 'TRON') {
      throw Exception('TRON 主网完整签名尚未接入，请在「系统设置」开启演示支付，或切换 BSC 钱包');
    }
    throw Exception('不支持的链: $chain');
  }

  static Future<String> _sendBsc({
    required String privateKeyHex,
    required String toAddress,
    required double amountBnb,
  }) async {
    final cfg = ChainConfig.bsc;
    final client = Web3Client(cfg.nodes.first, http.Client());
    try {
      final creds = EthPrivateKey.fromHex(privateKeyHex.startsWith('0x') ? privateKeyHex : '0x$privateKeyHex');
      final to = EthereumAddress.fromHex(toAddress.startsWith('0x') ? toAddress : '0x$toAddress');
      final txHash = await client.sendTransaction(
        creds,
        Transaction(
          to: to,
          value: EtherAmount.fromBigInt(EtherUnit.wei, BigInt.from(amountBnb * 1e18)),
        ),
        chainId: 56,
      );
      return txHash;
    } finally {
      await client.dispose();
    }
  }

}
