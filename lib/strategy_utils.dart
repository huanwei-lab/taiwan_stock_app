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

bool isMasterTrap({
  required double prevConcentration,
  required double currConcentration,
  required double dropThresholdPercent,
}) {
  return (prevConcentration - currConcentration) >= dropThresholdPercent;
}
