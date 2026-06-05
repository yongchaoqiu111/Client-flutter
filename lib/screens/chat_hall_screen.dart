import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/chat_config.dart';
import '../models/chat_message.dart';
import '../providers/app_state.dart';
import '../widgets/network_debug_panel.dart';

/// 官方群聊直播间：全局 WSS 收消息，30 秒频控 + 违规词过滤
class ChatHallScreen extends StatefulWidget {
  const ChatHallScreen({super.key});

  @override
  State<ChatHallScreen> createState() => _ChatHallScreenState();
}

class _ChatHallScreenState extends State<ChatHallScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _cooldownTicker;
  String? _lastRejectSnack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().ensureChatRoom(ChatConfig.officialRoom);
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
    final messages = state.officialChatMessages;
    final cooldown = state.chatCooldownSeconds;
    final reject = state.error;
    if (reject != null && reject != _lastRejectSnack) {
      _lastRejectSnack = reject;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reject)));
      });
    }
    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ChatConfig.officialRoomName, style: const TextStyle(fontSize: 16)),
            Text(
              _wsStatusLine(state),
              style: TextStyle(
                fontSize: 11,
                color: state.wsConnected ? Colors.greenAccent : Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重连 WSS',
            onPressed: () async {
              await context.read<AppState>().resubscribeChatRooms();
              if (context.mounted) setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: '排查日志',
            onPressed: () => _showDebugSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '发言规则',
            onPressed: () => _showRules(context),
          ),
        ],
      ),
      body: Column(
        children: [
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
                ? const Center(
                    child: Text(
                      '欢迎来到官方群聊直播间\n所有用户默认进入本频道',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
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
              title: '群聊排查日志',
              compact: true,
              initiallyExpanded: !state.wsConnected,
            ),
          ),
          _inputBar(context, state, cooldown),
        ],
      ),
    );
  }

  String _wsStatusLine(AppState state) {
    if (!state.wsConnected) {
      return state.wsLastError != null ? 'WSS 未连接: ${state.wsLastError}' : 'WSS 未连接';
    }
    return '群聊在线 · ${state.officialChatMessages.length} 条';
  }

  void _showDebugSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.all(12),
          child: ListView(
            controller: scroll,
            children: const [
              NetworkDebugPanel(
                title: '群聊/WSS 全链路日志',
                hint: '复制整段日志发给我，可精确定位订阅/收发问题',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputBar(BuildContext context, AppState state, int cooldown) {
    final canSend = state.canSendChat;
    return SafeArea(
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
                  hintText: canSend ? '说点什么…' : '冷却中 $cooldown 秒',
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
    );
  }

  void _send(BuildContext context) {
    final text = _input.text;
    try {
      final result = context.read<AppState>().sendChatMessage(text);
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

  void _showRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发言规则'),
        content: const Text(
          '1. 官方频道为默认群聊，全员可见\n'
          '2. 每人每 30 秒最多发送 1 条\n'
          '3. 自动屏蔽：微信、QQ、131-139/170-179 电话\n'
          '4. 自动屏蔽：诈骗、欺骗、传销等违规词\n'
          '5. 离开页面后消息仍会写入全局缓存',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
        ],
      ),
    );
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
