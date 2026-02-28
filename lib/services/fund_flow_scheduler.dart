import 'package:workmanager/workmanager.dart';

import 'fund_flow_cache.dart';
import 'fund_flow_service.dart';

const String _kTaskName = 'fund_flow_fetch';

/// Scheduler to periodically fetch EOD fund-flow rows and update cache.
class FundFlowScheduler {
  /// Initialize Workmanager and register a periodic task (daily by default).
  static Future<void> initialize({Duration frequency = const Duration(hours: 24)}) async {
    Workmanager().initialize(_callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _kTaskName,
      _kTaskName,
      frequency: frequency,
    );
  }

  /// Run a single fetch+cache for [date] (YYYYMMDD or YYYY-MM-DD). Returns
  /// the number of rows fetched.
  static Future<int> runOnceForDate(
    String date, {
    FundFlowService? fundService,
    FundFlowCache? cache,
    int alertMarginDropThreshold = 0,
    void Function(String title, String body)? notifyCallback,
  }) async {
    final svc = fundService ?? const FundFlowService();
    final rows = await svc.fetchEodFundFlow(date);

    final dateInt = int.tryParse(date.replaceAll('-', '')) ?? 0;

    final c = cache ?? await FundFlowCache.getInstance();
    // persist rows so previous margin queries work
    await c.saveRows(dateInt, rows);

    for (final r in rows) {
      final code = (r['code'] ?? '').toString();
      final curr = int.tryParse(r['margin_balance']?.toString() ?? '0') ?? 0;
      final prev = await c.getPreviousMargin(code, dateInt);
      final diff = prev == null ? 0 : curr - prev;
      if (alertMarginDropThreshold > 0 && diff <= -alertMarginDropThreshold) {
        final title = 'Margin drop: $code';
        final body = 'margin diff $diff';
        if (notifyCallback != null) notifyCallback(title, body);
      }
    }

    return rows.length;
  }
}

// Workmanager callback dispatcher
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final now = DateTime.now();
      final formatted = '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      await FundFlowScheduler.runOnceForDate(formatted);
      return Future.value(true);
    } catch (_) {
      return Future.value(false);
    }
  });
}
