import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madad_plus_mobile/main.dart';
import 'package:madad_plus_mobile/services/emergency_request_state.dart';
import 'package:madad_plus_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

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

  testWidgets('a new driver can finish a pickup and drop-off', (
    WidgetTester tester,
  ) async {
    await reachSignIn(tester);
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.tap(find.text('Register as Driver'));
    await tester.pump();

    expect(find.text('Ambulance number'), findsOneWidget);
    expect(find.text('This wireframe accepts what you type.'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('VERIFY'));
    await tester.pump();

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('BUSY'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
    expect(find.text('Mark as Unavailable'), findsOneWidget);
    expect(find.text('Picked up'), findsOneWidget);

    await tester.tap(find.text('Picked up'));
    await tester.pump();

    expect(find.text('To hospital'), findsOneWidget);
    expect(find.text('Picked up'), findsNothing);
    expect(find.text('Reached the hospital'), findsOneWidget);

    await tester.tap(find.text('Reached the hospital'));
    await tester.pump();

    expect(find.text('Drop-off'), findsOneWidget);
    expect(find.text('Mark as Unavailable'), findsNothing);
    expect(find.text('Slide to the end to confirm.'), findsOneWidget);

    tester.widget<Slider>(find.byType(Slider)).onChanged!(1);
    await tester.pump();

    expect(find.text('Patient dropped off'), findsOneWidget);
    expect(find.text('This ambulance is free again.'), findsOneWidget);
  });

  testWidgets('unavailable then available clears the call', (
    WidgetTester tester,
  ) async {
    await reachSignIn(tester);
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.tap(find.text('Register as Driver'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('VERIFY'));
    await tester.pump();

    await tester.tap(find.text('Mark as Unavailable'));
    await tester.pump();

    expect(find.text('UNAVAILABLE'), findsOneWidget);
    expect(find.text('Mark as Available'), findsOneWidget);
    expect(find.text('Picked up'), findsNothing);
    expect(
      find.text(
        'The nearest free ambulance is sent to the address the caller typed.',
      ),
      findsOneWidget,
    );

    final requestState = tester
        .element(find.text('UNAVAILABLE'))
        .read<EmergencyRequestState>();
    expect(requestState.currentScreen, EmergencyScreen.driverJob);
    expect(requestState.requestId, isNull);
    expect(requestState.isRequesting, isFalse);

    await tester.tap(find.text('Mark as Available'));
    await tester.pump();

    expect(find.text('FREE'), findsOneWidget);
    expect(find.text('No active call'), findsOneWidget);
    expect(find.text('Mark as Unavailable'), findsOneWidget);
    expect(
      find.text('The dispatcher now sees this ambulance as FREE.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.tap(find.text('Sign in as driver'));
    await tester.pump();
    await tester.tap(find.text('VERIFY'));
    await tester.pump();
    await tester.tap(find.text('Picked up'));
    await tester.pump();
    await tester.tap(find.text('Mark as Unavailable'));
    await tester.pump();

    expect(
      find.text(
        'The nearest free ambulance is sent to this ambulance so the patient can transfer.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'The nearest free ambulance is sent to the address the caller typed.',
      ),
      findsNothing,
    );
    expect(requestState.requestId, isNull);
  });

  testWidgets('a new user reaches home and can still open ambulance', (
    WidgetTester tester,
  ) async {
    await reachSignIn(tester);
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.tap(find.text('Register as User'));
    await tester.pump();

    expect(find.text('Ambulance number'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('VERIFY'));
    await tester.pump();

    expect(find.text('How can we help?'), findsOneWidget);
    expect(find.text('Driver portal'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Emergency help'));
    await tester.pump();
    expect(find.text('Ambulance'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pump();

    final iconTheme = tester
        .widget<NavigationBarTheme>(
          find.ancestor(
            of: find.byType(NavigationBar),
            matching: find.byType(NavigationBarTheme),
          ),
        )
        .data
        .iconTheme;
    expect(
      iconTheme?.resolve({WidgetState.selected})?.color,
      AppColors.blue,
    );
    expect(
      iconTheme?.resolve({})?.color,
      AppColors.ink,
    );

    await tester.tap(find.text('Profile'));
    await tester.pump();

    expect(find.text('Hal Jordan'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.text('Saved addresses'), findsOneWidget);
    expect(find.text('Notification settings'), findsOneWidget);
    expect(find.text('Language · English'), findsOneWidget);
    expect(find.text('Driver portal'), findsOneWidget);
    expect(find.text('Switch to provider mode'), findsNothing);
    expect(find.text('Dispatcher demo'), findsNothing);
    expect(find.text('Admin demo'), findsNothing);

    await tester.tap(find.text('Saved addresses'));
    await tester.pump();
    expect(find.text('Saved addresses'), findsOneWidget);

    await tester.tap(find.text('Driver portal'));
    await tester.pump();

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('BUSY'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
  });
}

Future<void> reachSignIn(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.text('GET STARTED'));
  await tester.pump();
  await tester.tap(find.text('CONTINUE'));
  await tester.pump();
}
