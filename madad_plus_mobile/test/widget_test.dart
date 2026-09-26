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
    expect(find.text('Switch to provider mode'), findsOneWidget);
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

  testWidgets('a user books a plumber and accepts the repair total', (
    WidgetTester tester,
  ) async {
    await reachHome(tester);
    await tapText(tester, 'Services');

    expect(find.text('What do you need fixed?'), findsOneWidget);
    expect(find.text('AC technician'), findsNothing);
    expect(find.text('Mechanic'), findsNothing);
    expect(find.text('Painter'), findsNothing);

    await tapText(tester, 'Plumber');
    await tapText(tester, 'Book plumber');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');

    expect(find.text('Confirm your request'), findsOneWidget);
    expect(find.text('Plumber · Pipe leak'), findsOneWidget);
    expect(find.textContaining('Rs.'), findsNothing);

    await tapText(tester, 'Confirm');
    expect(find.text('Finding a plumber'), findsOneWidget);
    expect(find.text('Cancel request'), findsOneWidget);
    expect(find.text('Provider accepts'), findsNothing);
    expect(find.text('Provider arrived'), findsNothing);
    expect(find.text('Mark job as complete'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await reachHome(tester);
    await tapText(tester, 'Profile');
    await tapText(tester, 'Switch to provider mode');
    await tapText(tester, 'Pipe leak repair');
    await tapText(tester, 'Accept job');
    await tapText(tester, 'Navigate to customer');
    await tapText(tester, 'Start job');
    await tapText(tester, 'Complete job');
    expect(find.text('Waiting for the repair total.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '2000');
    await tester.pump();
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Refuse'), findsNothing);

    await tapText(tester, 'Save repair total');
    expect(find.text('Repair total: 2000'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Refuse'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tapText(tester, 'Accept');

    expect(find.text('How was John?'), findsOneWidget);

    final requestState = tester
        .element(find.text('How was John?'))
        .read<EmergencyRequestState>();
    expect(requestState.amountOwed, 'Amount owed: x + 2000');
    expect(requestState.requestId, isNull);
    expect(requestState.isRequesting, isFalse);

    await tapText(tester, 'Submit rating');
    expect(find.text('How can we help?'), findsOneWidget);

    await tapText(tester, 'Requests');
    await tapText(tester, 'Plumber · Completed');
    expect(find.text('Amount owed: x + 2000'), findsOneWidget);
  });

  testWidgets('a busy provider holds one pending job and a cancelled one stays blocked', (
    WidgetTester tester,
  ) async {
    await reachSignIn(tester);
    await tapText(tester, 'Sign in as provider');
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(find.text('Existing account'), findsOneWidget);

    await tapText(tester, 'Sign in as provider');
    await tapText(tester, 'VERIFY');

    expect(find.text('Provider dashboard'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('No upcoming jobs.'), findsOneWidget);
    expect(find.text('Home'), findsNothing);

    await tapText(tester, 'Pipe leak repair');
    expect(find.text('Customer: Hal Jordan'), findsOneWidget);

    await tapText(tester, 'Accept job');
    expect(find.text('Customer notified'), findsOneWidget);
    expect(
      find.text('Other providers no longer see this request.'),
      findsOneWidget,
    );

    await tapText(tester, 'Navigate to customer');
    expect(find.text('Active job'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('On a job'), findsOneWidget);

    await tapText(tester, 'Tap install');
    await tapText(tester, 'Accept job');
    expect(find.text('Active job'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tapText(tester, 'Pending · Tap install · Gulshan-e-Iqbal');

    expect(find.text('This provider is busy'), findsOneWidget);
    expect(find.text('Accept job'), findsNothing);

    await tapText(tester, 'Cancel');

    expect(find.text('This provider is busy'), findsNothing);
    expect(find.text('You cannot take this request again.'), findsOneWidget);
    expect(find.text('Accept job'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tapText(tester, 'Water motor');
    await tapText(tester, 'Accept job');
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(
      find.text('Pending · Water motor · Shahrah-e-Faisal'),
      findsOneWidget,
    );
  });

  testWidgets('refusing the repair total leaves only the inspection fee', (
    WidgetTester tester,
  ) async {
    await reachHome(tester);
    await tapText(tester, 'Profile');
    await tapText(tester, 'Switch to provider mode');
    await tapText(tester, 'Pipe leak repair');
    await tapText(tester, 'Accept job');
    await tapText(tester, 'Navigate to customer');

    expect(find.text('Complete job'), findsNothing);

    await tapText(tester, 'Start job');
    await tapText(tester, 'Complete job');
    await tester.enterText(find.byType(TextField), '1500');
    await tester.pump();
    await tapText(tester, 'Save repair total');
    await tapText(tester, 'Refuse');

    expect(find.text('Amount owed: x'), findsOneWidget);
    expect(find.text('Cash'), findsNothing);
    expect(find.text('JazzCash'), findsNothing);
    expect(find.text('Other'), findsNothing);

    await tapText(tester, 'Back to services');
    expect(find.text('What do you need fixed?'), findsOneWidget);

    await tapText(tester, 'Profile');
    await tapText(tester, 'Switch to provider mode');
    expect(find.text('Amount owed: x'), findsOneWidget);
    expect(find.text('No upcoming jobs.'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('How can we help?'), findsOneWidget);
  });

  testWidgets('a new provider registers with a trade and lands on the dashboard', (
    WidgetTester tester,
  ) async {
    await reachSignIn(tester);
    await tapText(tester, 'Create account');
    await tapText(tester, 'Register as Provider');

    expect(find.text('Carpenter'), findsOneWidget);
    expect(find.text('Plumber'), findsOneWidget);
    expect(find.text('Electrician'), findsOneWidget);
    expect(find.text('Ambulance number'), findsNothing);

    await tapText(tester, 'Continue');
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Register as Provider'), findsOneWidget);

    await tapText(tester, 'Continue');
    await tapText(tester, 'VERIFY');
    expect(find.text('Provider dashboard'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Existing account'), findsOneWidget);
  });
}

Future<void> reachSignIn(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.text('GET STARTED'));
  await tester.pump();
  await tester.tap(find.text('CONTINUE'));
  await tester.pump();
}

Future<void> reachHome(WidgetTester tester) async {
  await reachSignIn(tester);
  await tapText(tester, 'CONTINUE');
  await tapText(tester, 'VERIFY');
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}
