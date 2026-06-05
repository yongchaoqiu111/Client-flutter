import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import 'home_screen.dart';
import 'network_screen.dart';
import 'podcast_screen.dart';
import 'profile_screen.dart';
import 'queue_screen.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final index = context.watch<AppState>().shellTabIndex;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          HomeScreen(),
          QueueScreen(),
          PodcastScreen(),
          NetworkScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => context.read<AppState>().setShellTab(i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '排单'),
          BottomNavigationBarItem(icon: Icon(Icons.podcasts), label: '播客'),
          BottomNavigationBarItem(icon: Icon(Icons.hub), label: '关系'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
