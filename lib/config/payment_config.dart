/// 打款与存证相关配置（收款地址以服务端 quote 为准）
class PaymentConfig {
  static const treasuryAddress = 'TREASURY_MULTISIG_PLACEHOLDER';

  /// true：不广播链上交易，生成本地 tx 哈希后提交共识（开发/测试）
  static const bool demoPaymentsDefault = true;

  /// 与 WSS-server TIMEOUT_CONFIG 默认值一致（服务端 quote 可覆盖）
  static const int pollIntervalSeconds = 15;
  static const int paymentTimeoutHours = 24;

  static Duration get pollInterval =>
      const Duration(seconds: pollIntervalSeconds);

  static Duration get paymentTimeout =>
      Duration(hours: paymentTimeoutHours);
}
