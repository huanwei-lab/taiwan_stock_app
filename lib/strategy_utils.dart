import 'package:stock_checker/models/stock_model.dart';


double computeSecondaryVolumeRatio(
  double requiredRatio, {
  required bool strategyFilterEnabled,
}) {
  if (!strategyFilterEnabled) {
    return requiredRatio;
  }
  return (requiredRatio - 0.2).clamp(1.0, requiredRatio);
}

double? computeForwardReturnPercent({
  required double entryPrice,
  required double latestPrice,
}) {
  if (entryPrice <= 0 || latestPrice <= 0) {
    return null;
  }
  return ((latestPrice - entryPrice) / entryPrice) * 100;
}

int calendarDayDiff(DateTime from, DateTime to) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

/// normalize trade value according to trading session progress
int normalizedTradeValueForFilter(int tradeValue, {DateTime? now}) {
  DateTime t = now ?? DateTime.now();
  bool isTrading(DateTime dt) {
    final mins = dt.hour * 60 + dt.minute;
    return mins >= 9 * 60 && mins < 13 * 60 + 30;
  }
  double progress(DateTime dt) {
    final mins = dt.hour * 60 + dt.minute;
    const start = 9 * 60;
    const total = (4 * 60) + 30;
    final elapsed = mins - start;
    final rat = total <= 0 ? 1.0 : (elapsed / total);
    return rat.clamp(0.2, 1.0);
  }
  if (!isTrading(t)) return tradeValue;
  final prog = progress(t);
  final est = (tradeValue / prog).round();
  final cap = tradeValue * 5;
  return est > cap ? cap : est;
}

/// generic score calculation used by StockListPage
int computeScore({
  required double volume,
  required double volumeReference,
  required double changePercent,
  required double price,
  required double maxPrice,
  required double chipConcentration,
  required double normalizedTradeValue,
  required int volumeWeight,
  required int changeWeight,
  required int priceWeight,
  required int concentrationWeight,
  required int tradeValueWeight,
}) {
  final volumeComponent = ((volume /
              (volumeReference <= 0 ? 1 : volumeReference))
          .clamp(0.0, 2.0) /
      2) *
      100;
  final changeComponent = changePercent <= 0
      ? 0
      : (changePercent / 7.0).clamp(0.0, 1.0) * 100;
  final priceComponent =
      ((maxPrice - price) / maxPrice).clamp(0.0, 1.0) * 100;
  final concentrationComponent = chipConcentration.clamp(0.0, 100.0);
  final tradeValueComponent =
      (normalizedTradeValue /
              (normalizedTradeValue > 0 ? normalizedTradeValue : 1))
          .clamp(0.0, 2.0) *
      50;

  final totalWeight = volumeWeight +
      changeWeight +
      priceWeight +
      concentrationWeight +
      tradeValueWeight;
  if (totalWeight == 0) return 0;
  final weightedScore = (volumeComponent * volumeWeight) +
      (changeComponent * changeWeight) +
      (priceComponent * priceWeight) +
      (concentrationComponent * concentrationWeight) +
      (tradeValueComponent * tradeValueWeight);
  return (weightedScore / totalWeight).round();
}

/// return best weight tuple [vw,cw,pw,con,tw] optimizing score*change metric
List<int> autoSearchWeights(
  List<StockModel> stocks,
  double volumeReference,
  double maxPrice,
) {
  double bestMetric = double.negativeInfinity;
  List<int> best = [0, 0, 0, 0, 0];
  if (stocks.isEmpty) return best;

  for (final v in [0, 25, 50, 75, 100]) {
    for (final c in [0, 25, 50, 75, 100]) {
      for (final p in [0, 25, 50, 75, 100]) {
        for (final con in [0, 25, 50, 75, 100]) {
          for (final tv in [0, 25, 50, 75, 100]) {
            double metric = 0;
            for (final stock in stocks) {
              final sc = computeScore(
                volume: stock.volume.toDouble(),
                volumeReference: volumeReference,
                changePercent: stock.change,
                price: stock.closePrice,
                maxPrice: maxPrice,
                chipConcentration: stock.chipConcentration,
                normalizedTradeValue:
                    normalizedTradeValueForFilter(stock.tradeValue)
                        .toDouble(),
                volumeWeight: v,
                changeWeight: c,
                priceWeight: p,
                concentrationWeight: con,
                tradeValueWeight: tv,
              );
              metric += sc * stock.change;
            }
            if (metric > bestMetric) {
              bestMetric = metric;
              best = [v, c, p, con, tv];
            }
          }
        }
      }
    }
  }
  return best;
}

bool isMasterTrap({
  required double prevConcentration,
  required double currConcentration,
  required double dropThresholdPercent,
}) {
  return (prevConcentration - currConcentration) >= dropThresholdPercent;
}

/// Returns true if [stock] satisfies the optional fund-flow and margin
/// criteria.  All parameters default to disabled/zero so callers can simply
/// specify the ones they care about.
bool passesFundFlowFilter(
  StockModel stock, {
  bool enableForeign = false,
  int minForeign = 0,
  bool enableTrust = false,
  int minTrust = 0,
  bool enableDealer = false,
  int minDealer = 0,
  bool enableMarginDiff = false,
  int minMarginDiff = 0,
}) {
  if (enableForeign && stock.foreignNet < minForeign) return false;
  if (enableTrust && stock.trustNet < minTrust) return false;
  if (enableDealer && stock.dealerNet < minDealer) return false;
  if (enableMarginDiff && stock.marginBalanceDiff < minMarginDiff) return false;
  return true;
}
