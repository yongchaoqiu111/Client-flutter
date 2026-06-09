/// 排单池规则 pool-v4-dual-pool（档位与排单商城出场比例一致）

class PoolRulesConfig {
  PoolRulesConfig._();

  static const rulesVersion = 'pool-v4-dual-pool';

  /// 主网出场池收款地址（各档共用）
  static const defaultExitPoolAddress = 'TRjvctzrc5WcEeu2UrT8mV5H6zW8dCgimR';

  static const int checkpointIntervalMs = 24 * 3600 * 1000;
  static const int entryPeriodDays = 15;
  static const int exitPeriodDays = 7;
  static const int matchPaymentTimeoutHours = 24;
  static const int maxOpenEntriesPerPayer = 1;
  static const int maxSplitsPerPayer = 3;
  static const int dailyMatchUtcHour = 0;
  static const int matchesPerDay = 1;

  /// 池满阈值 = poolCreditTrx × 此系数（与旧 30 万 / 3000 规则相同：100 笔满池）
  static const int poolTargetMultiplier = 100;

  static int checkpointCutoffMs([DateTime? now]) {
    final n = (now ?? DateTime.now()).toUtc();
    final utcDay = DateTime.utc(n.year, n.month, n.day);
    if (n.isBefore(utcDay)) {
      return utcDay.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    }
    return utcDay.millisecondsSinceEpoch;
  }

  static String checkpointDayId([DateTime? now]) {
    final ms = checkpointCutoffMs(now);
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String().substring(0, 10);
  }

  static DailyMatchContext dailyMatchContext([DateTime? now]) {
    final snapshotCutoffMs = checkpointCutoffMs(now);
    return DailyMatchContext(
      matchDayId: checkpointDayId(now),
      snapshotCutoffMs: snapshotCutoffMs,
      matchAtMs: snapshotCutoffMs,
      nextMatchAtMs: snapshotCutoffMs + checkpointIntervalMs,
      matchesPerDay: matchesPerDay,
      matchUtcHour: dailyMatchUtcHour,
      beijingMatchHour: dailyMatchUtcHour + 8,
    );
  }
}

class DailyMatchContext {
  const DailyMatchContext({
    required this.matchDayId,
    required this.snapshotCutoffMs,
    required this.matchAtMs,
    required this.nextMatchAtMs,
    required this.matchesPerDay,
    required this.matchUtcHour,
    required this.beijingMatchHour,
  });

  final String matchDayId;
  final int snapshotCutoffMs;
  final int matchAtMs;
  final int nextMatchAtMs;
  final int matchesPerDay;
  final int matchUtcHour;
  final int beijingMatchHour;
}

class PoolTierConfig {
  const PoolTierConfig({
    required this.id,
    required this.name,
    required this.purchaseAddress,
    required this.exitPoolAddress,
    required this.ticketPriceTrx,
    required this.poolCreditTrx,
    required this.poolTargetTrx,
    required this.exitAmountTrx,
    required this.profitRate,
  });

  final String id;
  final String name;
  final String purchaseAddress;
  final String exitPoolAddress;
  /// 链上进场实付 TRX（与排单商城购票倍数一致：张数 × 100）
  final double ticketPriceTrx;
  /// 计入本档资金池额度（= 排单额）
  final double poolCreditTrx;
  /// 本档池满阈值
  final double poolTargetTrx;
  /// 收款池单次出场应收 TRX（recv_out 整数单位）
  final double exitAmountTrx;
  /// 展示用收益率（出场/排单 - 1）
  final double profitRate;
}

/// 与 queue_tiers_presets 出场比例一致；算法相同，仅参数不同
const List<PoolTierConfig> kPoolTiers = [
  PoolTierConfig(
    id: '1000',
    name: '小额排单',
    purchaseAddress: 'TQmzZQQQk7C9F5aG9v6E5j8H9i0j1K2L3M4N5',
    exitPoolAddress: PoolRulesConfig.defaultExitPoolAddress,
    ticketPriceTrx: 100,
    poolCreditTrx: 1000,
    poolTargetTrx: 100000,
    exitAmountTrx: 1300,
    profitRate: 0.3,
  ),
  PoolTierConfig(
    id: '10000',
    name: '中额排单',
    purchaseAddress: 'TQmzZQQQk7C9F5aG9v6E5j8H9i0j1K2L3M4N6',
    exitPoolAddress: PoolRulesConfig.defaultExitPoolAddress,
    ticketPriceTrx: 1000,
    poolCreditTrx: 10000,
    poolTargetTrx: 1000000,
    exitAmountTrx: 12000,
    profitRate: 0.2,
  ),
  PoolTierConfig(
    id: '100000',
    name: '大额排单',
    purchaseAddress: 'TQmzZQQQk7C9F5aG9v6E5j8H9i0j1K2L3M4N7',
    exitPoolAddress: PoolRulesConfig.defaultExitPoolAddress,
    ticketPriceTrx: 5000,
    poolCreditTrx: 100000,
    poolTargetTrx: 10000000,
    exitAmountTrx: 110000,
    profitRate: 0.1,
  ),
  PoolTierConfig(
    id: '1000000',
    name: '超大额排单',
    purchaseAddress: 'TQmzZQQQk7C9F5aG9v6E5j8H9i0j1K2L3M4N8',
    exitPoolAddress: PoolRulesConfig.defaultExitPoolAddress,
    ticketPriceTrx: 50000,
    poolCreditTrx: 1000000,
    poolTargetTrx: 100000000,
    exitAmountTrx: 1080000,
    profitRate: 0.08,
  ),
];
