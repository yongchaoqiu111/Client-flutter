import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/node_config.dart';

typedef WsMessageHandler = void Function(Map<String, dynamic> message);

class WsService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _handlers = <WsMessageHandler>[];

  bool get isConnected => _channel != null;

  void addListener(WsMessageHandler handler) => _handlers.add(handler);

  void removeListener(WsMessageHandler handler) => _handlers.remove(handler);

  Future<void> connect(NodeConfig node) async {
    await disconnect();
    final uri = Uri.parse(node.wsUrl);
    _channel = WebSocketChannel.connect(uri);
    _sub = _channel!.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          for (final h in _handlers) {
            h(msg);
          }
        } catch (_) {}
      },
      onError: (_) => disconnect(),
      onDone: () => disconnect(),
    );
  }

  void subscribeReservoir() {
    send({'type': 'subscribe', 'topic': 'reservoir_updates'});
  }

  void send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _sub = null;
    _channel = null;
  }
}
