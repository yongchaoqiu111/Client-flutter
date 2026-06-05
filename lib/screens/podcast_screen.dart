import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PodcastScreen extends StatelessWidget {
  const PodcastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('播客大厅')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('直播中', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              _liveCard(context, 'A'),
              _liveCard(context, 'B'),
              _liveCard(context, 'C'),
            ],
          ),
          const SizedBox(height: 16),
          const Text('播客回放', style: TextStyle(fontWeight: FontWeight.bold)),
          Card(
            child: ListTile(
              title: const Text('蓄水池机制讲解'),
              subtitle: const Text('2024-06-04'),
              trailing: IconButton(icon: const Icon(Icons.play_arrow), onPressed: () {}),
            ),
          ),
          const SizedBox(height: 16),
          const Text('聊天大厅', style: TextStyle(fontWeight: FontWeight.bold)),
          ListTile(
            title: const Text('官方聊天室'),
            onTap: () => context.push('/chat'),
          ),
          ListTile(
            title: const Text('团队聊天室'),
            onTap: () => context.push('/chat'),
          ),
        ],
      ),
    );
  }

  Widget _liveCard(BuildContext context, String id) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => context.push('/podcast/room/$id'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.live_tv, color: Colors.red),
                const SizedBox(height: 8),
                Text('主播$id'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
