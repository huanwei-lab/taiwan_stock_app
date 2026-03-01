import 'package:shared_preferences/shared_preferences.dart';
import '../models/portfolio.dart';
import 'notification_service.dart';
import 'portfolio_service.dart';

/// 通知規則服務 - 監控持倉價格並發送通知
class NotificationRuleService {
  final SharedPreferences _prefs;
  final PortfolioService portfolioService;

  static const String _notificationHistoryKey =
      'notification.history.rules';

  NotificationRuleService(
    this._prefs, {
    required this.portfolioService,
  });

  /// 檢查所有持倉並發送必要的通知
  /// 返回發送的通知數量
  Future<int> checkAndNotifyPositions(
    Map<String, double> currentPrices,
  ) async {
    try {
      int notificationCount = 0;
      final positions = await portfolioService.getPositions();

      for (final position in positions) {
        if (!position.enableNotification) continue;

        final currentPrice = currentPrices[position.code];
        if (currentPrice == null || currentPrice <= 0) continue;

        // 檢查目標價通知
        if (position.targetPrice != null &&
            !position.targetNotificationSent &&
            currentPrice >= position.targetPrice!) {
          await _sendTargetPriceNotification(position, currentPrice);
          await _updatePositionNotificationState(
            position,
            targetNotificationSent: true,
          );
          notificationCount++;
        }

        // 檢查停損價通知
        if (position.stopLossPrice != null &&
            !position.stopLossNotificationSent &&
            currentPrice <= position.stopLossPrice!) {
          await _sendStopLossNotification(position, currentPrice);
          await _updatePositionNotificationState(
            position,
            stopLossNotificationSent: true,
          );
          notificationCount++;
        }
      }

      if (notificationCount > 0) {
        print(
          '[NotificationRuleService] Sent $notificationCount notifications',
        );
      }

      return notificationCount;
    } catch (e) {
      print('[NotificationRuleService] Error checking positions: $e');
      return 0;
    }
  }

  /// 發送目標價達成通知
  Future<void> _sendTargetPriceNotification(
    PortfolioPosition position,
    double currentPrice,
  ) async {
    final pnl = position.calculatePnl(currentPrice);
    final title = '🎯 ${position.code} 達到目標價';
    final body =
        '${position.name} 現價 \$${currentPrice.toStringAsFixed(2)}'
        '，目標 \$${position.targetPrice?.toStringAsFixed(2)} 已達成！'
        '\n損益：${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%';

    await NotificationService.showAlert(
      title: title,
      body: body,
      id: position.code.hashCode,
    );
    _logNotification(position.code, 'TARGET_PRICE', currentPrice);
  }

  /// 發送停損價觸發通知
  Future<void> _sendStopLossNotification(
    PortfolioPosition position,
    double currentPrice,
  ) async {
    final pnl = position.calculatePnl(currentPrice);
    final title = '🛑 ${position.code} 觸發停損';
    final body =
        '${position.name} 現價 \$${currentPrice.toStringAsFixed(2)}'
        '，停損 \$${position.stopLossPrice?.toStringAsFixed(2)} 已觸發！'
        '\n損益：${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%';

    await NotificationService.showAlert(
      title: title,
      body: body,
      id: position.code.hashCode,
    );
    _logNotification(position.code, 'STOP_LOSS', currentPrice);
  }

  /// 更新持倉的通知狀態
  Future<void> _updatePositionNotificationState(
    PortfolioPosition position, {
    bool? targetNotificationSent,
    bool? stopLossNotificationSent,
  }) async {
    try {
      final updatedPosition = position.updateNotificationState(
        targetNotificationSent: targetNotificationSent,
        stopLossNotificationSent: stopLossNotificationSent,
        lastNotificationCheckAt: DateTime.now(),
      );
      await portfolioService.updatePosition(position.code, updatedPosition);
    } catch (e) {
      print(
        '[NotificationRuleService] Error updating position '
        '${position.code}: $e',
      );
    }
  }

  /// 重置目標價通知狀態（用戶修改目標價後）
  Future<void> resetTargetPriceNotification(String code) async {
    try {
      final position = await portfolioService.getPosition(code);
      if (position != null) {
        final updated = position.updateNotificationState(
          targetNotificationSent: false,
        );
        await portfolioService.updatePosition(code, updated);
        print('[NotificationRuleService] Reset target notification for $code');
      }
    } catch (e) {
      print('[NotificationRuleService] Error resetting notification: $e');
    }
  }

  /// 重置停損價通知狀態（用戶修改停損價後）
  Future<void> resetStopLossNotification(String code) async {
    try {
      final position = await portfolioService.getPosition(code);
      if (position != null) {
        final updated = position.updateNotificationState(
          stopLossNotificationSent: false,
        );
        await portfolioService.updatePosition(code, updated);
        print('[NotificationRuleService] Reset stop loss notification for $code');
      }
    } catch (e) {
      print('[NotificationRuleService] Error resetting notification: $e');
    }
  }

  /// 記錄通知歷史
  void _logNotification(
    String code,
    String type,
    double price,
  ) {
    try {
      final history = _prefs.getStringList(_notificationHistoryKey) ?? [];
      final entry =
          '${DateTime.now().toIso8601String()}|$code|$type|$price';
      history.add(entry);

      // 只保留最近 100 條記錄
      if (history.length > 100) {
        history.removeRange(0, history.length - 100);
      }

      _prefs.setStringList(_notificationHistoryKey, history);
    } catch (e) {
      print('[NotificationRuleService] Error logging notification: $e');
    }
  }

  /// 獲取通知歷史
  List<Map<String, String>> getNotificationHistory() {
    try {
      final history = _prefs.getStringList(_notificationHistoryKey) ?? [];
      return history
          .reversed
          .map((entry) {
            final parts = entry.split('|');
            if (parts.length >= 4) {
              return {
                'timestamp': parts[0],
                'code': parts[1],
                'type': parts[2],
                'price': parts[3],
              };
            }
            return null;
          })
          .whereType<Map<String, String>>()
          .toList();
    } catch (e) {
      print('[NotificationRuleService] Error reading history: $e');
      return [];
    }
  }

  /// 清空通知歷史
  Future<void> clearNotificationHistory() async {
    try {
      await _prefs.remove(_notificationHistoryKey);
      print('[NotificationRuleService] Notification history cleared');
    } catch (e) {
      print('[NotificationRuleService] Error clearing history: $e');
    }
  }
}
