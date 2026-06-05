import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web3dart/crypto.dart';

import '../config/chain_config.dart';

/// 波场 TRX 转账：createtransaction → 本地 secp256k1 签名 → broadcasttransaction
class TronTransferService {
  static String get _apiBase => ChainConfig.tron.nodes.first.replaceAll(RegExp(r'/+$'), '');

  static Future<String> sendTrx({
    required String privateKeyHex,
    required String fromAddress,
    required String toAddress,
    required double amountTrx,
  }) async {
    final amountSun = (amountTrx * 1e6).round();
    if (amountSun <= 0) throw Exception('转账金额无效');

    final tx = await _createTransaction(
      ownerAddress: fromAddress,
      toAddress: toAddress,
      amountSun: amountSun,
    );

    final txId = tx['txID'] as String?;
    if (txId == null || txId.isEmpty) {
      throw Exception(tx['Error'] ?? tx['message'] ?? '创建交易失败');
    }

    final sigHex = _signTxId(txId, privateKeyHex);
    tx['signature'] = [sigHex];

    final result = await _post('/wallet/broadcasttransaction', tx);
    if (result['result'] != true) {
      final code = result['code'] ?? result['message'] ?? '广播失败';
      throw Exception('$code');
    }
    return txId;
  }

  static Future<Map<String, dynamic>> _createTransaction({
    required String ownerAddress,
    required String toAddress,
    required int amountSun,
  }) async {
    return _post('/wallet/createtransaction', {
      'owner_address': ownerAddress,
      'to_address': toAddress,
      'amount': amountSun,
      'visible': true,
    });
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http
        .post(
          Uri.parse('$_apiBase$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('TronGrid $path HTTP ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// 对 txID（SHA256 raw_data）做 ECDSA 签名，返回 65 字节 hex（r+s+v，v=0..3）
  static String _signTxId(String txIdHex, String privateKeyHex) {
    final hash = hexToBytes(txIdHex);
    final pkHex = privateKeyHex.startsWith('0x') ? privateKeyHex.substring(2) : privateKeyHex;
    final pkBytes = hexToBytes(pkHex);

    final sig = sign(hash, pkBytes);
    final r = _leftPad32(unsignedIntToBytes(sig.r));
    final s = _leftPad32(unsignedIntToBytes(sig.s));
    final out = Uint8List(65);
    out.setRange(0, 32, r);
    out.setRange(32, 64, s);
    out[64] = sig.v - 27;
    return bytesToHex(out);
  }

  static Uint8List _leftPad32(Uint8List data) {
    if (data.length >= 32) return Uint8List.fromList(data.sublist(data.length - 32));
    final out = Uint8List(32);
    out.setRange(32 - data.length, 32, data);
    return out;
  }
}
