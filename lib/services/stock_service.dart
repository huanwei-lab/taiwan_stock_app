import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/stock_model.dart';

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
