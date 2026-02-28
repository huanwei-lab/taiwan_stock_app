import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stock_checker/services/intraday_service.dart';

// Use real http.Response via constructor for simplicity in tests.

void main() {
  test('intraday parses and computes deltas', () async {
    // `now` not used in this test - removed to satisfy analyzer.
    final data1 = {
      'data': [
        ['0050', 'ETF', '...', '...', '0', '0', '0', '0', '0', '0', '0', '0', '0', '1000', '200', '...', '...']
      ]
    };
    final data2 = {
      'data': [
        ['0050', 'ETF', '...', '...', '0', '0', '0', '0', '0', '0', '0', '0', '0', '1200', '150', '...', '...']
      ]
    };

    final responses = [
      http.Response(jsonEncode(data1), 200),
      http.Response(jsonEncode(data2), 200),
    ];

    var idx = 0;
    final snapshots = <Map<String, Map<String, dynamic>>>[];
    final svc = IntradayService(
      interval: const Duration(milliseconds: 10),
      endpointBuilder: (_) => 'https://example.test',
      httpGet: (uri) async => responses[idx++],
      onSnapshot: (s) => snapshots.add(s),
    );

    svc.start();
    // allow two ticks
    await Future.delayed(const Duration(milliseconds: 50));
    svc.stop();

    expect(snapshots.length >= 2, true);
    final first = snapshots[0]['0050']!;
    final second = snapshots[1]['0050']!;
    expect(first['foreign_net'], 1000 - 200);
    expect(second['foreign_net'], 1200 - 150);
    expect(second['_delta_foreign'], (1200 - 150) - (1000 - 200));
  });
}
