import 'package:flutter_test/flutter_test.dart';
import 'package:ambulance_flutter/app.dart';

void main() {
  testWidgets('PranaSarathi app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const PranaSarathiApp());

    expect(find.textContaining('Ambulance Driver'), findsOneWidget);
  });
}
