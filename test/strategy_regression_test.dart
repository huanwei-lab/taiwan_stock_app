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

  test('StockModel.fromJson reads chip concentration value', () {
    final json = {
      'Code': '0001',
      'Name': '測試',
      'ClosingPrice': 50.0,
      'TradeVolume': 1000,
      'TradeValue': 50000,
      'Change': 0.5,
      'ChipConcentration': 82.3,
    };
    final stock = StockModel.fromJson(json);
    expect(stock.chipConcentration, closeTo(82.3, 0.0001));
  });
}
