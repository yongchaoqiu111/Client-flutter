import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 本地持久化池快照（增量回放）
class PoolSnapshotStore {
  static String _key(String poolId) => 'pool_snapshot_v4_$poolId';

  static Future<Map<String, dynamic>?> load(String poolId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(poolId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String poolId, Map<String, dynamic>? snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    if (snapshot == null) {
      await prefs.remove(_key(poolId));
      return;
    }
    await prefs.setString(_key(poolId), jsonEncode(snapshot));
  }
}
