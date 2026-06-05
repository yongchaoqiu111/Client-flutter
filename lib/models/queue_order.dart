class QueueOrder {
  QueueOrder({
    required this.id,
    required this.userAddress,
    required this.amount,
    required this.status,
    this.payAmount,
    this.ticketCost = 0,
    this.tierName = '',
    this.expectedExit = 0,
    this.createdAt,
    this.confirmedAt,
    this.txHash,
    this.exitDay,
    this.exitPaidTotal,
    this.expectedExitDays = 7,
  });

  final String id;
  final String userAddress;
  final num amount;
  final String status;
  final num? payAmount;
  final int ticketCost;
  final String tierName;
  final num expectedExit;
  final int? createdAt;
  final int? confirmedAt;
  final String? txHash;
  final int? exitDay;
  final num? exitPaidTotal;
  final int expectedExitDays;

  factory QueueOrder.fromJson(Map<String, dynamic> json) {
    return QueueOrder(
      id: json['id'] as String? ?? '',
      userAddress: json['userAddress'] as String? ?? '',
      amount: json['amount'] as num? ?? 0,
      status: json['status'] as String? ?? 'pending',
      payAmount: json['payAmount'] as num?,
      ticketCost: (json['ticketCost'] as num?)?.toInt() ?? 0,
      tierName: json['tierName'] as String? ?? '',
      expectedExit: json['expectedExit'] as num? ?? 0,
      createdAt: (json['createdAt'] as num?)?.toInt(),
      confirmedAt: (json['confirmedAt'] as num?)?.toInt(),
      txHash: json['txHash'] as String?,
      exitDay: (json['exitDay'] as num?)?.toInt(),
      exitPaidTotal: json['exitPaidTotal'] as num?,
    );
  }

  double get exitProgress {
    if (status != 'exiting') return status == 'exited' ? 1.0 : 0.0;
    final day = exitDay ?? 0;
    return (day / expectedExitDays).clamp(0.0, 1.0);
  }

  String get statusLabel {
    switch (status) {
      case 'waiting_payment':
        return '支付中';
      case 'confirmed':
        return '排队中';
      case 'exiting':
        return '收益中';
      case 'exited':
        return '已完成';
      default:
        return status;
    }
  }

  String get filterKey {
    switch (status) {
      case 'waiting_payment':
        return 'paying';
      case 'confirmed':
        return 'queued';
      case 'exiting':
        return 'earning';
      case 'exited':
        return 'done';
      default:
        return 'all';
    }
  }
}
