import '../models/pool_cycle_models.dart';
import '../utils/tron_address_util.dart';

class ExitPayVerify {
  static double round4(double v) => (v * 10000).roundToDouble() / 10000;

  static bool amountEqual(double a, double b) => (round4(a) - round4(b)).abs() < 0.000001;

  static PayVerifyResult derivePayVerifications(
    List<PayAssignmentRecord> payAssignments,
    List<RawPoolTx> exitPoolTxs,
    String exitPoolAddress,
    int evaluationMs, [
    Iterable<String> seedUsedTxIds = const [],
  ]) {
    final usedTxIds = {...seedUsedTxIds};
    final verified = <PayVerifiedRecord>[];
    final pending = <PayAssignmentRecord>[];
    final expired = <PayExpiredRecord>[];

    final sorted = [...payAssignments]..sort((a, b) {
        final c = a.matchAtMs.compareTo(b.matchAtMs);
        if (c != 0) return c;
        return a.assignmentId.compareTo(b.assignmentId);
      });

    final byEntry = <String, List<PayAssignmentRecord>>{};
    for (final a in sorted) {
      byEntry.putIfAbsent(a.payerEntryId, () => []).add(a);
    }

    for (final entry in byEntry.entries) {
      final assigns = entry.value;
      final hits = <({PayAssignmentRecord a, RawPoolTx tx})>[];

      for (final a in assigns) {
        RawPoolTx? hit;
        for (final t in exitPoolTxs) {
          if (usedTxIds.contains(t.txHash)) continue;
          if (!TronAddressUtil.equal(t.fromAddress, a.payer)) continue;
          if (t.toAddress != null &&
              exitPoolAddress.isNotEmpty &&
              !TronAddressUtil.equal(t.toAddress, exitPoolAddress)) {
            continue;
          }
          if (!amountEqual(t.amount, a.amountTrx)) continue;
          if (t.blockTimestamp < a.matchAtMs) continue;
          if (t.blockTimestamp > evaluationMs) continue;
          hit = t;
          break;
        }
        if (hit != null) {
          usedTxIds.add(hit.txHash);
          hits.add((a: a, tx: hit));
        } else if (evaluationMs <= a.deadlineMs) {
          pending.add(a);
        }
      }

      if (hits.length == assigns.length && assigns.isNotEmpty) {
        final last = hits.reduce((m, h) => h.tx.blockTimestamp > m.tx.blockTimestamp ? h : m);
        verified.add(PayVerifiedRecord(
          entryId: entry.key,
          payer: assigns.first.payer,
          mainnetTxId: last.tx.txHash,
          verifiedAtMs: last.tx.blockTimestamp,
        ));
      } else if (assigns.isNotEmpty &&
          evaluationMs > assigns.map((x) => x.deadlineMs).reduce((a, b) => a > b ? a : b)) {
        expired.add(PayExpiredRecord(entryId: entry.key, payer: assigns.first.payer));
      }
    }

    return PayVerifyResult(verified: verified, pending: pending, expired: expired, usedTxIds: usedTxIds);
  }
}

class PayVerifiedRecord {
  const PayVerifiedRecord({
    required this.entryId,
    required this.payer,
    required this.mainnetTxId,
    required this.verifiedAtMs,
  });

  final String entryId;
  final String payer;
  final String mainnetTxId;
  final int verifiedAtMs;
}

class PayExpiredRecord {
  const PayExpiredRecord({required this.entryId, required this.payer});
  final String entryId;
  final String payer;
}

class PayVerifyResult {
  const PayVerifyResult({
    required this.verified,
    required this.pending,
    required this.expired,
    required this.usedTxIds,
  });

  final List<PayVerifiedRecord> verified;
  final List<PayAssignmentRecord> pending;
  final List<PayExpiredRecord> expired;
  final Set<String> usedTxIds;
}
