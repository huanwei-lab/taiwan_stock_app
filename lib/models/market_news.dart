enum NewsRiskLevel {
  high,
  medium,
  low,
}

class MarketNewsItem {
  const MarketNewsItem({
    required this.title,
    required this.source,
    required this.link,
    required this.publishedAt,
    required this.riskDelta,
    required this.matchedKeywords,
  });

  final String title;
  final String source;
  final String link;
  final DateTime? publishedAt;
  final int riskDelta;
  final List<String> matchedKeywords;
}

class MarketNewsSnapshot {
  const MarketNewsSnapshot({
    required this.items,
    required this.riskScore,
    required this.level,
    required this.summary,
    required this.asOf,
  });

  final List<MarketNewsItem> items;
  final int riskScore;
  final NewsRiskLevel level;
  final String summary;
  final DateTime asOf;
}
