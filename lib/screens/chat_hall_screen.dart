import 'package:flutter/material.dart';

class ChatHallScreen extends StatelessWidget {
  const ChatHallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('聊天大厅')),
      body: ListView(
        children: const [
          ListTile(title: Text('官方聊天室'), trailing: Icon(Icons.chevron_right)),
          ListTile(title: Text('团队聊天室'), trailing: Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}
