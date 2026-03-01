import 'package:shared_preferences/shared_preferences.dart';

import 'intraday_service.dart';
import 'notification_service.dart';
import 'fund_flow_cache.dart';
import 'dart:developer' as developer;

/// Controller that manages the intraday poller and a persistent on/off flag.
class IntradayController {
  IntradayController._(this._svc, this._prefs);

  static const _kPrefKey = 'intraday_enabled';

  final IntradayService _svc;
  final SharedPreferences _prefs;

  /// Creates the controller and optionally starts the service if the stored
  /// preference is enabled.
  /// Create controller. If [service] is provided it will be used (useful for
  /// tests). Otherwise a new `IntradayService` is created and its
  /// `onSnapshot` will forward alerts to `NotificationService` when the
  /// intraday preference is enabled. [foreignDeltaThreshold] controls when a
  /// foreign net change triggers a notification. Set [debug] to true to log
  /// parsed snapshots.
  static Future<IntradayController> create({
    IntradayService? service,
    bool enableNotifications = true,
    int foreignDeltaThreshold = 1000,
    bool debug = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kPrefKey) ?? false;

    if (service != null) {
      final c = IntradayController._(service, prefs);
      if (enabled) c._svc.start();
      return c;
    }

    // Ensure fund-flow DB initialized so we can query streaks for confirmed alerts.
    try {
      await FundFlowCache.getInstance();
    } catch (_) {
      // ignore DB init errors; streak queries will be skipped if DB not ready
    }

    final svc = IntradayService(
      onSnapshot: (snapshot) async {
        if (debug) {
          developer.log('Intraday snapshot: ${snapshot.length} entries');
        }

        final prefEnabled = prefs.getBool(_kPrefKey) ?? false;
        if (!prefEnabled) return;

        for (final entry in snapshot.entries) {
          final code = entry.key;
          final row = entry.value;
          final deltaForeign = (row['_delta_foreign'] is int) ? row['_delta_foreign'] as int : int.tryParse(row['_delta_foreign']?.toString() ?? '0') ?? 0;
          final deltaMargin = (row['_delta_margin'] is int) ? row['_delta_margin'] as int : int.tryParse(row['_delta_margin']?.toString() ?? '0') ?? 0;

          if (debug) {
            developer.log('[$code] deltaForeign=$deltaForeign deltaMargin=$deltaMargin fields=${row.keys.toList()}');
          }

          if (enableNotifications && deltaForeign.abs() >= foreignDeltaThreshold) {
            await NotificationService.showAlert(
              title: '法人變動: $code',
              body: '外資變動 ${deltaForeign >= 0 ? '+' : ''}$deltaForeign',
            );
            // confirmed-breakout candidate: if foreign has consecutive buy days
            try {
              final minBreakoutDays = prefs.getInt('filter.multiDayBreakout.minDays') ?? 2;
              if (deltaForeign > 0) {
                final d = DateTime.now();
                final dateInt = int.parse('${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}');
                final foreignStreak = await FundFlowCache.countConsecutiveInstitutionBuyDays(code, dateInt, institution: 'foreign');
                if (foreignStreak >= minBreakoutDays) {
                  await NotificationService.showAlert(
                    title: 'Confirmed Breakout 候選: $code',
                    body: '外資連日買超 $foreignStreak 天 (delta ${deltaForeign >= 0 ? '+' : ''}$deltaForeign)'
                  );
                }
              }
            } catch (_) {
              // ignore DB lookup errors in intraday path
            }
          }
          if (enableNotifications && deltaMargin.abs() >= (foreignDeltaThreshold)) {
            await NotificationService.showAlert(
              title: '融資變動: $code',
              body: '融資變動 ${deltaMargin >= 0 ? '+' : ''}$deltaMargin',
            );
          }
        }
      },
    );

    final c = IntradayController._(svc, prefs);
    if (enabled) c._svc.start();
    return c;
  }

  bool get enabled => _prefs.getBool(_kPrefKey) ?? false;

  /// Enable intraday polling and persist preference.
  Future<void> enable() async {
    await _prefs.setBool(_kPrefKey, true);
    _svc.start();
  }

  /// Disable intraday polling and persist preference.
  Future<void> disable() async {
    await _prefs.setBool(_kPrefKey, false);
    _svc.stop();
  }

  /// Toggle and return new state.
  Future<bool> toggle() async {
    final next = !(enabled);
    if (next) {
      await enable();
    } else {
      await disable();
    }
    return next;
  }
}
