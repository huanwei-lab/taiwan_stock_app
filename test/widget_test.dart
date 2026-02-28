import 'package:flutter_test/flutter_test.dart';

import 'package:stock_checker/main.dart';

void main() {
  testWidgets('stock list page renders', (WidgetTester tester) async {
    await tester.pumpWidget(const StockCheckerApp());

    expect(find.text('台股飆股分析'), findsWidgets);
    expect(find.text('篩選飆股'), findsOneWidget);
  });
}
