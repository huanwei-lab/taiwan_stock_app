import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/strategy_config.dart';

/// 多策略管理服務
class StrategyService {
  static const String _strategiesKey = 'strategies.configs';
  static const String _activeStrategyKey = 'strategies.active';

  final SharedPreferences _prefs;

  StrategyService(this._prefs);

  /// 獲取所有策略
  Future<List<StrategyConfig>> getStrategies() async {
    final json = _prefs.getString(_strategiesKey);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list
          .map((item) => StrategyConfig.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[Strategy] Error loading strategies: $e');
      return [];
    }
  }

  /// 獲取當前活跃策略
  Future<StrategyConfig?> getActiveStrategy() async {
    final strategies = await getStrategies();
    try {
      return strategies.firstWhere((s) => s.isActive);
    } catch (e) {
      return null;
    }
  }

  /// 創建新策略
  Future<StrategyConfig> createStrategy({
    required String name,
    required String description,
    required Map<String, dynamic> parameters,
  }) async {
    final strategy = StrategyConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      parameters: parameters,
      createdAt: DateTime.now(),
    );

    final strategies = await getStrategies();
    strategies.add(strategy);
    await _saveStrategies(strategies);

    return strategy;
  }

  /// 更新策略
  Future<void> updateStrategy(StrategyConfig strategy) async {
    final strategies = await getStrategies();
    final index = strategies.indexWhere((s) => s.id == strategy.id);
    if (index != -1) {
      strategies[index] = strategy;
      await _saveStrategies(strategies);
    }
  }

  /// 設置活跃策略
  Future<void> setActiveStrategy(String strategyId) async {
    final strategies = await getStrategies();
    for (var strategy in strategies) {
      if (strategy.id == strategyId) {
        await updateStrategy(strategy.copyWith(isActive: true));
      } else if (strategy.isActive) {
        await updateStrategy(strategy.copyWith(isActive: false));
      }
    }
  }

  /// 刪除策略
  Future<void> deleteStrategy(String strategyId) async {
    final strategies = await getStrategies();
    strategies.removeWhere((s) => s.id == strategyId);
    await _saveStrategies(strategies);
  }

  /// 複製策略
  Future<StrategyConfig> cloneStrategy(String strategyId) async {
    final strategies = await getStrategies();
    final original = strategies.firstWhere((s) => s.id == strategyId);

    final clone = StrategyConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${original.name} (副本)',
      description: original.description,
      parameters: Map<String, dynamic>.from(original.parameters),
      createdAt: DateTime.now(),
    );

    strategies.add(clone);
    await _saveStrategies(strategies);

    return clone;
  }

  /// 更新策略的回測結果
  Future<void> updateStrategyBacktestResult({
    required String strategyId,
    required double winRate,
    required double profitFactor,
    required double maxDrawdown,
    required int totalTrades,
  }) async {
    final strategies = await getStrategies();
    final index = strategies.indexWhere((s) => s.id == strategyId);
    if (index != -1) {
      strategies[index] = strategies[index].copyWith(
        winRate: winRate,
        profitFactor: profitFactor,
        maxDrawdown: maxDrawdown,
        totalTrades: totalTrades,
      );
      await _saveStrategies(strategies);
    }
  }

  /// 獲取策略對比數據
  Future<StrategyComparison> getComparison() async {
    final strategies = await getStrategies();
    final active = await getActiveStrategy();

    return StrategyComparison(
      strategies: strategies,
      activeStrategy: active,
    );
  }

  /// 保存所有策略
  Future<void> _saveStrategies(List<StrategyConfig> strategies) async {
    final json = jsonEncode(strategies.map((s) => s.toJson()).toList());
    await _prefs.setString(_strategiesKey, json);
  }

  /// 導出策略
  Future<String> exportStrategies() async {
    final strategies = await getStrategies();
    return jsonEncode(strategies.map((s) => s.toJson()).toList());
  }

  /// 導入策略
  Future<void> importStrategies(String jsonData) async {
    try {
      final list = jsonDecode(jsonData) as List;
      final strategies =
          list.map((item) => StrategyConfig.fromJson(item as Map<String, dynamic>)).toList();

      final existing = await getStrategies();
      existing.addAll(strategies);
      await _saveStrategies(existing);
    } catch (e) {
      print('[Strategy] Error importing strategies: $e');
      rethrow;
    }
  }

  /// 清除所有策略
  Future<void> clearAll() async {
    await _prefs.remove(_strategiesKey);
    await _prefs.remove(_activeStrategyKey);
  }
}
