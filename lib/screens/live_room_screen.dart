import 'package:flutter/material.dart';

class LiveRoomScreen extends StatefulWidget {
  const LiveRoomScreen({required this.roomId, super.key});

  final String roomId;

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  final _msgs = <String>['欢迎进入直播间'];
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('直播间 ${widget.roomId}')),
      body: Column(
        children: [
          Container(
            height: 180,
            color: const Color(0xFF252550),
            alignment: Alignment.center,
            child: const Text('直播中', style: TextStyle(fontSize: 20)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _msgs.length,
              itemBuilder: (_, i) => Text(_msgs[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(hintText: '发送聊天消息...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_ctrl.text.isEmpty) return;
                    setState(() => _msgs.add(_ctrl.text));
                    _ctrl.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
