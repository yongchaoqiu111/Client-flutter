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

  /// 波场实时带宽：POST /wallet/getaccountresource
  static Future<TronBandwidthStatus> fetchTronBandwidth(String address) async {
    final node = ChainConfig.tron.nodes.first;
    final uri = Uri.parse('${node.replaceAll(RegExp(r'/+$'), '')}/wallet/getaccountresource');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'address': address, 'visible': true}),
        )
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) throw Exception('getaccountresource HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return TronBandwidthStatus.fromJson(body);
  }

  /// 预估单笔转账燃料费（与转账金额分开扣除）
  static Future<TransferFeeEstimate> estimateTransferFee(String chain, String fromAddress) async {
    final c = chain.toUpperCase();
    if (c == 'TRON') {
      return _estimateTrxTransferFee(fromAddress);
    }
    if (c == 'BSC') {
      return const TransferFeeEstimate(
        fee: 0.00025,
        label: '约 0.00025 BNB',
        note: '按当前 BSC 网络 gas 估算，实际以链上为准',
      );
    }
    return const TransferFeeEstimate(fee: 0, label: '—', note: '');
  }

  static Future<TransferFeeEstimate> _estimateTrxTransferFee(String address) async {
    const fallback = TransferFeeEstimate(
      fee: 0.268,
      label: '约 0.268 TRX',
      note: '带宽不足时将燃烧 TRX（查询失败，按常见值估算）',
    );
    try {
      final bw = await fetchTronBandwidth(address);
      if (bw.canCoverTransfer) {
        return TransferFeeEstimate(
          fee: 0,
          label: '约 0 TRX（消耗带宽）',
          note: '剩余带宽 ${bw.totalAvailableBp} BP，本笔约 ${TronBandwidthStatus.transferCostBp} BP；'
              '免费 ${bw.freeRemainingBp} + 质押 ${bw.stakedRemainingBp}',
          bandwidth: bw,
        );
      }
      return TransferFeeEstimate(
        fee: 0.268,
        label: '约 0.268 TRX（烧 TRX）',
        note: '总可用带宽 ${bw.totalAvailableBp} BP，不足 ${TronBandwidthStatus.transferCostBp} BP，将燃烧 TRX',
        bandwidth: bw,
      );
    } catch (_) {
      return fallback;
    }
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

class TransferFeeEstimate {
  const TransferFeeEstimate({
    required this.fee,
    required this.label,
    required this.note,
    this.bandwidth,
  });

  final double fee;
  final String label;
  final String note;
  final TronBandwidthStatus? bandwidth;
}

/// TronGrid getaccountresource 解析（商用钱包同款公式）
class TronBandwidthStatus {
  TronBandwidthStatus({
    required this.freeNetLimit,
    required this.freeNetUsed,
    required this.netLimit,
    required this.netUsed,
  });

  /// 普通 TRX 转账（无 memo）固定约 267 BP
  static const transferCostBp = 267;

  final int freeNetLimit;
  final int freeNetUsed;
  final int netLimit;
  final int netUsed;

  int get freeRemainingBp => freeNetLimit - freeNetUsed;
  int get stakedRemainingBp => netLimit - netUsed;
  int get totalAvailableBp => freeRemainingBp + stakedRemainingBp;
  bool get canCoverTransfer => totalAvailableBp >= transferCostBp;

  factory TronBandwidthStatus.fromJson(Map<String, dynamic> json) {
    return TronBandwidthStatus(
      freeNetLimit: (json['freeNetLimit'] as num?)?.toInt() ?? 0,
      freeNetUsed: (json['freeNetUsed'] as num?)?.toInt() ?? 0,
      netLimit: (json['NetLimit'] as num?)?.toInt() ?? 0,
      netUsed: (json['NetUsed'] as num?)?.toInt() ?? 0,
    );
  }
}
