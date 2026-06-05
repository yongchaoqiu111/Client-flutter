import 'package:shared_preferences/shared_preferences.dart';

import '../config/payment_config.dart';

class AppSettingsService {
  static const _demoKey = 'mmm_demo_payments';
  static const _backupPendingKey = 'mmm_mnemonic_backup_pending';

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
}
