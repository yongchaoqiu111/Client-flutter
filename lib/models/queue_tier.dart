class QueueTier {
  const QueueTier({
    required this.id,
    required this.name,
    required this.amount,
    required this.exitAmount,
    required this.profitRate,
    required this.ticketCost,
    this.eligibility = 'none',
  });

  final String id;
  final String name;
  final int amount;
  final int exitAmount;
  final double profitRate;
  final int ticketCost;
  final String eligibility;

  factory QueueTier.fromJson(Map<String, dynamic> json) {
    return QueueTier(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      exitAmount: (json['exitAmount'] as num?)?.toInt() ?? 0,
      profitRate: (json['profitRate'] as num?)?.toDouble() ?? 0,
      ticketCost: (json['ticketCost'] as num?)?.toInt() ?? 0,
      eligibility: json['eligibility'] as String? ?? 'none',
    );
  }

  String get eligibilityLabel {
    switch (eligibility) {
      case 'direct_referral_10':
        return '需直推 10 人';
      case '10_middle_tier':
        return '需 10 个中额下级';
      case '10_large_tier':
        return '需 10 个大额下级';
      default:
        return '无门槛';
    }
  }
}
