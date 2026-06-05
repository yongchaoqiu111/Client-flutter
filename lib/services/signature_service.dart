import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 客户端命令签名（与 private-chain/verify.js 一致）
class SignatureService {
  static Map<String, dynamic> signCommand({
    required String userAddress,
    required Map<String, dynamic> command,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nonce = timestamp.toRadixString(16);
    final payload = '$timestamp$nonce${jsonEncode(command)}';
    final signature = Hmac(sha256, utf8.encode(userAddress))
        .convert(utf8.encode(payload))
        .toString();

    return {
      'userAddress': userAddress,
      'command': command,
      'timestamp': timestamp,
      'nonce': nonce,
      'signature': signature,
    };
  }
}
