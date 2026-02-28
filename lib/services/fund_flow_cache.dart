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
}
