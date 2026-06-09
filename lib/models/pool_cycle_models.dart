class PoolEntry {

  const PoolEntry({

    required this.entryId,

    required this.poolId,

    required this.payer,

    required this.ticketPaidTrx,

    required this.poolCreditTrx,

    required this.exitAmountTrx,

    required this.blockTimestamp,

    required this.queueIndex,

    required this.status,

    this.remainingPoolCreditTrx,

    this.blockReason,

    this.completedAt,

    this.exitRemainderTrx,

    this.surplusToTicketTrx,

    this.recvQueueJoinedAt,

    this.payDeadlineMs,

    this.verifiedMainnetTxId,

    this.payAssignments = const [],

  });



  final String entryId;

  final String poolId;

  final String payer;

  final double ticketPaidTrx;

  final double poolCreditTrx;

  final double? remainingPoolCreditTrx;

  final double exitAmountTrx;

  final int blockTimestamp;

  final int queueIndex;

  final String status;

  final String? blockReason;

  final int? completedAt;

  final double? exitRemainderTrx;

  final double? surplusToTicketTrx;

  final int? recvQueueJoinedAt;

  final int? payDeadlineMs;

  final String? verifiedMainnetTxId;

  final List<PayAssignmentRecord> payAssignments;

}

class PayAssignmentRecord {
  const PayAssignmentRecord({
    required this.assignmentId,
    required this.payer,
    required this.payerEntryId,
    required this.amountTrx,
    required this.matchAtMs,
    required this.deadlineMs,
    required this.collectorAddress,
  });

  final String assignmentId;
  final String payer;
  final String payerEntryId;
  final double amountTrx;
  final int matchAtMs;
  final int deadlineMs;
  final String collectorAddress;
}

class RawPoolTx {
  const RawPoolTx({
    required this.txHash,
    required this.fromAddress,
    required this.amount,
    required this.blockTimestamp,
    this.toAddress,
    this.blockNumber,
  });

  final String txHash;
  final String fromAddress;
  final String? toAddress;
  final double amount;
  final int blockTimestamp;
  final int? blockNumber;
}



class PoolExitAnchor {

  const PoolExitAnchor({

    required this.entryId,

    required this.payer,

    required this.payee,

    required this.mainnetTxId,

    required this.anchoredAt,

    this.poolId,

  });



  final String entryId;

  final String payer;

  final String payee;

  final String mainnetTxId;

  final int anchoredAt;

  final String? poolId;

}



class PoolFillState {

  const PoolFillState({

    required this.poolId,

    required this.totalPoolCreditTrx,

    required this.targetTrx,

    required this.entryCount,

    required this.isFull,

    required this.fillPercent,

    required this.entryPeriodSatisfied,

    required this.canMatch,

    required this.daysSinceFirstEntry,

    required this.ticketPriceTrx,

    required this.poolCreditPerTicket,

    this.queuedPoolCreditTrx,

    this.consumedPoolCreditTrx,

    this.overflowPoolCreditTrx,

  });



  final String poolId;

  final double totalPoolCreditTrx;

  final double targetTrx;

  final int entryCount;

  final bool isFull;

  final double fillPercent;

  final bool entryPeriodSatisfied;

  final bool canMatch;

  final int daysSinceFirstEntry;

  final double ticketPriceTrx;

  final double poolCreditPerTicket;

  final double? queuedPoolCreditTrx;

  final double? consumedPoolCreditTrx;

  final double? overflowPoolCreditTrx;

}



class SplitAssignment {

  const SplitAssignment({

    required this.assignmentId,

    required this.poolId,

    required this.payer,

    required this.payerEntryId,

    this.beneficiary = '',

    required this.collectorAddress,

    required this.amountTrx,

    this.splitIndex = 0,

    this.exitAmountTrx = 0,

    this.collectorMode = 'exit_pool',

    this.channel = 'pool',

    this.countsForPool = true,

    this.matchDayId = '',

    this.matchAtMs = 0,

    this.deadlineMs = 0,

    this.purpose = '',

  });



  final String assignmentId;

  final String poolId;

  final String payer;

  final String payerEntryId;

  final String beneficiary;

  final String collectorAddress;

  final double amountTrx;

  final int splitIndex;

  final double exitAmountTrx;

  final String collectorMode;

  final String channel;

  final bool countsForPool;

  final String matchDayId;

  final int matchAtMs;

  final int deadlineMs;

  final String purpose;

}



/// 凑满 3900 后，付款方多余额度 → 打排单券地址

class TicketSurplusAssignment {

  const TicketSurplusAssignment({

    required this.assignmentId,

    required this.poolId,

    required this.payer,

    required this.payerEntryId,

    required this.collectorAddress,

    required this.amountTrx,

    required this.matchDayId,

  });



  final String assignmentId;

  final String poolId;

  final String payer;

  final String payerEntryId;

  final String collectorAddress;

  final double amountTrx;

  final String matchDayId;

}



class PoolCycleResult {

  const PoolCycleResult({

    required this.poolId,

    required this.checkpointCutoffMs,

    required this.fill,

    required this.entries,

    required this.assignments,

    required this.collectorMode,

    required this.purchaseAddress,

    required this.matchDayId,

    required this.matchAtMs,

    required this.nextMatchAtMs,

    this.ticketSurplusAssignments = const [],

    this.matchedCreditTrx = 0,

    this.overflowPoolCreditTrx = 0,

    this.receiverCount = 0,

    this.remainderTrx = 0,

    this.remainderToReceiverTrx = 0,

    this.ticketRemainderTrx = 0,

    this.exitPoolAddress = '',

    this.payAssignments = const [],

    this.recvAssignments = const [],

    this.replayMode = 'full',

    this.recvPoolCount = 0,

    this.snapshot,

  });



  final String poolId;

  final int checkpointCutoffMs;

  final PoolFillState fill;

  final List<PoolEntry> entries;

  final List<SplitAssignment> assignments;

  final List<TicketSurplusAssignment> ticketSurplusAssignments;

  final String collectorMode;

  final String purchaseAddress;

  final String matchDayId;

  final int matchAtMs;

  final int nextMatchAtMs;

  final double matchedCreditTrx;

  final double overflowPoolCreditTrx;

  final int receiverCount;

  final double remainderTrx;

  final double remainderToReceiverTrx;

  final double ticketRemainderTrx;

  final String exitPoolAddress;

  final List<SplitAssignment> payAssignments;

  final List<SplitAssignment> recvAssignments;

  final String replayMode;

  final int recvPoolCount;

  final Map<String, dynamic>? snapshot;

}



