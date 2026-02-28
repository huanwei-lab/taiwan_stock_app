import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/market_news.dart';

class NewsService {
  static const List<String> _negativeKeywords = <String>[
    '戰爭',
    '衝突',
    '空襲',
    '開戰',
    '動武',
    '飛彈',
    '封鎖',
    '制裁',
    '風險',
    '暴跌',
    '崩',
    '衰退',
    '下修',
    '升息',
    '通膨',
    '川普',
    '關稅',
    '地緣',
    '以色列',
    '伊朗',
    '中東',
    '荷姆茲',
    '疫情',
    '確診',
    '傳染',
    '封城',
    '流感',
    '猴痘',
    '斷鏈',
    '缺貨',
    '停工',
    '罷工',
    '塞港',
    '升息',
    '緊縮',
    '殖利率',
  ];

  static const List<String> _positiveKeywords = <String>[
    '利多',
    '成長',
    '創高',
    '上修',
    '突破',
    '回升',
    '擴產',
    '增資',
    '訂單',
    '獲利',
    '合作',
    '核可',
    '藥證',
    '新藥',
    '通過',
    '三期',
    'FDA',
    'EUA',
    '降息',
    '刺激',
    '補助',
    '政策利多',
  ];

  static const Map<String, String> _keywordCanonicalMap = <String, String>{
    '戰爭': '軍事衝突',
    '衝突': '軍事衝突',
    '空襲': '軍事衝突',
    '開戰': '軍事衝突',
    '動武': '軍事衝突',
    '飛彈': '軍事衝突',
    '封鎖': '軍事衝突',
    '制裁': '軍事衝突',
    '地緣': '軍事衝突',
    '以色列': '軍事衝突',
    '伊朗': '軍事衝突',
    '中東': '軍事衝突',
    '荷姆茲': '軍事衝突',
    '疫情': '疫情升溫',
    '確診': '疫情升溫',
    '傳染': '疫情升溫',
    '封城': '疫情升溫',
    '流感': '疫情升溫',
    '猴痘': '疫情升溫',
    'COVID': '疫情升溫',
    '新藥': '新藥核可',
    '藥證': '新藥核可',
    '核可': '新藥核可',
    '通過': '新藥核可',
    '三期': '新藥核可',
    'FDA': '新藥核可',
    'EUA': '新藥核可',
    '供應鏈': '供應鏈中斷',
    '斷鏈': '供應鏈中斷',
    '缺貨': '供應鏈中斷',
    '停工': '供應鏈中斷',
    '罷工': '供應鏈中斷',
    '塞港': '供應鏈中斷',
    '升息': '利率緊縮',
    '緊縮': '利率緊縮',
    '殖利率': '利率緊縮',
    '通膨': '通膨壓力',
    'CPI': '通膨壓力',
    '降息': '政策寬鬆',
    '刺激': '政策寬鬆',
    '補助': '政策寬鬆',
    '政策利多': '政策寬鬆',
    '利多': '正向題材',
    '成長': '正向題材',
    '創高': '正向題材',
    '上修': '正向題材',
    '突破': '正向題材',
    '回升': '正向題材',
    '擴產': '正向題材',
    '訂單': '正向題材',
    '獲利': '正向題材',
    '合作': '正向題材',
  };

  Future<MarketNewsSnapshot> fetchMarketSnapshot({String? keyword}) async {
    final query = _buildQuery(keyword);
    final uri = Uri.https(
      'news.google.com',
      '/rss/search',
      <String, String>{
        'q': query,
        'hl': 'zh-TW',
        'gl': 'TW',
        'ceid': 'TW:zh-Hant',
      },
    );

    final response = await _fetchWithFallback(uri);
    final document = XmlDocument.parse(utf8.decode(response.bodyBytes));
    final nodes = document.findAllElements('item').take(10).toList();

    final items = nodes.map((node) {
      final rawTitle = _firstText(node, 'title');
      final link = _firstText(node, 'link');
      final pubDateText = _firstText(node, 'pubDate');
      final (title, source) = _splitTitleAndSource(rawTitle);

      return MarketNewsItem(
        title: title,
        source: source,
        link: link,
        publishedAt: DateTime.tryParse(pubDateText),
        riskDelta: _computeHeadlineRiskDelta(title, source),
        matchedKeywords: _extractMatchedKeywords(title),
      );
    }).toList();

    final aggregateRisk = _computeAggregateRisk(items);
    return MarketNewsSnapshot(
      items: items,
      riskScore: aggregateRisk,
      level: _toRiskLevel(aggregateRisk),
      summary: _buildSummary(aggregateRisk),
      asOf: DateTime.now(),
    );
  }

  String _buildQuery(String? keyword) {
    final trimmed = keyword?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return '$trimmed 台股 OR 台灣股市 OR 美股 OR 國際股市 OR 戰爭 OR 地緣政治 OR 以色列 OR 伊朗 OR 中東 OR 油價 OR 聯準會 OR 關稅 OR 疫情 OR 確診 OR 新藥 OR 藥證 OR 核可 OR 供應鏈 OR 升息 OR 降息';
    }

    return '台股 OR 台灣股市 OR 美股 OR 國際股市 OR 戰爭 OR 地緣政治 OR 以色列 OR 伊朗 OR 中東 OR 油價 OR 川普 OR 聯準會 OR 關稅 OR 疫情 OR 確診 OR 新藥 OR 藥證 OR 核可 OR 供應鏈 OR 升息 OR 降息';
  }

  Future<http.Response> _fetchWithFallback(Uri uri) async {
    final uris = <Uri>[uri];

    if (kIsWeb) {
      uris.add(
        Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(uri.toString())}'),
      );
      uris.add(
        Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent(uri.toString())}'),
      );
    }

    Object? lastError;
    for (final target in uris) {
      try {
        final response = await http.get(target);
        if (response.statusCode == 200) {
          return response;
        }
        lastError = 'HTTP ${response.statusCode} from $target';
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception(lastError ?? 'Failed to fetch market news.');
  }

  String _firstText(XmlElement root, String tagName) {
    final values = root
        .findElements(tagName)
        .map((element) => element.innerText.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    return values.isEmpty ? '' : values.first;
  }

  (String, String) _splitTitleAndSource(String rawTitle) {
    final index = rawTitle.lastIndexOf(' - ');
    if (index <= 0 || index >= rawTitle.length - 3) {
      return (rawTitle, '新聞');
    }
    return (
      rawTitle.substring(0, index).trim(),
      rawTitle.substring(index + 3).trim(),
    );
  }

  int _computeHeadlineRiskDelta(String headline, String source) {
    final negativeHits = _extractCanonicalHits(headline, _negativeKeywords);
    final positiveHits = _extractCanonicalHits(headline, _positiveKeywords);
    final baseDelta = (negativeHits.length * 10) - (positiveHits.length * 8);
    final weighted = (baseDelta * _sourceRiskWeight(source)).round();
    return weighted.clamp(-35, 45);
  }

  List<String> _extractMatchedKeywords(String headline) {
    final negativeHits = _extractCanonicalHits(headline, _negativeKeywords);
    final positiveHits = _extractCanonicalHits(headline, _positiveKeywords);
    return <String>{...negativeHits, ...positiveHits}.toList();
  }

  List<String> _extractCanonicalHits(String headline, List<String> keywords) {
    final hits = <String>{};
    for (final keyword in keywords) {
      if (headline.contains(keyword)) {
        hits.add(_keywordCanonicalMap[keyword] ?? keyword);
      }
    }
    return hits.toList();
  }

  double _sourceRiskWeight(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('reuters') ||
        normalized.contains('bloomberg') ||
        normalized.contains('financial times') ||
        normalized.contains('華爾街日報')) {
      return 1.18;
    }
    if (normalized.contains('工商時報') ||
        normalized.contains('經濟日報') ||
        normalized.contains('中央社') ||
        normalized.contains('moneydj')) {
      return 1.08;
    }
    if (normalized == '新聞' || normalized.trim().isEmpty) {
      return 0.95;
    }
    return 1.0;
  }

  int _computeAggregateRisk(List<MarketNewsItem> items) {
    if (items.isEmpty) {
      return 50;
    }

    final sum = items.fold<int>(0, (prev, item) => prev + item.riskDelta);
    final avg = sum / items.length;
    final score = 50 + avg.round();
    return score.clamp(0, 100);
  }

  NewsRiskLevel _toRiskLevel(int score) {
    if (score >= 65) {
      return NewsRiskLevel.high;
    }
    if (score >= 45) {
      return NewsRiskLevel.medium;
    }
    return NewsRiskLevel.low;
  }

  String _buildSummary(int score) {
    if (score >= 65) {
      return '新聞風險偏高：先控倉位、避免追價。';
    }
    if (score >= 45) {
      return '新聞風險中等：可交易但需嚴守停損。';
    }
    return '新聞風險偏低：可按策略正常執行。';
  }
}
