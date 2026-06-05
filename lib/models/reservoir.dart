class ReservoirStatus {
  ReservoirStatus({
    required this.roundNumber,
    required this.currentTarget,
    required this.currentAmount,
    required this.status,
    this.expandCount = 0,
  });

  final int roundNumber;
  final double currentTarget;
  final double currentAmount;
  final String status;
  final int expandCount;

  double get fillRatio =>
      currentTarget > 0 ? (currentAmount / currentTarget).clamp(0.0, 1.0) : 0;

  factory ReservoirStatus.fromJson(Map<String, dynamic> json) {
    return ReservoirStatus(
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 1,
      currentTarget: (json['currentTarget'] as num?)?.toDouble() ?? 0,
      currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'filling',
      expandCount: (json['expandCount'] as num?)?.toInt() ?? 0,
    );
  }
}
