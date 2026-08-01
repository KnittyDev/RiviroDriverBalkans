import 'package:flutter_test/flutter_test.dart';
import 'package:rivilodriver/main.dart';

void main() {
  testWidgets('Rivilo Driver App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RiviloDriverApp());
    expect(find.byType(RiviloDriverApp), findsOneWidget);
  });
}
