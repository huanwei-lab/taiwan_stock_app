/// 持倉記錄
class PortfolioPosition {
  final String code;
  final String name;
  final int shares;
  final double entryPrice;
  final DateTime entryDate;
  final double? targetPrice;
  final double? stopLossPrice;
  final String? strategyName;
  final String? notes;
  final bool enableNotification;
  final bool targetNotificationSent;
  final bool stopLossNotificationSent;
  final DateTime? lastNotificationCheckAt;

  PortfolioPosition({
    required this.code,
    required this.name,
    required this.shares,
    required this.entryPrice,
    required this.entryDate,
    this.targetPrice,
    this.stopLossPrice,
    this.strategyName,
    this.notes,
    this.enableNotification = true,
    this.targetNotificationSent = false,
    this.stopLossNotificationSent = false,
    this.lastNotificationCheckAt,
  });

  // 當前損益計算（用於表示，需要傳入當前價格）
  double calculatePnl(double currentPrice) {
    return (currentPrice - entryPrice) / entryPrice * 100;
  }

  // 當前市值
  double calculateMarketValue(double currentPrice) {
    return currentPrice * shares;
  }

  // 複製並更新通知狀態
  PortfolioPosition updateNotificationState({
    bool? enableNotification,
    bool? targetNotificationSent,
    bool? stopLossNotificationSent,
    DateTime? lastNotificationCheckAt,
  }) {
    return PortfolioPosition(
      code: code,
      name: name,
      shares: shares,
      entryPrice: entryPrice,
      entryDate: entryDate,
      targetPrice: targetPrice,
      stopLossPrice: stopLossPrice,
      strategyName: strategyName,
      notes: notes,
      enableNotification: enableNotification ?? this.enableNotification,
      targetNotificationSent: targetNotificationSent ?? this.targetNotificationSent,
      stopLossNotificationSent: stopLossNotificationSent ?? this.stopLossNotificationSent,
      lastNotificationCheckAt: lastNotificationCheckAt ?? this.lastNotificationCheckAt,
    );
  }

  // JSON 序列化
  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'shares': shares,
    'entryPrice': entryPrice,
    'entryDate': entryDate.toIso8601String(),
    'targetPrice': targetPrice,
    'stopLossPrice': stopLossPrice,
    'strategyName': strategyName,
    'notes': notes,
    'enableNotification': enableNotification,
    'targetNotificationSent': targetNotificationSent,
    'stopLossNotificationSent': stopLossNotificationSent,
    'lastNotificationCheckAt': lastNotificationCheckAt?.toIso8601String(),
  };

  factory PortfolioPosition.fromJson(Map<String, dynamic> json) =>
      PortfolioPosition(
        code: json['code'] as String,
        name: json['name'] as String,
        shares: json['shares'] as int,
        entryPrice: (json['entryPrice'] as num).toDouble(),
        entryDate: DateTime.parse(json['entryDate'] as String),
        targetPrice: json['targetPrice'] != null
            ? (json['targetPrice'] as num).toDouble()
            : null,
        stopLossPrice: json['stopLossPrice'] != null
            ? (json['stopLossPrice'] as num).toDouble()
            : null,
        strategyName: json['strategyName'] as String?,
        notes: json['notes'] as String?,
        enableNotification: json['enableNotification'] as bool? ?? true,
        targetNotificationSent: json['targetNotificationSent'] as bool? ?? false,
        stopLossNotificationSent: json['stopLossNotificationSent'] as bool? ?? false,
        lastNotificationCheckAt: json['lastNotificationCheckAt'] != null
            ? DateTime.parse(json['lastNotificationCheckAt'] as String)
            : null,
      );
}

/// 交易記錄
class TradeRecord {
  final String id;
  final String code;
  final String name;
  final String type; // 'buy' 或 'sell'
  final int shares;
  final double price;
  final DateTime date;
  final double? pnlPercent;
  final String? reason;

  TradeRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.shares,
    required this.price,
    required this.date,
    this.pnlPercent,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'type': type,
    'shares': shares,
    'price': price,
    'date': date.toIso8601String(),
    'pnlPercent': pnlPercent,
    'reason': reason,
  };

  factory TradeRecord.fromJson(Map<String, dynamic> json) => TradeRecord(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    shares: json['shares'] as int,
    price: (json['price'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
    pnlPercent:
        json['pnlPercent'] != null ? (json['pnlPercent'] as num).toDouble() : null,
    reason: json['reason'] as String?,
  );
}
