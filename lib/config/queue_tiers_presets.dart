import '../models/queue_tier.dart';

/// 排单档位预算（与设计文档 §1.3、服务端 shared/queue-rules.js 一致）
class QueueTiersPresets {
  QueueTiersPresets._();

  static const ticketPriceTrx = 100;

  static const List<QueueTier> tiers = [
    QueueTier(
      id: 'tier1',
      name: '小额排单',
      amount: 1000,
      exitAmount: 1300,
      profitRate: 0.3,
      ticketCost: 1,
      eligibility: 'none',
    ),
    QueueTier(
      id: 'tier2',
      name: '中额排单',
      amount: 10000,
      exitAmount: 12000,
      profitRate: 0.2,
      ticketCost: 10,
      eligibility: 'direct_referral_10',
    ),
    QueueTier(
      id: 'tier3',
      name: '大额排单',
      amount: 100000,
      exitAmount: 110000,
      profitRate: 0.1,
      ticketCost: 50,
      eligibility: '10_middle_tier',
    ),
    QueueTier(
      id: 'tier4',
      name: '超大额排单',
      amount: 1000000,
      exitAmount: 1080000,
      profitRate: 0.08,
      ticketCost: 500,
      eligibility: '10_large_tier',
    ),
  ];

  static List<QueueTier> get defaultTiers => List<QueueTier>.from(tiers);
}
