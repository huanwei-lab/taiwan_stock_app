import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Simple SQLite-backed cache for end-of-day fund-flow rows.
class FundFlowCache {
  FundFlowCache._();

  static final FundFlowCache _instance = FundFlowCache._();
  static Database? _db;

  /// Obtain the singleton instance, ensuring DB is initialized.
  static Future<FundFlowCache> getInstance() async {
    if (_db == null) await _init();
    return _instance;
  }

  static Future<void> _init() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = join(databasesPath, 'fund_flow_cache.db');
    _db = await openDatabase(dbPath, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE eod_rows(
          code TEXT NOT NULL,
          date INTEGER NOT NULL,
          foreign_net INTEGER DEFAULT 0,
          trust_net INTEGER DEFAULT 0,
          dealer_net INTEGER DEFAULT 0,
          margin_balance INTEGER DEFAULT 0,
          PRIMARY KEY(code, date)
        )
      ''');
    });
  }

  /// Save parsed rows for a given YYYYMMDD integer date.
  Future<void> saveRows(int dateInt, List<Map<String, dynamic>> rows) async {
    final db = _db!;
    final batch = db.batch();
    for (final r in rows) {
      final code = (r['code'] ?? '').toString();
      final foreignNet = (r['foreign_net'] ?? 0) is int ? r['foreign_net'] : int.tryParse(r['foreign_net'].toString()) ?? 0;
      final trustNet = (r['trust_net'] ?? 0) is int ? r['trust_net'] : int.tryParse(r['trust_net'].toString()) ?? 0;
      final dealerNet = (r['dealer_net'] ?? 0) is int ? r['dealer_net'] : int.tryParse(r['dealer_net'].toString()) ?? 0;
      final marginBalance = (r['margin_balance'] ?? 0) is int ? r['margin_balance'] : int.tryParse(r['margin_balance'].toString()) ?? 0;

      batch.insert(
        'eod_rows',
        {
          'code': code,
          'date': dateInt,
          'foreign_net': foreignNet,
          'trust_net': trustNet,
          'dealer_net': dealerNet,
          'margin_balance': marginBalance,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get the latest margin_balance for [code] strictly before [dateInt].
  /// Returns null if none found.
  Future<int?> getPreviousMargin(String code, int dateInt) async {
    final db = _db!;
    final rows = await db.query(
      'eod_rows',
      columns: ['margin_balance'],
      where: 'code = ? AND date < ?',
      whereArgs: [code, dateInt],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final v = rows.first['margin_balance'];
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// Count consecutive previous days (including [dateInt]) where any institution
  /// net buy condition is met. [institution] can be 'foreign','trust','dealer' or 'any'.
  /// Correctly handles weekends (skips missing dates).
  /// This is a static helper that uses the internal DB. Use when a real DB is
  /// initialized (i.e., not in test fake caches).
  static Future<int> countConsecutiveInstitutionBuyDays(
      String code, int dateInt,
      {String institution = 'any'}) async {
    final db = _db!;
    final rows = await db.query(
      'eod_rows',
      columns: ['date', 'foreign_net', 'trust_net', 'dealer_net'],
      where: 'code = ? AND date <= ?',
      whereArgs: [code, dateInt],
      orderBy: 'date DESC',
    );

    int streak = 0;
    DateTime? lastDateInStreak;
    
    for (final r in rows) {
      final currentDateInt = r['date'] is int ? r['date'] as int : int.tryParse(r['date'].toString()) ?? 0;
      final currentDate = _parseDateInt(currentDateInt);
      
      // Check continuity: if there's a gap > 1 day, it must be a weekend/holiday
      if (lastDateInStreak != null) {
        final daysDiff = lastDateInStreak.difference(currentDate).inDays;
        // Normal case: 1 day apart (adjacent trading days)
        // Skip-weekend case: 3 days apart (Friday to Monday)
        // Skip-holiday case: varies
        // But if we see a larger gap in trading dates, that's a real break
        if (daysDiff > 3) {
          // Check if the gap includes a trading day we're missing → real break
          final shouldBreak = _hasUnexpectedGap(currentDate, lastDateInStreak);
          if (shouldBreak) break;
        }
      }
      
      final f = r['foreign_net'] is int ? r['foreign_net'] as int : int.tryParse(r['foreign_net'].toString()) ?? 0;
      final t = r['trust_net'] is int ? r['trust_net'] as int : int.tryParse(r['trust_net'].toString()) ?? 0;
      final d = r['dealer_net'] is int ? r['dealer_net'] as int : int.tryParse(r['dealer_net'].toString()) ?? 0;
      final any = (f + t + d) > 0;
      final cond = institution == 'foreign'
          ? f > 0
          : institution == 'trust'
              ? t > 0
              : institution == 'dealer'
                  ? d > 0
                  : any;
      
      if (cond) {
        streak += 1;
        lastDateInStreak = currentDate;
      } else {
        break;
      }
    }

    return streak;
  }

  /// Helper: parse YYYYMMDD integer to DateTime
  static DateTime _parseDateInt(int dateInt) {
    final str = dateInt.toString().padLeft(8, '0');
    final year = int.parse(str.substring(0, 4));
    final month = int.parse(str.substring(4, 6));
    final day = int.parse(str.substring(6, 8));
    return DateTime(year, month, day);
  }

  /// Helper: check if gap between two dates is unexpected (contains a trading day)
  static bool _hasUnexpectedGap(DateTime from, DateTime to) {
    // Simple heuristic: if the gap > 3 days and includes a weekday, it's a break
    // For now, if gap > 3, assume it's a real data break (not just weekends)
    final diff = to.difference(from).inDays;
    if (diff <= 3) return false; // Fri-Mon is 3 days, acceptable

    // If > 3 days, check if there's a weekday (Mon-Fri)
    var current = from.add(Duration(days: 1));
    while (current.isBefore(to)) {
      if (current.weekday >= DateTime.monday && current.weekday <= DateTime.friday) {
        return true; // Found unexpected trading day in gap
      }
      current = current.add(const Duration(days: 1));
    }
    return false;
  }
}
