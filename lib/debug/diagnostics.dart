import 'package:flutter/foundation.dart';
import 'package:stock_checker/models/stock_model.dart';
import 'package:stock_checker/services/fund_flow_cache.dart';
import 'package:stock_checker/services/breakout_filter_service.dart';
// Replicated defaults from main.dart for offline diagnostics.
const double _latestVolumeReference = 10000000.0;
const int _minTradeValueThreshold = 1000000000;
const int _minScoreThreshold = 60;
const int _maxChaseChangePercent = 6;

double _minPriceThresholdDefault() => 10.0;

// (removed unused enum _BreakoutStageModeRep)

/// Prints a diagnostic report for [stock] using replicated selection rules.
///
/// Optional params allow passing runtime data used by the app:
/// - [latestVolumeReference]: market volume reference used to compute volumeRatio
/// - [breakoutMinVolumeRatioPercent]: percent used to compute required volume ratio
/// - [enableStrategyFilter]: whether secondary ratio is adjusted
/// - [minTradeValueThreshold]: trade value threshold
/// - [enableBreakoutQuality]: whether breakout-quality checks are active
/// - [enableMultiDayBreakout]: whether multi-day streak is required
/// - [minBreakoutStreakDays]: required streak days for multi-day breakout
/// - [breakoutStreakByCode]: map of code->streak days
/// - [newsTitles]: recent market news titles for theme/event checks
void diagnoseStockPublic(
  StockModel stock,
  int score, {
  double latestVolumeReference = _latestVolumeReference,
  int breakoutMinVolumeRatioPercent = 130,
  bool enableStrategyFilter = true,
  int minTradeValueThreshold = _minTradeValueThreshold,
  bool enableBreakoutQuality = true,
  bool enableMultiDayBreakout = true,
  int minBreakoutStreakDays = 2,
  Map<String, int>? breakoutStreakByCode,
  List<String>? newsTitles,
  bool enableChipConcentrationFilter = false,
  double minChipConcentrationPercent = 70.0,
}) {
  debugPrint('--- Diagnose ${stock.code} ${stock.name} ---');
  debugPrint('closePrice=${stock.closePrice} change%=${stock.change.toStringAsFixed(2)} volume=${stock.volume} tradeValue=${stock.tradeValue}');
  debugPrint('foreign=${stock.foreignNet} trust=${stock.trustNet} dealer=${stock.dealerNet} marginDiff=${stock.marginBalanceDiff}');

  const effectiveMinScore = _minScoreThreshold; // simplified
  debugPrint('effectiveMinScore=$effectiveMinScore providedScore=$score');

  final volumeRatio = latestVolumeReference <= 0 ? 0.0 : stock.volume / latestVolumeReference;
  debugPrint('volumeReference=$latestVolumeReference volumeRatio=${volumeRatio.toStringAsFixed(3)}');

  // Use BreakoutFilterService to evaluate all modes
  final results = BreakoutFilterService.evaluateAllModes(
    stock,
    score,
    latestVolumeReference: latestVolumeReference,
    minTradeValueThreshold: minTradeValueThreshold,
    minScoreThreshold: _minScoreThreshold,
    maxChaseChangePercent: _maxChaseChangePercent,
    minPriceThreshold: _minPriceThresholdDefault(),
    enableBreakoutQuality: enableBreakoutQuality,
    enableMultiDayBreakout: enableMultiDayBreakout,
    breakoutStreakByCode: breakoutStreakByCode,
    minBreakoutStreakDays: minBreakoutStreakDays,
  );

  // Output results for each mode
  for (final mode in BreakoutMode.values) {
    final passed = results[mode] ?? false;
    debugPrint('mode=${mode.name} => ${passed ? 'PASS' : 'FAIL'}');
  }

  // False breakout detection
  final likelyFalse = BreakoutFilterService.isLikelyFalseBreakout(
    stock,
    score,
    maxChaseChangePercent: _maxChaseChangePercent,
    minScoreThreshold: _minScoreThreshold,
  );
  debugPrint('likelyFalseBreakout=$likelyFalse');

  // Confirmed-mode multi-day streak check (if enabled)
  if (enableMultiDayBreakout) {
    final codeStr = stock.code.toString();
    final streak = breakoutStreakByCode != null ? (breakoutStreakByCode[codeStr] ?? 0) : 0;
    final confirmed = streak >= minBreakoutStreakDays;
    debugPrint('confirmedMode: streak=$streak required=$minBreakoutStreakDays confirmed=$confirmed');
  }

  // Simple news/title event matching (if provided).
  if (newsTitles != null && newsTitles.isNotEmpty) {
    final lowered = newsTitles.map((s) => s.toLowerCase()).toList();
    const keywords = ['merger', 'acquisition', 'supply', 'order', 'contract', 'profit', 'earnings', 'ipo', 'rights', 'subscription'];
    final hits = <String>[];
    for (final kw in keywords) {
      for (final t in lowered) {
        if (t.contains(kw)) {
          hits.add(kw);
          break;
        }
      }
    }
    debugPrint('newsHits=${hits.toSet().toList()}');
  }

  debugPrint('--- End diagnose ---');
}

/// Returns a list of human-readable diagnostic lines for UI display.
List<String> getDiagnosisReport(
  StockModel stock,
  int score, {
  double latestVolumeReference = _latestVolumeReference,
  int minTradeValueThreshold = _minTradeValueThreshold,
  bool enableBreakoutQuality = true,
  bool enableMultiDayBreakout = true,
  int minBreakoutStreakDays = 2,
  Map<String, int>? breakoutStreakByCode,
  List<String>? newsTitles,
}) {
  final lines = <String>[];
  lines.add('Diagnose ${stock.code} ${stock.name}');
  lines.add('收盤 ${stock.closePrice} 變動 ${stock.change.toStringAsFixed(2)}% 量 ${stock.volume}');

  const effectiveMinScore = _minScoreThreshold;
  lines.add('effectiveMinScore=$effectiveMinScore providedScore=$score');

  final volumeRatio = latestVolumeReference <= 0 ? 0.0 : stock.volume / latestVolumeReference;
  lines.add('volumeRatio=${volumeRatio.toStringAsFixed(3)} (ref=$latestVolumeReference)');

  // Use BreakoutFilterService to evaluate all modes
  final results = BreakoutFilterService.evaluateAllModes(
    stock,
    score,
    latestVolumeReference: latestVolumeReference,
    minTradeValueThreshold: minTradeValueThreshold,
    minScoreThreshold: _minScoreThreshold,
    maxChaseChangePercent: _maxChaseChangePercent,
    minPriceThreshold: _minPriceThresholdDefault(),
    enableBreakoutQuality: enableBreakoutQuality,
    enableMultiDayBreakout: enableMultiDayBreakout,
    breakoutStreakByCode: breakoutStreakByCode,
    minBreakoutStreakDays: minBreakoutStreakDays,
  );

  // Output results for each mode
  for (final mode in BreakoutMode.values) {
    final passed = results[mode] ?? false;
    lines.add('${mode.name} => ${passed ? 'PASS' : 'FAIL'}');
  }

  // False breakout detection
  final likelyFalse = BreakoutFilterService.isLikelyFalseBreakout(
    stock,
    score,
    maxChaseChangePercent: _maxChaseChangePercent,
    minScoreThreshold: _minScoreThreshold,
  );
  lines.add('likelyFalseBreakout=$likelyFalse');

  // Confirmed-mode multi-day streak check
  if (enableMultiDayBreakout) {
    final codeStr = stock.code.toString();
    final streak = breakoutStreakByCode != null ? (breakoutStreakByCode[codeStr] ?? 0) : 0;
    final confirmed = streak >= minBreakoutStreakDays;
    lines.add('confirmedMode: streak=$streak required=$minBreakoutStreakDays confirmed=$confirmed');
  }

  // News/title event matching
  if (newsTitles != null && newsTitles.isNotEmpty) {
    final lowered = newsTitles.map((s) => s.toLowerCase()).toList();
    const keywords = ['merger', 'acquisition', 'supply', 'order', 'contract', 'profit', 'earnings', 'ipo', 'rights', 'subscription'];
    final hits = <String>[];
    for (final kw in keywords) {
      for (final t in lowered) {
        if (t.contains(kw)) {
          hits.add(kw);
          break;
        }
      }
    }
    if (hits.isNotEmpty) {
      lines.add('newsHits=${hits.toSet().toList()}');
    }
  }

  return lines;
}

/// Structured DTO for UI-friendly diagnostics.
class DiagnosisLine {
  final String title;
  final String? value;
  final String? status; // e.g. PASS / FAIL / INFO
  final String? severity; // e.g. success / warning / danger / info

  DiagnosisLine(this.title, {this.value, this.status, this.severity});
}

class DiagnosisReport {
  final String code;
  final String name;
  final List<DiagnosisLine> lines;
  final Map<String, int> institutionStreaks; // foreign/trust/dealer/any
  final bool confirmed;

  DiagnosisReport({
    required this.code,
    required this.name,
    required this.lines,
    required this.institutionStreaks,
    required this.confirmed,
  });
}

/// Async structured version: returns a `DiagnosisReport` with parsed lines
/// and fund-flow based institution streaks.
Future<DiagnosisReport> getDiagnosisReportStructuredAsync(
  StockModel stock,
  int score, {
  double latestVolumeReference = _latestVolumeReference,
  int minTradeValueThreshold = _minTradeValueThreshold,
  bool enableBreakoutQuality = true,
  bool enableMultiDayBreakout = true,
  int minBreakoutStreakDays = 2,
  Map<String, int>? breakoutStreakByCode,
  List<String>? newsTitles,
  DateTime? date,
}) async {
  // Build the legacy string lines then map them into structured lines.
  final raw = getDiagnosisReport(
    stock,
    score,
    latestVolumeReference: latestVolumeReference,
    minTradeValueThreshold: minTradeValueThreshold,
    enableBreakoutQuality: enableBreakoutQuality,
    enableMultiDayBreakout: enableMultiDayBreakout,
    minBreakoutStreakDays: minBreakoutStreakDays,
    breakoutStreakByCode: breakoutStreakByCode,
    newsTitles: newsTitles,
  );

  final lines = <DiagnosisLine>[];
  for (final l in raw) {
    if (l.contains('=>')) {
      final parts = l.split('=>');
      final left = parts[0].trim();
      final right = parts[1].trim();
      final status = right.split(' ').first;
      String? severity;
      if (status.toUpperCase().startsWith('PASS')) severity = 'success';
      if (status.toUpperCase().startsWith('FAIL')) severity = 'danger';
      lines.add(DiagnosisLine(left, value: right, status: status, severity: severity));
    } else {
      String? severity;
      if (l.contains('likelyFalse')) {
        severity = 'danger';
      } else if (l.toLowerCase().contains('newshits') || l.toLowerCase().contains('newshits') || l.toLowerCase().contains('newshits')) {
        severity = 'info';
      }
      // confirmed line handled later via report.confirmed
      lines.add(DiagnosisLine(l, value: null, status: null, severity: severity));
    }
  }

  // compute institution streaks using the FundFlowCache static helper
  final d = date ?? DateTime.now();
  final dateInt = int.parse('${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}');
  int foreignStreak = 0;
  int trustStreak = 0;
  int dealerStreak = 0;
  int anyStreak = 0;
  try {
    foreignStreak = await FundFlowCache.countConsecutiveInstitutionBuyDays(stock.code, dateInt, institution: 'foreign');
    trustStreak = await FundFlowCache.countConsecutiveInstitutionBuyDays(stock.code, dateInt, institution: 'trust');
    dealerStreak = await FundFlowCache.countConsecutiveInstitutionBuyDays(stock.code, dateInt, institution: 'dealer');
    anyStreak = await FundFlowCache.countConsecutiveInstitutionBuyDays(stock.code, dateInt, institution: 'any');
  } catch (_) {
    // If DB not ready or error occurs, leave streaks as zero.
  }

  final instMap = <String, int>{
    'foreign': foreignStreak,
    'trust': trustStreak,
    'dealer': dealerStreak,
    'any': anyStreak,
  };

  // Determine confirmed status: prefer breakoutStreakByCode if provided.
  final codeStr = stock.code.toString();
  final streak = breakoutStreakByCode != null ? (breakoutStreakByCode[codeStr] ?? 0) : anyStreak;
  final confirmed = streak >= minBreakoutStreakDays;

  return DiagnosisReport(
    code: stock.code,
    name: stock.name,
    lines: lines,
    institutionStreaks: instMap,
    confirmed: confirmed,
  );
}

/// Async version: include fund-flow based institution streak info (from cache).
Future<List<String>> getDiagnosisReportAsync(
  StockModel stock,
  int score, {
  double latestVolumeReference = _latestVolumeReference,
  int minTradeValueThreshold = _minTradeValueThreshold,
  bool enableBreakoutQuality = true,
  bool enableMultiDayBreakout = true,
  int minBreakoutStreakDays = 2,
  Map<String, int>? breakoutStreakByCode,
  List<String>? newsTitles,
  DateTime? date,
}) async {
  final lines = getDiagnosisReport(
    stock,
    score,
    latestVolumeReference: latestVolumeReference,
    minTradeValueThreshold: minTradeValueThreshold,
    enableBreakoutQuality: enableBreakoutQuality,
    enableMultiDayBreakout: enableMultiDayBreakout,
    minBreakoutStreakDays: minBreakoutStreakDays,
    breakoutStreakByCode: breakoutStreakByCode,
    newsTitles: newsTitles,
  );

  final d = date ?? DateTime.now();
  final dateInt = int.parse('${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}');
  final instStreak = await FundFlowCache.countConsecutiveInstitutionBuyDays(stock.code, dateInt, institution: 'any');
  lines.add('法人連日買超: $instStreak');

  // If breakout streak map provided, add confirmed label
  final streak = breakoutStreakByCode != null ? (breakoutStreakByCode[stock.code] ?? 0) : 0;
  final confirmed = streak >= minBreakoutStreakDays;
  lines.add('confirmed: ${confirmed ? 'YES' : 'NO'} (breakoutStreak=$streak)');

  return lines;
}

