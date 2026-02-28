import 'package:flutter_test/flutter_test.dart';

import 'package:stock_checker/services/fund_flow_scheduler.dart';
import 'package:stock_checker/services/fund_flow_service.dart';
import 'package:stock_checker/services/fund_flow_cache.dart';

class FakeFundFlowService extends FundFlowService {
  final List<Map<String, dynamic>> rows;
  FakeFundFlowService(this.rows);

  @override
  Future<List<Map<String, dynamic>>> fetchEodFundFlow(String date, {int maxBackfillDays = 7}) async {
    return rows;
  }
}

class FakeCache implements FundFlowCache {
  final Map<int, List<Map<String, dynamic>>> store = {};

  @override
  Future<void> saveRows(int dateInt, List<Map<String, dynamic>> rows) async {
    store[dateInt] = rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  @override
  Future<int?> getPreviousMargin(String code, int dateInt) async {
    final keys = store.keys.where((k) => k < dateInt).toList()..sort((a, b) => b - a);
    for (final k in keys) {
      final list = store[k]!;
      for (final r in list) {
        if ((r['code'] ?? '') == code) {
          final v = r['margin_balance'];
          if (v is int) return v;
          return int.tryParse(v.toString());
        }
      }
    }
    return null;
  }

  // The real FundFlowCache has getInstance; test won't use it.
  static Future<FundFlowCache> getInstance() async => throw UnimplementedError();
}

void main() {
  test('runOnceForDate saves rows and computes diffs via provided cache', () async {
    const prevDate = 20260301;

    final prevRows = [
      {'code': '0050', 'margin_balance': 5000},
    ];

    final currRows = [
      {'code': '0050', 'margin_balance': 3000},
      {'code': '2330', 'margin_balance': 1000},
    ];

    final fakeCache = FakeCache();
    await fakeCache.saveRows(prevDate, prevRows);

    final fakeSvc = FakeFundFlowService(currRows);

    var alerts = <String>[];
    final count = await FundFlowScheduler.runOnceForDate(
      '2026-03-02',
      fundService: fakeSvc,
      cache: fakeCache,
      alertMarginDropThreshold: 1000,
      notifyCallback: (t, b) => alerts.add('$t|$b'),
    );

    expect(count, 2);
    // For 0050: prev 5000 -> curr 3000 => diff -2000 -> should alert
    expect(alerts.length, 1);
    expect(alerts.first.contains('0050'), true);
  });
}
