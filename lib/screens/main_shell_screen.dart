import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'network_screen.dart';
import 'podcast_screen.dart';
import 'profile_screen.dart';
import 'queue_screen.dart';

/// 前端布局方案 §整体架构：首页 | 排单 | 播客 | 关系 | 我的
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;

  static const _tabs = [
    (icon: Icons.home, label: '首页'),
    (icon: Icons.list_alt, label: '排单'),
    (icon: Icons.podcasts, label: '播客'),
    (icon: Icons.people, label: '关系'),
    (icon: Icons.person, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          QueueScreen(),
          PodcastScreen(),
          NetworkScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          for (final t in _tabs)
            BottomNavigationBarItem(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}
