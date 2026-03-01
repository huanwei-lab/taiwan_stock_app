import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/portfolio.dart';

/// 持倉管理服務
class PortfolioService {
  static const String _positionsKey = 'portfolio.positions';
  static const String _tradesKey = 'portfolio.trades';

  final SharedPreferences _prefs;

  PortfolioService(this._prefs);

  /// 獲取所有持倉
  Future<List<PortfolioPosition>> getPositions() async {
    final json = _prefs.getString(_positionsKey);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list
          .map((item) => PortfolioPosition.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[Portfolio] Error loading positions: $e');
      return [];
    }
  }

  /// 添加持倉
  Future<void> addPosition(PortfolioPosition position) async {
    final positions = await getPositions();
    positions.add(position);
    await _savePositions(positions);
  }

  /// 更新持倉
  Future<void> updatePosition(
    String code,
    PortfolioPosition updated,
  ) async {
    final positions = await getPositions();
    final index = positions.indexWhere((p) => p.code == code);
    if (index != -1) {
      positions[index] = updated;
      await _savePositions(positions);
    }
  }

  /// 刪除持倉
  Future<void> removePosition(String code) async {
    final positions = await getPositions();
    positions.removeWhere((p) => p.code == code);
    await _savePositions(positions);
  }

  /// 獲取單個持倉
  Future<PortfolioPosition?> getPosition(String code) async {
    final positions = await getPositions();
    try {
      return positions.firstWhere((p) => p.code == code);
    } catch (e) {
      return null;
    }
  }

  /// 保存持倉
  Future<void> _savePositions(List<PortfolioPosition> positions) async {
    final json = jsonEncode(positions.map((p) => p.toJson()).toList());
    await _prefs.setString(_positionsKey, json);
  }

  /// 獲取所有交易記錄
  Future<List<TradeRecord>> getTrades() async {
    final json = _prefs.getString(_tradesKey);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list
          .map((item) => TradeRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[Portfolio] Error loading trades: $e');
      return [];
    }
  }

  /// 添加交易記錄
  Future<void> addTrade(TradeRecord trade) async {
    final trades = await getTrades();
    trades.add(trade);
    await _saveTrades(trades);
  }

  /// 獲取特定股票的交易記錄
  Future<List<TradeRecord>> getTradesByCode(String code) async {
    final trades = await getTrades();
    return trades.where((t) => t.code == code).toList();
  }

  /// 保存交易記錄
  Future<void> _saveTrades(List<TradeRecord> trades) async {
    final json = jsonEncode(trades.map((t) => t.toJson()).toList());
    await _prefs.setString(_tradesKey, json);
  }

  /// 導出所有持倉和交易為 JSON
  Future<String> exportPortfolioData() async {
    final positions = await getPositions();
    final trades = await getTrades();

    final data = {
      'positions': positions.map((p) => p.toJson()).toList(),
      'trades': trades.map((t) => t.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };

    return jsonEncode(data);
  }

  /// 導入持倉數據
  Future<void> importPortfolioData(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      final positions =
          (data['positions'] as List).cast<Map<String, dynamic>>();
      final trades = (data['trades'] as List).cast<Map<String, dynamic>>();

      final positionsList =
          positions.map((p) => PortfolioPosition.fromJson(p)).toList();
      final tradesList = trades.map((t) => TradeRecord.fromJson(t)).toList();

      await _savePositions(positionsList);
      await _saveTrades(tradesList);
    } catch (e) {
      print('[Portfolio] Error importing data: $e');
      rethrow;
    }
  }

  /// 清除所有數據
  Future<void> clearAll() async {
    await _prefs.remove(_positionsKey);
    await _prefs.remove(_tradesKey);
  }
}
