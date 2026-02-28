import 'dart:io';

/// Utility for loading the CSV exports from the app and computing simple
/// diagnostic metrics.  This is not invoked by the UI; you can run it from a
/// Dart script or the Dart REPL while pointing at the exported files.
///
/// The two CSVs produced by the app have the following columns (headers may
/// vary slightly depending on locale):
///
///   * predictions.csv: `date,code,score,core,top20,strong,...`
///   * outcomes.csv:    `date,code,return1d,return3d,return5d,...`
///
/// All values are treated as strings; the service converts what it needs.
///
class CsvAnalysisService {
  /// Reads `predictions.csv` and `outcomes.csv` from the given paths and prints
  /// a very basic summary to stdout.  You can supply `scoreThreshold` to
  /// calculate the hit rate (how many stocks exceeded that score) and the
  /// average 1-day return of those picks.
  static Future<void> evaluatePredictions({
    required String predictionsPath,
    required String outcomesPath,
    double scoreThreshold = 0,
  }) async {
    final preds = await _loadCsv(predictionsPath);
    final outs = await _loadCsv(outcomesPath);

    // index outcomes by code+date for quick lookup
    final outcomeMap = <String, Map<String, String>>{};
    for (var row in outs) {
      final key = '${row['code']}-${row['date']}';
      outcomeMap[key] = row;
    }

    // counters for simple diagnostics
    var total = 0;
    var above = 0;
    var sumReturn1d = 0.0;
    var returnCount = 0;

    for (var row in preds) {
      total++;
      final sc = double.tryParse(row['score'] ?? '0') ?? 0;
      if (sc >= scoreThreshold) {
        above++;
        final key = '${row['code']}-${row['date']}';
        final outRow = outcomeMap[key];
        if (outRow != null) {
          final r1 = double.tryParse(outRow['return1d'] ?? '');
          if (r1 != null) {
            sumReturn1d += r1;
            returnCount++;
          }
        }
      }
    }

    // print a brief summary so the script has some visible output
    stdout.writeln('evaluated $total predictions, $above above threshold');
    if (returnCount > 0) {
      stdout.writeln('avg 1d return of filtered picks: '
          '${(sumReturn1d / returnCount).toStringAsFixed(4)}');
    }

    // debug output intentionally removed; return results via API if needed
  }

  static Future<List<Map<String, String>>> _loadCsv(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('file not found: $path');
    }
    final lines = await file.readAsLines();
    if (lines.isEmpty) return [];
    final headers = lines.first.split(',').map((h) => h.trim()).toList();
    final data = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final parts = lines[i].split(',');
      final row = <String, String>{};
      for (var j = 0; j < headers.length && j < parts.length; j++) {
        row[headers[j]] = parts[j];
      }
      data.add(row);
    }
    return data;
  }
}
