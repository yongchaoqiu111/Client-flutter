import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 二级支付密码（设计文档 §6.1），仅本地校验
class PinService {
  static const _key = 'mmm_pay_pin_hash';
  static const _storage = FlutterSecureStorage();

  static String _hash(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

  static Future<bool> hasPin() async {
    final v = await _storage.read(key: _key);
    return v != null && v.isNotEmpty;
  }

  static Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw Exception('请输入 6 位数字密码');
    }
    await _storage.write(key: _key, value: _hash(pin));
  }

  static Future<bool> verify(String pin) async {
    final stored = await _storage.read(key: _key);
    if (stored == null) return false;
    return stored == _hash(pin);
  }

  static Future<bool> promptAndVerify(Future<String?> Function() askPin) async {
    final pin = await askPin();
    if (pin == null) return false;
    return verify(pin);
  }
}
