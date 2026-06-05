import 'package:shared_preferences/shared_preferences.dart';

import '../config/payment_config.dart';

class AppSettingsService {
  static const _demoKey = 'mmm_demo_payments';

  static Future<bool> isDemoPayments() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_demoKey) ?? PaymentConfig.demoPaymentsDefault;
  }

  static Future<void> setDemoPayments(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_demoKey, value);
  }
}
