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
