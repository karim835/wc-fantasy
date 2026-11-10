class NewsArticle {
  final String id;
  final String title;
  final String summary;
  final String url;
  final String? imageUrl;
  final String source;
  final String category;
  final DateTime publishedAt;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.url,
    this.imageUrl,
    required this.source,
    required this.category,
    required this.publishedAt,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        url: json['url'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        source: json['source'] as String? ?? '',
        category: json['category'] as String? ?? 'Actu',
        publishedAt: json['publishedAt'] != null
            ? DateTime.tryParse(json['publishedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  String get timeAgo {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
    return '${publishedAt.day}/${publishedAt.month}/${publishedAt.year}';
  }
}
