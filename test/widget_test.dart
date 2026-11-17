import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_scan_ai/main.dart'; 

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    // MyApp-ku bathila NutriScanApp use pannuvom
    await tester.pumpWidget(NutriScanApp());
    expect(find.byType(NutriScanApp), findsOneWidget);
  });
}