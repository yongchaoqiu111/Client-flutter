import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/node_config.dart';
import 'gateway_http_client.dart';
import 'network_debug.dart';

/// WSS：禁止 connectionFactory；DNS 用原生 HttpClient，IP 回退带 Host 头
class WsService {
  WebSocket? _socket;
  StreamSubscription? _sub;
  bool _connected = false;
  bool _connecting = false;
  String? lastError;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  bool get isConnected => _connected && _socket != null;

  Stream<Map<String, dynamic>> get onMessage => _messageController.stream;

  static Uri normalizeWssUri(String wsUrl, {String? overrideHost}) {
    var u = Uri.parse(wsUrl);
    if (overrideHost != null) u = u.replace(host: overrideHost);
    final port = u.scheme == 'wss' ? 443 : 80;
    if (!u.hasPort || u.port == 0) u = u.replace(port: port);
    if (u.path.isEmpty) u = u.replace(path: '/ws');
    return u;
  }

  Future<bool> connect(NodeConfig node) async {
    if (_connecting) return false;
    _connecting = true;
    lastError = null;

    try {
      await disconnect();
      final domainHost = Uri.parse(node.wsUrl).host.toLowerCase();
      NetworkDebug.log('WSS', '开始 ${node.wsUrl}');

      if (await _tryConnect(normalizeWssUri(node.wsUrl), hostHeader: domainHost, label: '①TLS+DNS')) {
        return true;
      }

      final ip = GatewayHttpClient.fallbackIps[domainHost];
      if (ip != null) {
        if (await _tryConnect(
          normalizeWssUri(node.wsUrl, overrideHost: ip),
          hostHeader: domainHost,
          label: '②TLS+IP+Host',
          ipDirect: true,
        )) {
          return true;
        }
      }

      lastError ??= 'WSS 全部失败';
      _connected = false;
      return false;
    } finally {
      _connecting = false;
    }
  }

  Future<bool> _tryConnect(
    Uri uri, {
    required String hostHeader,
    required String label,
    bool ipDirect = false,
  }) async {
    final sw = Stopwatch()..start();
    final url = uri.toString();
    NetworkDebug.log('WSS', '$label $url');
    try {
      final client = ipDirect ? GatewayHttpClient.createIpDirectClient() : HttpClient();
      final headers = ipDirect ? <String, String>{'Host': hostHeader} : null;

      final socket = await WebSocket.connect(
        url,
        customClient: client,
        headers: headers,
      ).timeout(const Duration(seconds: 8));

      sw.stop();
      _socket = socket;
      _connected = true;
      lastError = null;
      NetworkDebug.log('WSS', '$label 握手成功 ${sw.elapsedMilliseconds}ms');

      _sub = socket.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            if (!_messageController.isClosed) _messageController.add(msg);
          } catch (_) {}
        },
        onError: (err) {
          lastError = '$err';
          NetworkDebug.log('WSS', '$label onError: $err');
          _drop();
        },
        onDone: () => _drop(),
      );

      subscribeReservoir();
      subscribeChat(room: 'hall');
      return true;
    } catch (e, st) {
      sw.stop();
      lastError = '$e';
      NetworkDebug.log('WSS', '$label 失败 ${sw.elapsedMilliseconds}ms → $e');
      NetworkDebug.log('WSS', '$label stack: ${st.toString().split('\n').take(2).join(' | ')}');
      return false;
    }
  }

  void _drop() {
    _connected = false;
    _socket = null;
    _sub?.cancel();
    _sub = null;
  }

  void subscribe(String topic) => send({'type': 'subscribe', 'topic': topic});

  void subscribeReservoir() => subscribe('reservoir_updates');

  void subscribeChat({String room = 'hall'}) => subscribe('chat_$room');

  void send(Map<String, dynamic> payload) {
    if (!isConnected) return;
    _socket?.add(jsonEncode(payload));
  }

  void sendChat({required String room, required String content, String? sender}) {
    send({
      'type': 'chat_send',
      'room': room,
      'content': content,
      if (sender != null) 'sender': sender,
    });
  }

  Future<void> disconnect() async {
    _connected = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
  }
}
