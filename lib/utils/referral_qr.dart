/// 推荐/收款二维码内容
class ReferralQr {
  ReferralQr._();

  /// 扫码后得到完整推荐人地址（注册时填入 parent_hint）
  static String invitePayload(String address) {
    final addr = address.trim();
    if (addr.isEmpty) return '';
    return 'mmm:invite?parent=$addr';
  }

  /// TRON 钱包收款 URI（波场钱包扫码可识别）
  static String tronUri(String address, {num? amountTrx}) {
    final addr = address.trim();
    if (!addr.startsWith('T')) return addr;
    if (amountTrx == null) return 'tron:$addr';
    final amount = amountTrx is double
        ? amountTrx.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '')
        : amountTrx.toString();
    return 'tron:$addr?amount=$amount';
  }

  /// 购票/付款二维码（含精确金额，可另一台手机扫码）
  static String tronPaymentQr(String treasury, num payAmountTrx) =>
      tronUri(treasury, amountTrx: payAmountTrx);

  /// 首页展示：推荐邀请链接
  static String homeQrData(String address) => invitePayload(address);

  /// 从扫码/粘贴文本解析推荐人地址
  static String? parseParent(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('T') && s.length >= 30) return s;

    final uri = Uri.tryParse(s);
    if (uri != null) {
      final p = uri.queryParameters['parent'] ?? uri.queryParameters['ref'];
      if (p != null && p.startsWith('T')) return p;
    }

    final match = RegExp(r'(?:parent|ref)=([T][A-Za-z0-9]{20,})').firstMatch(s);
    return match?.group(1);
  }
}
