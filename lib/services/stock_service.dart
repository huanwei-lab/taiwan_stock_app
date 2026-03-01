import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/stock_model.dart';
import 'fund_flow_service.dart';
import 'fund_flow_cache.dart';

class StockService {
  // NOTE: the upstream API should include a field named `ChipConcentration` or
  // equivalent in its JSON response if you want the app's chip concentration
  // feature to work.  Otherwise StockModel.chipConcentration will default to 0
  // and the filter will have no effect.
  static const String _twseDailyCloseApi =
      'https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL';

  Future<List<StockModel>> fetchAllStocks() async {
    try {
      final response = await _fetchWithFallback();
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        throw Exception('Unexpected API response format: expected a JSON list.');
      }

      final stocks = decoded
          .whereType<Map>()
          .map((item) => StockModel.fromJson(item.cast<String, dynamic>()))
          .where((stock) => stock.code.isNotEmpty && stock.name.isNotEmpty)
          .toList();

      return stocks;
    } catch (error) {
      throw Exception('Failed to fetch stock data: $error');
    }
  }

  /// Fetches the main stock list and attempts to augment each `StockModel`
  /// with end-of-day fund flow / margin information for the given date
  /// (format: YYYYMMDD or YYYY-MM-DD depending on the upstream API).
  Future<List<StockModel>> fetchAllStocksWithFundFlow(String date) async {
    final stocks = await fetchAllStocks();
    const fundSvc = FundFlowService();
    final rows = await fundSvc.fetchEodFundFlow(date);

    // index rows by code for quick lookup
    final map = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final code = (r['code'] ?? '').toString().padLeft(4, '0');
      if (code.isNotEmpty) map[code] = r;
    }

    // compute margin diffs using the cache (if available)
    try {
      final cache = await FundFlowCache.getInstance();
      final dateInt = int.tryParse(date.replaceAll('-', '')) ?? 0;
      for (final entry in map.entries) {
        final code = entry.key;
        final row = entry.value;
        final currMargin = int.tryParse(row['margin_balance']?.toString() ?? '0') ?? 0;
        final prev = await cache.getPreviousMargin(code, dateInt);
        if (prev != null) {
          row['margin_balance_diff'] = currMargin - prev;
        } else {
          row['margin_balance_diff'] = 0;
        }
      }
    } catch (_) {
      // caching not available — leave margin diff absent (defaults applied later)
    }

    final merged = <StockModel>[];
    // Format date to YYYY-MM-DD for display
    final displayDate = date.contains('-') ? date : '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}';
    
    for (final s in stocks) {
      final r = map[s.code];
      if (r == null) {
        merged.add(s);
      } else {
        final applied = fundSvc.applyRowToModel(
          s,
          r,
          fundFlowDate: displayDate,
          isCachedFundFlow: r['_isCached'] == true, // Check if this row was from cache
        );
        merged.add(applied);
      }
    }

    return merged;
  }

  Future<http.Response> _fetchWithFallback() async {
    final uris = <Uri>[Uri.parse(_twseDailyCloseApi)];

    if (kIsWeb) {
      uris.add(
        Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(_twseDailyCloseApi)}'),
      );
      uris.add(
        Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent(_twseDailyCloseApi)}'),
      );
    }

    Object? lastError;
    for (final uri in uris) {
      try {
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          return response;
        }
        lastError = 'HTTP ${response.statusCode} from $uri';
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception(lastError ?? 'Unknown network error when fetching TWSE data.');
  }
}
