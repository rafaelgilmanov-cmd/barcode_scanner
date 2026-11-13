import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_scanner/main.dart';

void main() {
  testWidgets('Scanner app loads home page', (WidgetTester tester) async {
    await tester.pumpWidget(const ScannerApp());
    expect(find.text('Сканер кодов'), findsOneWidget);
  });
}