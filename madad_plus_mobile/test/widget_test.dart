import 'package:flutter_test/flutter_test.dart';

import 'package:madad_plus_mobile/main.dart';

void main() {
  testWidgets('customer can reach the ambulance confirmation screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Madad+'), findsOneWidget);

    await tester.tap(find.text('GET STARTED'));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.tap(find.text('VERIFY'));
    await tester.pump();
    await tester.tap(find.text('Emergency help'));
    await tester.pump();
    await tester.tap(find.text('Ambulance'));
    await tester.pump();
    await tester.tap(find.text('USE DEMO LOCATION'));
    await tester.pump();
    await tester.tap(find.text('CONTINUE NOW'));
    await tester.pump();

    expect(find.text('REQUEST NOW'), findsOneWidget);
  });
}
