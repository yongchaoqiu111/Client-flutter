import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/chat_config.dart';
import '../models/chat_message.dart';
import '../providers/app_state.dart';
import '../widgets/network_debug_panel.dart';

/// 播客直播间 A/B/C：接入 WSS 分房间聊天
class LiveRoomScreen extends StatefulWidget {
  const LiveRoomScreen({required this.roomId, super.key});

  final String roomId;

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _cooldownTicker;
  late final String _room;

  @override
  void initState() {
    super.initState();
    _room = ChatConfig.liveRoomId(widget.roomId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().ensureChatRoom(_room);
    });
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final messages = state.chatMessagesForRoom(_room);
    final cooldown = state.chatCooldownSecondsFor(_room);
    final canSend = state.canSendChatIn(_room);
    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ChatConfig.liveRoomTitle(widget.roomId), style: const TextStyle(fontSize: 16)),
            Text(
              state.wsConnected ? '聊天在线 · ${messages.length} 条' : 'WSS 未连接',
              style: TextStyle(
                fontSize: 11,
                color: state.wsConnected ? Colors.greenAccent : Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: '排查日志',
            onPressed: () => _showDebugSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重连并订阅本房间',
            onPressed: () async {
              await context.read<AppState>().ensureChatRoom(_room);
              await context.read<AppState>().resubscribeChatRooms();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 160,
            width: double.infinity,
            color: const Color(0xFF252550),
            alignment: Alignment.center,
            child: const Text('直播中', style: TextStyle(fontSize: 20)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1A2744),
            child: const Text(
              ChatConfig.rulesHint,
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      '欢迎来到${ChatConfig.liveRoomTitle(widget.roomId)}\n发言将同步给同房间用户',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _MessageBubble(
                      message: messages[i],
                      isMine: messages[i].sender == state.address,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: NetworkDebugPanel(
              title: '直播间排查日志',
              compact: true,
              initiallyExpanded: !state.wsConnected,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 200,
                      enabled: canSend,
                      decoration: InputDecoration(
                        hintText: canSend ? '发送聊天消息…' : '冷却中 $cooldown 秒',
                        counterText: '',
                      ),
                      onSubmitted: canSend ? (_) => _send(context) : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: canSend ? () => _send(context) : null,
                    child: Text(canSend ? '发送' : '${cooldown}s'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDebugSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.all(12),
          child: ListView(
            controller: scroll,
            children: [
              NetworkDebugPanel(
                title: '直播间 $_room 日志',
                hint: 'room=$_room · 复制日志发给我',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _send(BuildContext context) {
    final text = _input.text;
    try {
      final result = context.read<AppState>().sendChatMessage(text, room: _room);
      if (!result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.reason ?? '发送失败')),
        );
        return;
      }
      _input.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送异常: $e')),
      );
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final short = message.sender.length > 10
        ? '${message.sender.substring(0, 10)}…'
        : message.sender;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF1E4D6B) : const Color(0xFF2A2A45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(short, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 4),
            Text(message.content, style: const TextStyle(height: 1.35)),
          ],
        ),
      ),
    );
  }
}
