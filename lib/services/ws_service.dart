import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  final Set<String> _chatRooms = {'hall'};

  bool get isConnected => _connected && _socket != null;
  /// 与旧版一致：握手成功即视为可用（不再阻塞等 gateway_connected）
  bool get upstreamReady => isConnected;
  String get chatRoomsLabel => _chatRooms.join(',');

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
      ).timeout(const Duration(seconds: 12));

      sw.stop();
      _socket = socket;
      _connected = true;
      lastError = null;
      NetworkDebug.log('WSS', '$label 握手成功 ${sw.elapsedMilliseconds}ms');

      _sub = socket.listen(
        (data) {
          try {
            final msg = _parseWsMessage(data);
            if (msg == null) return;
            final type = msg['type']?.toString();
            if (type == 'gateway_connected' || type == 'welcome') {
              NetworkDebug.log('WSS', '收到 $type，补发订阅');
              _resubscribeAll();
            }
            if (!_messageController.isClosed) _messageController.add(msg);
          } catch (e) {
            NetworkDebug.log('WSS', '消息解析失败: $e type=${data.runtimeType}');
          }
        },
        onError: (err) {
          lastError = '$err';
          NetworkDebug.log('WSS', '$label onError: $err');
          _drop();
        },
        onDone: () {
          NetworkDebug.log('WSS', '$label 连接断开');
          _drop();
        },
      );

      // 恢复旧版：握手成功立即订阅（上一版稳定行为）
      _resubscribeAll();
      return true;
    } catch (e, st) {
      sw.stop();
      lastError = '$e';
      NetworkDebug.log('WSS', '$label 失败 ${sw.elapsedMilliseconds}ms → $e');
      NetworkDebug.log('WSS', '$label stack: ${st.toString().split('\n').take(2).join(' | ')}');
      return false;
    }
  }

  /// 模拟器/部分机型 WSS 帧为二进制 Uint8ArrayView，不能 data as String
  static Map<String, dynamic>? _parseWsMessage(dynamic data) {
    final text = _frameToText(data).trim();
    if (text.isEmpty) return null;
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  static String _frameToText(dynamic data) {
    if (data is String) return data;
    if (data is Uint8List) return utf8.decode(data);
    if (data is TypedData) {
      return utf8.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    if (data is List<int>) return utf8.decode(List<int>.from(data));
    return data.toString();
  }

  void _drop() {
    _connected = false;
    _socket = null;
    _sub?.cancel();
    _sub = null;
  }

  void subscribe(String topic) {
    final ok = send({'type': 'subscribe', 'topic': topic});
    NetworkDebug.log('WS→', 'subscribe $topic ${ok ? "已发" : "失败"}');
  }

  void subscribeReservoir() => subscribe('reservoir_updates');

  void subscribePoolCheckpoint() => subscribe('pool_checkpoint');

  void subscribeChat({required String room}) {
    _chatRooms.add(room);
    subscribe('chat_$room');
  }

  void _resubscribeAll() {
    if (!isConnected) return;
    subscribeReservoir();
    subscribePoolCheckpoint();
    for (final room in _chatRooms) {
      subscribe('chat_$room');
    }
  }

  void resubscribeChatRooms() => _resubscribeAll();

  bool send(Map<String, dynamic> payload) {
    if (!isConnected) return false;
    _socket?.add(jsonEncode(payload));
    return true;
  }

  bool sendChat({required String room, required String content, String? sender}) {
    final ok = send({
      'type': 'chat_send',
      'room': room,
      'content': content,
      if (sender != null) 'sender': sender,
    });
    final from = sender == null ? '?' : (sender.length > 10 ? '${sender.substring(0, 10)}…' : sender);
    NetworkDebug.log('WS→', 'chat_send room=$room from=$from ${ok ? "已发" : "失败"}');
    return ok;
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
