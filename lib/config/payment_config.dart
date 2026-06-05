/// 打款与存证相关配置（无私钥在服务端）
class PaymentConfig {
  static const treasuryAddress = 'TREASURY_MULTISIG_PLACEHOLDER';

  /// true：不广播链上交易，生成本地 tx 哈希后提交共识（开发/测试）
  static const bool demoPaymentsDefault = true;
}
