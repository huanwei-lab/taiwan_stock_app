import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/backtest_result.dart';
import '../models/historical_candle.dart';

class BacktestGridItem {
  const BacktestGridItem({
    required this.stopLossPercent,
    required this.takeProfitPercent,
    required this.result,
  });

  final int stopLossPercent;
  final int takeProfitPercent;
  final BacktestResult result;
}

class WalkForwardWindow {
  const WalkForwardWindow({
    required this.windowIndex,
    required this.stopLossPercent,
    required this.takeProfitPercent,
    required this.result,
  });

  final int windowIndex;
  final int stopLossPercent;
  final int takeProfitPercent;
  final BacktestResult result;
}

class WalkForwardResult {
  const WalkForwardResult({
    required this.stockCode,
    required this.windows,
    required this.totalPnlPercent,
    required this.averagePnlPercent,
  });

  final String stockCode;
  final List<WalkForwardWindow> windows;
  final double totalPnlPercent;
  final double averagePnlPercent;
}

class BacktestService {
  Future<BacktestResult> runSimpleBacktest({
    required String stockCode,
    required int months,
    required int minVolume,
    required int minTradeValue,
    required int stopLossPercent,
    required int takeProfitPercent,
    required bool enableTrailingStop,
    required int trailingPullbackPercent,
    required bool enableAdaptiveAtr,
    required int atrTakeProfitMultiplier,
    required int feeBps,
    required int slippageBps,
  }) async {
    final candles = await _fetchHistory(stockCode: stockCode, months: months);
    return _simulateBacktest(
      stockCode: stockCode,
      candles: candles,
      minVolume: minVolume,
      minTradeValue: minTradeValue,
      stopLossPercent: stopLossPercent,
      takeProfitPercent: takeProfitPercent,
      enableTrailingStop: enableTrailingStop,
      trailingPullbackPercent: trailingPullbackPercent,
      enableAdaptiveAtr: enableAdaptiveAtr,
      atrTakeProfitMultiplier: atrTakeProfitMultiplier,
      feeBps: feeBps,
      slippageBps: slippageBps,
    );
  }

  Future<List<BacktestGridItem>> runParameterGrid({
    required String stockCode,
    required int months,
    required int minVolume,
    required int minTradeValue,
    required List<int> stopLossCandidates,
    required List<int> takeProfitCandidates,
    required bool enableTrailingStop,
    required int trailingPullbackPercent,
    required bool enableAdaptiveAtr,
    required int atrTakeProfitMultiplier,
    required int feeBps,
    required int slippageBps,
  }) async {
    final candles = await _fetchHistory(stockCode: stockCode, months: months);

    final normalizedStopLoss = stopLossCandidates.toSet().toList()..sort();
    final normalizedTakeProfit = takeProfitCandidates.toSet().toList()..sort();

    final results = <BacktestGridItem>[];
    for (final stopLoss in normalizedStopLoss) {
      for (final takeProfit in normalizedTakeProfit) {
        final result = _simulateBacktest(
          stockCode: stockCode,
          candles: candles,
          minVolume: minVolume,
          minTradeValue: minTradeValue,
          stopLossPercent: stopLoss,
          takeProfitPercent: takeProfit,
          enableTrailingStop: enableTrailingStop,
          trailingPullbackPercent: trailingPullbackPercent,
          enableAdaptiveAtr: enableAdaptiveAtr,
          atrTakeProfitMultiplier: atrTakeProfitMultiplier,
          feeBps: feeBps,
          slippageBps: slippageBps,
        );
        results.add(
          BacktestGridItem(
            stopLossPercent: stopLoss,
            takeProfitPercent: takeProfit,
            result: result,
          ),
        );
      }
    }

    results.sort((a, b) {
      final scoreA = _gridScore(a.result);
      final scoreB = _gridScore(b.result);
      return scoreB.compareTo(scoreA);
    });

    return results;
  }

  Future<WalkForwardResult> runWalkForwardBacktest({
    required String stockCode,
    required int months,
    required int minVolume,
    required int minTradeValue,
    required List<int> stopLossCandidates,
    required List<int> takeProfitCandidates,
    required bool enableTrailingStop,
    required int trailingPullbackPercent,
    required bool enableAdaptiveAtr,
    required int atrTakeProfitMultiplier,
    required int feeBps,
    required int slippageBps,
    required int trainMonths,
    required int validationMonths,
  }) async {
    final candles = await _fetchHistory(stockCode: stockCode, months: months);
    if (candles.length < 60) {
      throw Exception('歷史資料不足，無法進行 Walk-forward。');
    }

    final trainDays = (trainMonths * 20).clamp(40, 400);
    final validationDays = (validationMonths * 20).clamp(20, 200);
    final normalizedStopLoss = stopLossCandidates.toSet().toList()..sort();
    final normalizedTakeProfit = takeProfitCandidates.toSet().toList()..sort();

    final windows = <WalkForwardWindow>[];
    double aggregateEquity = 1.0;
    var anchor = trainDays;
    var windowIndex = 1;

    while (anchor + validationDays <= candles.length) {
      final train = candles.sublist(anchor - trainDays, anchor);
      final validation = candles.sublist(anchor, anchor + validationDays);

      BacktestResult? bestTrain;
      int bestStopLoss = normalizedStopLoss.first;
      int bestTakeProfit = normalizedTakeProfit.first;

      for (final stopLoss in normalizedStopLoss) {
        for (final takeProfit in normalizedTakeProfit) {
          final trainResult = _simulateBacktest(
            stockCode: stockCode,
            candles: train,
            minVolume: minVolume,
            minTradeValue: minTradeValue,
            stopLossPercent: stopLoss,
            takeProfitPercent: takeProfit,
            enableTrailingStop: enableTrailingStop,
            trailingPullbackPercent: trailingPullbackPercent,
            enableAdaptiveAtr: enableAdaptiveAtr,
            atrTakeProfitMultiplier: atrTakeProfitMultiplier,
            feeBps: feeBps,
            slippageBps: slippageBps,
          );

          if (bestTrain == null || _gridScore(trainResult) > _gridScore(bestTrain)) {
            bestTrain = trainResult;
            bestStopLoss = stopLoss;
            bestTakeProfit = takeProfit;
          }
        }
      }

      final validationResult = _simulateBacktest(
        stockCode: stockCode,
        candles: validation,
        minVolume: minVolume,
        minTradeValue: minTradeValue,
        stopLossPercent: bestStopLoss,
        takeProfitPercent: bestTakeProfit,
        enableTrailingStop: enableTrailingStop,
        trailingPullbackPercent: trailingPullbackPercent,
        enableAdaptiveAtr: enableAdaptiveAtr,
        atrTakeProfitMultiplier: atrTakeProfitMultiplier,
        feeBps: feeBps,
        slippageBps: slippageBps,
      );

      windows.add(
        WalkForwardWindow(
          windowIndex: windowIndex,
          stopLossPercent: bestStopLoss,
          takeProfitPercent: bestTakeProfit,
          result: validationResult,
        ),
      );

      aggregateEquity *= (1 + validationResult.totalPnlPercent / 100);
      anchor += validationDays;
      windowIndex += 1;
    }

    if (windows.isEmpty) {
      throw Exception('Walk-forward 期間不足，請增加回測月數。');
    }

    final totalPnlPercent = (aggregateEquity - 1) * 100;
    final averagePnlPercent = windows
            .map((item) => item.result.totalPnlPercent)
            .fold<double>(0.0, (sum, value) => sum + value) /
        windows.length;

    return WalkForwardResult(
      stockCode: stockCode,
      windows: windows,
      totalPnlPercent: totalPnlPercent,
      averagePnlPercent: averagePnlPercent,
    );
  }

  double _gridScore(BacktestResult result) {
    return result.totalPnlPercent -
        (result.maxDrawdownPercent * 0.5) -
        (result.maxConsecutiveLosses * 2);
  }

  BacktestResult _simulateBacktest({
    required String stockCode,
    required List<HistoricalCandle> candles,
    required int minVolume,
    required int minTradeValue,
    required int stopLossPercent,
    required int takeProfitPercent,
    required bool enableTrailingStop,
    required int trailingPullbackPercent,
    required bool enableAdaptiveAtr,
    required int atrTakeProfitMultiplier,
    required int feeBps,
    required int slippageBps,
  }) {
    if (candles.length < 2) {
      throw Exception('歷史資料不足，無法回測。');
    }

    final trades = <BacktestTrade>[];
    final equityCurve = <double>[1.0];

    bool hasPosition = false;
    double entryPrice = 0;
    DateTime? entryDate;
    double highestSinceEntry = 0;
    bool trailingArmed = false;
    double currentEquity = 1.0;

    for (var index = 1; index < candles.length; index++) {
      final prev = candles[index - 1];
      final curr = candles[index];
      final changePercent = prev.close == 0
          ? 0
          : ((curr.close - prev.close) / prev.close) * 100;

      if (!hasPosition) {
        final passEntry = curr.volume >= minVolume &&
            curr.tradeValue >= minTradeValue &&
            changePercent > 0;

        if (passEntry) {
          hasPosition = true;
          entryPrice = curr.close;
          entryDate = curr.date;
          highestSinceEntry = curr.close;
          trailingArmed = false;
        }
        continue;
      }

      if (curr.close > highestSinceEntry) {
        highestSinceEntry = curr.close;
      }

      final rawPnlPercent = ((curr.close - entryPrice) / entryPrice) * 100;
      final costPercent = (feeBps + slippageBps) / 100.0;
      final pnlPercent = rawPnlPercent - costPercent;
      final adaptiveTakeProfit = enableAdaptiveAtr
          ? _adaptiveTakeProfitThreshold(
              candles: candles,
              index: index,
              baseTakeProfitPercent: takeProfitPercent,
              atrTakeProfitMultiplier: atrTakeProfitMultiplier,
            )
          : takeProfitPercent.toDouble();
      final hitStopLoss = pnlPercent <= -stopLossPercent;
      final hitTakeProfit = !enableTrailingStop && pnlPercent >= adaptiveTakeProfit;

      if (enableTrailingStop && pnlPercent >= adaptiveTakeProfit) {
        trailingArmed = true;
      }

      final trailingPullback = highestSinceEntry == 0
          ? 0.0
          : ((highestSinceEntry - curr.close) / highestSinceEntry) * 100;
      final hitTrailingStop = enableTrailingStop &&
          trailingArmed &&
          trailingPullback >= trailingPullbackPercent;

      if (hitStopLoss || hitTakeProfit || hitTrailingStop) {
        trades.add(
          BacktestTrade(
            entryDate: entryDate!,
            exitDate: curr.date,
            entryPrice: entryPrice,
            exitPrice: curr.close,
            pnlPercent: pnlPercent,
          ),
        );

        currentEquity *= (1 + pnlPercent / 100);
        equityCurve.add(currentEquity);

        hasPosition = false;
        entryPrice = 0;
        entryDate = null;
        highestSinceEntry = 0;
        trailingArmed = false;
      }
    }

    if (hasPosition && entryDate != null) {
      final last = candles.last;
      final rawPnlPercent = ((last.close - entryPrice) / entryPrice) * 100;
      final costPercent = (feeBps + slippageBps) / 100.0;
      final pnlPercent = rawPnlPercent - costPercent;
      trades.add(
        BacktestTrade(
          entryDate: entryDate,
          exitDate: last.date,
          entryPrice: entryPrice,
          exitPrice: last.close,
          pnlPercent: pnlPercent,
        ),
      );
      currentEquity *= (1 + pnlPercent / 100);
      equityCurve.add(currentEquity);
    }

    final totalTrades = trades.length;
    final wins = trades.where((trade) => trade.pnlPercent > 0).length;
    final winRate = totalTrades == 0 ? 0.0 : (wins / totalTrades) * 100;
    final averagePnl = totalTrades == 0
      ? 0.0
        : trades.map((trade) => trade.pnlPercent).reduce((a, b) => a + b) /
            totalTrades;
    final totalPnl = (currentEquity - 1) * 100;

    final grossProfit = trades
        .where((trade) => trade.pnlPercent > 0)
        .fold<double>(0.0, (sum, trade) => sum + trade.pnlPercent);
    final grossLossAbs = trades
        .where((trade) => trade.pnlPercent < 0)
        .fold<double>(0.0, (sum, trade) => sum + trade.pnlPercent.abs());
    final profitFactor = grossLossAbs == 0
        ? (grossProfit > 0 ? 999.0 : 0.0)
        : (grossProfit / grossLossAbs);

    var maxConsecutiveLosses = 0;
    var currentConsecutiveLosses = 0;
    for (final trade in trades) {
      if (trade.pnlPercent < 0) {
        currentConsecutiveLosses += 1;
        if (currentConsecutiveLosses > maxConsecutiveLosses) {
          maxConsecutiveLosses = currentConsecutiveLosses;
        }
      } else {
        currentConsecutiveLosses = 0;
      }
    }

    var peak = equityCurve.first;
    var maxDrawdown = 0.0;
    for (final equity in equityCurve) {
      if (equity > peak) {
        peak = equity;
      }
      final drawdown = ((peak - equity) / peak) * 100;
      if (drawdown > maxDrawdown) {
        maxDrawdown = drawdown;
      }
    }

    return BacktestResult(
      stockCode: stockCode,
      totalTrades: totalTrades,
      winRate: winRate,
      averagePnlPercent: averagePnl,
      maxDrawdownPercent: maxDrawdown,
      totalPnlPercent: totalPnl,
      profitFactor: profitFactor,
      maxConsecutiveLosses: maxConsecutiveLosses,
      trades: trades,
    );
  }

  Future<List<HistoricalCandle>> _fetchHistory({
    required String stockCode,
    required int months,
  }) async {
    final now = DateTime.now();
    final candles = <HistoricalCandle>[];

    for (var i = months - 1; i >= 0; i--) {
      final target = DateTime(now.year, now.month - i, 1);
      final dateText =
          '${target.year.toString().padLeft(4, '0')}${target.month.toString().padLeft(2, '0')}01';

      final uri = Uri.parse(
        'https://www.twse.com.tw/rwd/zh/afterTrading/STOCK_DAY?date=$dateText&stockNo=$stockCode&response=json',
      );

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        continue;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        continue;
      }

      final data = decoded['data'];
      if (data is! List) {
        continue;
      }

      for (final row in data) {
        if (row is! List || row.length < 7) {
          continue;
        }

        final date = _parseTwDate(row[0]?.toString() ?? '');
        final volume = _parseInt(row[1]);
        final tradeValue = _parseInt(row[2]);
        final close = _parseDouble(row[6]);

        if (date == null || close == null) {
          continue;
        }

        candles.add(
          HistoricalCandle(
            date: date,
            close: close,
            volume: volume ?? 0,
            tradeValue: tradeValue ?? 0,
          ),
        );
      }
    }

    candles.sort((a, b) => a.date.compareTo(b.date));
    return candles;
  }

  DateTime? _parseTwDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) {
      return null;
    }

    final twYear = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (twYear == null || month == null || day == null) {
      return null;
    }

    final year = twYear + 1911;
    return DateTime(year, month, day);
  }

  int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    final cleaned = value.toString().replaceAll(',', '').trim();
    return int.tryParse(cleaned);
  }

  double? _parseDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    final cleaned = value.toString().replaceAll(',', '').trim();
    return double.tryParse(cleaned);
  }

  double _adaptiveTakeProfitThreshold({
    required List<HistoricalCandle> candles,
    required int index,
    required int baseTakeProfitPercent,
    required int atrTakeProfitMultiplier,
  }) {
    final atrProxyPercent = _rollingAtrProxyPercent(
      candles: candles,
      endIndex: index,
      period: 14,
    );
    final adaptive = (atrProxyPercent * atrTakeProfitMultiplier).clamp(4.0, 25.0);
    return adaptive > baseTakeProfitPercent ? adaptive : baseTakeProfitPercent.toDouble();
  }

  double _rollingAtrProxyPercent({
    required List<HistoricalCandle> candles,
    required int endIndex,
    required int period,
  }) {
    if (candles.length < 2 || endIndex <= 0) {
      return 0.0;
    }
    final start = (endIndex - period).clamp(1, endIndex);
    var count = 0;
    var sum = 0.0;
    for (var i = start; i <= endIndex; i++) {
      final prev = candles[i - 1];
      final curr = candles[i];
      if (prev.close <= 0) {
        continue;
      }
      final changePercent = ((curr.close - prev.close).abs() / prev.close) * 100;
      sum += changePercent;
      count += 1;
    }
    if (count == 0) {
      return 0.0;
    }
    return sum / count;
  }
}
