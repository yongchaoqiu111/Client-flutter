import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// 网关常量。禁止全局 HttpOverrides/connectionFactory（会破坏 TLS → nginx 400）
class GatewayHttpClient {
  GatewayHttpClient._();

  static const fallbackIps = <String, String>{
    'book26.top': '165.154.244.129',
    'news16.top': '165.154.244.129',
  };

  static const serverIp = '165.154.244.129';

  static HttpClient shared() => HttpClient();

  static bool isRetriableError(Object error) {
    final msg = error.toString();
    return msg.contains('Failed host lookup') ||
        msg.contains('No address associated with hostname') ||
        msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Connection timed out') ||
        msg.contains('HandshakeException') ||
        msg.contains('CERTIFICATE') ||
        msg.contains('plain HTTP request was sent to HTTPS');
  }

  /// IP 直连时放宽证书（仅用于 https://165.154.244.129 + Host 头）
  static HttpClient createIpDirectClient() {
    final client = HttpClient();
    client.badCertificateCallback = (_, __, ___) => true;
    return client;
  }

  static String? ipBaseFor(String apiUrl) {
    final uri = Uri.tryParse(apiUrl);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (!fallbackIps.containsKey(host)) return null;
    return uri.replace(host: serverIp).toString().replaceAll(RegExp(r'/+$'), '');
  }

  /// IP 直连时必须带原域名 Host，否则 nginx/网关无法正确转发 POST
  static Future<http.Response> requestViaIp({
    required String method,
    required String ipBase,
    required String path,
    required String hostHeader,
    String? body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final client = createIpDirectClient();
    try {
      final uri = Uri.parse('$ipBase$path');
      final req = await client.openUrl(method, uri).timeout(timeout);
      req.headers.set(HttpHeaders.hostHeader, hostHeader);
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(body);
      }
      final response = await req.close().timeout(timeout);
      final text = await response.transform(utf8.decoder).join().timeout(timeout);
      return http.Response(text, response.statusCode, headers: {
        HttpHeaders.contentTypeHeader: response.headers.contentType?.toString() ?? 'application/json',
      });
    } finally {
      client.close(force: true);
    }
  }
}
