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
    for (final node in cfg.nodes) {
      try {
        final uri = Uri.parse('${node.replaceAll(RegExp(r'/+$'), '')}/wallet/getaccount');
        final res = await http
            .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'address': address, 'visible': true}))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final sun = (body['balance'] as num?)?.toInt() ?? 0;
          return sun / 1e6;
        }
      } catch (_) {}
    }
    throw Exception('TRON 节点查询失败');
  }

  static Future<double> _evmBalance(ChainConfig cfg, String address) async {
    if (!address.startsWith('0x')) throw Exception('BSC 地址须 0x 开头');
    for (final node in cfg.nodes) {
      try {
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
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final hex = body['result'] as String?;
          if (hex != null) {
            final wei = BigInt.parse(hex);
            return wei.toDouble() / BigInt.from(10).pow(cfg.decimals).toDouble();
          }
        }
      } catch (_) {}
    }
    throw Exception('${cfg.id} 节点查询失败');
  }
}

class _CacheEntry {
  _CacheEntry(this.balance, this.at);
  final double balance;
  final DateTime at;
}
