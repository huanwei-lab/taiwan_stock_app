import 'package:flutter_test/flutter_test.dart';
import 'package:stock_checker/strategy_utils.dart';
import 'package:stock_checker/models/stock_model.dart';

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

  test('computeScore respects concentration weight', () {
    final base = computeScore(
      volume: 100,
      volumeReference: 100,
      changePercent: 2,
      price: 50,
      maxPrice: 100,
      chipConcentration: 50,
      normalizedTradeValue: 100,
      volumeWeight: 1,
      changeWeight: 1,
      priceWeight: 1,
      concentrationWeight: 0,
      tradeValueWeight: 0,
    );
    final withConcentration = computeScore(
      volume: 100,
      volumeReference: 100,
      changePercent: 2,
      price: 50,
      maxPrice: 100,
      chipConcentration: 50,
      normalizedTradeValue: 100,
      volumeWeight: 1,
      changeWeight: 1,
      priceWeight: 1,
      concentrationWeight: 5,
      tradeValueWeight: 0,
    );
    expect(withConcentration, greaterThan(base));
  });

  test('isMasterTrap flags concentration drop', () {
    expect(
      isMasterTrap(
        prevConcentration: 80,
        currConcentration: 60,
        dropThresholdPercent: 15,
      ),
      isTrue,
    );
    expect(
      isMasterTrap(
        prevConcentration: 80,
        currConcentration: 70,
        dropThresholdPercent: 15,
      ),
      isFalse,
    );
  });

  test('autoSearchWeights chooses non-zero weights', () {
    final stocks = [
      const StockModel(
        code: 'A',
        name: 'A',
        closePrice: 50,
        volume: 1000000,
        tradeValue: 50000000,
        change: 5,
        chipConcentration: 20,
      ),
      const StockModel(
        code: 'B',
        name: 'B',
        closePrice: 80,
        volume: 2000000,
        tradeValue: 80000000,
        change: -2,
        chipConcentration: 5,
      ),
    ];
    final weights = autoSearchWeights(stocks, 1000000, 100);
    expect(weights.length, 5);
    expect(weights.any((w) => w != 0), isTrue);
  });

  test('breadth bias shifts threshold up/down', () {
    int compute(double breadth) {
      var th = 50;
      if (breadth < 0.9) th += 2;
      if (breadth > 1.1) th -= 2;
      return th;
    }
    expect(compute(0.8), greaterThan(compute(1.0)));
    expect(compute(1.2), lessThan(compute(1.0)));
  });

  test('passesFundFlowFilter respects thresholds', () {
    const stock = StockModel(
      code: 'X',
      name: 'X',
      closePrice: 10,
      volume: 1000,
      tradeValue: 10000,
      change: 1,
      chipConcentration: 0,
      foreignNet: 500,
      trustNet: -200,
      dealerNet: 1000,
      marginBalanceDiff: 50,
    );
    expect(
      passesFundFlowFilter(stock,
          enableForeign: true, minForeign: 100, enableDealer: true, minDealer: 500),
      isTrue,
    );
    expect(
      passesFundFlowFilter(stock,
          enableForeign: true, minForeign: 600),
      isFalse,
    );
    expect(
      passesFundFlowFilter(stock,
          enableTrust: true, minTrust: -100),
      isFalse,
    );
    expect(
      passesFundFlowFilter(stock,
          enableMarginDiff: true, minMarginDiff: 100),
      isFalse,
    );
  });
}
