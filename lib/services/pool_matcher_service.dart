import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/pool_rules_config.dart';
import '../models/pool_cycle_models.dart';
import '../utils/tron_address_util.dart';
import 'pool_engine_service.dart';
import 'pool_snapshot_store.dart';

/// 方案 A：TronGrid 拉买券 + 出场池入账，本地 pool-v4 双池引擎
class PoolMatcherService {
  PoolMatcherService({this.tronGridApiKey});

  final String? tronGridApiKey;
  final PoolEngineService _engine = PoolEngineService();

  Future<List<dynamic>> fetchAccountTransactions(String address) async {
    final headers = <String, String>{};
    if (tronGridApiKey != null && tronGridApiKey!.isNotEmpty) {
      headers['TRON-PRO-API-KEY'] = tronGridApiKey!;
    }
    final all = <dynamic>[];
    String? fingerprint;
    for (var page = 0; page < 20; page++) {
      final query = <String, String>{
        'only_to': 'true',
        'limit': '200',
        'order_by': 'block_timestamp,asc',
      };
      if (fingerprint != null) query['fingerprint'] = fingerprint;
      final url = Uri.https('api.trongrid.io', '/v1/accounts/$address/transactions', query);
      final response = await http.get(url, headers: headers);
      if (response.statusCode != 200) break;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final batch = data['data'] as List<dynamic>? ?? [];
      all.addAll(batch);
      final meta = data['meta'] as Map<String, dynamic>?;
      fingerprint = meta?['fingerprint'] as String?;
      if (fingerprint == null || batch.isEmpty) break;
    }
    return all;
  }

  List<RawPoolTx> parseTransferTxs(List<dynamic> txs) {
    final out = <RawPoolTx>[];
    for (final tx in txs) {
      try {
        final rawData = tx['raw_data'] as Map<String, dynamic>?;
        final contracts = rawData?['contract'] as List<dynamic>?;
        if (contracts == null || contracts.isEmpty) continue;
        final contract = contracts[0] as Map<String, dynamic>;
        if (contract['type'] != 'TransferContract') continue;
        final value = (contract['parameter'] as Map<String, dynamic>?)?['value'] as Map<String, dynamic>?;
        if (value == null) continue;

        final amountSun = value['amount'] as num?;
        final fromAddress = value['owner_address'] as String?;
        final toAddress = value['to_address'] as String?;
        final txHash = tx['txID'] as String?;
        final blockTimestamp = tx['block_timestamp'] as int?;
        if (amountSun == null || fromAddress == null || txHash == null || blockTimestamp == null) {
          continue;
        }
        out.add(RawPoolTx(
          txHash: txHash,
          fromAddress: TronAddressUtil.normalize(fromAddress),
          toAddress: toAddress != null ? TronAddressUtil.normalize(toAddress) : null,
          amount: amountSun / 1e6,
          blockTimestamp: blockTimestamp,
          blockNumber: tx['blockNumber'] as int?,
        ));
      } catch (_) {}
    }
    return out;
  }

  List<RawPoolTx> parseEntryTxs(List<dynamic> txs, String poolId, double ticketPriceTrx) {
    return parseTransferTxs(txs)
        .where((t) => (t.amount - ticketPriceTrx).abs() < 0.000001)
        .toList();
  }

  List<RawPoolTx> parseExitPoolTxs(List<dynamic> txs, double ticketPriceTrx) {
    return parseTransferTxs(txs)
        .where((t) => (t.amount - ticketPriceTrx).abs() > 0.000001)
        .toList();
  }

  Future<Map<String, PoolCycleResult>> runFullMatcher({int? nowMs}) async {
    final purchaseByPool = <String, List<RawPoolTx>>{};
    final exitByPool = <String, List<RawPoolTx>>{};
    final snapshotsByPool = <String, Map<String, dynamic>>{};

    for (final tier in kPoolTiers) {
      final snap = await PoolSnapshotStore.load(tier.id);
      if (snap != null) snapshotsByPool[tier.id] = snap;

      final purchaseRaw = await fetchAccountTransactions(tier.purchaseAddress);
      purchaseByPool[tier.id] = parseEntryTxs(purchaseRaw, tier.id, tier.ticketPriceTrx);

      final exitAddr = tier.exitPoolAddress;
      if (exitAddr != tier.purchaseAddress) {
        final exitRaw = await fetchAccountTransactions(exitAddr);
        exitByPool[tier.id] = parseExitPoolTxs(exitRaw, tier.ticketPriceTrx);
      } else {
        exitByPool[tier.id] = parseExitPoolTxs(purchaseRaw, tier.ticketPriceTrx);
      }
    }

    final pools = _engine.runAllPools(
      purchaseTxsByPool: purchaseByPool,
      exitPoolTxsByPool: exitByPool,
      snapshotsByPool: snapshotsByPool.isEmpty ? null : snapshotsByPool,
      nowMs: nowMs,
    );

    for (final entry in pools.entries) {
      await PoolSnapshotStore.save(entry.key, entry.value.snapshot);
    }

    return pools;
  }

  List<SplitAssignment> assignmentsForUser(
    Map<String, PoolCycleResult> pools,
    String userAddress,
  ) {
    final out = <SplitAssignment>[];
    for (final p in pools.values) {
      for (final a in p.assignments) {
        if (TronAddressUtil.equal(a.payer, userAddress) ||
            TronAddressUtil.equal(a.beneficiary, userAddress)) {
          out.add(a);
        }
      }
    }
    return out;
  }
}
