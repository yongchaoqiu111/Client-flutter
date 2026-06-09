import '../config/pool_rules_config.dart';
import '../models/pool_cycle_models.dart';

/// 无服务器排单（Dart 引擎仍为 v3 路径，v4 双池以 WSS-server/shared/pool-rules.js 为准）
class PoolEngineService {
  static const _msDay = 24 * 3600 * 1000;

  List<PoolEntry> buildEntries(String poolId, List<RawPoolTx> txs) {
    final cfg = kPoolTiers.firstWhere((t) => t.id == poolId);
    final sorted = _sortTxs(txs);
    final valid = sorted
        .where((tx) => (tx.amount - cfg.ticketPriceTrx).abs() < 0.000001)
        .toList();
    return List.generate(valid.length, (i) {
      final tx = valid[i];
      return PoolEntry(
        entryId: tx.txHash,
        poolId: poolId,
        payer: tx.fromAddress,
        ticketPaidTrx: tx.amount,
        poolCreditTrx: cfg.poolCreditTrx,
        remainingPoolCreditTrx: cfg.poolCreditTrx,
        exitAmountTrx: cfg.exitAmountTrx,
        blockTimestamp: tx.blockTimestamp,
        queueIndex: i + 1,
        status: 'queued',
      );
    });
  }

  List<PoolEntry> applyLifecycle(List<PoolEntry> entries, List<PoolExitAnchor> anchors) {
    final anchorByEntry = {for (final a in anchors) a.entryId: a};
    final openByPayer = <String, String>{};
    final result = <PoolEntry>[];

    const frozenStatuses = {'done', 'blocked', 'consumed', 'exit_pending', 'exit_partial'};

    for (final e in entries) {
      final anchor = anchorByEntry[e.entryId];
      if (anchor != null) {
        result.add(PoolEntry(
          entryId: e.entryId,
          poolId: e.poolId,
          payer: e.payer,
          ticketPaidTrx: e.ticketPaidTrx,
          poolCreditTrx: e.poolCreditTrx,
          remainingPoolCreditTrx: 0,
          exitAmountTrx: e.exitAmountTrx,
          blockTimestamp: e.blockTimestamp,
          queueIndex: e.queueIndex,
          status: 'done',
          completedAt: anchor.anchoredAt,
        ));
        continue;
      }
      if (frozenStatuses.contains(e.status)) {
        result.add(e);
        continue;
      }
      if (openByPayer.containsKey(e.payer)) {
        result.add(PoolEntry(
          entryId: e.entryId,
          poolId: e.poolId,
          payer: e.payer,
          ticketPaidTrx: e.ticketPaidTrx,
          poolCreditTrx: e.poolCreditTrx,
          remainingPoolCreditTrx: 0,
          exitAmountTrx: e.exitAmountTrx,
          blockTimestamp: e.blockTimestamp,
          queueIndex: e.queueIndex,
          status: 'blocked',
          blockReason: '一次只能排一单',
        ));
        continue;
      }
      openByPayer[e.payer] = e.entryId;
      result.add(PoolEntry(
        entryId: e.entryId,
        poolId: e.poolId,
        payer: e.payer,
        ticketPaidTrx: e.ticketPaidTrx,
        poolCreditTrx: e.poolCreditTrx,
        remainingPoolCreditTrx: e.remainingPoolCreditTrx ?? e.poolCreditTrx,
        exitAmountTrx: e.exitAmountTrx,
        blockTimestamp: e.blockTimestamp,
        queueIndex: e.queueIndex,
        status: 'queued',
      ));
    }
    return result;
  }

  double poolLedgerBalance(List<PoolEntry> entries, List<_MatchDaySummary> matchDays) {
    final committed = entries
        .where((e) => e.status != 'blocked' && e.status != 'done')
        .fold(0.0, (s, e) => s + e.poolCreditTrx);
    final consumed = matchDays.fold(0.0, (s, d) => s + d.matchedCreditTrx);
    return _round4(committed - consumed);
  }

  double _remainingCredit(PoolEntry e) {
    if (e.status != 'queued') return 0;
    return e.remainingPoolCreditTrx ?? e.poolCreditTrx;
  }

  PoolFillState poolFillState(
    String poolId,
    List<PoolEntry> entries,
    int evaluationMs, [
    List<_MatchDaySummary> matchDays = const [],
  ]) {
    final cfg = kPoolTiers.firstWhere((t) => t.id == poolId);
    final credits = poolLedgerBalance(entries, matchDays);
    final queuedCredits = entries
        .where((e) => e.status == 'queued')
        .fold(0.0, (s, e) => s + _remainingCredit(e));
    final active = entries.where((e) => e.status != 'blocked' && e.status != 'done').toList();
    final firstTs = active.isEmpty
        ? null
        : active.map((e) => e.blockTimestamp).reduce((a, b) => a < b ? a : b);
    const minFillMs = PoolRulesConfig.entryPeriodDays * _msDay;
    final full = credits >= cfg.poolTargetTrx;
    final overflow = _round4(credits > cfg.poolTargetTrx ? credits - cfg.poolTargetTrx : 0);
    final days = firstTs == null ? 0 : ((evaluationMs - firstTs) / _msDay).floor();
    final entryOk = firstTs != null && evaluationMs >= firstTs + minFillMs;
    final consumed = matchDays.fold(0.0, (s, d) => s + d.matchedCreditTrx);

    return PoolFillState(
      poolId: poolId,
      totalPoolCreditTrx: credits,
      queuedPoolCreditTrx: queuedCredits,
      consumedPoolCreditTrx: consumed,
      overflowPoolCreditTrx: overflow,
      targetTrx: cfg.poolTargetTrx,
      entryCount: entries.where((e) => e.status == 'queued').length,
      isFull: full,
      fillPercent: cfg.poolTargetTrx > 0 ? (credits / cfg.poolTargetTrx * 100).clamp(0, 100) : 0,
      entryPeriodSatisfied: entryOk,
      canMatch: full && entryOk && overflow > 0.000001,
      daysSinceFirstEntry: days,
      ticketPriceTrx: cfg.ticketPriceTrx,
      poolCreditPerTicket: cfg.poolCreditTrx,
    );
  }

  _SplitResult _buildSplitInternal(
    String poolId,
    List<PoolEntry> entries,
    List<PoolExitAnchor> anchors,
    int evaluationMs,
    List<_MatchDaySummary> matchDays,
  ) {
    final cfg = kPoolTiers.firstWhere((t) => t.id == poolId);
    final fill = poolFillState(poolId, entries, evaluationMs, matchDays);
    if (!fill.canMatch) {
      return _SplitResult(fill: fill);
    }

    final queued = entries.where((e) => e.status == 'queued').toList()
      ..sort((a, b) => a.queueIndex.compareTo(b.queueIndex));
    if (queued.isEmpty) return _SplitResult(fill: fill);

    String collectorFor(PoolEntry entry) {
      final a = anchors.where((x) => x.entryId == entry.entryId).firstOrNull;
      if (a != null && a.payee.isNotEmpty) return a.payee;
      return cfg.purchaseAddress;
    }

    final hasPersonal = anchors.any((a) => a.payee.isNotEmpty && a.payee != cfg.purchaseAddress);
    final collectorMode = hasPersonal ? 'exit_pool' : 'purchase_address';
    final exitAmount = cfg.exitAmountTrx;
    final overflow = fill.overflowPoolCreditTrx ?? 0;
    if (overflow <= 0.000001) return _SplitResult(fill: fill);

    final partialEntries = entries.where((e) => e.status == 'exit_partial').toList()
      ..sort((a, b) => a.queueIndex.compareTo(b.queueIndex));
    final partialNeed = partialEntries.fold(
      0.0,
      (s, e) => s + (e.exitRemainderTrx ?? exitAmount),
    );
    final overflowForNew = _round4(overflow - partialNeed < 0 ? 0 : overflow - partialNeed);
    final fullNewCount = (overflowForNew / exitAmount).floor();
    final remainderTrx = _round4(overflowForNew - fullNewCount * exitAmount);

    final partialIds = partialEntries.map((e) => e.entryId).toSet();
    final newCandidates = queued.where((e) => !partialIds.contains(e.entryId)).toList();
    final fullNewEntries = newCandidates.take(fullNewCount).toList();
    final partialNewEntries =
        remainderTrx > 0.000001 && newCandidates.length > fullNewCount
            ? [newCandidates[fullNewCount]]
            : <PoolEntry>[];
    final ticketRemainderTrx =
        remainderTrx > 0.000001 && partialNewEntries.isEmpty ? remainderTrx : 0.0;

    final receiverIds = {
      ...partialIds,
      ...fullNewEntries.map((e) => e.entryId),
      ...partialNewEntries.map((e) => e.entryId),
    };
    final overflowPayers = _selectOverflowPayers(queued, overflow, receiverIds);

    final receivers = <_ReceiverSlot>[
      ...partialEntries.map((e) => _ReceiverSlot(
            slotId: 'recv_${e.entryId}',
            entryId: e.entryId,
            beneficiary: e.payer,
            collectorAddress: collectorFor(e),
            remainingTrx: e.exitRemainderTrx ?? exitAmount,
          )),
      ...fullNewEntries.map((e) => _ReceiverSlot(
            slotId: 'recv_${e.entryId}',
            entryId: e.entryId,
            beneficiary: e.payer,
            collectorAddress: collectorFor(e),
            remainingTrx: exitAmount,
          )),
      ...partialNewEntries.map((e) => _ReceiverSlot(
            slotId: 'recv_${e.entryId}',
            entryId: e.entryId,
            beneficiary: e.payer,
            collectorAddress: collectorFor(e),
            remainingTrx: exitAmount,
          )),
    ];
    final fundingPayers = overflowPayers;
    final receiverCount = receivers.length;
    final remainderToReceiverTrx = partialNewEntries.isNotEmpty ? remainderTrx : 0.0;

    final assignments = <SplitAssignment>[];
    var payerIdx = 0;

    for (final recv in receivers) {
      while (recv.remainingTrx > 0.000001) {
        while (payerIdx < fundingPayers.length &&
            (fundingPayers[payerIdx].availableTrx <= 0.000001 ||
                fundingPayers[payerIdx].splitCount >= PoolRulesConfig.maxSplitsPerPayer)) {
          payerIdx++;
        }
        if (payerIdx >= fundingPayers.length) break;

        final payer = fundingPayers[payerIdx];
        final chunk = payer.availableTrx < recv.remainingTrx
            ? payer.availableTrx
            : recv.remainingTrx;

        assignments.add(SplitAssignment(
          assignmentId: 'asg_${recv.slotId}_${payer.entryId}_${assignments.length}',
          poolId: poolId,
          payer: payer.payer,
          payerEntryId: payer.entryId,
          beneficiary: recv.beneficiary,
          collectorAddress: recv.collectorAddress,
          amountTrx: _round4(chunk),
          splitIndex: payer.splitCount + 1,
          exitAmountTrx: exitAmount,
          collectorMode: collectorMode,
        ));

        payer.availableTrx = _round4(payer.availableTrx - chunk);
        payer.splitCount++;
        recv.remainingTrx = _round4(recv.remainingTrx - chunk);
      }
    }

    final matchDayId =
        DateTime.fromMillisecondsSinceEpoch(evaluationMs, isUtc: true).toIso8601String().substring(0, 10);
    final ticketSurplus =
        _buildTicketRemainder(poolId, ticketRemainderTrx, fundingPayers, cfg.purchaseAddress, matchDayId);
    final deployed = _round4(
      assignments.fold(0.0, (s, a) => s + a.amountTrx) +
          ticketSurplus.fold(0.0, (s, a) => s + a.amountTrx),
    );
    final matchedCreditTrx = deployed > 0.000001 ? deployed : overflow;
    return _SplitResult(
      fill: fill,
      receivers: receivers,
      payers: fundingPayers,
      assignments: assignments,
      ticketSurplusAssignments: ticketSurplus,
      matchedCreditTrx: matchedCreditTrx,
      collectorMode: collectorMode,
      overflowPoolCreditTrx: overflow,
      receiverCount: receiverCount,
      remainderTrx: remainderTrx,
      remainderToReceiverTrx: remainderToReceiverTrx,
      ticketRemainderTrx: ticketRemainderTrx,
    );
  }

  List<_FundingPayer> _selectOverflowPayers(
    List<PoolEntry> queued,
    double overflowAmount,
    Set<String> excludeIds,
  ) {
    final payers = <_FundingPayer>[];
    var sum = 0.0;
    final candidates = queued.where((e) => !excludeIds.contains(e.entryId)).toList();
    for (var i = candidates.length - 1; i >= 0 && sum + 0.000001 < overflowAmount; i--) {
      final e = candidates[i];
      final credit = _remainingCredit(e);
      payers.insert(
        0,
        _FundingPayer(entryId: e.entryId, payer: e.payer, availableTrx: credit),
      );
      sum = _round4(sum + credit);
    }
    return payers;
  }

  void _applyConsumption(List<PoolEntry> entries, _SplitResult split) {
    final map = {for (final e in entries) e.entryId: e};

    for (final recv in split.receivers) {
      final e = map[recv.entryId];
      if (e == null) continue;
      final idx = entries.indexOf(e);
      if (recv.remainingTrx <= 0.000001) {
        entries[idx] = PoolEntry(
          entryId: e.entryId,
          poolId: e.poolId,
          payer: e.payer,
          ticketPaidTrx: e.ticketPaidTrx,
          poolCreditTrx: e.poolCreditTrx,
          remainingPoolCreditTrx: 0,
          exitAmountTrx: e.exitAmountTrx,
          blockTimestamp: e.blockTimestamp,
          queueIndex: e.queueIndex,
          status: 'exit_pending',
        );
      } else {
        entries[idx] = PoolEntry(
          entryId: e.entryId,
          poolId: e.poolId,
          payer: e.payer,
          ticketPaidTrx: e.ticketPaidTrx,
          poolCreditTrx: e.poolCreditTrx,
          remainingPoolCreditTrx: 0,
          exitAmountTrx: e.exitAmountTrx,
          blockTimestamp: e.blockTimestamp,
          queueIndex: e.queueIndex,
          status: 'exit_partial',
          exitRemainderTrx: recv.remainingTrx,
        );
      }
    }

    for (final payer in split.payers) {
      final e = map[payer.entryId];
      if (e == null) continue;
      final idx = entries.indexOf(e);
      entries[idx] = PoolEntry(
        entryId: e.entryId,
        poolId: e.poolId,
        payer: e.payer,
        ticketPaidTrx: e.ticketPaidTrx,
        poolCreditTrx: e.poolCreditTrx,
        remainingPoolCreditTrx: 0,
        exitAmountTrx: e.exitAmountTrx,
        blockTimestamp: e.blockTimestamp,
        queueIndex: e.queueIndex,
        status: 'consumed',
        surplusToTicketTrx: payer.availableTrx > 0.000001 ? payer.availableTrx : null,
      );
    }
  }

  List<TicketSurplusAssignment> _buildTicketRemainder(
    String poolId,
    double remainder,
    List<_FundingPayer> payers,
    String purchaseAddress,
    String matchDayId,
  ) {
    if (remainder <= 0.000001) return [];
    final out = <TicketSurplusAssignment>[];
    var left = remainder;
    for (final payer in payers) {
      if (left <= 0.000001) break;
      final chunk = payer.availableTrx < left ? payer.availableTrx : left;
      if (chunk <= 0.000001) continue;
      out.add(TicketSurplusAssignment(
        assignmentId: 'remainder_${matchDayId}_${payer.entryId}_${out.length}',
        poolId: poolId,
        payer: payer.payer,
        payerEntryId: payer.entryId,
        collectorAddress: purchaseAddress,
        amountTrx: _round4(chunk),
        matchDayId: matchDayId,
      ));
      payer.availableTrx = _round4(payer.availableTrx - chunk);
      left = _round4(left - chunk);
    }
    return out;
  }

  PoolCycleResult runPoolCycle({
    required String poolId,
    required List<RawPoolTx> txs,
    List<PoolExitAnchor> anchors = const [],
    int? nowMs,
  }) {
    final wallNow = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final cfg = kPoolTiers.firstWhere((t) => t.id == poolId);
    final wallDt = DateTime.fromMillisecondsSinceEpoch(wallNow, isUtc: true);
    final cutoff = PoolRulesConfig.checkpointCutoffMs(wallDt);
    final matchCtx = PoolRulesConfig.dailyMatchContext(wallDt);
    final sorted = _sortTxs(txs.where((t) => t.blockTimestamp <= cutoff).toList());

    final stateMap = <String, PoolEntry>{};
    final matchDays = <_MatchDaySummary>[];

    if (sorted.isNotEmpty) {
      final firstTs = sorted.map((t) => t.blockTimestamp).reduce((a, b) => a < b ? a : b);
      final firstMatchDay = _utcDayMs(firstTs + PoolRulesConfig.entryPeriodDays * _msDay);
      final endDay = _utcDayMs(cutoff);

      for (var dayMs = firstMatchDay; dayMs < endDay; dayMs += _msDay) {
        final r = _runDayMatch(poolId, sorted, anchors, stateMap, dayMs, matchDays);
        if (r != null) matchDays.add(r.summary);
      }

      final today = _runDayMatch(poolId, sorted, anchors, stateMap, endDay, matchDays);
      if (today != null) matchDays.add(today.summary);

      final entries = _mergeAtCutoff(poolId, sorted, stateMap, anchors);
      final fill = poolFillState(poolId, entries, cutoff, matchDays);

      return PoolCycleResult(
        poolId: poolId,
        checkpointCutoffMs: cutoff,
        fill: fill,
        entries: entries,
        assignments: today?.split.assignments ?? const [],
        ticketSurplusAssignments: today?.split.ticketSurplusAssignments ?? const [],
        collectorMode: today?.split.collectorMode ?? 'none',
        purchaseAddress: cfg.purchaseAddress,
        matchDayId: matchCtx.matchDayId,
        matchAtMs: matchCtx.matchAtMs,
        nextMatchAtMs: matchCtx.nextMatchAtMs,
        matchedCreditTrx: today?.split.matchedCreditTrx ?? 0,
        overflowPoolCreditTrx: today?.split.overflowPoolCreditTrx ?? 0,
        receiverCount: today?.split.receiverCount ?? 0,
        remainderTrx: today?.split.remainderTrx ?? 0,
        remainderToReceiverTrx: today?.split.remainderToReceiverTrx ?? 0,
        ticketRemainderTrx: today?.split.ticketRemainderTrx ?? 0,
      );
    }

    return PoolCycleResult(
      poolId: poolId,
      checkpointCutoffMs: cutoff,
      fill: poolFillState(poolId, const [], cutoff),
      entries: const [],
      assignments: const [],
      collectorMode: 'none',
      purchaseAddress: cfg.purchaseAddress,
      matchDayId: matchCtx.matchDayId,
      matchAtMs: matchCtx.matchAtMs,
      nextMatchAtMs: matchCtx.nextMatchAtMs,
    );
  }

  _DayMatchResult? _runDayMatch(
    String poolId,
    List<RawPoolTx> sorted,
    List<PoolExitAnchor> anchors,
    Map<String, PoolEntry> stateMap,
    int dayCutoff,
    List<_MatchDaySummary> priorMatchDays,
  ) {
    final dayTxs = sorted.where((t) => t.blockTimestamp <= dayCutoff).toList();
    var entries = _mergeAtCutoff(poolId, dayTxs, stateMap, anchors);
    final split = _buildSplitInternal(poolId, entries, anchors, dayCutoff, priorMatchDays);
    if (split.assignments.isEmpty && split.ticketSurplusAssignments.isEmpty) return null;

    _applyConsumption(entries, split);
    final matchDayId = DateTime.fromMillisecondsSinceEpoch(dayCutoff, isUtc: true)
        .toIso8601String()
        .substring(0, 10);
    for (final e in entries) {
      stateMap[e.entryId] = e;
    }

    return _DayMatchResult(
      split: split,
      summary: _MatchDaySummary(
        matchDayId: matchDayId,
        matchedCreditTrx: split.matchedCreditTrx,
        remainingPoolCreditTrx: poolFillState(poolId, entries, dayCutoff, [
          ...priorMatchDays,
          _MatchDaySummary(matchDayId: matchDayId, matchedCreditTrx: split.matchedCreditTrx, remainingPoolCreditTrx: 0),
        ]).totalPoolCreditTrx,
      ),
    );
  }

  List<PoolEntry> _mergeAtCutoff(
    String poolId,
    List<RawPoolTx> txs,
    Map<String, PoolEntry> stateMap,
    List<PoolExitAnchor> anchors,
  ) {
    final fresh = buildEntries(poolId, txs);
    final merged = fresh.map((e) {
      final prev = stateMap[e.entryId];
      if (prev == null) return e;
      return PoolEntry(
        entryId: e.entryId,
        poolId: e.poolId,
        payer: e.payer,
        ticketPaidTrx: e.ticketPaidTrx,
        poolCreditTrx: e.poolCreditTrx,
        remainingPoolCreditTrx: prev.remainingPoolCreditTrx,
        exitAmountTrx: e.exitAmountTrx,
        blockTimestamp: e.blockTimestamp,
        queueIndex: e.queueIndex,
        status: prev.status,
        blockReason: prev.blockReason,
        completedAt: prev.completedAt,
        exitRemainderTrx: prev.exitRemainderTrx,
        surplusToTicketTrx: prev.surplusToTicketTrx,
      );
    }).toList();
    return applyLifecycle(merged, anchors);
  }

  Map<String, PoolCycleResult> runAllPools({
    required Map<String, List<RawPoolTx>> txsByPool,
    Map<String, List<RawPoolTx>> exitPoolTxsByPool = const {},
    List<PoolExitAnchor> anchors = const [],
    int? nowMs,
  }) {
    // TODO(v4): 接入 exitPoolTxsByPool + derivePayVerifications，与 pool-rules.js 同步
    final out = <String, PoolCycleResult>{};
    for (final tier in kPoolTiers) {
      out[tier.id] = runPoolCycle(
        poolId: tier.id,
        txs: txsByPool[tier.id] ?? [],
        anchors: anchors.where((a) => a.poolId == null || a.poolId == tier.id).toList(),
        nowMs: nowMs,
      );
    }
    return out;
  }

  int _utcDayMs(int tsMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true);
    return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch;
  }

  double _round4(double v) => (v * 10000).roundToDouble() / 10000;

  List<RawPoolTx> _sortTxs(List<RawPoolTx> txs) {
    final copy = [...txs];
    copy.sort((a, b) {
      final bn = (a.blockNumber ?? 0) - (b.blockNumber ?? 0);
      if (bn != 0) return bn;
      final bt = a.blockTimestamp - b.blockTimestamp;
      if (bt != 0) return bt;
      return a.txHash.compareTo(b.txHash);
    });
    return copy;
  }
}

class _ReceiverSlot {
  _ReceiverSlot({
    required this.slotId,
    required this.entryId,
    required this.beneficiary,
    required this.collectorAddress,
    required this.remainingTrx,
  });

  final String slotId;
  final String entryId;
  final String beneficiary;
  final String collectorAddress;
  double remainingTrx;
}

class _FundingPayer {
  _FundingPayer({
    required this.entryId,
    required this.payer,
    required this.availableTrx,
  });

  final String entryId;
  final String payer;
  double availableTrx;
  int splitCount = 0;
}

class _SplitResult {
  _SplitResult({
    required this.fill,
    this.receivers = const [],
    this.payers = const [],
    this.assignments = const [],
    this.ticketSurplusAssignments = const [],
    this.matchedCreditTrx = 0,
    this.collectorMode = 'none',
    this.overflowPoolCreditTrx = 0,
    this.receiverCount = 0,
    this.remainderTrx = 0,
    this.remainderToReceiverTrx = 0,
    this.ticketRemainderTrx = 0,
  });

  final PoolFillState fill;
  final List<_ReceiverSlot> receivers;
  final List<_FundingPayer> payers;
  final List<SplitAssignment> assignments;
  final List<TicketSurplusAssignment> ticketSurplusAssignments;
  final double matchedCreditTrx;
  final String collectorMode;
  final double overflowPoolCreditTrx;
  final int receiverCount;
  final double remainderTrx;
  final double remainderToReceiverTrx;
  final double ticketRemainderTrx;
}

class _MatchDaySummary {
  const _MatchDaySummary({
    required this.matchDayId,
    required this.matchedCreditTrx,
    required this.remainingPoolCreditTrx,
  });

  final String matchDayId;
  final double matchedCreditTrx;
  final double remainingPoolCreditTrx;
}

class _DayMatchResult {
  const _DayMatchResult({
    required this.split,
    required this.summary,
  });

  final _SplitResult split;
  final _MatchDaySummary summary;
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

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
