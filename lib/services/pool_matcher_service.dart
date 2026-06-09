import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/pool_rules_config.dart';
import '../config/pool_snapshot_config.dart';
import '../models/pool_cycle_models.dart';
import '../utils/tron_address_util.dart';
import 'pool_engine_service.dart';
import 'pool_remote_snapshot_service.dart';
import 'pool_snapshot_store.dart';
import 'pool_tx_cache_store.dart';

enum PoolMatcherSource {
  remoteSnapshot,
  localTronGrid,
}

class PoolMatcherResult {
  const PoolMatcherResult({
    required this.pools,
    required this.source,
    this.snapshotUrl,
    this.contentHash,
  });

  final Map<String, PoolCycleResult> pools;
  final PoolMatcherSource source;
  final String? snapshotUrl;
  final String? contentHash;

  bool get isRemoteSnapshot => source == PoolMatcherSource.remoteSnapshot;
}

/// 方案 A：平台快照优先；用户 TronGrid Key 仅用于本地回放与本人链上验款
class PoolMatcherService {
  PoolMatcherService({this.tronGridApiKey});

  final String? tronGridApiKey;
  final PoolEngineService _engine = PoolEngineService();

  bool get hasUserApiKey => tronGridApiKey != null && tronGridApiKey!.trim().isNotEmpty;

  Map<String, String> get _headers {
    final headers = <String, String>{};
    if (hasUserApiKey) {
      headers['TRON-PRO-API-KEY'] = tronGridApiKey!.trim();
    }
    return headers;
  }

  Future<List<dynamic>> fetchAccountTransactions(
    String address, {
    int? minTimestamp,
  }) async {
    if (!hasUserApiKey) {
      throw Exception(
        '查询链上数据须配置个人 TronGrid API Key。'
        '看全队大盘可直接读平台快照，无需 Key。',
      );
    }

    final all = <dynamic>[];
    String? fingerprint;
    for (var page = 0; page < 20; page++) {
      final query = <String, String>{
        'only_to': 'true',
        'limit': '200',
        'order_by': 'block_timestamp,asc',
      };
      if (minTimestamp != null && minTimestamp > 0) {
        query['min_timestamp'] = '$minTimestamp';
      }
      if (fingerprint != null) query['fingerprint'] = fingerprint;
      final url = Uri.https('api.trongrid.io', '/v1/accounts/$address/transactions', query);
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 429) {
        throw Exception('TronGrid 请求过于频繁(429)，请稍后再试或更换 API Key');
      }
      if (response.statusCode != 200) {
        throw Exception('TronGrid HTTP ${response.statusCode}');
      }
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

  List<RawPoolTx> parseEntryTxs(List<RawPoolTx> transfers, double ticketPriceTrx) {
    return transfers
        .where((t) => (t.amount - ticketPriceTrx).abs() < 0.000001)
        .toList();
  }

  List<RawPoolTx> parseExitPoolTxs(List<RawPoolTx> transfers, double ticketPriceTrx) {
    return transfers
        .where((t) => (t.amount - ticketPriceTrx).abs() > 0.000001)
        .toList();
  }

  List<RawPoolTx> _dedupeTxs(List<RawPoolTx> txs) {
    final seen = <String>{};
    final out = <RawPoolTx>[];
    for (final t in txs) {
      if (seen.add(t.txHash)) out.add(t);
    }
    out.sort((a, b) {
      final bt = a.blockTimestamp - b.blockTimestamp;
      if (bt != 0) return bt;
      return a.txHash.compareTo(b.txHash);
    });
    return out;
  }

  int? _minTimestampForIncremental(List<RawPoolTx> cached) {
    if (cached.isEmpty) return null;
    var maxTs = cached.first.blockTimestamp;
    for (final t in cached) {
      if (t.blockTimestamp > maxTs) maxTs = t.blockTimestamp;
    }
    return maxTs + 1;
  }

  Future<List<RawPoolTx>> _loadMergedTransfers(String address) async {
    final cached = await PoolTxCacheStore.load(address);
    final minTs = _minTimestampForIncremental(cached);
    final raw = await fetchAccountTransactions(address, minTimestamp: minTs);
    final fetched = parseTransferTxs(raw);
    final merged = _dedupeTxs([...cached, ...fetched]);
    await PoolTxCacheStore.save(address, merged);
    return merged;
  }

  /// 刷新大盘：优先 Vercel/GitHub 静态快照（无需用户 Key）
  Future<PoolMatcherResult> runMatcher({int? nowMs, bool forceLocal = false}) async {
    if (!forceLocal) {
      try {
        final remote = await PoolRemoteSnapshotService.fetchPublished();
        if (remote != null && remote.pools.isNotEmpty) {
          return PoolMatcherResult(
            pools: remote.pools,
            source: PoolMatcherSource.remoteSnapshot,
            snapshotUrl: remote.sourceUrl,
            contentHash: remote.contentHash,
          );
        }
      } catch (_) {}
    }

    if (!hasUserApiKey) {
      final hint = PoolSnapshotConfig.isConfigured
          ? '平台快照暂不可用，且未配置 TronGrid Key，无法本地回放。'
          : '未配置快照 URL，且未配置 TronGrid Key。';
      throw Exception('$hint 请在设置中填写个人 API Key，或稍后再试。');
    }

    final pools = await runFullMatcher(nowMs: nowMs);
    return PoolMatcherResult(
      pools: pools,
      source: PoolMatcherSource.localTronGrid,
    );
  }

  /// 验款 / 本地全量回放（必须用户 Key）
  Future<PoolMatcherResult> runChainVerify({int? nowMs}) {
    return runMatcher(nowMs: nowMs, forceLocal: true);
  }

  Future<Map<String, PoolCycleResult>> runFullMatcher({int? nowMs}) async {
    final purchaseByPool = <String, List<RawPoolTx>>{};
    final exitByPool = <String, List<RawPoolTx>>{};
    final snapshotsByPool = <String, Map<String, dynamic>>{};

    for (final tier in kPoolTiers) {
      final snap = await PoolSnapshotStore.load(tier.id);
      if (snap != null) snapshotsByPool[tier.id] = snap;

      final purchaseTransfers = await _loadMergedTransfers(tier.purchaseAddress);
      purchaseByPool[tier.id] = parseEntryTxs(purchaseTransfers, tier.ticketPriceTrx);

      final exitAddr = tier.exitPoolAddress;
      if (exitAddr != tier.purchaseAddress) {
        final exitTransfers = await _loadMergedTransfers(exitAddr);
        exitByPool[tier.id] = parseExitPoolTxs(exitTransfers, tier.ticketPriceTrx);
      } else {
        exitByPool[tier.id] = parseExitPoolTxs(purchaseTransfers, tier.ticketPriceTrx);
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
