/// 策略配置
class StrategyConfig {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic> parameters; // 存储策略参数
  final DateTime createdAt;
  final double? winRate;
  final double? profitFactor;
  final double? maxDrawdown;
  final int? totalTrades;
  final bool isActive; // 是否为当前活跃策略

  StrategyConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.parameters,
    required this.createdAt,
    this.winRate,
    this.profitFactor,
    this.maxDrawdown,
    this.totalTrades,
    this.isActive = false,
  });

  // 快速获取重要参数
  int? getStopLoss() => parameters['stopLoss'] as int?;
  int? getTakeProfit() => parameters['takeProfit'] as int?;
  int? getMinScore() => parameters['minScore'] as int?;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'parameters': parameters,
    'createdAt': createdAt.toIso8601String(),
    'winRate': winRate,
    'profitFactor': profitFactor,
    'maxDrawdown': maxDrawdown,
    'totalTrades': totalTrades,
    'isActive': isActive,
  };

  factory StrategyConfig.fromJson(Map<String, dynamic> json) => StrategyConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    parameters: Map<String, dynamic>.from(json['parameters'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
    winRate: json['winRate'] != null ? (json['winRate'] as num).toDouble() : null,
    profitFactor:
        json['profitFactor'] != null ? (json['profitFactor'] as num).toDouble() : null,
    maxDrawdown:
        json['maxDrawdown'] != null ? (json['maxDrawdown'] as num).toDouble() : null,
    totalTrades: json['totalTrades'] as int?,
    isActive: json['isActive'] as bool? ?? false,
  );

  // 创建副本但改变状态
  StrategyConfig copyWith({
    String? name,
    String? description,
    Map<String, dynamic>? parameters,
    double? winRate,
    double? profitFactor,
    double? maxDrawdown,
    int? totalTrades,
    bool? isActive,
  }) =>
      StrategyConfig(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        parameters: parameters ?? this.parameters,
        createdAt: createdAt,
        winRate: winRate ?? this.winRate,
        profitFactor: profitFactor ?? this.profitFactor,
        maxDrawdown: maxDrawdown ?? this.maxDrawdown,
        totalTrades: totalTrades ?? this.totalTrades,
        isActive: isActive ?? this.isActive,
      );
}

/// 策略对比页面用的数据
class StrategyComparison {
  final List<StrategyConfig> strategies;
  final StrategyConfig? activeStrategy;

  StrategyComparison({
    required this.strategies,
    this.activeStrategy,
  });

  // 按胜率排序
  List<StrategyConfig> sortByWinRate() {
    final sorted = List<StrategyConfig>.from(strategies);
    sorted.sort((a, b) {
      final aWr = a.winRate ?? 0;
      final bWr = b.winRate ?? 0;
      return bWr.compareTo(aWr);
    });
    return sorted;
  }

  // 按利润因子排序
  List<StrategyConfig> sortByProfitFactor() {
    final sorted = List<StrategyConfig>.from(strategies);
    sorted.sort((a, b) {
      final aPf = a.profitFactor ?? 0;
      final bPf = b.profitFactor ?? 0;
      return bPf.compareTo(aPf);
    });
    return sorted;
  }

  // 获取最佳策略
  StrategyConfig? getBestStrategy({required String metric}) {
    if (strategies.isEmpty) return null;
    switch (metric) {
      case 'winRate':
        return sortByWinRate().first;
      case 'profitFactor':
        return sortByProfitFactor().first;
      default:
        return strategies.first;
    }
  }
}
