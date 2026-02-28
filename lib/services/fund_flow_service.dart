import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock_model.dart';
import 'fund_flow_cache.dart';

/// Lightweight service to fetch TWSE/TPEX end-of-day fund flow and margin
/// data and map rows to a simplified structure that can be applied to
/// `StockModel` instances.
class FundFlowService {
  const FundFlowService();

  /// Fetches a TWSE-like JSON for the given date (YYYY-MM-DD).
  ///
  /// NOTE: The exact endpoint varies; caller should replace the placeholder
  /// URI below with the concrete one from TWSE/TPEX or a proxy service.
  /// Fetches EOD fund flow/margin rows for [date]. If no usable data is
  /// returned for [date], this will automatically backfill by trying prior
  /// calendar days up to [maxBackfillDays]. The input [date] may be either
  /// `YYYY-MM-DD` or `YYYYMMDD`.
  Future<List<Map<String, dynamic>>> fetchEodFundFlow(String date, {int maxBackfillDays = 7}) async {
    DateTime parseDate(String s) {
      final clean = s.replaceAll('-', '').trim();
      if (clean.length != 8) throw const FormatException('Invalid date format');
      final y = int.parse(clean.substring(0, 4));
      final m = int.parse(clean.substring(4, 6));
      final d = int.parse(clean.substring(6, 8));
      return DateTime(y, m, d);
    }

    DateTime start;
    try {
      start = parseDate(date);
    } catch (_) {
      // If parsing fails, fallback to today.
      start = DateTime.now();
    }

    List<Map<String, dynamic>> tryParseResponse(String body) {
      final rows = <Map<String, dynamic>>[];
      dynamic raw;
      try {
        raw = jsonDecode(body);
      } catch (_) {
        return rows;
      }

      int parseIntSafe(dynamic v) {
        if (v == null) return 0;
        return int.tryParse(v.toString().replaceAll(',', '').trim()) ?? 0;
      }

      try {
        if (raw is Map && raw['data'] is List) {
          final fields = raw['fields'] is List ? List<String>.from(raw['fields'].map((e) => e.toString())) : null;

          int findFieldIndex(List<String>? flds, List<String> keywords) {
            if (flds == null) return -1;
            for (var i = 0; i < flds.length; i++) {
              final low = flds[i].toLowerCase();
              var matched = true;
              for (final kw in keywords) {
                if (!low.contains(kw)) {
                  matched = false;
                  break;
                }
              }
              if (matched) return i;
            }
            return -1;
          }

          int idxForeignBuy = findFieldIndex(fields, ['外資', '買']);
          int idxForeignSell = findFieldIndex(fields, ['外資', '賣']);
          int idxTrustBuy = findFieldIndex(fields, ['投信', '買']);
          int idxTrustSell = findFieldIndex(fields, ['投信', '賣']);
          int idxDealerBuy = findFieldIndex(fields, ['自營', '買']);
          int idxDealerSell = findFieldIndex(fields, ['自營', '賣']);
          int idxMargin = findFieldIndex(fields, ['融資', '餘額']);
          // Fallback to legacy heuristic indexes when 'fields' not present.
          if (fields == null) {
            idxForeignBuy = 13;
            idxForeignSell = 14;
            idxTrustBuy = 15;
            idxTrustSell = 16;
            idxDealerBuy = 17;
            idxDealerSell = 18;
            idxMargin = 19;
          }

          for (final item in raw['data']) {
            if (item is List && item.isNotEmpty) {
              final code = item[0].toString().padLeft(4, '0');
              final foreignBuy = idxForeignBuy >= 0 && idxForeignBuy < item.length ? parseIntSafe(item[idxForeignBuy]) : 0;
              final foreignSell = idxForeignSell >= 0 && idxForeignSell < item.length ? parseIntSafe(item[idxForeignSell]) : 0;
              final trustBuy = idxTrustBuy >= 0 && idxTrustBuy < item.length ? parseIntSafe(item[idxTrustBuy]) : 0;
              final trustSell = idxTrustSell >= 0 && idxTrustSell < item.length ? parseIntSafe(item[idxTrustSell]) : 0;
              final dealerBuy = idxDealerBuy >= 0 && idxDealerBuy < item.length ? parseIntSafe(item[idxDealerBuy]) : 0;
              final dealerSell = idxDealerSell >= 0 && idxDealerSell < item.length ? parseIntSafe(item[idxDealerSell]) : 0;
              final marginBal = idxMargin >= 0 && idxMargin < item.length ? parseIntSafe(item[idxMargin]) : 0;

              final map = <String, dynamic>{
                'code': code,
                'foreign_net': foreignBuy - foreignSell,
                'trust_net': trustBuy - trustSell,
                'dealer_net': dealerBuy - dealerSell,
                'margin_balance': marginBal,
              };
              rows.add(map);
            } else if (item is Map) {
              rows.add(Map<String, dynamic>.from(item));
            }
          }
        }
      } catch (_) {
        // ignore and return what we've parsed so far
      }
      return rows;
    }

    for (var offset = 0; offset <= maxBackfillDays; offset++) {
      final tryDate = start.subtract(Duration(days: offset));
      final formatted = '${tryDate.year.toString().padLeft(4, '0')}${tryDate.month.toString().padLeft(2, '0')}${tryDate.day.toString().padLeft(2, '0')}';

      // NOTE: Replace this URI with the chosen TWSE/TPEX endpoint when
      // committing to a specific source. We keep the call generic but include
      // `date` in YYYYMMDD which is commonly accepted by TWSE endpoints.
      final uri = Uri.parse('https://www.twse.com.tw/fund/T86?response=json&date=$formatted&selectType=ALL');

      http.Response resp;
      try {
        resp = await http.get(uri);
      } catch (_) {
        // network error — try previous day
        continue;
      }

      if (resp.statusCode != 200) {
        continue;
      }

      final rows = tryParseResponse(resp.body);
      if (rows.isNotEmpty) {
        // store into cache for later diff computations
        try {
          final cache = await FundFlowCache.getInstance();
          final dateInt = int.parse(formatted);
          await cache.saveRows(dateInt, rows);
        } catch (_) {
          // non-fatal: caching failure shouldn't break fetch
        }
        return rows;
      }
      // otherwise continue to previous day
    }

    // no data found within backfill window
    return <Map<String, dynamic>>[];
  }

  /// Applies a parsed row map onto a `StockModel` by returning a new
  /// `StockModel` instance that copies existing fields and fills in fund
  /// flow/margin fields when available. If the input map lacks numeric
  /// values, zero is used.
  StockModel applyRowToModel(StockModel base, Map<String, dynamic> row) {
    int toIntSafe(dynamic v) {
      if (v == null) return 0;
      return int.tryParse(v.toString().replaceAll(',', '').trim()) ?? 0;
    }

    final foreignNet = toIntSafe(row['foreign_net']);
    final trustNet = toIntSafe(row['trust_net']);
    final dealerNet = toIntSafe(row['dealer_net']);

    final marginDiff = toIntSafe(row['margin_balance_diff'] ?? row['margin_balance_diff'] ?? 0);

    return StockModel(
      code: base.code,
      name: base.name,
      closePrice: base.closePrice,
      volume: base.volume,
      tradeValue: base.tradeValue,
      change: base.change,
      chipConcentration: base.chipConcentration,
      foreignNet: foreignNet,
      trustNet: trustNet,
      dealerNet: dealerNet,
      marginBalanceDiff: marginDiff,
    );
  }
}
