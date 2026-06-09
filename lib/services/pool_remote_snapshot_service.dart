import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/pool_snapshot_config.dart';
import '../models/pool_cycle_models.dart';
import 'pool_publish_codec.dart';
import 'pool_snapshot_store.dart';

class PoolRemoteSnapshotBundle {
  const PoolRemoteSnapshotBundle({
    required this.pools,
    required this.contentHash,
    required this.matchDayId,
    required this.tronBlockNumber,
    required this.publishedAt,
    required this.sourceUrl,
  });

  final Map<String, PoolCycleResult> pools;
  final String contentHash;
  final String matchDayId;
  final int tronBlockNumber;
  final int publishedAt;
  final String sourceUrl;
}

/// 从 Vercel / 后期 WSS 静态 JSON 加载全队快照（与 publish-pool-snapshot.js 同结构）
class PoolRemoteSnapshotService {
  static const _timeout = Duration(seconds: 20);

  static Future<PoolRemoteSnapshotBundle?> fetchPublished() async {
    if (!PoolSnapshotConfig.isConfigured) return null;

    PoolRemoteSnapshotBundle? first;
    String? lastHash;

    for (final uri in PoolSnapshotConfig.allSnapshotUris) {
      final bundle = await _fetchOne(uri);
      if (bundle == null) continue;

      if (first == null) {
        first = bundle;
        lastHash = bundle.contentHash;
        continue;
      }

      if (lastHash != null &&
          bundle.contentHash.isNotEmpty &&
          lastHash != bundle.contentHash) {
        // 多 V 内容不一致时仍返回首个成功源，由二期 WSS hash 校验补强
        continue;
      }
    }

    return first;
  }

  static Future<PoolRemoteSnapshotBundle?> _fetchOne(Uri uri) async {
    try {
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) return null;

      final poolsRaw = body['pools'] as Map<String, dynamic>? ?? {};
      final pools = <String, PoolCycleResult>{};
      for (final entry in poolsRaw.entries) {
        pools[entry.key] =
            PoolPublishCodec.poolFromJson(entry.value as Map<String, dynamic>);
        final snap = entry.value['snapshot'] as Map<String, dynamic>?;
        if (snap != null) {
          await PoolSnapshotStore.save(entry.key, snap);
        }
      }
      if (pools.isEmpty) return null;

      final block = body['tronBlock'] as Map<String, dynamic>? ?? {};
      return PoolRemoteSnapshotBundle(
        pools: pools,
        contentHash: body['contentHash'] as String? ?? '',
        matchDayId: body['matchDayId'] as String? ?? '',
        tronBlockNumber: (block['number'] as num?)?.toInt() ?? 0,
        publishedAt: (body['publishedAt'] as num?)?.toInt() ?? 0,
        sourceUrl: uri.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
