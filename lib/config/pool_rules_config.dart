/// 排单池规则（与 WSS-server shared/pool-config.js pool-v3-split 一致）

class PoolRulesConfig {

  PoolRulesConfig._();



  static const rulesVersion = 'pool-v4-dual-pool';

  /// 主网出场池收款地址（三档共用）
  static const defaultExitPoolAddress = 'TRjvctzrc5WcEeu2UrT8mV5H6zW8dCgimR';

  static const int checkpointIntervalMs = 24 * 3600 * 1000;

  static const int entryPeriodDays = 15;

  static const int exitPeriodDays = 7;

  static const int matchPaymentTimeoutHours = 24;

  static const int maxOpenEntriesPerPayer = 1;

  static const int maxSplitsPerPayer = 3;

  /// 每日唯一匹配：UTC 0:00（北京 08:00），全天只匹配一次
  static const int dailyMatchUtcHour = 0;
  static const int matchesPerDay = 1;

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

  });



  final String id;

  final String name;

  final String purchaseAddress;

  /// 出场应付地址（可与买券同址，靠金额区分）
  final String exitPoolAddress;

  final double ticketPriceTrx;

  final double poolCreditTrx;

  final double poolTargetTrx;

  final double exitAmountTrx;

}



const List<PoolTierConfig> kPoolTiers = [

  PoolTierConfig(

    id: '3000',

    name: '3000档',

    purchaseAddress: 'TQmzZQQQk7C9F5aG9v6E5j8H9i0j1K2L3M4N5',

    exitPoolAddress: PoolRulesConfig.defaultExitPoolAddress,

    ticketPriceTrx: 100,

    poolCreditTrx: 3000,

    poolTargetTrx: 300000,

    exitAmountTrx: 3900,

  ),

  PoolTierConfig(

    id: '30000',

    name: '30000档',

    purchaseAddress: 'TQmzZQQQk7C9F5aG9v6E5j8H9i0j1K2L3M4N6',

    exitPoolAddress: 'TQmzZQQQk7C9F5aG9v6E5j8H9i0j1K2L3M4N6',

    ticketPriceTrx: 1000,

    poolCreditTrx: 30000,

    poolTargetTrx: 3000000,

    exitAmountTrx: 39000,

  ),

  PoolTierConfig(

    id: '300000',

    name: '30万档',

    purchaseAddress: 'TQmzZQQQk7C9F5aG9v6E5j8H9i0j1K2L3M4N7',

    exitPoolAddress: PoolRulesConfig.defaultExitPoolAddress,

    ticketPriceTrx: 10000,

    poolCreditTrx: 300000,

    poolTargetTrx: 30000000,

    exitAmountTrx: 390000,

  ),

];


