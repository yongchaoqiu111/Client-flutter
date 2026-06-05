import 'dart:convert';
import 'dart:io';

import '../models/node_probe_result.dart';
import 'gateway_http_client.dart';
import 'network_debug.dart';

/// HTTPS 测速：使用无 connectionFactory 的 HttpClient，避免 TLS 被破坏
class GatewayPing {
  static const _timeout = Duration(seconds: 8);
  static String? lastDetail;

  static Future<NodeProbeResult> ping(String apiUrl) async {
    final base = apiUrl.replaceAll(RegExp(r'/+$'), '');
    final sw = Stopwatch()..start();
    NetworkDebug.log('HTTP', '开始测速 $base');
    final err = await _openHome(base);
    if (err == null) {
      NetworkDebug.log('HTTP', '测速成功 ${sw.elapsedMilliseconds}ms');
      return NodeProbeResult(online: true, latencyMs: sw.elapsedMilliseconds);
    }
    NetworkDebug.log('HTTP', '测速失败: $err');
    return const NodeProbeResult(online: false);
  }

  static Future<String> pingOrError(String apiUrl) async {
    await ping(apiUrl);
    return lastDetail ?? '连接失败（见诊断日志）';
  }

  static Future<Object?> _openHome(String base) async {
    final host = Uri.parse(base).host.toLowerCase();

    NetworkDebug.log('HTTP', '① DNS GET $base');
    final err1 = await _httpsGet(url: '$base/', hostHeader: null);
    if (err1 == null) {
      lastDetail = 'DNS OK';
      return null;
    }
    NetworkDebug.log('HTTP', '① DNS 失败: $err1');

    final ip = GatewayHttpClient.fallbackIps[host];
    if (ip == null) {
      lastDetail = '$err1';
      return err1;
    }

    NetworkDebug.log('HTTP', '② IP GET https://$ip/ Host=$host');
    final err2 = await _httpsGet(
      url: 'https://$ip/',
      hostHeader: host,
      allowBadCert: true,
    );
    if (err2 == null) {
      lastDetail = 'IP OK';
      return null;
    }
    NetworkDebug.log('HTTP', '② IP 失败: $err2');
    lastDetail = 'DNS: $err1 | IP: $err2';
    return err2;
  }

  static Future<Object?> _httpsGet({
    required String url,
    String? hostHeader,
    bool allowBadCert = false,
  }) async {
    final client = HttpClient();
    final sw = Stopwatch()..start();
    try {
      if (allowBadCert) {
        client.badCertificateCallback = (_, __, ___) => true;
      }
      final request = await client.getUrl(Uri.parse(url));
      if (hostHeader != null) {
        request.headers.set(HttpHeaders.hostHeader, hostHeader);
      }
      final response = await request.close().timeout(_timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      sw.stop();

      NetworkDebug.log(
        'HTTP',
        '${sw.elapsedMilliseconds}ms HTTP ${response.statusCode} '
        'body=${body.length > 80 ? '${body.substring(0, 80)}…' : body}',
      );

      if (response.statusCode >= 200 && response.statusCode < 400) {
        return null;
      }
      return Exception('HTTP ${response.statusCode}');
    } catch (e) {
      sw.stop();
      NetworkDebug.log('HTTP', '异常 ${sw.elapsedMilliseconds}ms → $e');
      return e;
    } finally {
      client.close(force: true);
    }
  }
}
