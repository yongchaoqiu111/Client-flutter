import '../config/pool_rules_config.dart';
import '../models/pool_cycle_models.dart';
import 'exit_pay_verify.dart';
import 'pool_snapshot.dart';

/// 无服务器排单 · pool-v4-dual-pool（与 WSS-server/shared/pool-rules.js 对齐）
class PoolEngineService {
  static const _msDay = 24 * 3600 * 1000;
  static const payInChannel = 'pay_in';
  static const recvOutChannel = 'recv_out';
  static const ticketSurplusChannel = 'ticket_surplus';

  static const _payPoolActive = {'pay_queued', 'pay_pending'};
  static const _frozenStatuses = {
    'pay_pending',
    'pay_expired',
    'recv_queued',
    'recv_partial',
    'recv_pending',
    'done',
    'consumed',
    'blocked',
  };

  List<RawPoolTx> sortPoolTxs(List<RawPoolTx> txs) {
    final sorted = [...txs];
    sorted.sort((a, b) {
      final bn = (a.blockNumber ?? 0) - (b.blockNumber ?? 0);
      if (bn != 0) return bn;
      final bt = a.blockTimestamp - b.blockTimestamp;
      if (bt != 0) return bt;
      return a.txHash.compareTo(b.txHash);
    });
    return sorted;
  }

  List<RawPoolTx> filterByCheckpoint(List<RawPoolTx> txs, int? cutoffMs) {
    if (cutoffMs == null) return txs;
    return txs.where((t) => t.blockTimestamp <= cutoffMs).toList();
  }

  int utcDayMs(int tsMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true);
    return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch;
  }

  PoolTierConfig _poolConfig(String poolId) =>
      kPoolTiers.firstWhere((p) => p.id == poolId);

  double remainingCreditOf(PoolEntry entry) {
    if (!_payPoolActive.contains(entry.status)) return 0;
    return entry.remainingPoolCreditTrx ?? entry.poolCreditTrx;
  }

  double poolLedgerBalance(List<PoolEntry> entries, [List<MatchDaySummary> matchDays = const []]) {
    final committed = entries
        .where((e) => !{'blocked', 'pay_expired', 'done'}.contains(e.status))
        .fold(0.0, (s, e) => s + e.poolCreditTrx);
    final consumed = matchDays.fold(0.0, (s, d) => s + d.matchedCreditTrx);
    return _round4(committed - consumed);
  }

  List<PoolEntry> buildEntries(String poolId, List<RawPoolTx> txs, [int queueIndexStart = 0]) {
    final cfg = _poolConfig(poolId);
    final sorted = sortPoolTxs(txs);
    final valid = sorted.where((tx) => (tx.amount - cfg.ticketPriceTrx).abs() < 0.000001).toList();
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
        queueIndex: queueIndexStart + i + 1,
        status: 'pay_queued',
      );
    });
  }

  List<PoolEntry> applyLifecycle(List<PoolEntry> entries, Set<String> blockedPayers) {
    final openByPayer = <String, String>{};
    final result = <PoolEntry>[];
    for (final e in entries) {
      if (_frozenStatuses.contains(e.status)) {
        result.add(e);
        continue;
      }
      if (blockedPayers.contains(e.payer)) {
        result.add(_copyEntry(e, status: 'blocked', blockReason: '一次只能排一单', remainingPoolCreditTrx: 0));
        continue;
      }
      if (openByPayer.containsKey(e.payer)) {
        result.add(_copyEntry(e, status: 'blocked', blockReason: '一次只能排一单', remainingPoolCreditTrx: 0));
        continue;
      }
      openByPayer[e.payer] = e.entryId;
      result.add(_copyEntry(
        e,
        status: 'pay_queued',
        remainingPoolCreditTrx: e.remainingPoolCreditTrx ?? e.poolCreditTrx,
      ));
    }
    return result;
  }

  List<PoolEntry> mergeEntryStates(List<PoolEntry> fresh, Map<String, PoolEntry> stateMap) {
    return fresh.map((e) {
      final prev = stateMap[e.entryId];
      if (prev == null) return e;
      return _copyEntry(
        e,
        status: prev.status,
        remainingPoolCreditTrx: prev.remainingPoolCreditTrx,
        exitRemainderTrx: prev.exitRemainderTrx,
        surplusToTicketTrx: prev.surplusToTicketTrx,
        recvQueueJoinedAt: prev.recvQueueJoinedAt,
        payAssignments: prev.payAssignments,
        completedAt: prev.completedAt,
        blockReason: prev.blockReason,
        verifiedMainnetTxId: prev.verifiedMainnetTxId,
        payDeadlineMs: prev.payDeadlineMs,
      );
    }).toList();
  }

  PoolFillState poolFillState(
    String poolId,
    List<PoolEntry> entries,
    int evaluationMs, [
    List<MatchDaySummary> matchDays = const [],
  ]) {
    final cfg = _poolConfig(poolId);
    final credits = poolLedgerBalance(entries, matchDays);
    final queuedCredits = entries
        .where((e) => _payPoolActive.contains(e.status))
        .fold(0.0, (s, e) => s + remainingCreditOf(e));
    final active = entries.where((e) => !{'blocked', 'pay_expired', 'done'}.contains(e.status)).toList();
    final firstTs = active.isEmpty
        ? null
        : active.map((e) => e.blockTimestamp).reduce((a, b) => a < b ? a : b);
    final minFillMs = PoolRulesConfig.entryPeriodDays * _msDay;
    final full = credits >= cfg.poolTargetTrx;
    final days = firstTs != null ? ((evaluationMs - firstTs) / _msDay).floor() : 0;
    final entryOk = firstTs != null && evaluationMs >= firstTs + minFillMs;
    final overflow = _round4((credits - cfg.poolTargetTrx).clamp(0, double.infinity));

    return PoolFillState(
      poolId: poolId,
      totalPoolCreditTrx: credits,
      targetTrx: cfg.poolTargetTrx,
      entryCount: entries.where((e) => _payPoolActive.contains(e.status)).length,
      isFull: full,
      fillPercent: (credits / cfg.poolTargetTrx * 100).clamp(0, 100).toDouble(),
      entryPeriodSatisfied: entryOk,
      canMatch: full && entryOk && overflow > 0.000001,
      daysSinceFirstEntry: days,
      ticketPriceTrx: cfg.ticketPriceTrx,
      poolCreditPerTicket: cfg.poolCreditTrx,
      queuedPoolCreditTrx: queuedCredits,
      consumedPoolCreditTrx: matchDays.fold<double>(0, (s, d) => s + d.matchedCreditTrx),
      overflowPoolCreditTrx: overflow,
    );
  }

  _DayMatchResult buildDayMatch(
    String poolId,
    List<PoolEntry> entries,
    int evaluationMs,
    List<MatchDaySummary> matchDays,
  ) {
    final cfg = _poolConfig(poolId);
    final exitPoolAddress = cfg.exitPoolAddress;
    final fill = poolFillState(poolId, entries, evaluationMs, matchDays);
    final overflow = fill.overflowPoolCreditTrx ?? 0;
    final empty = _DayMatchResult(
      fill: fill,
      exitPoolAddress: exitPoolAddress,
      purchaseAddress: cfg.purchaseAddress,
      overflowPoolCreditTrx: overflow,
    );
    if (!fill.canMatch || overflow <= 0.000001) return empty;

    final matchDayId =
        DateTime.fromMillisecondsSinceEpoch(evaluationMs, isUtc: true).toIso8601String().substring(0, 10);
    final payQueued = entries.where((e) => e.status == 'pay_queued').toList()
      ..sort((a, b) => a.queueIndex.compareTo(b.queueIndex));

    final payers = _selectPayPoolPayers(payQueued, overflow);
    final payAssignments =
        _buildPayInAssignments(poolId, payers, exitPoolAddress, evaluationMs, matchDayId);
    final recvSplit = _buildRecvPhase(
      poolId,
      entries,
      overflow,
      cfg.exitAmountTrx,
      exitPoolAddress,
      matchDayId,
      evaluationMs,
    );
    final ticketSurplus = _buildTicketRemainderAssignments(
      poolId,
      recvSplit.ticketRemainderTrx,
      payers,
      cfg.purchaseAddress,
      matchDayId,
    );

    final deployedTrx = _round4(
      payAssignments.fold(0.0, (s, a) => s + a.amountTrx) +
          ticketSurplus.fold(0.0, (s, a) => s + a.amountTrx),
    );

    return _DayMatchResult(
      fill: fill,
      payAssignments: payAssignments,
      recvPhase: recvSplit,
      ticketSurplusAssignments: ticketSurplus,
      matchedCreditTrx: deployedTrx > 0.000001 ? deployedTrx : _round4(overflow),
      overflowPoolCreditTrx: overflow,
      exitPoolAddress: exitPoolAddress,
      purchaseAddress: cfg.purchaseAddress,
    );
  }

  _VerifyResult applyPayVerifications(
    List<PoolEntry> entries,
    List<RawPoolTx> exitPoolTxs,
    String exitPoolAddress,
    int evaluationMs,
    Set<String> usedExitTxIds,
  ) {
    final entryMap = {for (final e in entries) e.entryId: e};
    final pendingAssigns = <PayAssignmentRecord>[];
    final used = {...usedExitTxIds};
    for (final e in entries) {
      if (e.status == 'pay_pending' && e.payAssignments.isNotEmpty) {
        pendingAssigns.addAll(e.payAssignments);
      }
      if (e.verifiedMainnetTxId != null) used.add(e.verifiedMainnetTxId!);
    }
    if (pendingAssigns.isEmpty) {
      return _VerifyResult(entries: entries, usedExitTxIds: used);
    }

    final result = ExitPayVerify.derivePayVerifications(
      pendingAssigns,
      exitPoolTxs,
      exitPoolAddress,
      evaluationMs,
      used,
    );
    used.addAll(result.usedTxIds);

    for (final v in result.verified) {
      final e = entryMap[v.entryId];
      if (e == null) continue;
      entryMap[v.entryId] = _copyEntry(
        e,
        status: 'recv_queued',
        recvQueueJoinedAt: v.verifiedAtMs,
        verifiedMainnetTxId: v.mainnetTxId,
        remainingPoolCreditTrx: 0,
        payAssignments: const [],
        completedAt: null,
      );
      used.add(v.mainnetTxId);
    }
    for (final x in result.expired) {
      final e = entryMap[x.entryId];
      if (e == null) continue;
      entryMap[x.entryId] = _copyEntry(
        e,
        status: 'pay_expired',
        remainingPoolCreditTrx: 0,
        payAssignments: const [],
        blockReason: '出场打款超时',
      );
    }
    return _VerifyResult(entries: entryMap.values.toList(), usedExitTxIds: used);
  }

  List<PoolEntry> applyPayInTasks(List<PoolEntry> entries, List<SplitAssignment> payAssignments) {
    final entryMap = {for (final e in entries) e.entryId: e};
    final byEntry = <String, List<SplitAssignment>>{};
    for (final a in payAssignments) {
      byEntry.putIfAbsent(a.payerEntryId, () => []).add(a);
    }
    for (final entry in byEntry.entries) {
      final e = entryMap[entry.key];
      if (e == null || e.status != 'pay_queued') continue;
      final assigns = entry.value
          .map((a) => PayAssignmentRecord(
                assignmentId: a.assignmentId,
                payer: a.payer,
                payerEntryId: a.payerEntryId,
                amountTrx: a.amountTrx,
                matchAtMs: a.matchAtMs,
                deadlineMs: a.deadlineMs,
                collectorAddress: a.collectorAddress,
              ))
          .toList();
      entryMap[entry.key] = _copyEntry(
        e,
        status: 'pay_pending',
        payAssignments: assigns,
        payDeadlineMs: assigns.map((x) => x.deadlineMs).reduce((a, b) => a > b ? a : b),
      );
    }
    return entryMap.values.toList();
  }

  List<PoolEntry> applyRecvConsumption(List<PoolEntry> entries, _RecvPhaseResult recvSplit, double exitAmount) {
    final entryMap = {for (final e in entries) e.entryId: e};
    for (final recv in recvSplit.receivers) {
      final e = entryMap[recv.entryId];
      if (e == null) continue;
      if (recv.isRemainderSlot && (recv.remainderBudgetTrx ?? 0) > 0.000001) {
        entryMap[recv.entryId] = _copyEntry(
          e,
          status: 'recv_partial',
          exitRemainderTrx: _round4(exitAmount - recv.remainderBudgetTrx!),
        );
      } else if (recv.isPartialCarryover) {
        var rem = _round4((e.exitRemainderTrx ?? exitAmount) - recv.needTrx);
        var status = 'recv_partial';
        if (rem <= 0.000001) {
          status = 'recv_pending';
          rem = 0;
        }
        entryMap[recv.entryId] = _copyEntry(e, status: status, exitRemainderTrx: rem);
      } else {
        entryMap[recv.entryId] = _copyEntry(e, status: 'recv_pending', exitRemainderTrx: 0);
      }
    }
    return entryMap.values.toList();
  }

  _RunDayResult? runDayMatch(
    String poolId,
    List<RawPoolTx> purchaseTxs,
    List<RawPoolTx> exitPoolTxs,
    Map<String, PoolEntry> stateMap,
    int dayStartMs,
    List<MatchDaySummary> priorMatchDays,
    int verifyThroughMs,
    _ReplayCtx replayCtx,
  ) {
    List<PoolEntry> entries;
    if (replayCtx.incrementalFromMs > 0) {
      final newBuys = purchaseTxs
          .where((t) =>
              t.blockTimestamp > replayCtx.incrementalFromMs && t.blockTimestamp <= dayStartMs)
          .toList();
      entries = mergeEntryStates(buildEntries(poolId, newBuys, replayCtx.lastQueueIndex), stateMap);
      for (final e in entries) {
        if (e.queueIndex > replayCtx.lastQueueIndex) replayCtx.lastQueueIndex = e.queueIndex;
      }
    } else {
      final dayPurchase = filterByCheckpoint(purchaseTxs, dayStartMs);
      entries = mergeEntryStates(buildEntries(poolId, dayPurchase), stateMap);
    }

    entries = applyLifecycle(entries, replayCtx.blockedPayers);
    final dayExit = filterByCheckpoint(exitPoolTxs, verifyThroughMs);
    final cfg = _poolConfig(poolId);
    final exitPoolAddress = cfg.exitPoolAddress;

    final verifyResult =
        applyPayVerifications(entries, dayExit, exitPoolAddress, verifyThroughMs, replayCtx.usedExitTxIds);
    entries = verifyResult.entries;
    replayCtx.usedExitTxIds = verifyResult.usedExitTxIds;

    for (final e in entries) {
      stateMap[e.entryId] = e;
      if (e.status == 'blocked') replayCtx.blockedPayers.add(e.payer);
      if (e.queueIndex > replayCtx.lastQueueIndex) replayCtx.lastQueueIndex = e.queueIndex;
    }

    final fill = poolFillState(poolId, entries, dayStartMs, priorMatchDays);
    if (!fill.canMatch) return null;

    final split = buildDayMatch(poolId, entries, dayStartMs, priorMatchDays);
    if (split.payAssignments.isEmpty && split.recvAssignments.isEmpty) return null;

    entries = applyPayInTasks(entries, split.payAssignments);
    entries = applyRecvConsumption(entries, split.recvPhase!, cfg.exitAmountTrx);
    for (final e in entries) stateMap[e.entryId] = e;

    final afterMatchDays = [
      ...priorMatchDays,
      MatchDaySummary(matchDayId: _dayId(dayStartMs), matchedCreditTrx: split.matchedCreditTrx),
    ];
    return _RunDayResult(
      entries: entries,
      split: split,
      summary: MatchDaySummary(
        matchDayId: _dayId(dayStartMs),
        matchedCreditTrx: split.matchedCreditTrx,
        remainingPoolCreditTrx: poolFillState(poolId, entries, dayStartMs, afterMatchDays).totalPoolCreditTrx,
      ),
    );
  }

  _ReplayResult replayPoolTimeline(
    String poolId,
    List<RawPoolTx> purchaseTxs,
    List<RawPoolTx> exitPoolTxs,
    int wallNowMs, [
    Map<String, dynamic>? snapshot,
  ]) {
    final cfg = _poolConfig(poolId);
    final sortedPurchase = sortPoolTxs(purchaseTxs);
    final exitPoolAddress = cfg.exitPoolAddress;

    var stateMap = <String, PoolEntry>{};
    var matchDays = <MatchDaySummary>[];
    _ReplayCtx? replayCtx;
    int loopStartDay;
    _DayMatchResult? todayResult;

    if (snapshot != null) {
      final loaded = PoolSnapshotCodec.loadSnapshot(snapshot);
      if (loaded == null) throw StateError('invalid pool snapshot');
      if (snapshot['poolId'] != poolId) {
        throw StateError('snapshot poolId ${snapshot['poolId']} != $poolId');
      }
      stateMap = loaded.stateMap;
      matchDays = loaded.matchDays;
      replayCtx = _ReplayCtx(
        incrementalFromMs: loaded.incrementalFromMs,
        blockedPayers: loaded.blockedPayers,
        usedExitTxIds: loaded.usedExitTxIds,
        lastQueueIndex: loaded.lastQueueIndex,
      );
      loopStartDay =
          loaded.lastMatchDayMs > 0 ? loaded.lastMatchDayMs + _msDay : utcDayMs(wallNowMs);
    } else if (sortedPurchase.isEmpty) {
      final emptySnap = PoolSnapshotCodec.exportSnapshot(poolId, stateMap, matchDays, wallNowMs);
      return _ReplayResult(
        entries: const [],
        fill: poolFillState(poolId, const [], wallNowMs),
        exitPoolAddress: exitPoolAddress,
        purchaseAddress: cfg.purchaseAddress,
        snapshot: emptySnap,
        replayMode: 'full',
      );
    } else {
      final firstTs = sortedPurchase.map((t) => t.blockTimestamp).reduce((a, b) => a < b ? a : b);
      loopStartDay = utcDayMs(firstTs + PoolRulesConfig.entryPeriodDays * _msDay);
      replayCtx = _ReplayCtx();
    }

    final endDay = utcDayMs(wallNowMs);
    final ctx = replayCtx!;

    for (var dayMs = loopStartDay; dayMs < endDay; dayMs += _msDay) {
      final result = runDayMatch(
        poolId,
        sortedPurchase,
        exitPoolTxs,
        stateMap,
        dayMs,
        matchDays,
        dayMs + _msDay,
        ctx,
      );
      if (result != null) matchDays.add(result.summary);
    }

    final todayMatch = runDayMatch(
      poolId,
      sortedPurchase,
      exitPoolTxs,
      stateMap,
      endDay,
      matchDays,
      wallNowMs,
      ctx,
    );
    if (todayMatch != null) {
      matchDays.add(todayMatch.summary);
      todayResult = todayMatch.split;
    }

    final newBuysFinal = ctx.incrementalFromMs > 0
        ? PoolSnapshotCodec.filterTxsAfter(sortedPurchase, ctx.incrementalFromMs)
            .where((t) => t.blockTimestamp <= wallNowMs)
            .toList()
        : <RawPoolTx>[];
    if (newBuysFinal.isNotEmpty) {
      final fresh = buildEntries(poolId, newBuysFinal, ctx.lastQueueIndex);
      final merged = mergeEntryStates(fresh, stateMap);
      final lifecycled = applyLifecycle(merged, ctx.blockedPayers);
      for (final e in lifecycled) {
        stateMap[e.entryId] = e;
        if (e.queueIndex > ctx.lastQueueIndex) ctx.lastQueueIndex = e.queueIndex;
      }
    }

    var entries = stateMap.values.toList()..sort((a, b) => a.queueIndex.compareTo(b.queueIndex));
    final verifyResult = applyPayVerifications(
      entries,
      filterByCheckpoint(exitPoolTxs, wallNowMs),
      exitPoolAddress,
      wallNowMs,
      ctx.usedExitTxIds,
    );
    entries = verifyResult.entries;
    ctx.usedExitTxIds = verifyResult.usedExitTxIds;
    for (final e in entries) stateMap[e.entryId] = e;

    final fill = poolFillState(poolId, entries, wallNowMs, matchDays);
    final split = todayResult;
    final payAssignments = split?.payAssignments.isNotEmpty == true
        ? split!.payAssignments
        : entries
            .where((e) => e.status == 'pay_pending')
            .expand((e) => e.payAssignments)
            .map((a) => SplitAssignment(
                  assignmentId: a.assignmentId,
                  poolId: poolId,
                  payer: a.payer,
                  payerEntryId: a.payerEntryId,
                  collectorAddress: a.collectorAddress,
                  amountTrx: a.amountTrx,
                  matchAtMs: a.matchAtMs,
                  deadlineMs: a.deadlineMs,
                  channel: payInChannel,
                  purpose: 'pay_pool_to_exit',
                  matchDayId: _dayId(a.matchAtMs),
                ))
            .toList();
    final recvAssignments = split?.recvPhase?.assignments ?? [];

    final exportedSnapshot = PoolSnapshotCodec.exportSnapshot(
      poolId,
      stateMap,
      matchDays,
      wallNowMs,
      blockedPayers: ctx.blockedPayers,
      usedExitTxIds: ctx.usedExitTxIds,
    );

    return _ReplayResult(
      entries: entries,
      fill: fill,
      payAssignments: payAssignments,
      recvAssignments: recvAssignments,
      ticketSurplusAssignments: split?.ticketSurplusAssignments ?? const [],
      matchedCreditTrx: split?.matchedCreditTrx ?? 0,
      overflowPoolCreditTrx: split?.overflowPoolCreditTrx ?? 0,
      receiverCount: split?.recvPhase?.receiverCount ?? 0,
      remainderTrx: split?.recvPhase?.remainderTrx ?? 0,
      remainderToReceiverTrx: split?.recvPhase?.remainderToReceiverTrx ?? 0,
      ticketRemainderTrx: split?.recvPhase?.ticketRemainderTrx ?? 0,
      exitPoolAddress: exitPoolAddress,
      purchaseAddress: cfg.purchaseAddress,
      snapshot: exportedSnapshot,
      replayMode: snapshot != null ? 'incremental' : 'full',
    );
  }

  PoolCycleResult runPoolCycle({
    required String poolId,
    List<RawPoolTx> txs = const [],
    List<RawPoolTx>? purchaseTxs,
    List<RawPoolTx> exitPoolTxs = const [],
    int? nowMs,
    Map<String, dynamic>? snapshot,
  }) {
    final buyTxs = purchaseTxs ?? txs;
    final wallNow = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final matchCtx = PoolRulesConfig.dailyMatchContext(
      DateTime.fromMillisecondsSinceEpoch(wallNow, isUtc: true),
    );
    final replay = replayPoolTimeline(poolId, buyTxs, exitPoolTxs, wallNow, snapshot);
    final recvPoolCount =
        replay.entries.where((e) => {'recv_queued', 'recv_partial', 'recv_pending'}.contains(e.status)).length;

    return PoolCycleResult(
      poolId: poolId,
      checkpointCutoffMs: matchCtx.snapshotCutoffMs,
      fill: replay.fill,
      entries: replay.entries,
      assignments: [...replay.payAssignments, ...replay.recvAssignments],
      payAssignments: replay.payAssignments,
      recvAssignments: replay.recvAssignments,
      ticketSurplusAssignments: replay.ticketSurplusAssignments,
      collectorMode: 'exit_pool',
      purchaseAddress: replay.purchaseAddress,
      exitPoolAddress: replay.exitPoolAddress,
      matchDayId: matchCtx.matchDayId,
      matchAtMs: matchCtx.matchAtMs,
      nextMatchAtMs: matchCtx.nextMatchAtMs,
      matchedCreditTrx: replay.matchedCreditTrx,
      overflowPoolCreditTrx: replay.overflowPoolCreditTrx,
      receiverCount: replay.receiverCount,
      remainderTrx: replay.remainderTrx,
      remainderToReceiverTrx: replay.remainderToReceiverTrx,
      ticketRemainderTrx: replay.ticketRemainderTrx,
      replayMode: replay.replayMode,
      recvPoolCount: recvPoolCount,
      snapshot: replay.snapshot,
    );
  }

  Map<String, PoolCycleResult> runAllPools({
    Map<String, List<RawPoolTx>>? txsByPool,
    Map<String, List<RawPoolTx>>? purchaseTxsByPool,
    Map<String, List<RawPoolTx>> exitPoolTxsByPool = const {},
    Map<String, Map<String, dynamic>>? snapshotsByPool,
    int? nowMs,
  }) {
    final pools = <String, PoolCycleResult>{};
    for (final cfg in kPoolTiers) {
      pools[cfg.id] = runPoolCycle(
        poolId: cfg.id,
        purchaseTxs: (purchaseTxsByPool ?? txsByPool)?[cfg.id] ?? const [],
        exitPoolTxs: exitPoolTxsByPool[cfg.id] ?? const [],
        snapshot: snapshotsByPool?[cfg.id],
        nowMs: nowMs,
      );
    }
    return pools;
  }

  // --- helpers ---

  double _round4(double v) => (v * 10000).roundToDouble() / 10000;

  String _dayId(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String().substring(0, 10);

  PoolEntry _copyEntry(
    PoolEntry e, {
    String? status,
    double? remainingPoolCreditTrx,
    double? exitRemainderTrx,
    double? surplusToTicketTrx,
    int? recvQueueJoinedAt,
    int? payDeadlineMs,
    String? verifiedMainnetTxId,
    List<PayAssignmentRecord>? payAssignments,
    String? blockReason,
    int? completedAt,
  }) {
    return PoolEntry(
      entryId: e.entryId,
      poolId: e.poolId,
      payer: e.payer,
      ticketPaidTrx: e.ticketPaidTrx,
      poolCreditTrx: e.poolCreditTrx,
      remainingPoolCreditTrx: remainingPoolCreditTrx ?? e.remainingPoolCreditTrx,
      exitAmountTrx: e.exitAmountTrx,
      blockTimestamp: e.blockTimestamp,
      queueIndex: e.queueIndex,
      status: status ?? e.status,
      blockReason: blockReason ?? e.blockReason,
      completedAt: completedAt ?? e.completedAt,
      exitRemainderTrx: exitRemainderTrx ?? e.exitRemainderTrx,
      surplusToTicketTrx: surplusToTicketTrx ?? e.surplusToTicketTrx,
      recvQueueJoinedAt: recvQueueJoinedAt ?? e.recvQueueJoinedAt,
      payDeadlineMs: payDeadlineMs ?? e.payDeadlineMs,
      verifiedMainnetTxId: verifiedMainnetTxId ?? e.verifiedMainnetTxId,
      payAssignments: payAssignments ?? e.payAssignments,
    );
  }

  List<_PayPoolPayer> _selectPayPoolPayers(List<PoolEntry> payQueued, double overflowAmount) {
    final payers = <_PayPoolPayer>[];
    var sum = 0.0;
    for (var i = payQueued.length - 1; i >= 0 && sum + 0.000001 < overflowAmount; i--) {
      final e = payQueued[i];
      final credit = remainingCreditOf(e);
      payers.insert(
        0,
        _PayPoolPayer(entryId: e.entryId, payer: e.payer, availableTrx: credit),
      );
      sum = _round4(sum + credit);
    }
    return payers;
  }

  List<SplitAssignment> _buildPayInAssignments(
    String poolId,
    List<_PayPoolPayer> payers,
    String exitPoolAddress,
    int matchAtMs,
    String matchDayId,
  ) {
    final deadlineMs = matchAtMs + PoolRulesConfig.matchPaymentTimeoutHours * 3600 * 1000;
    final out = <SplitAssignment>[];
    for (final p in payers) {
      if (p.availableTrx <= 0.000001) continue;
      out.add(SplitAssignment(
        assignmentId: 'pay_${matchDayId}_${p.entryId}',
        poolId: poolId,
        channel: payInChannel,
        payer: p.payer,
        payerEntryId: p.entryId,
        collectorAddress: exitPoolAddress,
        amountTrx: _round4(p.availableTrx),
        matchDayId: matchDayId,
        matchAtMs: matchAtMs,
        deadlineMs: deadlineMs,
        purpose: 'pay_pool_to_exit',
      ));
    }
    return out;
  }

  _RecvPhaseResult _buildRecvPhase(
    String poolId,
    List<PoolEntry> entries,
    double overflow,
    double exitAmount,
    String exitPoolAddress,
    String matchDayId,
    int matchAtMs,
  ) {
    final partialEntries = entries.where((e) => e.status == 'recv_partial').toList()
      ..sort((a, b) => (a.recvQueueJoinedAt ?? 0).compareTo(b.recvQueueJoinedAt ?? 0));

    final partialNeed =
        partialEntries.fold(0.0, (s, e) => s + (e.exitRemainderTrx ?? exitAmount));
    final overflowForNew = _round4((overflow - partialNeed).clamp(0, double.infinity));
    final fullNewCount = (overflowForNew / exitAmount).floor();
    final remainderTrx = _round4(overflowForNew - fullNewCount * exitAmount);

    final recvQueued = _recvPoolOrder(entries).where((e) => e.status == 'recv_queued').toList();
    final partialIds = partialEntries.map((e) => e.entryId).toSet();
    final newCandidates = recvQueued.where((e) => !partialIds.contains(e.entryId)).toList();
    final fullNewEntries = newCandidates.take(fullNewCount).toList();
    final partialNewEntries = remainderTrx > 0.000001 && newCandidates.length > fullNewCount
        ? [newCandidates[fullNewCount]]
        : <PoolEntry>[];

    final ticketRemainderTrx =
        remainderTrx > 0.000001 && partialNewEntries.isEmpty ? remainderTrx : 0.0;

    final receivers = <_ReceiverSlot>[];
    for (var i = 0; i < partialEntries.length; i++) {
      final e = partialEntries[i];
      receivers.add(_ReceiverSlot(
        entryId: e.entryId,
        beneficiary: e.payer,
        needTrx: e.exitRemainderTrx ?? exitAmount,
        isPartialCarryover: true,
        queueIndex: i + 1,
      ));
    }
    for (var i = 0; i < fullNewEntries.length; i++) {
      final e = fullNewEntries[i];
      receivers.add(_ReceiverSlot(
        entryId: e.entryId,
        beneficiary: e.payer,
        needTrx: exitAmount,
        queueIndex: partialEntries.length + i + 1,
      ));
    }
    for (var i = 0; i < partialNewEntries.length; i++) {
      final e = partialNewEntries[i];
      receivers.add(_ReceiverSlot(
        entryId: e.entryId,
        beneficiary: e.payer,
        needTrx: exitAmount,
        queueIndex: partialEntries.length + fullNewEntries.length + i + 1,
        isRemainderSlot: true,
        remainderBudgetTrx: remainderTrx,
      ));
    }

    final assignments = receivers
        .map((recv) => SplitAssignment(
              assignmentId: 'recv_${matchDayId}_${recv.entryId}',
              poolId: poolId,
              channel: recvOutChannel,
              payer: '',
              beneficiary: recv.beneficiary,
              payerEntryId: recv.entryId,
              collectorAddress: exitPoolAddress,
              amountTrx: _round4(recv.needTrx),
              exitAmountTrx: exitAmount,
              matchDayId: matchDayId,
              matchAtMs: matchAtMs,
            ))
        .toList();

    return _RecvPhaseResult(
      receivers: receivers,
      assignments: assignments,
      receiverCount: receivers.length,
      remainderTrx: remainderTrx,
      remainderToReceiverTrx: partialNewEntries.isNotEmpty ? remainderTrx : 0,
      ticketRemainderTrx: ticketRemainderTrx,
    );
  }

  List<TicketSurplusAssignment> _buildTicketRemainderAssignments(
    String poolId,
    double ticketRemainderTrx,
    List<_PayPoolPayer> payers,
    String purchaseAddress,
    String matchDayId,
  ) {
    if (ticketRemainderTrx <= 0.000001) return const [];
    final out = <TicketSurplusAssignment>[];
    var left = ticketRemainderTrx;
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
      left = _round4(left - chunk);
    }
    return out;
  }

  List<PoolEntry> _recvPoolOrder(List<PoolEntry> entries) {
    final list = entries.where((e) => e.status == 'recv_queued' || e.status == 'recv_partial').toList();
    list.sort((a, b) {
      final ta = a.recvQueueJoinedAt ?? a.blockTimestamp;
      final tb = b.recvQueueJoinedAt ?? b.blockTimestamp;
      if (ta != tb) return ta.compareTo(tb);
      return a.queueIndex.compareTo(b.queueIndex);
    });
    return list;
  }
}

class _ReplayCtx {
  _ReplayCtx({
    this.incrementalFromMs = 0,
    Set<String>? blockedPayers,
    Set<String>? usedExitTxIds,
    this.lastQueueIndex = 0,
  })  : blockedPayers = blockedPayers ?? {},
        usedExitTxIds = usedExitTxIds ?? {};

  int incrementalFromMs;
  Set<String> blockedPayers;
  Set<String> usedExitTxIds;
  int lastQueueIndex;
}

class _PayPoolPayer {
  const _PayPoolPayer({
    required this.entryId,
    required this.payer,
    required this.availableTrx,
  });

  final String entryId;
  final String payer;
  final double availableTrx;
}

class _ReceiverSlot {
  const _ReceiverSlot({
    required this.entryId,
    required this.beneficiary,
    required this.needTrx,
    this.queueIndex = 0,
    this.isPartialCarryover = false,
    this.isRemainderSlot = false,
    this.remainderBudgetTrx,
  });

  final String entryId;
  final String beneficiary;
  final double needTrx;
  final int queueIndex;
  final bool isPartialCarryover;
  final bool isRemainderSlot;
  final double? remainderBudgetTrx;
}

class _RecvPhaseResult {
  const _RecvPhaseResult({
    required this.receivers,
    required this.assignments,
    required this.receiverCount,
    required this.remainderTrx,
    required this.remainderToReceiverTrx,
    required this.ticketRemainderTrx,
  });

  final List<_ReceiverSlot> receivers;
  final List<SplitAssignment> assignments;
  final int receiverCount;
  final double remainderTrx;
  final double remainderToReceiverTrx;
  final double ticketRemainderTrx;
}

class _DayMatchResult {
  const _DayMatchResult({
    required this.fill,
    required this.exitPoolAddress,
    required this.purchaseAddress,
    required this.overflowPoolCreditTrx,
    this.payAssignments = const [],
    this.recvPhase,
    this.ticketSurplusAssignments = const [],
    this.matchedCreditTrx = 0,
  });

  final PoolFillState fill;
  final List<SplitAssignment> payAssignments;
  final _RecvPhaseResult? recvPhase;
  final List<TicketSurplusAssignment> ticketSurplusAssignments;
  final double matchedCreditTrx;
  final double overflowPoolCreditTrx;
  final String exitPoolAddress;
  final String purchaseAddress;

  List<SplitAssignment> get recvAssignments => recvPhase?.assignments ?? const [];
}

class _RunDayResult {
  const _RunDayResult({
    required this.entries,
    required this.split,
    required this.summary,
  });

  final List<PoolEntry> entries;
  final _DayMatchResult split;
  final MatchDaySummary summary;
}

class _VerifyResult {
  const _VerifyResult({
    required this.entries,
    required this.usedExitTxIds,
  });

  final List<PoolEntry> entries;
  final Set<String> usedExitTxIds;
}

class _ReplayResult {
  const _ReplayResult({
    required this.entries,
    required this.fill,
    required this.exitPoolAddress,
    required this.purchaseAddress,
    required this.snapshot,
    required this.replayMode,
    this.payAssignments = const [],
    this.recvAssignments = const [],
    this.ticketSurplusAssignments = const [],
    this.matchedCreditTrx = 0,
    this.overflowPoolCreditTrx = 0,
    this.receiverCount = 0,
    this.remainderTrx = 0,
    this.remainderToReceiverTrx = 0,
    this.ticketRemainderTrx = 0,
  });

  final List<PoolEntry> entries;
  final PoolFillState fill;
  final List<SplitAssignment> payAssignments;
  final List<SplitAssignment> recvAssignments;
  final List<TicketSurplusAssignment> ticketSurplusAssignments;
  final double matchedCreditTrx;
  final double overflowPoolCreditTrx;
  final int receiverCount;
  final double remainderTrx;
  final double remainderToReceiverTrx;
  final double ticketRemainderTrx;
  final String exitPoolAddress;
  final String purchaseAddress;
  final Map<String, dynamic> snapshot;
  final String replayMode;
}
