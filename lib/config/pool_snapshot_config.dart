/// 平台发布的 pool 快照（一期 Vercel CDN / 二期 WSS 节点 API）
class PoolSnapshotConfig {
  PoolSnapshotConfig._();

  /// 编译时主 URL（不要尾部斜杠）
  /// 例: --dart-define=POOL_SNAPSHOT_URL=https://js-chi-flax.vercel.app
  static const String baseUrl = String.fromEnvironment(
    'POOL_SNAPSHOT_URL',
    defaultValue: 'https://js-chi-flax.vercel.app',
  );

  /// 多个 Vercel 镜像分流，逗号分隔（内容与 GitHub js 仓同源）
  /// 例: --dart-define=POOL_SNAPSHOT_URLS=https://a.vercel.app,https://b.vercel.app
  static const String _extraUrls = String.fromEnvironment(
    'POOL_SNAPSHOT_URLS',
    defaultValue: '',
  );

  static List<String> get snapshotBaseUrls {
    final urls = <String>[];
    void add(String raw) {
      final u = raw.trim().replaceAll(RegExp(r'/+$'), '');
      if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
    }

    for (final part in _extraUrls.split(',')) {
      add(part);
    }
    add(baseUrl);
    return urls;
  }

  static bool get isConfigured => snapshotBaseUrls.isNotEmpty;

  static List<String> manifestUrls(String base) => ['$base/manifest.json'];
  static List<String> snapshotUrls(String base) => ['$base/snapshot.json'];

  static List<Uri> get allSnapshotUris =>
      snapshotBaseUrls.expand((b) => snapshotUrls(b)).map(Uri.parse).toList();

  static List<Uri> get allManifestUris =>
      snapshotBaseUrls.expand((b) => manifestUrls(b)).map(Uri.parse).toList();
}
