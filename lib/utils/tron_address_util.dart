import 'dart:typed_data';

import 'package:bs58check/bs58check.dart' as bs58;

/// TRON 地址比较（Base58 T… 或 hex 41…）
class TronAddressUtil {
  TronAddressUtil._();

  static String? toHex(String? address) {
    if (address == null || address.trim().isEmpty) return null;
    final raw = address.trim();
    if (raw.startsWith('T')) {
      try {
        final bytes = bs58.decode(raw);
        return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      } catch (_) {
        return null;
      }
    }
    return raw.replaceFirst(RegExp(r'^0x'), '').toLowerCase();
  }

  static bool equal(String? a, String? b) {
    if (a == null || b == null) return false;
    final ha = toHex(a);
    final hb = toHex(b);
    if (ha != null && hb != null) return ha == hb;
    return a.trim() == b.trim();
  }

  static String normalize(String? address) {
    if (address == null) return '';
    if (address.startsWith('T')) return address;
    final hex = toHex(address);
    if (hex == null) return address;
    try {
      final bytes = Uint8List.fromList(
        List.generate(hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)),
      );
      return bs58.encode(bytes);
    } catch (_) {
      return address;
    }
  }
}
