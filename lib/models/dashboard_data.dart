class DashboardData {
  DashboardData({
    required this.orderCounts,
    required this.teamCount,
    required this.ticketPriceToday,
    required this.checkinRate,
    required this.thankRate,
    required this.assessmentLevel,
    required this.rewardBalance,
    required this.ticketBalance,
  });

  final Map<String, int> orderCounts;
  final int teamCount;
  final num ticketPriceToday;
  final num checkinRate;
  final num thankRate;
  final String assessmentLevel;
  final num rewardBalance;
  final int ticketBalance;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    final counts = json['orderCounts'] as Map<String, dynamic>? ?? {};
    final assessment = json['assessment'] as Map<String, dynamic>? ?? {};
    return DashboardData(
      orderCounts: {
        'queued': (counts['queued'] as num?)?.toInt() ?? 0,
        'paying': (counts['paying'] as num?)?.toInt() ?? 0,
        'earning': (counts['earning'] as num?)?.toInt() ?? 0,
        'done': (counts['done'] as num?)?.toInt() ?? 0,
      },
      teamCount: (json['teamCount'] as num?)?.toInt() ?? (user['teamCount'] as num?)?.toInt() ?? 0,
      ticketPriceToday: (json['ticketPriceToday'] as num?) ?? (assessment['price'] as num?) ?? 100,
      checkinRate: (assessment['checkinRate'] as num?) ?? 0,
      thankRate: (assessment['thankRate'] as num?) ?? 0,
      assessmentLevel: assessment['level'] as String? ?? 'level1',
      rewardBalance: (user['rewardBalance'] as num?) ?? 0,
      ticketBalance: (user['ticketBalance'] as num?)?.toInt() ?? 0,
    );
  }
}
