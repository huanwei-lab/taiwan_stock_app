import 'package:stock_checker/models/stock_model.dart';

/// Comprehensive trap prevention logic to avoid holding losers.
/// Protects against:
/// - False breakouts (high change on low volume)
/// - Overheated entries (too close to recent highs)
/// - Weak fundamentals (insufficient fund support)
/// - Technical traps (exhaustion moves before reversals)
class TrapPreventionService {
  /// Check if stock is likely overheated (too close to recent high).
  /// Returns true if stock should be excluded.
  static bool isLikelyOverheated({
    required StockModel stock,
    required double weekHighPrice,
    required double monthHighPrice,
    required double threeMonthHighPrice,
    double? allowedPercFromMonthHigh = 2.0, // within 2% of month high = risky
  }) {
    if (monthHighPrice <= 0) return false;

    final distanceFromMonthHigh =
        ((monthHighPrice - stock.closePrice) / monthHighPrice * 100).abs();
    
    // If within 2% of month high, likely overheated
    if (distanceFromMonthHigh <= (allowedPercFromMonthHigh ?? 2.0)) {
      return true;
    }

    // If stock is near 3-month high AND has weak volume recently = exhaustion
    if (threeMonthHighPrice > 0) {
      final distanceFrom3MHigh =
          ((threeMonthHighPrice - stock.closePrice) / threeMonthHighPrice * 100).abs();
      if (distanceFrom3MHigh <= 1.5 && stock.change >= 2.5) {
        return true; // Top reversal sign
      }
    }

    return false;
  }

  /// Check if recent performance suggests exhaustion (likely pullback coming).
  /// Returns risk score (1-5): 1=safe, 5=extremely risky
  static int evaluateExhaustionRisk({
    required StockModel stock,
    required List<double> last5DaysChanges,
    required List<int> last5DaysVolume,
  }) {
    if (last5DaysChanges.length < 5) return 1; // Not enough data

    // Sum of gains in last 5 days
    final totalGain = last5DaysChanges.fold<double>(0, (sum, change) => sum + (change >= 0 ? change : 0));

    // Check for pattern: 3+ consecutive big gains = exhaustion likely
    int consecutiveBigGains = 0;
    int maxConsecutive = 0;
    for (final change in last5DaysChanges) {
      if (change >= 1.5) {
        consecutiveBigGains++;
        maxConsecutive = maxConsecutive > consecutiveBigGains ? maxConsecutive : consecutiveBigGains;
      } else {
        consecutiveBigGains = 0;
      }
    }

    // Volume exhaustion: last volume weaker than previous = bearish reversal
    bool volumeExhaustion = false;
    if (last5DaysVolume.length >= 3) {
      final avgPrevVolume = (last5DaysVolume[0] + last5DaysVolume[1]) / 2;
      final lastVolume = last5DaysVolume.last.toDouble();
      if (lastVolume < avgPrevVolume * 0.85 && stock.change >= 1.5) {
        volumeExhaustion = true;
      }
    }

    // Risk scoring
    int risk = 1;
    if (totalGain >= 6.0) risk += 1; // 6%+ gain in 5d
    if (maxConsecutive >= 3) risk += 1; // 3+ consecutive big days
    if (volumeExhaustion) risk += 1; // Volume drying up at top
    if (stock.change >= 3.5) risk += 1; // Today's gain especially high

    return risk.clamp(1, 5);
  }

  /// Check fund flow authenticity (distinguish real buying from wash/trap).
  /// Returns true if fund flow is suspicious.
  static bool isSuspiciousFundFlow({
    required int foreignNet,
    required int trustNet,
    required int dealerNet,
    required double change,
    required int volume,
    required double volumeRef,
  }) {
    // Dealer net selling while stock rises = likely bearish trap
    if (dealerNet < -5000000 && change >= 1.5) {
      return true;
    }

    // Foreign + trust buying but volume weak = less conviction
    final totalInstitutional = foreignNet + trustNet;
    final volumeRatio = volumeRef <= 0 ? 0.0 : volume / volumeRef.toInt();
    if (totalInstitutional > 50000000 && volumeRatio < 0.8 && change >= 2.0) {
      return true; // Suspicious: big buying but weak volume
    }

    // Huge volume but mixed flow (dealer selling while foreign buying) = conflict
    final netFlow = totalInstitutional + dealerNet;
    if (volumeRatio >= 1.3 && netFlow.abs() < 20000000) {
      return true; // High volume but undecisive funds
    }

    return false;
  }

  /// Multi-day validation for breakout (avoid caught at opening).
  /// Returns true if breakout is solid.
  static bool isValidMultiDayBreakout({
    required StockModel stock,
    required int breakoutStreak,
    int minBreakoutDays = 2,
    required double? yesterdayClose,
    required double? dayBeforeClose,
  }) {
    if (breakoutStreak < minBreakoutDays) {
      return false;
    }

    // Check if today's close is sustained vs breakdown
    if (yesterdayClose != null && yesterdayClose > 0) {
      // If gap down from yesterday = failed breakout
      if (stock.closePrice < yesterdayClose * 0.98) {
        return false;
      }
    }

    return true;
  }

  /// Assess if entry price is reasonable (not chasing too hard).
  /// Returns true if entry is within safe range.
  static bool isReasonableEntryPrice({
    required StockModel stock,
    required double dayOpenPrice,
    required double dayHighPrice,
    required double breakoutPrice, // Usually recent support/resistance
  }) {
    // Avoid buying after stock already jumped 3%+ in opening
    final gapUp = ((stock.closePrice - dayOpenPrice) / dayOpenPrice * 100).abs();
    if (gapUp >= 3.0) {
      return false; // Already chased hard
    }

    // Avoid buying at daily high (no buffer)
    final distanceFromHigh = ((dayHighPrice - stock.closePrice) / dayHighPrice * 100).abs();
    if (distanceFromHigh < 0.5) {
      return false; // No margin of safety
    }

    // Reasonable if close is within 1.5% of today's high
    if (distanceFromHigh <= 1.5 && stock.change >= 2.0) {
      return true; // Strong follow-through, safe entry
    }

    return true;
  }

  /// Detect panic selling (washout) vs genuine weakness.
  /// Returns true if this is a buyable washout.
  static bool isLikelyWashout({
    required StockModel stock,
    required List<double> last3DaysVolume,
    required int lowestPriceIn20Days,
  }) {
    // Washout: big down day on massive volume breaking support
    if (stock.change <= -2.5 && last3DaysVolume.isNotEmpty) {
      final today = last3DaysVolume.last;
      final avg = last3DaysVolume.fold<double>(0, (sum, v) => sum + v) / last3DaysVolume.length;
      
      // Volume spike on down day = capitulation
      if (today > avg * 1.3) {
        // And broke prior support
        if (stock.closePrice <= lowestPriceIn20Days * 1.01) {
          return true; // Classic washout setup
        }
      }
    }

    return false;
  }

  /// Score the overall quality of a candidate (1-10 scale).
  /// Higher = safer, lower = more risky.
  static int overallQualityScore({
    required StockModel stock,
    required double monthHighPrice,
    required int breakoutStreak,
    required int foreignNet,
    required int trustNet,
    required int dealerNet,
    required List<double> last5DaysChanges,
    required double volumeRef,
  }) {
    int score = 7; // Default neutral

    // Positive factors
    if (breakoutStreak >= 3) score += 1; // Multi-day breakout
    if (foreignNet > 50000000) score += 1; // Strong foreign support
    if (trustNet > 50000000) score += 1; // Strong trust support
    if (!isSuspiciousFundFlow(
      foreignNet: foreignNet,
      trustNet: trustNet,
      dealerNet: dealerNet,
      change: stock.change,
      volume: stock.volume,
      volumeRef: volumeRef,
    )) {
      score += 1; // Good fund flow
    }

    // Negative factors
    if (isLikelyOverheated(
      stock: stock,
      weekHighPrice: monthHighPrice,
      monthHighPrice: monthHighPrice,
      threeMonthHighPrice: monthHighPrice,
    )) {
      score -= 2; // Too close to recent high
    }
    if (dealerNet < -10000000) {
      score -= 1; // Heavy dealer selling
    }
    if (evaluateExhaustionRisk(
      stock: stock,
      last5DaysChanges: last5DaysChanges,
      last5DaysVolume: [], // Simplified without volume data
    ) >= 4) {
      score -= 2; // High exhaustion risk
    }

    return score.clamp(1, 10);
  }
}
