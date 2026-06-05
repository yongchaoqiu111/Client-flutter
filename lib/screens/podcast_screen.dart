import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/podcast_episode.dart';
import '../providers/app_state.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadPodcastFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final album = state.podcastAlbum;

    return Scaffold(
      appBar: AppBar(
        title: const Text('播客大厅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.podcastLoading
                ? null
                : () => state.loadPodcastFeed(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.loadPodcastFeed(force: true),
        child: ListView(
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
            const SizedBox(height: 20),
            const Text('喜马拉雅 · 播客回放', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (state.podcastLoading && album == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.podcastError != null && album == null)
              Card(
                child: ListTile(
                  title: const Text('播客加载失败'),
                  subtitle: Text(state.podcastError!),
                  trailing: TextButton(
                    onPressed: () => state.loadPodcastFeed(force: true),
                    child: const Text('重试'),
                  ),
                ),
              )
            else if (album != null) ...[
              _albumHeader(album),
              const SizedBox(height: 12),
              ...album.episodes.map((e) => _episodeTile(context, e)),
            ],
            const SizedBox(height: 16),
            const Text('聊天大厅', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.groups, color: Colors.cyan),
              title: const Text('官方群聊直播间'),
              subtitle: const Text('默认频道 · 30秒/条 · 违规自动屏蔽'),
              onTap: () => context.push('/chat'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _albumHeader(PodcastAlbum album) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (album.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(album.imageUrl, width: 72, height: 72, fit: BoxFit.cover),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(album.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(album.author, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    album.description.length > 80
                        ? '${album.description.substring(0, 80)}…'
                        : album.description,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '共 ${album.episodes.length} 期 · 喜马拉雅',
                    style: const TextStyle(color: Colors.cyan, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _episodeTile(BuildContext context, PodcastEpisode episode) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [if (episode.pubDate.isNotEmpty) episode.pubDate, if (episode.duration.isNotEmpty) episode.duration]
              .join(' · '),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.play_circle_outline),
          onPressed: () => context.push('/podcast/play', extra: episode),
        ),
        onTap: () => context.push('/podcast/play', extra: episode),
      ),
    );
  }

  Widget _liveCard(BuildContext context, String id) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => context.push('/podcast/room/$id'),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.live_tv, color: Colors.red),
                SizedBox(height: 8),
                Text('直播间'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
