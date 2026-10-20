import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madad_plus_mobile/main.dart';
import 'package:madad_plus_mobile/services/emergency_outcome.dart';
import 'package:madad_plus_mobile/services/emergency_request_state.dart';
import 'package:madad_plus_mobile/services/emergency_service.dart';
import 'package:madad_plus_mobile/services/emergency_socket_service.dart';
import 'package:madad_plus_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('with no home location, use my current location asks for one', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    await reachHome(tester, session.state);

    expect(find.text('Karachi, DHA Phase 5'), findsOneWidget);
    await tapText(tester, 'Karachi, DHA Phase 5');
    expect(find.text('Where are you?'), findsOneWidget);
    expect(find.text('No saved locations yet.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Address'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tapText(tester, 'Emergency help');
    await tapText(tester, 'Ambulance');

    final findMine = tester.getTopLeft(find.text('Find my location')).dy;
    final useMine = tester.getTopLeft(find.text('Use my current location')).dy;
    final address = tester
        .getTopLeft(find.widgetWithText(TextField, 'Address'))
        .dy;
    expect(findMine < useMine, isTrue);
    expect(useMine < address, isTrue);

    await tapText(tester, 'Use my current location');
    expect(
      find.text('Set a location from the home address first.'),
      findsOneWidget,
    );
    expect(session.state.pinLatitude, isNull);
  });

  testWidgets('a saved home location shows in the title and drops the pin', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'homePlaces':
          '[{"address":"Clifton Block 5","latitude":24.8138,"longitude":67.03}]',
      'homeChosen': 'Clifton Block 5',
    });
    final session = testSession();
    await reachHome(tester, session.state);
    await pumpAsync(tester);

    expect(find.text('Clifton Block 5'), findsOneWidget);
    expect(find.text('Karachi, DHA Phase 5'), findsNothing);

    await tapText(tester, 'Emergency help');
    await tapText(tester, 'Ambulance');
    await tapText(tester, 'Use my current location');

    expect(session.state.pinLatitude, 24.8138);
    expect(session.state.pinLongitude, 67.03);
    expect(session.state.resolvedAddress, 'Clifton Block 5');
    expect(
      find.text('Set a location from the home address first.'),
      findsNothing,
    );
  });

  testWidgets('customer can reach the ambulance confirmation screen', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    await tester.pumpWidget(MyApp(requestState: session.state));

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
    session.state.setTestAmbulanceRequest(
      latitude: 24.8138,
      longitude: 67.0300,
      address: 'Clifton Block 5',
      incident: 'Accident',
      people: 2,
    );
    await tester.pump();
    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    expect(find.text('Type the details instead'), findsOneWidget);
    session.state.goTo(EmergencyScreen.emergencyDetails);
    await tester.pump();
    await tester.tap(find.text('CONTINUE NOW'));
    await tester.pump();

    expect(find.text('REQUEST NOW'), findsOneWidget);
    expect(find.text('Clifton Block 5'), findsOneWidget);
    expect(session.api.emergencyPosts, 0);
  });

  testWidgets('a driver picks a live ambulance and moves a call to drop-off', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    await reachSignIn(tester, session.state);
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.tap(find.text('Register as Driver'));
    await tester.pump();

    expect(find.text('Ambulance number'), findsOneWidget);
    expect(find.text('This wireframe accepts what you type.'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('VERIFY'));
    await pumpAsync(tester);

    expect(find.text('Choose your ambulance'), findsOneWidget);
    expect(find.text('A-01 · Sara Khan'), findsOneWidget);
    expect(find.text('DHA Phase 5, Street 12, Near XYZ Mall'), findsNothing);

    await tester.tap(find.text('A-01 · Sara Khan'));
    await pumpAsync(tester);

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('BUSY'), findsOneWidget);
    expect(find.text('Clifton Block 5'), findsOneWidget);
    expect(find.text('Accident · 2 people'), findsOneWidget);
    expect(find.text('I am burnt'), findsOneWidget);
    expect(find.text('Caller +92 300 0000000'), findsOneWidget);
    expect(find.text('Chest pain, caller +92 300 1234567'), findsNothing);
    expect(find.text('Indus Hospital, Korangi Crossing'), findsNothing);
    expect(find.text('Picked up'), findsOneWidget);
    expect(find.text('Mark as unavailable'), findsOneWidget);
    expect(find.text('Mark as available'), findsNothing);

    await tester.tap(find.text('Picked up'));
    await pumpAsync(tester);

    expect(find.text('To hospital'), findsOneWidget);
    expect(find.text('Parklane Hospital'), findsOneWidget);
    expect(find.text('Reached the hospital'), findsOneWidget);
    expect(find.text('Mark as unavailable'), findsOneWidget);
    expect(find.text('Mark as available'), findsNothing);

    await tester.tap(find.text('Reached the hospital'));
    await pumpAsync(tester);

    expect(find.text('Drop-off'), findsOneWidget);
    expect(find.text('Slide to the end to confirm.'), findsOneWidget);

    tester.widget<Slider>(find.byType(Slider)).onChanged!(1);
    await pumpAsync(tester);

    expect(find.text('Patient dropped off'), findsOneWidget);
    expect(find.text('This ambulance is free again.'), findsOneWidget);
  });

  testWidgets('a driver with no call does not see the old pickup lines', (
    WidgetTester tester,
  ) async {
    final session = testSession(withCall: false);
    await reachSignIn(tester, session.state);
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.tap(find.text('Register as Driver'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('VERIFY'));
    await pumpAsync(tester);
    await tester.tap(find.text('A-01 · Sara Khan'));
    await pumpAsync(tester);

    expect(find.text('No active call'), findsOneWidget);
    expect(find.text('No call on this ambulance.'), findsOneWidget);
    expect(find.text('DHA Phase 5, Street 12, Near XYZ Mall'), findsNothing);
    expect(find.text('Picked up'), findsNothing);
    expect(find.text('FREE'), findsOneWidget);
    expect(find.text('Mark as unavailable'), findsOneWidget);
    expect(session.state.requestId, isNull);

    await tester.ensureVisible(find.text('Mark as unavailable'));
    await tester.pump();
    await tester.tap(find.text('Mark as unavailable'));
    await tester.pump();

    expect(find.text('UNAVAILABLE'), findsOneWidget);
    expect(find.text('Mark as available'), findsOneWidget);
    expect(find.text('Mark as unavailable'), findsNothing);

    await tester.tap(find.text('Mark as available'));
    await tester.pump();

    expect(find.text('FREE'), findsOneWidget);
    expect(find.text('Mark as unavailable'), findsOneWidget);
    expect(find.text('Mark as available'), findsNothing);
  });

  testWidgets('refresh keeps a free driver free', (WidgetTester tester) async {
    final session = testSession(withCall: false);
    await reachDriverCall(tester, session.state);

    expect(find.text('FREE'), findsOneWidget);
    session.api.portalStatus = 'UNAVAILABLE';
    await tapText(tester, 'Refresh');
    await pumpAsync(tester);

    expect(find.text('FREE'), findsOneWidget);
    expect(find.text('UNAVAILABLE'), findsNothing);
    expect(find.text('Mark as unavailable'), findsOneWidget);
  });

  testWidgets('a driver on a call cancels, then confirms, mark as unavailable', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    await reachDriverCall(tester, session.state);

    await tapText(tester, 'Mark as unavailable');
    await tester.pumpAndSettle();
    expect(find.text('Mark this ambulance unavailable?'), findsOneWidget);
    expect(
      find.text(
        'This ambulance becomes unavailable and the nearest free ambulance takes this call.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(session.api.reassignCalls, 0);
    expect(find.text('BUSY'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);

    await tapText(tester, 'Mark as unavailable');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Mark as unavailable'));
    await tester.pumpAndSettle();

    expect(session.api.reassignCalls, 1);
    expect(session.api.reassignLat, isNull);
    expect(session.api.reassignLng, isNull);
    expect(find.text('UNAVAILABLE'), findsOneWidget);
    expect(find.text('No active call'), findsOneWidget);
    expect(session.state.driverCall, isNull);
    expect(find.text('Mark as available'), findsOneWidget);
  });

  testWidgets('mark as unavailable sends the ambulance location when known', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    session.api.ambulances[0] = const AmbulanceRow(
      id: 'amb-1',
      label: 'A-01',
      status: 'BUSY',
      driverId: 'drv-1',
      driverName: 'Sara Khan',
      latitude: 24.86,
      longitude: 67.0,
    );
    await reachDriverCall(tester, session.state);

    await tapText(tester, 'Mark as unavailable');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Mark as unavailable'));
    await tester.pumpAndSettle();

    expect(session.api.reassignLat, 24.86);
    expect(session.api.reassignLng, 67.0);
  });

  for(final failure in [
    (
      code: 404,
      message:
          'This call is no longer assigned to your ambulance. Tap Refresh to see your current call.',
    ),
    (
      code: 409,
      message:
          'This call can no longer be handed over. Tap Refresh to see its current status.',
    ),
  ]) {
    testWidgets('a ${failure.code} keeps the call and shows a readable message', (
      WidgetTester tester,
    ) async {
      final session = testSession();
      session.api.reassignError = ApiException(
        'Server said no.',
        statusCode: failure.code,
      );
      await reachDriverCall(tester, session.state);

      await tapText(tester, 'Mark as unavailable');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Mark as unavailable'));
      await tester.pumpAndSettle();

      expect(session.api.reassignCalls, 1);
      expect(find.text('BUSY'), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget);
      expect(session.state.driverCall, isNotNull);
      expect(find.text(failure.message), findsOneWidget);
    });
  }

  test('callerMessageFrom reads only the caller message', () {
    expect(
      callerMessageFrom({'callerMessage': 'Your ambulance has changed to A-02.'}),
      'Your ambulance has changed to A-02.',
    );
    expect(
      callerMessageFrom({'callerMessage': 'A replacement ambulance is being found.'}),
      'A replacement ambulance is being found.',
    );
    expect(callerMessageFrom({'callerMessage': '   '}), isNull);
    expect(callerMessageFrom({'requestId': 'req-1', 'status': 'ASSIGNED'}), isNull);
    expect(callerMessageFrom('Your ambulance has changed to A-02.'), isNull);
    expect(callerMessageFrom(null), isNull);
  });

  testWidgets('the caller sees the ambulance update on every trip screen', (
    WidgetTester tester,
  ) async {
    final session = testSession(withCall: false);
    session.state.result = const EmergencyRequestResult(
      requestId: 'req-1',
      status: 'ASSIGNED',
      assignedAmbulance: AmbulanceAssignment(id: 'amb-1', label: 'A-01'),
      consideredNearest: null,
    );
    await tester.pumpWidget(MyApp(requestState: session.state));
    session.state.receiveCallerMessage('Your ambulance has changed to A-02.');

    for(final screen in [
      EmergencyScreen.emergencyAssigned,
      EmergencyScreen.emergencyEnRoute,
      EmergencyScreen.emergencyApproaching,
      EmergencyScreen.emergencyArrived,
    ]) {
      session.state.goTo(screen);
      await tester.pump();
      expect(find.text('Ambulance update'), findsOneWidget);
      expect(find.text('Your ambulance has changed to A-02.'), findsOneWidget);
    }

    expect(find.text('Ambulance has arrived'), findsOneWidget);
    expect(find.text('RETURN TO HOME'), findsNothing);
    expect(find.text('BACK TO HOME'), findsNothing);

    session.state.goTo(EmergencyScreen.emergencyComplete);
    await tester.pump();
    expect(find.text('Request complete'), findsWidgets);
    await tapText(tester, 'BACK TO HOME');

    expect(find.text('How can we help?'), findsOneWidget);
    expect(session.state.callerMessage, isNull);
  });

  for(final replaced in [true, false]) {
    testWidgets(
      replaced
          ? 'about driver shows the replacement ambulance'
          : 'about driver keeps the old ambulance when none is sent',
      (WidgetTester tester) async {
        final session = testSession(withCall: false);
        session.state.result = const EmergencyRequestResult(
          requestId: 'req-1',
          status: 'ASSIGNED',
          assignedAmbulance: AmbulanceAssignment(
            id: 'amb-2',
            label: 'A-02',
            driverName: 'Hassan Ali',
            driverPhone: '+92 301 1234567',
          ),
          consideredNearest: null,
        );
        session.state.remainingSeconds = 0;
        session.state.goTo(EmergencyScreen.emergencyApproaching);
        await tester.pumpWidget(MyApp(requestState: session.state));

        final payload = <String, dynamic>{
          'requestId': 'req-1',
          'status': 'EN_ROUTE',
          'reassignmentStatus': 'ASSIGNED',
          'callerMessage': 'Your ambulance has changed to A-05.',
          if(replaced)
            'assignedAmbulance': {'id': 'new-ambulance-id', 'label': 'A-05'},
        };
        session.state.receiveCallerMessage(
          callerMessageFrom(payload)!,
          assignment: reassignedAmbulanceFrom(payload),
        );
        await tester.pump();

        expect(find.text('Your ambulance has changed to A-05.'), findsOneWidget);
        await tapText(tester, 'About driver');

        if(replaced) {
          expect(find.text('Ambulance: A-05'), findsOneWidget);
          expect(find.text('Driver: N/A'), findsOneWidget);
          expect(find.text('Phone: N/A'), findsOneWidget);
        }
        else {
          expect(find.text('Ambulance: A-02'), findsOneWidget);
          expect(find.text('Driver: Hassan Ali'), findsOneWidget);
          expect(find.text('Phone: +92 301 1234567'), findsOneWidget);
        }
      },
    );
  }

  testWidgets('a new user reaches home and can still open ambulance', (
    WidgetTester tester,
  ) async {
    final session = testSession(withCall: false);
    await reachSignIn(tester, session.state);
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
    expect(find.byIcon(Icons.person), findsNWidgets(2));
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
    await pumpAsync(tester);

    expect(find.text('Choose your ambulance'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('a missing demo user id does not post a domestic booking', (
    WidgetTester tester,
  ) async {
    final session = testSession(demoUserId: '');
    await reachHome(tester, session.state);
    await tapText(tester, 'Services');
    await tapText(tester, 'Plumber');
    await pumpAsync(tester);
    await tapText(tester, 'Karachi Plumbers');
    await tapText(tester, 'Book plumber');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Describe your service problem'),
      'Kitchen sink leak',
    );
    await tester.pump();
    await tapText(tester, 'Continue');
    session.state.setDomesticPin(
      latitude: 24.8138,
      longitude: 67.0300,
      address: 'Clifton Block 5',
    );
    await tester.pump();
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Confirm');
    await pumpAsync(tester);

    expect(
      find.textContaining('The demo user id is missing'),
      findsOneWidget,
    );
    expect(session.api.domesticPosts, 0);
    expect(find.text('Finding a plumber'), findsNothing);
  });

  testWidgets('a user books a plumber and accepts the repair total', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    await reachHome(tester, session.state);
    await tapText(tester, 'Services');

    expect(find.text('What do you need fixed?'), findsOneWidget);
    expect(find.text('AC technician'), findsNothing);
    expect(find.text('Mechanic'), findsNothing);
    expect(find.text('Painter'), findsNothing);

    await tapText(tester, 'Plumber');
    await pumpAsync(tester);
    await tapText(tester, 'Karachi Plumbers');
    await tapText(tester, 'Book plumber');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Describe your service problem'),
      'Kitchen sink leak',
    );
    await tester.pump();
    await tapText(tester, 'Continue');
    expect(find.text('Where should we send the provider?'), findsOneWidget);
    expect(find.text('Find my location'), findsOneWidget);
    expect(find.text('Show on map'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Address'), findsOneWidget);
    await tapText(tester, 'Continue');
    expect(find.text('Where should we send the provider?'), findsOneWidget);
    session.state.setDomesticPin(
      latitude: 24.8138,
      longitude: 67.0300,
      address: 'Clifton Block 5',
    );
    await tester.pump();
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');

    expect(find.text('Confirm your request'), findsOneWidget);
    expect(find.text('Plumber · Pipe leak'), findsOneWidget);
    expect(find.textContaining('Rs. 500'), findsOneWidget);

    await tapText(tester, 'Confirm');
    await pumpAsync(tester);
    expect(find.text('Finding a plumber'), findsOneWidget);
    expect(find.text('Cancel request'), findsOneWidget);
    expect(session.api.domesticPosts, 1);
    expect(find.text('Hal Jordan'), findsNothing);
    expect(find.textContaining('18 min'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    final providerSession = EmergencyRequestState(
      emergencyService: session.api,
      socketService: SilentSocketService(relay: session.api),
      demoUserId: 'user-1',
    );
    await reachHome(tester, providerSession);
    await tapText(tester, 'Profile');
    await tapText(tester, 'Switch to provider mode');
    await pumpAsync(tester);
    await tapText(tester, 'Plumber');
    await tapText(tester, 'Yes, continue');
    await pumpAsync(tester);
    await tapText(tester, 'Pipe leak · Water leak · Kitchen sink leak');
    expect(find.text('Customer: Test User'), findsOneWidget);
    expect(find.text('Customer: Hal Jordan'), findsNothing);

    await tapText(tester, 'Accept job');
    await pumpAsync(tester);
    await tapText(tester, 'Navigate to customer');
    await tapText(tester, 'Start job');
    await tapText(tester, 'Complete job');
    expect(find.text('Waiting for the repair total.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '2000');
    await tester.pump();
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Refuse'), findsNothing);

    await tapText(tester, 'Submit');
    await pumpAsync(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Refuse'), findsNothing);
    expect(find.byType(TextField), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MyApp(requestState: session.state));
    await tester.pump();
    expect(find.text('Review before payment'), findsOneWidget);
    expect(find.text('Repair total: 2000'), findsOneWidget);
    expect(find.text('Total: Rs. 2500'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tapText(tester, 'Accept');
    await pumpAsync(tester);

    expect(find.text('How was Karachi Plumbers?'), findsOneWidget);
    expect(session.state.amountOwed, 'Amount owed: Rs. 2500');
    expect(session.state.requestId, isNull);
    expect(session.state.isRequesting, isFalse);

    await tapText(tester, 'Submit rating');
    expect(find.text('How can we help?'), findsOneWidget);

    await tapText(tester, 'Requests');
    await tapText(tester, 'Plumber · Completed');
    expect(find.text('Amount owed: Rs. 2500'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MyApp(requestState: providerSession));
    await tester.pump();
    expect(find.text('Provider dashboard'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Amount owed: Rs. 2500'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('FINISHED'), findsOneWidget);
    expect(
      find.text('Accepted · Pipe leak · Water leak · Kitchen sink leak'),
      findsNothing,
    );

    await tapText(tester, 'Finished · Pipe leak · Water leak · Kitchen sink leak');
    expect(find.text('Finished job'), findsOneWidget);
    expect(find.text('Pipe leak · Water leak · Kitchen sink leak'), findsOneWidget);
    expect(find.text('Price: Rs. 2500'), findsOneWidget);
    expect(find.text('Start job'), findsNothing);
    expect(find.text('Navigate to customer'), findsNothing);
    expect(find.text('Upload photos'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Provider dashboard'), findsOneWidget);
  });

  testWidgets('a busy provider cannot take a second job until the first is done', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    session.api.seedJobs([
      session.api.booking(
        requestId: 'job-1',
        description: 'Pipe leak',
        address: 'Clifton',
      ),
      session.api.booking(
        requestId: 'job-2',
        description: 'Tap install',
        address: 'Gulshan-e-Iqbal',
      ),
    ]);
    await reachSignIn(tester, session.state);
    await tapText(tester, 'Sign in as provider');
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(find.text('Existing account'), findsOneWidget);

    await tapText(tester, 'Sign in as provider');
    await tapText(tester, 'VERIFY');
    await pumpAsync(tester);

    expect(find.text('Which provider do you want to test as?'), findsOneWidget);
    expect(find.text('What work do you do?'), findsNothing);
    expect(find.textContaining('Rs.'), findsNothing);
    await tapText(tester, 'Karachi Plumbers · Plumber');
    await pumpAsync(tester);

    expect(find.text('Provider dashboard'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);

    await tapText(tester, 'Pipe leak');
    expect(find.text('Customer: Test User'), findsOneWidget);

    await tapText(tester, 'Accept job');
    await pumpAsync(tester);
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
    expect(
      find.text('Finish the active job before taking this one.'),
      findsOneWidget,
    );
    expect(find.text('Accept job'), findsNothing);
  });

  testWidgets('refusing the repair total leaves only the inspection fee', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    await reachHome(tester, session.state);
    await tapText(tester, 'Services');
    await tapText(tester, 'Plumber');
    await pumpAsync(tester);
    await tapText(tester, 'Karachi Plumbers');
    await tapText(tester, 'Book plumber');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Describe your service problem'),
      'Kitchen sink leak',
    );
    await tester.pump();
    await tapText(tester, 'Continue');
    session.state.setDomesticPin(
      latitude: 24.8138,
      longitude: 67.0300,
      address: 'Clifton Block 5',
    );
    await tester.pump();
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Confirm');
    await pumpAsync(tester);

    await tester.pumpWidget(const SizedBox());
    final providerSession = EmergencyRequestState(
      emergencyService: session.api,
      socketService: SilentSocketService(relay: session.api),
      demoUserId: 'user-1',
    );
    await reachHome(tester, providerSession);
    await tapText(tester, 'Profile');
    await tapText(tester, 'Switch to provider mode');
    await pumpAsync(tester);
    await tapText(tester, 'Plumber');
    await tapText(tester, 'Yes, continue');
    await pumpAsync(tester);
    await tapText(tester, 'Pipe leak · Water leak · Kitchen sink leak');
    await tapText(tester, 'Accept job');
    await pumpAsync(tester);
    await tapText(tester, 'Navigate to customer');

    expect(find.text('Complete job'), findsNothing);

    await tapText(tester, 'Start job');
    await tapText(tester, 'Complete job');
    await tester.enterText(find.byType(TextField), '1500');
    await tester.pump();
    await tapText(tester, 'Submit');
    await pumpAsync(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Refuse'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MyApp(requestState: session.state));
    await tester.pump();
    expect(find.text('Total: Rs. 2000'), findsOneWidget);
    await tapText(tester, 'Refuse');
    await pumpAsync(tester);

    expect(find.text('Amount owed: Rs. 500'), findsOneWidget);
    expect(find.text('Cash'), findsNothing);
    expect(find.text('JazzCash'), findsNothing);
    expect(find.text('Other'), findsNothing);

    await tapText(tester, 'Back to services');
    expect(find.text('What do you need fixed?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MyApp(requestState: providerSession));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Amount owed: Rs. 500'), findsOneWidget);
    expect(find.text('Inspection fee: Rs. 500'), findsOneWidget);
    expect(find.text('Inspection fee: x'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Amount owed: Rs. 500'), findsOneWidget);
    expect(
      find.text('Accepted · Pipe leak · Water leak · Kitchen sink leak'),
      findsOneWidget,
    );
  });

  testWidgets('a new provider registers with a trade and confirms that business', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    await reachSignIn(tester, session.state);
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
    await pumpAsync(tester);
    expect(find.text('Is this you?'), findsOneWidget);
    expect(find.text('Your business'), findsOneWidget);
    expect(find.text('Karachi Plumbers · Plumber'), findsOneWidget);
    expect(find.text('Which provider are you?'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Existing account'), findsOneWidget);
  });

  testWidgets('the demo provider list hides fees', (WidgetTester tester) async {
    final session = testSession();
    await reachSignIn(tester, session.state);
    expect(find.text('Demo: act as a provider'), findsNothing);
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('Sign in as driver'), findsOneWidget);
    expect(find.text('Sign in as provider'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    await tapText(tester, 'Sign in as provider');
    await tapText(tester, 'VERIFY');
    await pumpAsync(tester);

    expect(find.text('Which provider do you want to test as?'), findsOneWidget);
    expect(
      find.text('Demo only. Anyone can open any provider here.'),
      findsOneWidget,
    );
    expect(find.text('Karachi Plumbers · Plumber'), findsOneWidget);
    expect(find.textContaining('Rs.'), findsNothing);
    expect(find.text('Provider dashboard'), findsNothing);
    expect(
      find.text('Requests booked with you will show up here.'),
      findsNothing,
    );
  });
}

class SilentSocketService extends EmergencySocketService {
  SilentSocketService({this.relay});

  final FakeEmergencyService? relay;

  @override
  void connectDriver({
    required String driverId,
    required void Function(EmergencyCall call) onCall,
  }) {}

  @override
  void disconnectDriver() {}

  @override
  void connectProvider({
    required String providerId,
    required void Function(DomesticBooking booking) onBooking,
  }) {
    relay?.listeners.add(onBooking);
  }

  @override
  void disconnectProvider() {}

  @override
  void connectDomestic({
    required String requestId,
    required void Function(DomesticBooking booking) onBooking,
  }) {
    relay?.listeners.add(onBooking);
  }

  @override
  void disconnectDomestic() {}

  @override
  void connect({
    required String requestId,
    required void Function(EmergencyOutcome outcome) onOutcome,
    void Function(EmergencyRequestResult result)? onAssigned,
    void Function(EmergencyCall call)? onPickedUp,
    void Function(EmergencyCompletion completion)? onCompleted,
    void Function(String message, AmbulanceAssignment? assignment)?
        onCallerMessage,
    void Function()? onDisconnected,
    void Function()? onReconnected,
  }) {}

  @override
  void disconnect() {}
}

class FakeEmergencyService extends EmergencyService {
  var emergencyPosts = 0;
  var domesticPosts = 0;
  var reassignCalls = 0;
  double? reassignLat;
  double? reassignLng;
  ApiException? reassignError;
  EmergencyCall? portalCall;
  String? portalStatus;
  final jobs = <DomesticBooking>[];
  final listeners = <void Function(DomesticBooking booking)>[];

  final ambulances = [
    const AmbulanceRow(
      id: 'amb-1',
      label: 'A-01',
      status: 'FREE',
      driverId: 'drv-1',
      driverName: 'Sara Khan',
    ),
  ];

  final providers = [
    const ProviderRow(
      id: 'prov-1',
      name: 'Karachi Plumbers',
      status: 'ONLINE',
      rating: 4.6,
      inspectionFee: 500,
      specialisationId: 'spec-plumber',
      specialisationName: 'Plumber',
    ),
  ];

  FakeEmergencyService({this.portalCall});

  DomesticBooking booking({
    required String requestId,
    required String description,
    required String address,
    String status = 'PENDING',
  }) {
    return DomesticBooking(
      requestId: requestId,
      status: status,
      description: description,
      address: address,
      userName: 'Test User',
      providerName: 'Karachi Plumbers',
      providerRating: 4.6,
      inspectionFee: 500,
      specialisationName: 'Plumber',
    );
  }

  void seedJobs(List<DomesticBooking> seeded) {
    jobs
      ..clear()
      ..addAll(seeded);
  }

  EmergencyCall callWith({
    required String status,
    String? hospitalName,
    String? hospitalAddress,
  }) {
    return EmergencyCall(
      requestId: 'req-1',
      status: status,
      pickupAddress: 'Clifton Block 5',
      emergencyDescription: 'Accident',
      peopleCount: 2,
      callerPhone: '+92 300 0000000',
      hospitalName: hospitalName,
      hospitalAddress: hospitalAddress,
      assignedDriverId: 'drv-1',
    );
  }

  @override
  Future<EmergencyRequestResult> createEmergencyRequest({
    required double lat,
    required double lng,
    required String address,
    required String description,
    required int peopleCount,
    required String inputMethod,
    String? additionalDetails,
  }) async {
    emergencyPosts += 1;
    throw ApiException('Tests must not send an emergency request.');
  }

  @override
  Future<void> completeEmergencyRequest({required String requestId}) async {}

  @override
  Future<List<AmbulanceRow>> listAmbulances() async => ambulances;

  @override
  Future<DriverPortal> loadDriverPortal(String driverId) async {
    return DriverPortal(
      driverName: 'Sara Khan',
      ambulanceLabel: 'A-01',
      ambulanceStatus: portalStatus ?? (portalCall == null ? 'FREE' : 'BUSY'),
      activeRequest: portalCall,
    );
  }

  @override
  Future<EmergencyCall> updateDriverRequest({
    required String driverId,
    required String requestId,
    required String action,
  }) async {
    if(action == 'pickup') {
      portalCall = callWith(
        status: 'PICKED_UP',
        hospitalName: 'Parklane Hospital',
        hospitalAddress: 'Clifton, Karachi',
      );
    }
    else if(action == 'hospital') {
      portalCall = callWith(
        status: 'ARRIVED',
        hospitalName: 'Parklane Hospital',
        hospitalAddress: 'Clifton, Karachi',
      );
    }
    else {
      final completed = callWith(
        status: 'COMPLETED',
        hospitalName: 'Parklane Hospital',
        hospitalAddress: 'Clifton, Karachi',
      );
      portalCall = null;
      return completed;
    }
    return portalCall!;
  }

  @override
  Future<DriverReassignment> reassignDriverRequest({
    required String driverId,
    required String requestId,
    double? lat,
    double? lng,
  }) async {
    reassignCalls += 1;
    reassignLat = lat;
    reassignLng = lng;
    final error = reassignError;
    if(error != null) {
      throw error;
    }
    portalCall = null;
    return const DriverReassignment(
      ambulanceId: 'amb-1',
      status: 'UNAVAILABLE',
      replacementRequestId: 'req-1',
      reassignmentStatus: 'ASSIGNED',
      callerMessage: 'Your ambulance has changed to A-02.',
      request: null,
    );
  }

  @override
  Future<List<ProviderRow>> listProviders() async => providers;

  @override
  Future<double> setInspectionFee({
    required String providerId,
    required double inspectionFee,
  }) async {
    return inspectionFee;
  }

  @override
  Future<DomesticBooking> createDomesticRequest({
    required String userId,
    required String providerId,
    required String specialisationId,
    required String description,
    required String address,
  }) async {
    domesticPosts += 1;
    final created = booking(
      requestId: 'dom-$domesticPosts',
      description: description,
      address: address,
    );
    jobs.add(created);
    return created;
  }

  @override
  Future<List<DomesticBooking>> listProviderRequests(String providerId) async {
    return List.of(jobs);
  }

  @override
  Future<DomesticBooking> acceptProviderRequest({
    required String providerId,
    required String requestId,
  }) async {
    final index = jobs.indexWhere((job) => job.requestId == requestId);
    final current = jobs[index];
    final accepted = DomesticBooking(
      requestId: current.requestId,
      status: 'ACCEPTED',
      description: current.description,
      address: current.address,
      userName: current.userName,
      providerName: current.providerName,
      providerRating: current.providerRating,
      inspectionFee: current.inspectionFee,
      specialisationName: current.specialisationName,
    );
    jobs[index] = accepted;
    return accepted;
  }

  DomesticBooking withReceipt(
    String requestId, {
    required String receiptStatus,
    double? quotedTotal,
    double? finalTotal,
  }) {
    final index = jobs.indexWhere((job) => job.requestId == requestId);
    final current = jobs[index];
    final updated = DomesticBooking(
      requestId: current.requestId,
      status: current.status,
      description: current.description,
      address: current.address,
      userName: current.userName,
      providerName: current.providerName,
      providerRating: current.providerRating,
      inspectionFee: current.inspectionFee,
      specialisationName: current.specialisationName,
      quotedTotal: quotedTotal ?? current.quotedTotal,
      receiptInspectionFee: current.inspectionFee,
      finalTotal: finalTotal,
      receiptStatus: receiptStatus,
    );
    jobs[index] = updated;
    for(final listener in List.of(listeners)) {
      listener(updated);
    }
    return updated;
  }

  @override
  Future<DomesticBooking> submitRepairCost({
    required String providerId,
    required String requestId,
    required double quotedTotal,
  }) async {
    return withReceipt(
      requestId,
      receiptStatus: 'NEGOTIABLE',
      quotedTotal: quotedTotal,
    );
  }

  @override
  Future<DomesticBooking> decideRepairCost({
    required String requestId,
    required bool accept,
  }) async {
    final current = jobs.firstWhere((job) => job.requestId == requestId);
    final fee = current.receiptInspectionFee ?? 0;
    return withReceipt(
      requestId,
      receiptStatus: accept ? 'ACCEPTED' : 'DECLINED',
      finalTotal: accept ? fee + (current.quotedTotal ?? 0) : fee,
    );
  }
}

class TestSession {
  TestSession({required this.api, required this.state});

  final FakeEmergencyService api;
  final EmergencyRequestState state;
}

TestSession testSession({
  String demoUserId = 'user-1',
  bool withCall = true,
}) {
  final api = FakeEmergencyService(
    portalCall: withCall
        ? EmergencyCall(
            requestId: 'req-1',
            status: 'ASSIGNED',
            pickupAddress: 'Clifton Block 5',
            emergencyDescription: 'Accident',
            peopleCount: 2,
            callerPhone: '+92 300 0000000',
            hospitalName: null,
            hospitalAddress: null,
            assignedDriverId: 'drv-1',
            additionalDetails: 'I am burnt',
          )
        : null,
  );
  return TestSession(
    api: api,
    state: EmergencyRequestState(
      emergencyService: api,
      socketService: SilentSocketService(relay: api),
      demoUserId: demoUserId,
    ),
  );
}

Future<void> pumpAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> reachSignIn(
  WidgetTester tester,
  EmergencyRequestState state,
) async {
  await tester.pumpWidget(MyApp(requestState: state));
  await tester.tap(find.text('GET STARTED'));
  await tester.pump();
  await tester.tap(find.text('CONTINUE'));
  await tester.pump();
}

Future<void> reachDriverCall(
  WidgetTester tester,
  EmergencyRequestState state,
) async {
  await reachSignIn(tester, state);
  await tester.tap(find.text('Create account'));
  await tester.pump();
  await tester.tap(find.text('Register as Driver'));
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await tester.pump();
  await tester.tap(find.text('VERIFY'));
  await pumpAsync(tester);
  await tester.tap(find.text('A-01 · Sara Khan'));
  await pumpAsync(tester);
}

Future<void> reachHome(
  WidgetTester tester,
  EmergencyRequestState state,
) async {
  await reachSignIn(tester, state);
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
