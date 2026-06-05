import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../config/podcast_config.dart';
import '../models/podcast_episode.dart';

class XimalayaFeedService {
  static Future<PodcastAlbum> fetchAlbum([String? feedUrl]) async {
    final url = feedUrl ?? PodcastConfig.ximalayaFeedUrl;
    final res = await http
        .get(
          Uri.parse(url),
          headers: const {'User-Agent': 'MMM-Client/1.0'},
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('喜马拉雅 RSS 加载失败: HTTP ${res.statusCode}');
    }

    return _parseRss(res.body);
  }

  static PodcastAlbum _parseRss(String xmlBody) {
    final doc = XmlDocument.parse(xmlBody);
    final channel = doc.findAllElements('channel').first;

    final albumTitle = _elementText(channel, 'title');
    final author = _elementText(channel, 'itunes:author');
    final description = _stripHtml(_elementText(channel, 'description'));
    final link = _elementText(channel, 'link');
    final imageUrl = _channelImage(channel);

    final episodes = <PodcastEpisode>[];
    for (final item in channel.findElements('item')) {
      final enclosure = item.getElement('enclosure');
      final audioUrl = _decodeUrl(enclosure?.getAttribute('url') ?? '');
      if (audioUrl.isEmpty) continue;

      episodes.add(
        PodcastEpisode(
          id: _elementText(item, 'guid').isNotEmpty
              ? _elementText(item, 'guid')
              : _elementText(item, 'title'),
          title: _elementText(item, 'title'),
          audioUrl: audioUrl,
          duration: _elementText(item, 'itunes:duration'),
          pubDate: _formatPubDate(_elementText(item, 'pubDate')),
          link: _elementText(item, 'link'),
          imageUrl: _itemImage(item) ?? imageUrl,
        ),
      );
    }

    return PodcastAlbum(
      id: PodcastConfig.ximalayaAlbumId,
      title: albumTitle.isEmpty ? '老板私人技术' : albumTitle,
      author: author.isEmpty ? 'ChaseQiu' : author,
      description: description,
      imageUrl: imageUrl,
      link: link.isEmpty ? PodcastConfig.ximalayaAlbumPage : link,
      episodes: episodes,
    );
  }

  static String _elementText(XmlElement parent, String name) {
    final local = name.contains(':') ? name.split(':').last : name;
    for (final child in parent.childElements) {
      if (child.name.local == local || child.name.qualified == name) {
        return child.innerText.trim();
      }
    }
    final direct = parent.getElement(name);
    if (direct != null) return direct.innerText.trim();
    return '';
  }

  static String _channelImage(XmlElement channel) {
    final img = channel.getElement('itunes:image');
    return img?.getAttribute('href') ?? '';
  }

  static String? _itemImage(XmlElement item) {
    final img = item.getElement('itunes:image');
    return img?.getAttribute('href');
  }

  static String _decodeUrl(String url) => url.replaceAll('&amp;', '&').trim();

  static String _stripHtml(String html) {
    if (html.isEmpty) return '';
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _formatPubDate(String raw) {
    if (raw.isEmpty) return '';
    final parts = raw.split(' ');
    if (parts.length >= 4) {
      final day = parts[1].padLeft(2, '0');
      final month = _monthNum(parts[2]);
      final year = parts[3];
      if (month.isNotEmpty) return '$year-$month-$day';
    }
    return raw.length > 16 ? raw.substring(0, 16) : raw;
  }

  static String _monthNum(String mon) {
    const map = {
      'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
      'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
      'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12',
    };
    return map[mon] ?? '';
  }
}
