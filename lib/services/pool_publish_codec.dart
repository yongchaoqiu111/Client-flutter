import '../models/pool_cycle_models.dart';

/// 解析 GitHub/Vercel 发布的 snapshot.json → PoolCycleResult
class PoolPublishCodec {
  static PoolCycleResult poolFromJson(Map<String, dynamic> j) {
    final fillMap = j['fill'] as Map<String, dynamic>? ?? {};
    return PoolCycleResult(
      poolId: j['poolId'] as String? ?? '',
      checkpointCutoffMs: (j['checkpointCutoffMs'] as num?)?.toInt() ?? 0,
      fill: PoolFillState(
        poolId: fillMap['poolId'] as String? ?? j['poolId'] as String? ?? '',
        targetTrx: (fillMap['targetTrx'] as num?)?.toDouble() ?? 0,
        totalPoolCreditTrx: (fillMap['totalPoolCreditTrx'] as num?)?.toDouble() ?? 0,
        entryCount: (fillMap['entryCount'] as num?)?.toInt() ?? 0,
        isFull: fillMap['isFull'] as bool? ?? false,
        fillPercent: (fillMap['fillPercent'] as num?)?.toDouble() ?? 0,
        entryPeriodSatisfied: fillMap['entryPeriodSatisfied'] as bool? ?? false,
        canMatch: fillMap['canMatch'] as bool? ?? false,
        daysSinceFirstEntry: (fillMap['daysSinceFirstEntry'] as num?)?.toInt() ?? 0,
        ticketPriceTrx: (fillMap['ticketPriceTrx'] as num?)?.toDouble() ?? 100,
        poolCreditPerTicket: (fillMap['poolCreditPerTicket'] as num?)?.toDouble() ?? 0,
        queuedPoolCreditTrx: (fillMap['queuedPoolCreditTrx'] as num?)?.toDouble(),
        consumedPoolCreditTrx: (fillMap['consumedPoolCreditTrx'] as num?)?.toDouble(),
        overflowPoolCreditTrx: (fillMap['overflowPoolCreditTrx'] as num?)?.toDouble(),
      ),
      entries: _entries(j['entries'] as List<dynamic>? ?? []),
      assignments: _assignments(j['assignments'] as List<dynamic>? ?? []),
      ticketSurplusAssignments: _ticketSurplus(j['ticketSurplusAssignments'] as List<dynamic>? ?? []),
      collectorMode: j['collectorMode'] as String? ?? 'exit_pool',
      purchaseAddress: j['purchaseAddress'] as String? ?? '',
      matchDayId: j['matchDayId'] as String? ?? '',
      matchAtMs: (j['matchAtMs'] as num?)?.toInt() ?? 0,
      nextMatchAtMs: (j['nextMatchAtMs'] as num?)?.toInt() ?? 0,
      matchedCreditTrx: (j['matchedCreditTrx'] as num?)?.toDouble() ?? 0,
      overflowPoolCreditTrx: (j['overflowPoolCreditTrx'] as num?)?.toDouble() ?? 0,
      receiverCount: (j['receiverCount'] as num?)?.toInt() ?? 0,
      remainderTrx: (j['remainderTrx'] as num?)?.toDouble() ?? 0,
      remainderToReceiverTrx: (j['remainderToReceiverTrx'] as num?)?.toDouble() ?? 0,
      ticketRemainderTrx: (j['ticketRemainderTrx'] as num?)?.toDouble() ?? 0,
      exitPoolAddress: j['exitPoolAddress'] as String? ?? '',
      payAssignments: _assignments(j['payAssignments'] as List<dynamic>? ?? []),
      recvAssignments: _assignments(j['recvAssignments'] as List<dynamic>? ?? []),
      replayMode: j['replayMode'] as String? ?? 'published',
      recvPoolCount: (j['recvPoolCount'] as num?)?.toInt() ?? 0,
      snapshot: j['snapshot'] as Map<String, dynamic>?,
    );
  }

  static List<PoolEntry> _entries(List<dynamic> list) {
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return PoolEntry(
        entryId: m['entryId'] as String? ?? '',
        poolId: m['poolId'] as String? ?? '',
        payer: m['payer'] as String? ?? '',
        ticketPaidTrx: (m['ticketPaidTrx'] as num?)?.toDouble() ?? 0,
        poolCreditTrx: (m['poolCreditTrx'] as num?)?.toDouble() ?? 0,
        exitAmountTrx: (m['exitAmountTrx'] as num?)?.toDouble() ?? 0,
        blockTimestamp: (m['blockTimestamp'] as num?)?.toInt() ?? 0,
        queueIndex: (m['queueIndex'] as num?)?.toInt() ?? 0,
        status: m['status'] as String? ?? 'pay_queued',
        remainingPoolCreditTrx: (m['remainingPoolCreditTrx'] as num?)?.toDouble(),
        payDeadlineMs: (m['payDeadlineMs'] as num?)?.toInt(),
        verifiedMainnetTxId: m['verifiedMainnetTxId'] as String?,
      );
    }).toList();
  }

  static List<SplitAssignment> _assignments(List<dynamic> list) {
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return SplitAssignment(
        assignmentId: m['assignmentId'] as String? ?? '',
        poolId: m['poolId'] as String? ?? '',
        payer: m['payer'] as String? ?? '',
        payerEntryId: m['payerEntryId'] as String? ?? '',
        beneficiary: m['beneficiary'] as String? ?? '',
        collectorAddress: m['collectorAddress'] as String? ?? '',
        amountTrx: (m['amountTrx'] as num?)?.toDouble() ?? 0,
        splitIndex: (m['splitIndex'] as num?)?.toInt() ?? 0,
        exitAmountTrx: (m['exitAmountTrx'] as num?)?.toDouble() ?? 0,
        collectorMode: m['collectorMode'] as String? ?? 'exit_pool',
        channel: m['channel'] as String? ?? '',
        countsForPool: m['countsForPool'] as bool? ?? true,
        matchDayId: m['matchDayId'] as String? ?? '',
        matchAtMs: (m['matchAtMs'] as num?)?.toInt() ?? 0,
        deadlineMs: (m['deadlineMs'] as num?)?.toInt() ?? 0,
        purpose: m['purpose'] as String? ?? '',
      );
    }).toList();
  }

  static List<TicketSurplusAssignment> _ticketSurplus(List<dynamic> list) {
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return TicketSurplusAssignment(
        assignmentId: m['assignmentId'] as String? ?? '',
        poolId: m['poolId'] as String? ?? '',
        payer: m['payer'] as String? ?? '',
        payerEntryId: m['payerEntryId'] as String? ?? '',
        collectorAddress: m['collectorAddress'] as String? ?? '',
        amountTrx: (m['amountTrx'] as num?)?.toDouble() ?? 0,
        matchDayId: m['matchDayId'] as String? ?? '',
      );
    }).toList();
  }
}
