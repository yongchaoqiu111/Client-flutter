class PodcastEpisode {
  const PodcastEpisode({
    required this.id,
    required this.title,
    required this.audioUrl,
    this.duration = '',
    this.pubDate = '',
    this.link = '',
    this.imageUrl = '',
  });

  final String id;
  final String title;
  final String audioUrl;
  final String duration;
  final String pubDate;
  final String link;
  final String imageUrl;
}

class PodcastAlbum {
  const PodcastAlbum({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.imageUrl,
    required this.episodes,
    this.link = '',
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final String imageUrl;
  final String link;
  final List<PodcastEpisode> episodes;
}
