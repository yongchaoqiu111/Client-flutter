import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/chain_config.dart';

/// 只读链上余额（借鉴 pmsj get_balance，无 session、无私钥）
class ChainRpcService {
  static final _cache = <String, _CacheEntry>{};
  static const _cacheTtl = Duration(seconds: 5);

  static Future<double> getBalance(String chain, String address) async {
    final cfg = ChainConfig.byId(chain);
    if (cfg == null) throw Exception('不支持的链');

    final cacheKey = '$chain:$address';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.balance;
    }

    final balance = chain.toUpperCase() == 'TRON'
        ? await _trxBalance(cfg, address)
        : await _evmBalance(cfg, address);

    _cache[cacheKey] = _CacheEntry(balance, DateTime.now());
    return balance;
  }

  static Future<double> _trxBalance(ChainConfig cfg, String address) async {
    if (!address.startsWith('T')) throw Exception('TRON 地址须 T 开头');
    final tasks = cfg.nodes.map((node) => _fetchTrxBalance(node, address));
    return _firstSuccess(tasks, 'TRON 节点查询失败');
  }

  static Future<double> _fetchTrxBalance(String node, String address) async {
    final uri = Uri.parse('${node.replaceAll(RegExp(r'/+$'), '')}/wallet/getaccount');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'address': address, 'visible': true}),
        )
        .timeout(const Duration(seconds: 4));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final sun = (body['balance'] as num?)?.toInt() ?? 0;
    return sun / 1e6;
  }

  static Future<double> _evmBalance(ChainConfig cfg, String address) async {
    if (!address.startsWith('0x')) throw Exception('BSC 地址须 0x 开头');
    final tasks = cfg.nodes.map((node) => _fetchEvmBalance(node, cfg.decimals, address));
    return _firstSuccess(tasks, '${cfg.id} 节点查询失败');
  }

  static Future<double> _fetchEvmBalance(String node, int decimals, String address) async {
    final res = await http
        .post(
          Uri.parse(node),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'method': 'eth_getBalance',
            'params': [address, 'latest'],
            'id': 1,
          }),
        )
        .timeout(const Duration(seconds: 4));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final hex = body['result'] as String?;
    if (hex == null) throw Exception('无余额数据');
    final wei = BigInt.parse(hex);
    return wei.toDouble() / BigInt.from(10).pow(decimals).toDouble();
  }

  static Future<double> _firstSuccess(
    Iterable<Future<double>> tasks,
    String errorMessage,
  ) {
    final completer = Completer<double>();
    var pending = 0;
    for (final task in tasks) {
      pending++;
      task.then((value) {
        if (!completer.isCompleted) completer.complete(value);
      }).catchError((_) {
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.completeError(Exception(errorMessage));
        }
      });
    }
    if (pending == 0) return Future.error(Exception(errorMessage));
    return completer.future;
  }
}

class _CacheEntry {
  _CacheEntry(this.balance, this.at);
  final double balance;
  final DateTime at;
}
