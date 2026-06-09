import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pool_cycle_models.dart';

/// 链上转账本地缓存（按地址增量合并，避免每次从 0 全量拉 TronGrid）
class PoolTxCacheStore {
  static String _key(String address) => 'pool_tx_cache_v1_$address';

  static Map<String, dynamic> _toMap(RawPoolTx t) => {
        'txHash': t.txHash,
        'fromAddress': t.fromAddress,
        'toAddress': t.toAddress,
        'amount': t.amount,
        'blockTimestamp': t.blockTimestamp,
        'blockNumber': t.blockNumber,
      };

  static RawPoolTx _fromMap(Map<String, dynamic> m) => RawPoolTx(
        txHash: m['txHash'] as String,
        fromAddress: m['fromAddress'] as String,
        toAddress: m['toAddress'] as String?,
        amount: (m['amount'] as num).toDouble(),
        blockTimestamp: m['blockTimestamp'] as int,
        blockNumber: m['blockNumber'] as int?,
      );

  static Future<List<RawPoolTx>> load(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(address));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => _fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(String address, List<RawPoolTx> txs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(txs.map(_toMap).toList());
    await prefs.setString(_key(address), encoded);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('pool_tx_cache_v1_'));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
