import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/podcast_episode.dart';

class PodcastPlayerScreen extends StatefulWidget {
  const PodcastPlayerScreen({required this.episode, super.key});

  final PodcastEpisode episode;

  @override
  State<PodcastPlayerScreen> createState() => _PodcastPlayerScreenState();
}

class _PodcastPlayerScreenState extends State<PodcastPlayerScreen> {
  final _player = AudioPlayer();
  bool _playing = false;
  bool _loading = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    try {
      await _player.setSourceUrl(widget.episode.audioUrl);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_loading || _error != null) return;
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.resume();
      setState(() => _playing = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.episode;
    final maxMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;

    return Scaffold(
      appBar: AppBar(title: const Text('播客播放')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (e.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(e.imageUrl, height: 200, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            Text(e.title, style: Theme.of(context).textTheme.titleLarge),
            if (e.pubDate.isNotEmpty)
              Text(e.pubDate, style: const TextStyle(color: Colors.white54)),
            if (e.duration.isNotEmpty)
              Text('时长 ${e.duration}', style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.orange))
            else ...[
              Slider(
                value: _position.inMilliseconds.clamp(0, maxMs).toDouble(),
                max: maxMs.toDouble(),
                onChanged: _loading
                    ? null
                    : (v) => _player.seek(Duration(milliseconds: v.toInt())),
              ),
              Text(
                '${_fmt(_position)} / ${_duration.inMilliseconds > 0 ? _fmt(_duration) : e.duration}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
            ],
            const Spacer(),
            FilledButton.icon(
              onPressed: _error == null ? _togglePlay : null,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              label: Text(_loading ? '加载中…' : (_playing ? '暂停' : '播放')),
            ),
          ],
        ),
      ),
    );
  }
}
