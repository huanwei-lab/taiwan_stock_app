class HistoricalCandle {
  const HistoricalCandle({
    required this.date,
    required this.close,
    required this.volume,
    required this.tradeValue,
  });

  final DateTime date;
  final double close;
  final int volume;
  final int tradeValue;
}
