import 'package:shared_preferences/shared_preferences.dart';

import '../config/payment_config.dart';

class AppSettingsService {
  static const _demoKey = 'mmm_demo_payments';
  static const _backupPendingKey = 'mmm_mnemonic_backup_pending';
  static const _tronGridApiKey = 'mmm_trongrid_api_key';

  static Future<bool> isDemoPayments() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_demoKey) ?? PaymentConfig.demoPaymentsDefault;
  }

  static Future<void> setDemoPayments(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_demoKey, value);
  }

  static Future<bool> isMnemonicBackupPending() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_backupPendingKey) ?? false;
  }

  static Future<void> setMnemonicBackupPending(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_backupPendingKey, value);
  }

  static Future<String?> getTronGridApiKey() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_tronGridApiKey);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  static Future<void> setTronGridApiKey(String? value) async {
    final p = await SharedPreferences.getInstance();
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await p.remove(_tronGridApiKey);
      return;
    }
    await p.setString(_tronGridApiKey, trimmed);
  }
}
