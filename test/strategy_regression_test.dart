import 'package:flutter_test/flutter_test.dart';
import 'package:stock_checker/strategy_utils.dart';

void main() {
  test('secondary volume ratio should be relaxed only when strategy filter enabled', () {
    expect(
      computeSecondaryVolumeRatio(1.3, strategyFilterEnabled: true),
      closeTo(1.1, 0.0001),
    );
    expect(
      computeSecondaryVolumeRatio(1.3, strategyFilterEnabled: false),
      closeTo(1.3, 0.0001),
    );
  });

  test('forward return should compute correct positive and negative outcomes', () {
    expect(
      computeForwardReturnPercent(entryPrice: 100, latestPrice: 105),
      closeTo(5.0, 0.0001),
    );
    expect(
      computeForwardReturnPercent(entryPrice: 100, latestPrice: 95),
      closeTo(-5.0, 0.0001),
    );
  });

  test('calendar day diff should be stable across intraday time differences', () {
    final from = DateTime(2026, 2, 28, 9, 1);
    final to = DateTime(2026, 3, 3, 8, 59);
    expect(calendarDayDiff(from, to), 3);
  });
}
