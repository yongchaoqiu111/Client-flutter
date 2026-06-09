import '../config/pool_rules_config.dart';
import '../models/pool_cycle_models.dart';

const _archiveStatuses = {'done', 'pay_expired', 'blocked'};

class LoadedPoolSnapshot {
  LoadedPoolSnapshot({
    required this.stateMap,
    required this.matchDays,
    required this.blockedPayers,
    required this.usedExitTxIds,
    required this.lastQueueIndex,
    required this.incrementalFromMs,
    required this.lastMatchDayMs,
    required this.archivedEntryCount,
  });

  final Map<String, PoolEntry> stateMap;
  final List<MatchDaySummary> matchDays;
  final Set<String> blockedPayers;
  final Set<String> usedExitTxIds;
  final int lastQueueIndex;
  final int incrementalFromMs;
  final int lastMatchDayMs;
  final int archivedEntryCount;
}

class MatchDaySummary {
  const MatchDaySummary({
    required this.matchDayId,
    required this.matchedCreditTrx,
    this.remainingPoolCreditTrx,
  });

  final String matchDayId;
  final double matchedCreditTrx;
  final double? remainingPoolCreditTrx;

  Map<String, dynamic> toJson() => {
        'matchDayId': matchDayId,
        'matchedCreditTrx': matchedCreditTrx,
        if (remainingPoolCreditTrx != null) 'remainingPoolCreditTrx': remainingPoolCreditTrx,
      };

  static MatchDaySummary fromJson(Map<String, dynamic> j) => MatchDaySummary(
        matchDayId: j['matchDayId'] as String? ?? '',
        matchedCreditTrx: (j['matchedCreditTrx'] as num?)?.toDouble() ?? 0,
        remainingPoolCreditTrx: (j['remainingPoolCreditTrx'] as num?)?.toDouble(),
      );
}

class PoolSnapshotCodec {
  static Map<String, dynamic> exportSnapshot(
    String poolId,
    Map<String, PoolEntry> stateMap,
    List<MatchDaySummary> matchDays,
    int wallNowMs, {
    Set<String>? blockedPayers,
    Set<String>? usedExitTxIds,
  }) {
    final active = <Map<String, dynamic>>[];
    final blocked = {...?blockedPayers};
    var lastQueueIndex = 0;
    var archived = 0;

    for (final e in stateMap.values) {
      if (_archiveStatuses.contains(e.status)) {
        archived += 1;
        if (e.status == 'blocked') blocked.add(e.payer);
        continue;
      }
      active.add(_serializeEntry(e));
      if (e.queueIndex > lastQueueIndex) lastQueueIndex = e.queueIndex;
    }

    active.sort((a, b) => (a['queueIndex'] as int).compareTo(b['queueIndex'] as int));

    final lastMatchDayMs = matchDays.isEmpty
        ? 0
        : DateTime.parse('${matchDays.last.matchDayId}T00:00:00.000Z').millisecondsSinceEpoch;

    return {
      'rulesVersion': PoolRulesConfig.rulesVersion,
      'poolId': poolId,
      'snapshotAtMs': wallNowMs,
      'snapshotDayId': DateTime.fromMillisecondsSinceEpoch(wallNowMs, isUtc: true)
          .toIso8601String()
          .substring(0, 10),
      'lastMatchDayMs': lastMatchDayMs,
      'matchDays': matchDays.map((d) => d.toJson()).toList(),
      'activeEntries': active,
      'blockedPayers': blocked.toList(),
      'usedExitTxIds': (usedExitTxIds ?? {}).toList(),
      'lastQueueIndex': lastQueueIndex,
      'archivedEntryCount': archived,
    };
  }

  static LoadedPoolSnapshot? loadSnapshot(Map<String, dynamic>? snapshot) {
    if (snapshot == null || snapshot['poolId'] == null) return null;
    final ver = snapshot['rulesVersion'] as String?;
    if (ver != null && ver != PoolRulesConfig.rulesVersion) {
      throw StateError('snapshot rulesVersion mismatch: $ver');
    }
    final stateMap = <String, PoolEntry>{};
    for (final raw in snapshot['activeEntries'] as List<dynamic>? ?? []) {
      final e = _deserializeEntry(raw as Map<String, dynamic>);
      stateMap[e.entryId] = e;
    }
    final matchDays = (snapshot['matchDays'] as List<dynamic>? ?? [])
        .map((d) => MatchDaySummary.fromJson(d as Map<String, dynamic>))
        .toList();
    return LoadedPoolSnapshot(
      stateMap: stateMap,
      matchDays: matchDays,
      blockedPayers: {...snapshot['blockedPayers'] as List<dynamic>? ?? []}.cast<String>(),
      usedExitTxIds: {...snapshot['usedExitTxIds'] as List<dynamic>? ?? []}.cast<String>(),
      lastQueueIndex: snapshot['lastQueueIndex'] as int? ?? 0,
      incrementalFromMs: snapshot['snapshotAtMs'] as int? ?? 0,
      lastMatchDayMs: snapshot['lastMatchDayMs'] as int? ?? 0,
      archivedEntryCount: snapshot['archivedEntryCount'] as int? ?? 0,
    );
  }

  static List<RawPoolTx> filterTxsAfter(List<RawPoolTx> txs, int afterMs) {
    return txs.where((t) => t.blockTimestamp > afterMs).toList();
  }

  static Map<String, dynamic> _serializeEntry(PoolEntry e) => {
        'entryId': e.entryId,
        'poolId': e.poolId,
        'payer': e.payer,
        'ticketPaidTrx': e.ticketPaidTrx,
        'poolCreditTrx': e.poolCreditTrx,
        'remainingPoolCreditTrx': e.remainingPoolCreditTrx,
        'exitAmountTrx': e.exitAmountTrx,
        'blockTimestamp': e.blockTimestamp,
        'queueIndex': e.queueIndex,
        'status': e.status,
        'payAssignments': e.payAssignments
            .map((a) => {
                  'assignmentId': a.assignmentId,
                  'payer': a.payer,
                  'payerEntryId': a.payerEntryId,
                  'amountTrx': a.amountTrx,
                  'matchAtMs': a.matchAtMs,
                  'deadlineMs': a.deadlineMs,
                  'collectorAddress': a.collectorAddress,
                })
            .toList(),
        'payDeadlineMs': e.payDeadlineMs,
        'recvQueueJoinedAt': e.recvQueueJoinedAt,
        'verifiedMainnetTxId': e.verifiedMainnetTxId,
        'exitRemainderTrx': e.exitRemainderTrx,
        'surplusToTicketTrx': e.surplusToTicketTrx,
        'blockReason': e.blockReason,
        'completedAt': e.completedAt,
      };

  static PoolEntry _deserializeEntry(Map<String, dynamic> j) {
    final assigns = <PayAssignmentRecord>[];
    for (final raw in j['payAssignments'] as List<dynamic>? ?? []) {
      final m = raw as Map<String, dynamic>;
      assigns.add(PayAssignmentRecord(
        assignmentId: m['assignmentId'] as String? ?? '',
        payer: m['payer'] as String? ?? '',
        payerEntryId: m['payerEntryId'] as String? ?? '',
        amountTrx: (m['amountTrx'] as num?)?.toDouble() ?? 0,
        matchAtMs: m['matchAtMs'] as int? ?? 0,
        deadlineMs: m['deadlineMs'] as int? ?? 0,
        collectorAddress: m['collectorAddress'] as String? ?? '',
      ));
    }
    return PoolEntry(
      entryId: j['entryId'] as String? ?? '',
      poolId: j['poolId'] as String? ?? '',
      payer: j['payer'] as String? ?? '',
      ticketPaidTrx: (j['ticketPaidTrx'] as num?)?.toDouble() ?? 0,
      poolCreditTrx: (j['poolCreditTrx'] as num?)?.toDouble() ?? 0,
      remainingPoolCreditTrx: (j['remainingPoolCreditTrx'] as num?)?.toDouble(),
      exitAmountTrx: (j['exitAmountTrx'] as num?)?.toDouble() ?? 0,
      blockTimestamp: j['blockTimestamp'] as int? ?? 0,
      queueIndex: j['queueIndex'] as int? ?? 0,
      status: j['status'] as String? ?? 'pay_queued',
      payAssignments: assigns,
      payDeadlineMs: j['payDeadlineMs'] as int?,
      recvQueueJoinedAt: j['recvQueueJoinedAt'] as int?,
      verifiedMainnetTxId: j['verifiedMainnetTxId'] as String?,
      exitRemainderTrx: (j['exitRemainderTrx'] as num?)?.toDouble(),
      surplusToTicketTrx: (j['surplusToTicketTrx'] as num?)?.toDouble(),
      blockReason: j['blockReason'] as String?,
      completedAt: j['completedAt'] as int?,
    );
  }
}
