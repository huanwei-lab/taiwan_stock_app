import 'package:stock_checker/models/stock_model.dart';

/// Unified breakout stage evaluation logic.
/// Single source of truth for all breakout mode checks (early, confirmed, squeeze, etc.)
/// Used by main.dart selection, diagnostics, and backtesting.
class BreakoutFilterService {
  // Replicated defaults used in filtering (should match those in main.dart)
  static const double defaultLatestVolumeReference = 10000000.0;
  static const int defaultMinTradeValueThreshold = 1000000000;
  static const int defaultMinScoreThreshold = 60;
  static const int defaultMaxChaseChangePercent = 6;
  static const double defaultMinPriceThreshold = 10.0;

  static double? _cachedLatestVolumeReference;

  /// Set the current market volume reference (should be updated dynamically by main.dart).
  static void setLatestVolumeReference(double value) {
    _cachedLatestVolumeReference = value;
  }

  /// Get current volume reference, falling back to default if not set.
  static double getLatestVolumeReference() {
    return _cachedLatestVolumeReference ?? defaultLatestVolumeReference;
  }

  /// Evaluate all breakout modes for a given stock.
  /// Returns a map of breakout mode → pass/fail.
  /// Callbacks allow main.dart to provide context-specific checks (e.g., theme news support).
  static Map<BreakoutMode, bool> evaluateAllModes(
    StockModel stock,
    int score, {
    double? latestVolumeReference,
    int? minTradeValueThreshold,
    int? minScoreThreshold,
    int? maxChaseChangePercent,
    double? minPriceThreshold,
    bool? enableBreakoutQuality,
    bool? enableMultiDayBreakout,
    Map<String, int>? breakoutStreakByCode,
    int? minBreakoutStreakDays,
    bool Function(StockModel)? hasThemeNewsSupport,
    bool Function(StockModel)? hasEventCatalystSupport,
    bool Function(StockModel)? passesChipConcentration,
    int? breakoutMinVolumeRatioPercent,
    double Function(double, {required bool strategyFilterEnabled})? computeSecondaryVolumeRatio,
    bool? enableStrategyFilter,
    int Function(int)? normalizeTradeValue,
  }) {
    final volumeRef = latestVolumeReference ?? getLatestVolumeReference();
    final tradeValueTh = minTradeValueThreshold ?? defaultMinTradeValueThreshold;
    final scoreTh = minScoreThreshold ?? defaultMinScoreThreshold;
    final maxChase =
        maxChaseChangePercent ?? defaultMaxChaseChangePercent;
    final minPrice = minPriceThreshold ?? defaultMinPriceThreshold;
    final breakoutQual = enableBreakoutQuality ?? true;
    final multiDay = enableMultiDayBreakout ?? true;
    final streakDays = minBreakoutStreakDays ?? 2;

    final effectiveMinScore = _effectiveMinScore(stock, scoreTh);
    final volumeRatio = volumeRef <= 0 ? 0.0 : stock.volume / volumeRef;

    return {
      BreakoutMode.early: _passesEarly(
        stock,
        score,
        volumeRatio,
        effectiveMinScore,
        tradeValueTh,
        maxChase,
        breakoutQual,
        breakoutMinVolumeRatioPercent ?? 100,
        computeSecondaryVolumeRatio,
        enableStrategyFilter ?? false,
        passesChipConcentration,
        normalizeTradeValue,
      ),
      BreakoutMode.confirmed: _passesConfirmed(
        stock,
        score,
        volumeRatio,
        effectiveMinScore,
        tradeValueTh,
        maxChase,
        breakoutQual,
        multiDay,
        breakoutStreakByCode,
        streakDays,
        breakoutMinVolumeRatioPercent ?? 100,
        computeSecondaryVolumeRatio,
        enableStrategyFilter ?? false,
        passesChipConcentration,
        normalizeTradeValue,
      ),
      BreakoutMode.lowBaseTheme: _passesLowBase(
        stock,
        score,
        volumeRatio,
        effectiveMinScore,
        tradeValueTh,
        minPrice,
        hasThemeNewsSupport,
      ),
      BreakoutMode.pullbackRebreak: _passesPullback(
        stock,
        score,
        volumeRatio,
        effectiveMinScore,
        tradeValueTh,
        breakoutStreakByCode,
      ),
      BreakoutMode.squeezeSetup: _passesSqueeze(
        stock,
        score,
        volumeRatio,
        effectiveMinScore,
        tradeValueTh,
      ),
      BreakoutMode.preEventPosition: _passesPreEvent(
        stock,
        score,
        volumeRatio,
        effectiveMinScore,
        tradeValueTh,
        hasEventCatalystSupport,
      ),
    };
  }

  /// Convenience: get matched modes for a stock.
  static List<BreakoutMode> getMatchedModes(
    StockModel stock,
    int score, {
    double? latestVolumeReference,
    int? minTradeValueThreshold,
    int? minScoreThreshold,
    int? maxChaseChangePercent,
    double? minPriceThreshold,
    bool? enableBreakoutQuality,
    bool? enableMultiDayBreakout,
    Map<String, int>? breakoutStreakByCode,
    int? minBreakoutStreakDays,
    bool Function(StockModel)? hasThemeNewsSupport,
    bool Function(StockModel)? hasEventCatalystSupport,
    bool Function(StockModel)? passesChipConcentration,
    int? breakoutMinVolumeRatioPercent,
    double Function(double, {required bool strategyFilterEnabled})? computeSecondaryVolumeRatio,
    bool? enableStrategyFilter,
    int Function(int)? normalizeTradeValue,
  }) {
    final results = evaluateAllModes(
      stock,
      score,
      latestVolumeReference: latestVolumeReference,
      minTradeValueThreshold: minTradeValueThreshold,
      minScoreThreshold: minScoreThreshold,
      maxChaseChangePercent: maxChaseChangePercent,
      minPriceThreshold: minPriceThreshold,
      enableBreakoutQuality: enableBreakoutQuality,
      enableMultiDayBreakout: enableMultiDayBreakout,
      breakoutStreakByCode: breakoutStreakByCode,
      minBreakoutStreakDays: minBreakoutStreakDays,
      hasThemeNewsSupport: hasThemeNewsSupport,
      hasEventCatalystSupport: hasEventCatalystSupport,
      passesChipConcentration: passesChipConcentration,
      breakoutMinVolumeRatioPercent: breakoutMinVolumeRatioPercent,
      computeSecondaryVolumeRatio: computeSecondaryVolumeRatio,
      enableStrategyFilter: enableStrategyFilter,
      normalizeTradeValue: normalizeTradeValue,
    );
    return results.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
  }

  // Private implementations for each mode

  static int _effectiveMinScore(StockModel stock, int minScoreThreshold) {
    // Simplified: just use the threshold
    // In real app, might account for price tiers
    return minScoreThreshold;
  }

  static bool _passesEarly(
    StockModel stock,
    int score,
    double volumeRatio,
    int effectiveMinScore,
    int minTradeValueThreshold,
    int maxChaseChangePercent,
    bool enableBreakoutQuality,
    int breakoutMinVolumeRatioPercent,
    double Function(double, {required bool strategyFilterEnabled})? computeSecondaryVolumeRatio,
    bool enableStrategyFilter,
    bool Function(StockModel)? passesChipConcentration,
    int Function(int)? normalizeTradeValue,
  ) {
    if (!enableBreakoutQuality) return true;

    // Check chip concentration if callback provided
    if (passesChipConcentration != null && !passesChipConcentration(stock)) {
      return false;
    }

    // Check volume
    final requiredRatio = breakoutMinVolumeRatioPercent / 100;
    final secondaryRequiredRatio = computeSecondaryVolumeRatio != null
        ? computeSecondaryVolumeRatio(requiredRatio, strategyFilterEnabled: enableStrategyFilter)
        : requiredRatio;
    final passVolume = volumeRatio >= secondaryRequiredRatio;

    // Check other conditions
    final passChange = stock.change >= 1.5;
    final passScore = score >= (effectiveMinScore + 3).clamp(0, 100);
    final normalizedTradeValue = normalizeTradeValue != null
        ? normalizeTradeValue(stock.tradeValue)
        : stock.tradeValue;
    final passTradeValue = normalizedTradeValue >= minTradeValueThreshold;

    return passVolume && passChange && passScore && passTradeValue;
  }

  static bool _passesConfirmed(
    StockModel stock,
    int score,
    double volumeRatio,
    int effectiveMinScore,
    int minTradeValueThreshold,
    int maxChaseChangePercent,
    bool enableBreakoutQuality,
    bool enableMultiDayBreakout,
    Map<String, int>? breakoutStreakByCode,
    int minBreakoutStreakDays,
    int breakoutMinVolumeRatioPercent,
    double Function(double, {required bool strategyFilterEnabled})? computeSecondaryVolumeRatio,
    bool enableStrategyFilter,
    bool Function(StockModel)? passesChipConcentration,
    int Function(int)? normalizeTradeValue,
  ) {
    // First, check if passes basic quality
    final passesQuality = _passesEarly(
      stock,
      score,
      volumeRatio,
      effectiveMinScore,
      minTradeValueThreshold,
      maxChaseChangePercent,
      enableBreakoutQuality,
      breakoutMinVolumeRatioPercent,
      computeSecondaryVolumeRatio,
      enableStrategyFilter,
      passesChipConcentration,
      normalizeTradeValue,
    );
    if (!passesQuality) return false;

    if (!enableMultiDayBreakout) return true;

    // Check multi-day breakout streak
    final streak = breakoutStreakByCode?[stock.code] ?? 0;
    return streak >= minBreakoutStreakDays;
  }

  static bool _passesLowBase(
    StockModel stock,
    int score,
    double volumeRatio,
    int effectiveMinScore,
    int minTradeValueThreshold,
    double minPriceThreshold,
    bool Function(StockModel)? hasThemeNewsSupport,
  ) {
    final basicCheck = stock.closePrice <= (minPriceThreshold * 0.65) &&
        stock.change >= -1.0 &&
        stock.change <= 4.5 &&
        volumeRatio >= 0.9 &&
        stock.tradeValue >= (minTradeValueThreshold * 0.6).toInt();
    
    if (!basicCheck) return false;

    // If no callback, use score-based fallback
    if (hasThemeNewsSupport == null) {
      return score >= (effectiveMinScore - 10).clamp(0, 100);
    }

    // Use callback to check for theme news OR score-based fallback
    return hasThemeNewsSupport(stock) ||
        score >= (effectiveMinScore - 10).clamp(0, 100);
  }

  static bool _passesPullback(
    StockModel stock,
    int score,
    double volumeRatio,
    int effectiveMinScore,
    int minTradeValueThreshold,
    Map<String, int>? breakoutStreakByCode,
  ) {
    return stock.change >= 0.5 &&
        stock.change <= 4.0 &&
        volumeRatio >= 1.05 &&
        score >= (effectiveMinScore - 5).clamp(0, 100) &&
        stock.tradeValue >= (minTradeValueThreshold * 0.75).toInt() &&
        (breakoutStreakByCode?[stock.code] ?? 0) >= 1;
  }

  static bool _passesSqueeze(
    StockModel stock,
    int score,
    double volumeRatio,
    int effectiveMinScore,
    int minTradeValueThreshold,
  ) {
    return stock.change.abs() <= 1.2 &&
        volumeRatio >= 0.75 &&
        volumeRatio <= 1.1 &&
        score >= (effectiveMinScore - 12).clamp(0, 100) &&
        stock.tradeValue >= (minTradeValueThreshold * 0.65).toInt();
  }

  static bool _passesPreEvent(
    StockModel stock,
    int score,
    double volumeRatio,
    int effectiveMinScore,
    int minTradeValueThreshold,
    bool Function(StockModel)? hasEventCatalystSupport,
  ) {
    final basicCheck = stock.change.abs() <= 3.2 &&
        volumeRatio >= 0.9 &&
        score >= (effectiveMinScore - 6).clamp(0, 100) &&
        stock.tradeValue >= (minTradeValueThreshold * 0.75).toInt();
    
    if (!basicCheck) return false;

    // Require event catalyst support if callback provided
    if (hasEventCatalystSupport != null) {
      return hasEventCatalystSupport(stock);
    }

    return true;
  }

  /// Detect potential false breakout based on heuristics.
  static bool isLikelyFalseBreakout(
    StockModel stock,
    int score, {
    int? maxChaseChangePercent,
    int? minScoreThreshold,
  }) {
    final maxChase = maxChaseChangePercent ?? defaultMaxChaseChangePercent;
    final minScore = minScoreThreshold ?? defaultMinScoreThreshold;

    final veryHighChange = stock.change >= (maxChase + 1);
    final weakFollowThrough =
        stock.change >= 3.0 && (stock.volume / getLatestVolumeReference()) < 1.1;
    final weakScoreJump = stock.change >= 2.5 && score < (minScore + 5);

    return veryHighChange || weakFollowThrough || weakScoreJump;
  }
}

enum BreakoutMode {
  early,
  confirmed,
  lowBaseTheme,
  pullbackRebreak,
  squeezeSetup,
  preEventPosition,
}
