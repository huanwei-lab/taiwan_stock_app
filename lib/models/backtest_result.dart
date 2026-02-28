class BacktestTrade {
  const BacktestTrade({
    required this.entryDate,
    required this.exitDate,
    required this.entryPrice,
    required this.exitPrice,
    required this.pnlPercent,
  });

  final DateTime entryDate;
  final DateTime exitDate;
  final double entryPrice;
  final double exitPrice;
  final double pnlPercent;
}

class BacktestResult {
  const BacktestResult({
    required this.stockCode,
    required this.totalTrades,
    required this.winRate,
    required this.averagePnlPercent,
    required this.maxDrawdownPercent,
    required this.totalPnlPercent,
    required this.profitFactor,
    required this.maxConsecutiveLosses,
    required this.trades,
  });

  final String stockCode;
  final int totalTrades;
  final double winRate;
  final double averagePnlPercent;
  final double maxDrawdownPercent;
  final double totalPnlPercent;
  final double profitFactor;
  final int maxConsecutiveLosses;
  final List<BacktestTrade> trades;
}
