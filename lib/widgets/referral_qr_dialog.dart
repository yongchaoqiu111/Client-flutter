import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_theme.dart';
import '../utils/referral_qr.dart';

/// 推荐/收款二维码：与助记词弹窗同款居中卡片，白底黑码便于扫描
void showReferralQrDialog(
  BuildContext context, {
  required String address,
  String title = '我的推荐二维码',
  String? subtitle,
}) {
  if (address.isEmpty) return;
  final data = ReferralQr.homeQrData(address);

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Material(
                color: Colors.white,
                elevation: 2,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: QrImageView(
                    data: data,
                    version: QrVersions.auto,
                    size: 240,
                    gapless: true,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('地址已复制')),
                );
              },
              child: SelectableText(
                address,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle ?? '好友扫码注册可绑定你为推荐人 · 点击地址复制',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
