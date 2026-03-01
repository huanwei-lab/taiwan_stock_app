import 'package:flutter_test/flutter_test.dart';
import 'package:stock_checker/services/stock_service.dart';
import 'package:stock_checker/strategy_utils.dart';
import 'package:stock_checker/debug/diagnostics.dart';

void main() {
  test('diagnose 3481', () async {
    final svc = StockService();
    final today = DateTime.now();
    final dateStr = '${today.year.toString().padLeft(4, '0')}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    final stocks = await svc.fetchAllStocksWithFundFlow(dateStr);
    const code = '3481';
    final stock = stocks.firstWhere((s) => s.code == code, orElse: () => throw Exception('stock $code not found'));

    // compute score using app defaults
    const volumeReference = 10000000.0; // matches default _latestVolumeReference
    final normalizedTradeValue = normalizedTradeValueForFilter(stock.tradeValue).toDouble();
    final score = computeScore(
      volume: stock.volume.toDouble(),
      volumeReference: volumeReference,
      changePercent: stock.change,
      price: stock.closePrice,
      maxPrice: 100.0, // conservative placeholder; main app uses _maxPriceThreshold
      chipConcentration: stock.chipConcentration,
      normalizedTradeValue: normalizedTradeValue,
      volumeWeight: 40,
      changeWeight: 35,
      priceWeight: 25,
      concentrationWeight: 0,
      tradeValueWeight: 0,
    );

    diagnoseStockPublic(stock, score);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
