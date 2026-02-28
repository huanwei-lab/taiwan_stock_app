import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Intraday poller that fetches a configurable TWSE-like endpoint every
/// [interval] while running. Designed to run in-app (foreground). Background
/// execution every 1 minute is not reliable on mobile OSes; consider a server
/// push for guaranteed 1-minute background updates.
class IntradayService {
  IntradayService({
    this.interval = const Duration(minutes: 5),
    this.endpointBuilder,
    this.onSnapshot,
    this.httpGet,
  });

  /// Polling interval (default 1 minute).
  final Duration interval;

  /// Builds a URI string for a given moment. By default a placeholder is used
  /// and should be replaced with a concrete TWSE intraday endpoint if known.
  final String Function(DateTime now)? endpointBuilder;

  /// Callback invoked with the parsed snapshot (map of code -> row map).
  final void Function(Map<String, Map<String, dynamic>> snapshot)? onSnapshot;

  /// Injected http GET function for easier testing.
  final Future<http.Response> Function(Uri uri)? httpGet;

  Timer? _timer;
  Map<String, Map<String, dynamic>> _lastSnapshot = {};

  /// Start polling. Does an immediate fetch then schedules repeated fetches.
  void start() {
    stop();
    _fetchAndNotify();
    _timer = Timer.periodic(interval, (_) => _fetchAndNotify());
  }

  /// Stop polling.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetchAndNotify() async {
    final now = DateTime.now();
    final uriStr = endpointBuilder?.call(now) ?? _defaultEndpoint(now);
    final uri = Uri.parse(uriStr);
    http.Response resp;
    try {
      resp = await (httpGet?.call(uri) ?? http.get(uri));
    } catch (_) {
      return;
    }
    if (resp.statusCode != 200) return;

    final snapshot = _parseResp(resp.body);
    // compute diffs against last snapshot and attach '_delta' field
    snapshot.forEach((code, row) {
      final prev = _lastSnapshot[code];
      if (prev != null) {
        final prevForeign = _toInt(prev['foreign_net']);
        final currForeign = _toInt(row['foreign_net']);
        row['_delta_foreign'] = currForeign - prevForeign;

        final prevMargin = _toInt(prev['margin_balance']);
        final currMargin = _toInt(row['margin_balance']);
        row['_delta_margin'] = currMargin - prevMargin;
      } else {
        row['_delta_foreign'] = 0;
        row['_delta_margin'] = 0;
      }
    });

    _lastSnapshot = snapshot;
    if (onSnapshot != null) onSnapshot!(snapshot);
  }

  Map<String, Map<String, dynamic>> _parseResp(String body) {
    final out = <String, Map<String, dynamic>>{};
    dynamic raw;
    try {
      raw = jsonDecode(body);
    } catch (_) {
      return out;
    }
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
      int idxMargin = findFieldIndex(fields, ['融資', '餘額']);
      // Fallback to common heuristic indexes when fields are not provided.
      if (fields == null) {
        idxForeignBuy = 13;
        idxForeignSell = 14;
        idxMargin = 19;
      }

      for (final item in raw['data']) {
        if (item is List && item.isNotEmpty) {
          final code = item[0].toString().padLeft(4, '0');
          final foreignBuy = idxForeignBuy >= 0 && idxForeignBuy < item.length ? _parseInt(item[idxForeignBuy]) : 0;
          final foreignSell = idxForeignSell >= 0 && idxForeignSell < item.length ? _parseInt(item[idxForeignSell]) : 0;
          final margin = idxMargin >= 0 && idxMargin < item.length ? _parseInt(item[idxMargin]) : 0;
          out[code] = {
            'code': code,
            'foreign_net': foreignBuy - foreignSell,
            'margin_balance': margin,
          };
        } else if (item is Map && item['code'] != null) {
          final code = item['code'].toString().padLeft(4, '0');
          out[code] = Map<String, dynamic>.from(item);
        }
      }
    }
    return out;
  }

  int _parseInt(dynamic v) {
    if (v == null) return 0;
    return int.tryParse(v.toString().replaceAll(',', '').trim()) ?? 0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  String _defaultEndpoint(DateTime now) {
    final formatted = '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    // TWSE fund-flow endpoint (T86) is commonly used for fund/margin snapshots.
    // Note: TWSE may not provide true per-minute intraday fund-flow data via
    // this endpoint; this URL is a best-effort test URI — replace with the
    // official TWSE intraday endpoint or a commercial realtime API when
    // available.
    return 'https://www.twse.com.tw/fund/T86?response=json&date=$formatted&selectType=ALL';
  }
}
