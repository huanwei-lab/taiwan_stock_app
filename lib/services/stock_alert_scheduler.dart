import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';
import 'stock_service.dart';

const String stockAlertTaskName = 'stock.exit.signal.task';

@pragma('vm:entry-point')
void stockAlertCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await StockAlertScheduler.runExitSignalCheck();
    return true;
  });
}

class StockAlertScheduler {
  static const String _enableExitSignalKey = 'exit.enableSignal';
  static const String _stopLossPercentKey = 'exit.stopLossPercent';
  static const String _takeProfitPercentKey = 'exit.takeProfitPercent';
  static const String _entryPricesKey = 'position.entryPrices';
  static const String _lastAlertSignalMapKey = 'alert.lastSignalMap';

  static Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await NotificationService.initialize();

    await Workmanager().initialize(
      stockAlertCallbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    await Workmanager().registerPeriodicTask(
      'stock-exit-signal-monitor',
      stockAlertTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> runExitSignalCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enableExitSignalKey) ?? true;
    if (!enabled) {
      return;
    }

    final stopLossPercent = prefs.getInt(_stopLossPercentKey) ?? 5;
    final takeProfitPercent = prefs.getInt(_takeProfitPercentKey) ?? 10;

    final entryPriceRaw = prefs.getString(_entryPricesKey);
    if (entryPriceRaw == null || entryPriceRaw.isEmpty) {
      return;
    }

    final decodedEntryPrice = jsonDecode(entryPriceRaw);
    if (decodedEntryPrice is! Map<String, dynamic>) {
      return;
    }

    final entryPriceByCode = <String, double>{};
    decodedEntryPrice.forEach((key, value) {
      final parsed = double.tryParse(value.toString());
      if (parsed != null && parsed > 0) {
        entryPriceByCode[key] = parsed;
      }
    });

    if (entryPriceByCode.isEmpty) {
      return;
    }

    final stocks = await StockService().fetchAllStocks();
    final stockMap = {for (final stock in stocks) stock.code: stock};

    final lastSignalRaw = prefs.getString(_lastAlertSignalMapKey);
    final lastSignalMap = <String, String>{};
    if (lastSignalRaw != null && lastSignalRaw.isNotEmpty) {
      final decoded = jsonDecode(lastSignalRaw);
      if (decoded is Map<String, dynamic>) {
        decoded.forEach((key, value) {
          lastSignalMap[key] = value.toString();
        });
      }
    }

    final currentSignalMap = <String, String>{};
    final alerts = <String>[];

    for (final entry in entryPriceByCode.entries) {
      final code = entry.key;
      final entryPrice = entry.value;
      final stock = stockMap[code];
      if (stock == null) {
        continue;
      }

      final pnlPercent = ((stock.closePrice - entryPrice) / entryPrice) * 100;
      String signalType = 'normal';
      String? alertText;

      if (pnlPercent <= -stopLossPercent) {
        signalType = 'stop_loss';
        alertText = '$code 停損警示 ${pnlPercent.toStringAsFixed(1)}%';
      } else if (pnlPercent >= takeProfitPercent) {
        signalType = 'take_profit';
        alertText = '$code 停利訊號 +${pnlPercent.toStringAsFixed(1)}%';
      }

      currentSignalMap[code] = signalType;

      if (alertText != null && lastSignalMap[code] != signalType) {
        alerts.add(alertText);
      }
    }

    await prefs.setString(_lastAlertSignalMapKey, jsonEncode(currentSignalMap));

    if (alerts.isEmpty) {
      return;
    }

    final preview = alerts.take(3).join(' / ');
    final suffix = alerts.length > 3 ? ' 等 ${alerts.length} 檔' : '';

    await NotificationService.showAlert(
      title: '台股出場提醒',
      body: '$preview$suffix',
    );
  }
}
