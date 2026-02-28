import 'package:stock_checker/services/csv_analysis_service.dart';

/// Simple CLI that takes two arguments: path to predictions.csv and
/// path to outcomes.csv.  Optionally supply a minimum score threshold as a
/// third argument.

void main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart tools/evaluate_csv.dart <predictions.csv> <outcomes.csv> [minScore]');
    return;
  }
  final pred = args[0];
  final out = args[1];
  final threshold = args.length >= 3 ? double.tryParse(args[2]) ?? 0 : 0;
  await CsvAnalysisService.evaluatePredictions(
    predictionsPath: pred,
    outcomesPath: out,
    scoreThreshold: threshold,
  );
}
