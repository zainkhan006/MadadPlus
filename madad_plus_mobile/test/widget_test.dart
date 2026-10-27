import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madad_plus_mobile/emergency_flow.dart';
import 'package:madad_plus_mobile/main.dart';
import 'package:madad_plus_mobile/services/emergency_outcome.dart';
import 'package:madad_plus_mobile/services/emergency_request_state.dart';
import 'package:madad_plus_mobile/services/emergency_service.dart';
import 'package:madad_plus_mobile/services/emergency_socket_service.dart';
import 'package:madad_plus_mobile/theme/app_theme.dart';
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

  testWidgets('saved requests show after the app restarts', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'emergencyRequests':
          '[{"id":"req-9","address":"Clifton Block 5","happened":"Accident",'
          '"people":3,"status":"COMPLETED"}]',
      'domesticHistory':
          '[{"label":"Plumber · Completed","owed":"Amount owed: Rs. 2500"}]',
    });
    final session = testSession();
    await reachHome(tester, session.state);
    await pumpAsync(tester);

    await tapText(tester, 'Requests');
    expect(find.text('Clifton Block 5'), findsOneWidget);
    expect(find.text('Accident'), findsOneWidget);
    expect(find.text('3 people'), findsOneWidget);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('No emergency request yet.'), findsNothing);

    await tapText(tester, 'Domestic');
    await tester.pumpAndSettle();
    expect(find.text('Plumber'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Amount owed'), findsOneWidget);
    expect(find.text('Rs. 2500'), findsOneWidget);
    expect(find.text('Problem'), findsNothing);
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
    await submitCallerName(tester, 'hal jordan');
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

  testWidgets('an assigned ambulance leaves the finding help spinner', (
    WidgetTester tester,
  ) async {
    final session = await reachAmbulanceRequest(tester);
    session.api.scriptedEmergencyResult = EmergencyRequestResult(
      requestId: 'req-assigned',
      status: 'ASSIGNED',
      assignedAmbulance: const AmbulanceAssignment(
        id: 'amb-1',
        label: 'A-01',
        latitude: 24.805,
        longitude: 67.0375,
      ),
      consideredNearest: null,
      pickupLatitude: 24.8138,
      pickupLongitude: 67.03,
    );

    await tapText(tester, 'REQUEST NOW');
    await pumpAsync(tester);

    expect(find.text('A-01 is coming'), findsOneWidget);
    expect(find.text('Finding help'), findsNothing);
    expect(find.text('FINDING HELP NOW'), findsNothing);
    expect(session.api.emergencyPosts, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    session.state.dispose();
  });

  testWidgets('a queued ambulance request leaves the finding help spinner', (
    WidgetTester tester,
  ) async {
    final session = await reachAmbulanceRequest(tester);
    session.api.scriptedEmergencyResult = const EmergencyRequestResult(
      requestId: 'req-queued',
      status: 'QUEUED',
      assignedAmbulance: null,
      consideredNearest: null,
    );

    await tapText(tester, 'REQUEST NOW');
    await pumpAsync(tester);

    expect(find.text('All ambulances are busy'), findsOneWidget);
    expect(find.text('Finding help'), findsNothing);
    expect(find.text('FINDING HELP NOW'), findsNothing);
    expect(session.api.emergencyPosts, 1);
  });

  testWidgets('a timed out ambulance request leaves the finding help spinner', (
    WidgetTester tester,
  ) async {
    final session = await reachAmbulanceRequest(tester);
    session.api.scriptedEmergencyError = TimeoutException(
      'The server did not answer.',
    );

    await tapText(tester, 'REQUEST NOW');
    await pumpAsync(tester);

    expect(
      find.text(
        'The server was asleep and is waking up now, so tap request again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Finding help'), findsNothing);
    expect(find.text('FINDING HELP NOW'), findsNothing);
    expect(session.api.emergencyPosts, 1);
  });

  testWidgets('sign out returns the driver to login', (WidgetTester tester) async {
    final session = testSession(withCall: false);
    await reachSignIn(tester, session.state);
    await submitStaffName(tester, 'Sign in as driver', 'Sara Khan');
    await tapText(tester, 'VERIFY');
    await pumpAsync(tester);

    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Change ambulance'), findsNothing);
    await tapText(tester, 'Sign out');
    await pumpAsync(tester);

    expect(find.text('Existing account'), findsOneWidget);
    expect(find.text('How can we help?'), findsNothing);
    expect(find.text('No active call'), findsNothing);
  });

  testWidgets('driver registration does not ask which ambulance', (
    WidgetTester tester,
  ) async {
    final session = testSession(withCall: false);
    await reachSignIn(tester, session.state);
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.tap(find.text('Register as Driver'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Zain Ali');
    await tester.enterText(
      find.widgetWithText(TextField, 'Phone number'),
      '0333 1234567',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Ambulance number'),
      'A-08',
    );
    await tester.tap(find.text('Continue'));
    await pumpAsync(tester);
    await tester.tap(find.text('VERIFY'));
    await pumpAsync(tester);

    expect(find.text('How can we help?'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
    expect(session.state.driverId, 'drv-new');
    expect(find.text('Choose your ambulance'), findsNothing);
    expect(find.text('Which ambulance are you driving?'), findsNothing);
  });

  testWidgets('Hassan Ali opens his driver page', (WidgetTester tester) async {
    final session = testSession(withCall: false);
    addHassanAli(session.api);
    await reachSignIn(tester, session.state);
    await submitStaffName(tester, 'Sign in as driver', 'Hassan Ali');

    expect(find.text('Verify phone'), findsOneWidget);
    await tapText(tester, 'VERIFY');
    await pumpAsync(tester);

    expect(find.text('No active call'), findsOneWidget);
    expect(find.text('Choose your ambulance'), findsNothing);
  });

  testWidgets('a driver name matches without matching capitals', (
    WidgetTester tester,
  ) async {
    final session = testSession(withCall: false);
    session.api.ambulances.add(
      const AmbulanceRow(
        id: 'amb-7',
        label: 'A-07',
        status: 'BUSY',
        driverId: 'drv-7',
        driverName: 'Fahad Iqbal',
      ),
    );
    await reachSignIn(tester, session.state);
    await submitStaffName(tester, 'Sign in as driver', 'fahad iqbal');

    expect(find.text('Verify phone'), findsOneWidget);
    expect(
      find.text('Nobody was found with that name or number.'),
      findsNothing,
    );
  });

  testWidgets('a provider name matches without matching capitals', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    await reachSignIn(tester, session.state);
    await submitStaffName(tester, 'Sign in as provider', 'karachi plumbers');

    expect(find.text('Verify phone'), findsOneWidget);
    expect(
      find.text('Nobody was found with that name or number.'),
      findsNothing,
    );
  });

  testWidgets('Hassan Ali phone opens his driver page', (
    WidgetTester tester,
  ) async {
    final session = testSession(withCall: false);
    addHassanAli(session.api);
    await reachSignIn(tester, session.state);
    await submitStaffName(tester, 'Sign in as driver', '+92 301 1234567');

    expect(find.text('Verify phone'), findsOneWidget);
    await tapText(tester, 'VERIFY');
    await pumpAsync(tester);

    expect(find.text('No active call'), findsOneWidget);
    expect(find.text('Choose your ambulance'), findsNothing);
  });

  testWidgets('an unknown staff name stays on the name page', (
    WidgetTester tester,
  ) async {
    final session = testSession(withCall: false);
    await reachSignIn(tester, session.state);
    await submitStaffName(tester, 'Sign in as driver', 'Nobody');

    expect(
      find.text('Nobody was found with that name or number.'),
      findsOneWidget,
    );
    expect(find.text('Name or phone number'), findsOneWidget);
    expect(find.text('Verify phone'), findsNothing);
    expect(find.text('Choose your ambulance'), findsNothing);
  });

  testWidgets('a caller name matches without matching capitals', (
    WidgetTester tester,
  ) async {
    final session = testSession(withCall: false);
    await reachSignIn(tester, session.state);
    await submitCallerName(tester, 'hal jordan');

    expect(find.text('Verify phone'), findsOneWidget);
    expect(
      find.text(
        'Nobody was found with that name or number. Type the name you registered with, or your phone number.',
      ),
      findsNothing,
    );
  });

  testWidgets('an unknown caller name stays on the sign-in page', (
    WidgetTester tester,
  ) async {
    final session = testSession(withCall: false);
    await reachSignIn(tester, session.state);
    await submitCallerName(tester, 'Nobody');

    expect(
      find.text(
        'Nobody was found with that name or number. Type the name you registered with, or your phone number.',
      ),
      findsOneWidget,
    );
    expect(find.text('Verify phone'), findsNothing);
  });

  testWidgets('a driver picks a live ambulance and moves a call to drop-off', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    await reachSignIn(tester, session.state);
    await submitStaffName(tester, 'Sign in as driver', 'Sara Khan');
    await tapText(tester, 'VERIFY');
    await pumpAsync(tester);

    expect(find.text('Choose your ambulance'), findsNothing);
    expect(find.text('Which ambulance are you driving?'), findsNothing);

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('BUSY'), findsOneWidget);
    expect(find.text('Clifton Block 5'), findsOneWidget);
    expect(find.text('2 people still waiting'), findsOneWidget);
    expect(find.text('Accident'), findsOneWidget);
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
    expect(find.text('Parklane Hospital, Clifton, Karachi'), findsOneWidget);
    expect(find.text('Patient is on board'), findsOneWidget);
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
    await submitStaffName(tester, 'Sign in as driver', 'Sara Khan');
    await tapText(tester, 'VERIFY');
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

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ibad Khan');
    await tester.enterText(
      find.widgetWithText(TextField, 'Phone number'),
      '0332 6767679',
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
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

    expect(find.text('Ibad Khan'), findsOneWidget);
    expect(find.text('Hal Jordan'), findsNothing);
    expect(find.byIcon(Icons.person), findsNWidgets(2));
    expect(find.text('Saved addresses'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Notification settings'), findsNothing);
    expect(find.text('Language · English'), findsNothing);
    expect(find.text('Driver portal'), findsNothing);
    expect(find.text('Switch to provider mode'), findsNothing);
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
    session.api.callers
      ..clear()
      ..add(
        const CallerRow(
          id: '',
          name: 'Hal Jordan',
          phone: '+92 300 0000001',
        ),
      );
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

  testWidgets('a saved home drops the provider pin', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    await openProviderLocation(tester, session.state);
    await tapText(tester, 'Use my current location');
    expect(
      find.text('Set a location from the home address first.'),
      findsOneWidget,
    );
    expect(find.text('Where should we send the provider?'), findsOneWidget);
    expect(session.state.domesticPinLatitude, isNull);

    SharedPreferences.setMockInitialValues({
      'homePlaces':
          '[{"address":"Clifton Block 5","latitude":24.8138,"longitude":67.03}]',
      'homeChosen': 'Clifton Block 5',
    });
    final saved = testSession();
    await openProviderLocation(tester, saved.state);
    await pumpAsync(tester);
    await tapText(tester, 'Use my current location');
    expect(saved.state.domesticPinLatitude, 24.8138);
    expect(saved.state.domesticPinLongitude, 67.03);
    expect(saved.state.domesticAddress, 'Clifton Block 5');
    expect(
      find.text('Set a location from the home address first.'),
      findsNothing,
    );
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
    final requestType = tester.widget<Text>(find.text('Pipe leak'));
    final requestNote = tester.widget<Text>(
      find.text('Water leak\nKitchen sink leak'),
    );
    expect(requestType.style?.fontWeight, FontWeight.w700);
    expect(requestNote.style?.fontWeight, FontWeight.w400);
    expect(requestNote.style?.fontFamily, requestType.style?.fontFamily);
    expect(requestNote.style?.fontSize, requestType.style?.fontSize);
    await tapText(tester, 'Pipe leak');
    expect(find.text('Customer: Test User'), findsOneWidget);
    expect(find.text('Customer: Hal Jordan'), findsNothing);

    await tapText(tester, 'Accept job');
    await pumpAsync(tester);
    await tapText(tester, 'Start job');
    await tapText(tester, 'Complete job');
    expect(find.text('Waiting for the repair total.'), findsOneWidget);

    await fillPart(tester, 0, 'Pipe joint', '2000');
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
    expect(find.text('No emergency request yet.'), findsOneWidget);
    await tapText(tester, 'Domestic');
    await tester.pumpAndSettle();
    expect(find.text('Plumber'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Pipe leak'), findsOneWidget);
    expect(find.text('Water leak'), findsOneWidget);
    expect(find.text('Kitchen sink leak'), findsOneWidget);
    expect(find.text('Clifton Block 5'), findsOneWidget);
    expect(find.text('Amount owed'), findsOneWidget);
    expect(find.text('Rs. 2500'), findsOneWidget);
    expect(find.text('No domestic request yet.'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MyApp(requestState: providerSession));
    await tester.pump();
    expect(find.text('Provider dashboard'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Amount owed: Rs. 2500'), findsNothing);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('FINISHED'), findsOneWidget);
    expect(
      find.text('Accepted · Pipe leak · Water leak · Kitchen sink leak'),
      findsNothing,
    );

    final finishedType = tester.widget<Text>(find.text('Pipe leak'));
    final finishedNote = tester.widget<Text>(
      find.text('Water leak\nKitchen sink leak'),
    );
    expect(finishedType.style?.fontWeight, FontWeight.w600);
    expect(finishedNote.style?.fontWeight, FontWeight.w400);
    expect(finishedNote.style?.height, 1.5);
    expect(finishedNote.style?.fontFamily, finishedType.style?.fontFamily);
    expect(finishedNote.style?.fontSize, finishedType.style?.fontSize);
    await tapText(tester, 'Pipe leak');
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

    await submitStaffName(tester, 'Sign in as provider', 'Karachi Plumbers');
    await tapText(tester, 'VERIFY');
    await pumpAsync(tester);

    expect(find.text('Provider dashboard'), findsOneWidget);
    expect(find.text('Select a provider to test.'), findsNothing);
    expect(find.text('Demo: act as a provider'), findsNothing);
    expect(find.text('What work do you do?'), findsNothing);
    expect(find.text('Available'), findsOneWidget);

    await tapText(tester, 'Pipe leak');
    expect(find.text('Customer: Test User'), findsOneWidget);

    await tapText(tester, 'Accept job');
    await pumpAsync(tester);
    expect(find.text('Clifton'), findsOneWidget);
    expect(find.text('Pipe leak'), findsOneWidget);
    expect(find.text('Note'), findsNothing);
    expect(find.text('Customer notified'), findsNothing);

    await tapText(tester, 'Start job');
    expect(find.text('Active job'), findsOneWidget);
    expect(find.text('Provider notes'), findsOneWidget);
    expect(find.text('Upload photos'), findsOneWidget);
    expect(find.text('Complete job'), findsOneWidget);
    expect(session.state.domesticJob, DomesticJob.inProgress);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('On a job'), findsOneWidget);
    expect(find.text("TODAY'S JOBS"), findsNothing);
    expect(find.text('FINISHED'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('No finished jobs.'), findsOneWidget);
    expect(find.text('Ongoing'), findsNothing);

    await tapText(tester, 'Tap install');
    expect(
      find.text('Finish the active job before taking this one.'),
      findsOneWidget,
    );
    expect(find.text('Accept job'), findsNothing);
  });

  testWidgets('part prices add up and send only the parts total', (
    WidgetTester tester,
  ) async {
    final session = testSession();
    session.api.seedJobs([
      DomesticBooking(
        requestId: 'job-1',
        status: 'PENDING',
        description: 'Other · ac',
        address: 'Clifton',
        userName: 'Test User',
        providerName: 'Karachi Plumbers',
        providerRating: 4.6,
        inspectionFee: 2500,
        specialisationName: 'Electrician',
      ),
      DomesticBooking(
        requestId: 'job-done',
        status: 'ACCEPTED',
        description: 'Pipe leak · Kitchen sink leak',
        address: 'DHA',
        userName: 'Test User',
        providerName: 'Karachi Plumbers',
        providerRating: 4.6,
        inspectionFee: 500,
        specialisationName: 'Plumber',
        receiptStatus: 'ACCEPTED',
        finishedAt: DateTime.now(),
      ),
      DomesticBooking(
        requestId: 'job-declined',
        status: 'ACCEPTED',
        description: 'Fan · humming',
        address: 'DHA',
        userName: 'Test User',
        providerName: 'Karachi Plumbers',
        providerRating: 4.6,
        inspectionFee: 650,
        specialisationName: 'Electrician',
        receiptStatus: 'DECLINED',
        finalTotal: 650,
        finishedAt: DateTime.now(),
      ),
      DomesticBooking(
        requestId: 'job-undated',
        status: 'ACCEPTED',
        description: 'Wire · loose',
        address: 'DHA',
        userName: 'Test User',
        providerName: 'Karachi Plumbers',
        providerRating: 4.6,
        inspectionFee: 500,
        specialisationName: 'Electrician',
        receiptStatus: 'ACCEPTED',
      ),
    ]);
    await reachSignIn(tester, session.state);
    await submitStaffName(tester, 'Sign in as provider', 'Karachi Plumbers');
    await tapText(tester, 'VERIFY');
    await pumpAsync(tester);
    final requestType = tester.widget<Text>(find.text('Other'));
    final requestNote = tester.widget<Text>(find.text('ac'));
    expect(requestType.style?.fontWeight, FontWeight.w700);
    expect(requestNote.style?.fontWeight, FontWeight.w400);
    expect(requestNote.style?.fontFamily, requestType.style?.fontFamily);
    expect(requestNote.style?.fontSize, requestType.style?.fontSize);
    final finishedType = tester.widget<Text>(find.text('Pipe leak'));
    final finishedNote = tester.widget<Text>(find.text('Kitchen sink leak'));
    expect(finishedType.style?.fontWeight, FontWeight.w600);
    expect(finishedNote.style?.fontWeight, FontWeight.w400);
    expect(finishedNote.style?.height, 1.5);
    expect(finishedNote.style?.fontFamily, finishedType.style?.fontFamily);
    expect(finishedNote.style?.fontSize, finishedType.style?.fontSize);
    expect(find.text('Wire'), findsOneWidget);
    expect(find.text(fullDateLabel(DateTime.now())), findsNWidgets(3));
    expect(find.text('Accepted'), findsNothing);
    expect(find.text('Finished'), findsNWidgets(3));
    final finishedStatus = tester.widget<Text>(find.text('Finished').first);
    expect(finishedStatus.style?.color, AppColors.green);
    await tapText(tester, 'Fan');
    expect(find.text('Finished job'), findsOneWidget);
    expect(find.text('Start job'), findsNothing);
    expect(find.text('Price: Rs. 650'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    final clock = find.byIcon(Icons.access_time_rounded);
    await tester.ensureVisible(clock);
    await tester.pump();
    await tester.tap(clock);
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(find.byKey(const Key('finished-next-day'))).onPressed,
      isNull,
    );
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();
    expect(
      tester.widget<IconButton>(find.byKey(const Key('finished-next-day'))).onPressed,
      isNotNull,
    );
    await tapText(tester, 'OK');
    await tester.pumpAndSettle();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    expect(find.text(finishedDayLabel(yesterday)), findsOneWidget);
    expect(find.text('Pipe leak'), findsNothing);
    expect(find.text('Fan'), findsNothing);
    expect(find.text('Wire'), findsNothing);
    expect(find.text('No finished jobs.'), findsOneWidget);
    await tapText(tester, 'Other');
    await tapText(tester, 'Accept job');
    await pumpAsync(tester);

    expect(find.text('Other'), findsOneWidget);
    expect(find.text('ac'), findsOneWidget);

    await tapText(tester, 'Start job');
    await tapText(tester, 'Complete job');
    expect(find.text('Repair total'), findsNothing);
    expect(find.text('Inspection fee: Rs. 2500'), findsOneWidget);
    final feeTop = tester.getTopLeft(find.text('Inspection fee: Rs. 2500')).dy;
    final rowTop = tester
        .getTopLeft(find.widgetWithText(TextField, 'Component').first)
        .dy;
    expect(feeTop < rowTop, isTrue);

    await fillPart(tester, 0, 'Capacitor', '100');
    await tester.enterText(find.widgetWithText(TextField, 'Component').at(1), 'Fan');
    await tester.pump();
    expect(find.text('Submit'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Price').at(1), '250');
    await tester.pump();
    expect(find.text('Parts total: Rs. 350'), findsOneWidget);
    expect(find.text('Final total: Rs. 2850'), findsOneWidget);

    await tapText(tester, 'Submit');
    await pumpAsync(tester);
    expect(session.api.jobs.first.quotedTotal, 350);
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
    await tapText(tester, 'Pipe leak');
    await tapText(tester, 'Accept job');
    await pumpAsync(tester);

    expect(find.text('Complete job'), findsNothing);

    await tapText(tester, 'Start job');
    await tapText(tester, 'Complete job');
    await fillPart(tester, 0, 'Pipe joint', '1500');
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
    expect(find.text('Amount owed: Rs. 500'), findsNothing);
    expect(find.text('Inspection fee: Rs. 500'), findsOneWidget);
    expect(find.text('Inspection fee: x'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Amount owed: Rs. 500'), findsNothing);
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

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Raja circuitry and electrical works',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Phone number'),
      '0334 7654321',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'CNIC'),
      '42101-6969679-1',
    );
    await tapText(tester, 'Electrician');
    await tapText(tester, 'Continue');
    await pumpAsync(tester);
    await tapText(tester, 'VERIFY');
    await pumpAsync(tester);
    expect(find.text('Provider dashboard'), findsOneWidget);
    expect(find.text('Raja circuitry and electrical works'), findsOneWidget);
    expect(find.text('Is this you?'), findsNothing);
    expect(find.text('Kashif electric wala · Electrician'), findsNothing);
  });

  testWidgets('the demo provider list hides fees', (WidgetTester tester) async {
    final session = testSession();
    await reachSignIn(tester, session.state);
    expect(find.text('Demo: act as a provider'), findsNothing);
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('Sign in as driver'), findsOneWidget);
    expect(find.text('Sign in as provider'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    await submitStaffName(tester, 'Sign in as provider', 'Karachi Plumbers');
    await tapText(tester, 'VERIFY');
    await pumpAsync(tester);

    expect(find.text('Provider dashboard'), findsOneWidget);
    expect(find.text('Karachi Plumbers'), findsOneWidget);
    expect(find.text('Select a provider to test.'), findsNothing);
    expect(find.text('Demo: act as a provider'), findsNothing);
    expect(
      find.text('Demo only. Anyone can open any provider here.'),
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
  EmergencyRequestResult? scriptedEmergencyResult;
  Exception? scriptedEmergencyError;

  final ambulances = [
    const AmbulanceRow(
      id: 'amb-1',
      label: 'A-01',
      status: 'FREE',
      driverId: 'drv-1',
      driverName: 'Sara Khan',
    ),
  ];

  final callers = [
    const CallerRow(
      id: 'user-demo',
      name: 'Hal Jordan',
      phone: '+92 300 0000001',
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
    final error = scriptedEmergencyError;
    if(error != null) {
      scriptedEmergencyError = null;
      throw error;
    }
    final scripted = scriptedEmergencyResult;
    if(scripted != null) {
      scriptedEmergencyResult = null;
      return scripted;
    }
    throw ApiException('Tests must not send an emergency request.');
  }

  @override
  Future<void> completeEmergencyRequest({required String requestId}) async {}

  @override
  Future<List<AmbulanceRow>> listAmbulances() async => ambulances;

  @override
  Future<String> setDriverAvailability({
    required String driverId,
    required bool available,
  }) async {
    return available ? 'FREE' : 'UNAVAILABLE';
  }

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
  Future<List<CallerRow>> listCallers() async => callers;

  @override
  Future<ProviderRow> registerProvider({
    required String name,
    required String phone,
    required String cnic,
    required String trade,
  }) async {
    final created = ProviderRow(
      id: 'prov-new',
      name: name,
      status: 'ONLINE',
      rating: 0,
      inspectionFee: 0,
      specialisationId: 'spec-new',
      specialisationName: trade,
      phone: phone,
    );
    providers.add(created);
    return created;
  }

  @override
  Future<AmbulanceRow> registerDriver({
    required String name,
    required String phone,
    required String ambulanceLabel,
  }) async {
    return AmbulanceRow(
      id: 'amb-new',
      label: ambulanceLabel.toUpperCase(),
      status: 'FREE',
      driverId: 'drv-new',
      driverName: name,
      driverPhone: phone,
      latitude: 24.86,
      longitude: 67.05,
    );
  }

  @override
  Future<CallerRow> registerCaller({
    required String name,
    required String phone,
  }) async {
    final created = CallerRow(id: 'user-new', name: name, phone: phone);
    callers.add(created);
    return created;
  }

  @override
  Future<List<ProviderRow>> listProviders() async => providers;

  @override
  Future<double> setProviderRating({
    required String providerId,
    required int rating,
  }) async {
    final index = providers.indexWhere((row) => row.id == providerId);
    if(index == -1) {
      return rating.toDouble();
    }
    final current = providers[index];
    final saved = ((current.rating + rating) / 2 * 10).round() / 10;
    providers[index] = current.withRating(saved);
    return saved;
  }

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
      finishedAt: current.finishedAt,
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

Future<TestSession> reachAmbulanceRequest(WidgetTester tester) async {
  final session = testSession();
  await tester.pumpWidget(MyApp(requestState: session.state));
  await tester.tap(find.text('GET STARTED'));
  await tester.pump();
  await tester.tap(find.text('CONTINUE'));
  await tester.pump();
  await submitCallerName(tester, 'hal jordan');
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
  session.state.goTo(EmergencyScreen.emergencyDetails);
  await tester.pump();
  await tester.tap(find.text('CONTINUE NOW'));
  await tester.pump();
  expect(find.text('REQUEST NOW'), findsOneWidget);
  return session;
}

void addHassanAli(FakeEmergencyService api) {
  api.ambulances.add(
    const AmbulanceRow(
      id: 'amb-2',
      label: 'A-02',
      status: 'FREE',
      driverId: 'drv-2',
      driverName: 'Hassan Ali',
      driverPhone: '+92 301 1234567',
    ),
  );
}

Future<void> submitStaffName(
  WidgetTester tester,
  String link,
  String name,
) async {
  await tapText(tester, link);
  await tester.enterText(
    find.widgetWithText(TextField, 'Name or phone number'),
    name,
  );
  await tester.pump();
  await tapText(tester, 'CONTINUE');
  await pumpAsync(tester);
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
  await submitStaffName(tester, 'Sign in as driver', 'Sara Khan');
  await tester.tap(find.text('VERIFY'));
  await pumpAsync(tester);
}

Future<void> fillPart(
  WidgetTester tester,
  int row,
  String component,
  String price,
) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Component').at(row),
    component,
  );
  await tester.enterText(find.widgetWithText(TextField, 'Price').at(row), price);
  await tester.pump();
}

Future<void> openProviderLocation(
  WidgetTester tester,
  EmergencyRequestState state,
) async {
  await reachHome(tester, state);
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
}

Future<void> submitCallerName(WidgetTester tester, String name) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Name or phone number'),
    name,
  );
  await tester.pump();
  await tapText(tester, 'CONTINUE');
  await pumpAsync(tester);
}

Future<void> reachHome(
  WidgetTester tester,
  EmergencyRequestState state,
) async {
  await reachSignIn(tester, state);
  await submitCallerName(tester, 'hal jordan');
  await tapText(tester, 'VERIFY');
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}
