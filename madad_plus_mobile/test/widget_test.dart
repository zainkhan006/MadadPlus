import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madad_plus_mobile/main.dart';
import 'package:madad_plus_mobile/services/emergency_outcome.dart';
import 'package:madad_plus_mobile/services/emergency_request_state.dart';
import 'package:madad_plus_mobile/services/emergency_service.dart';
import 'package:madad_plus_mobile/services/emergency_socket_service.dart';
import 'package:madad_plus_mobile/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
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
    expect(find.text('Caller +92 300 0000000'), findsOneWidget);
    expect(find.text('Chest pain, caller +92 300 1234567'), findsNothing);
    expect(find.text('Indus Hospital, Korangi Crossing'), findsNothing);
    expect(find.text('Picked up'), findsOneWidget);

    await tester.tap(find.text('Picked up'));
    await pumpAsync(tester);

    expect(find.text('To hospital'), findsOneWidget);
    expect(find.text('Parklane Hospital'), findsOneWidget);
    expect(find.text('Reached the hospital'), findsOneWidget);

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
    expect(session.state.requestId, isNull);
  });

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
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      'Clifton Block 5',
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
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      'Clifton Block 5',
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
      socketService: SilentSocketService(),
      demoUserId: 'user-1',
    );
    await reachHome(tester, providerSession);
    await tapText(tester, 'Profile');
    await tapText(tester, 'Switch to provider mode');
    await pumpAsync(tester);
    await tapText(tester, 'Karachi Plumbers · Plumber');
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

    await tapText(tester, 'Save repair total');
    expect(find.text('Repair total: 2000'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Refuse'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tapText(tester, 'Accept');

    expect(find.text('How was Karachi Plumbers?'), findsOneWidget);

    final requestState = tester
        .element(find.text('How was Karachi Plumbers?'))
        .read<EmergencyRequestState>();
    expect(requestState.amountOwed, 'Amount owed: Rs. 500 + 2000');
    expect(requestState.requestId, isNull);
    expect(requestState.isRequesting, isFalse);

    await tapText(tester, 'Submit rating');
    expect(find.text('How can we help?'), findsOneWidget);

    await tapText(tester, 'Requests');
    await tapText(tester, 'Plumber · Completed');
    expect(find.text('Amount owed: Rs. 500 + 2000'), findsOneWidget);
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

    expect(find.text('Which provider are you?'), findsOneWidget);
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
    session.api.seedJobs([
      session.api.booking(
        requestId: 'job-1',
        description: 'Pipe leak',
        address: 'Clifton',
      ),
    ]);
    await reachHome(tester, session.state);
    await tapText(tester, 'Profile');
    await tapText(tester, 'Switch to provider mode');
    await pumpAsync(tester);
    await tapText(tester, 'Karachi Plumbers · Plumber');
    await pumpAsync(tester);
    await tapText(tester, 'Pipe leak');
    await tapText(tester, 'Accept job');
    await pumpAsync(tester);
    await tapText(tester, 'Navigate to customer');

    expect(find.text('Complete job'), findsNothing);

    await tapText(tester, 'Start job');
    await tapText(tester, 'Complete job');
    await tester.enterText(find.byType(TextField), '1500');
    await tester.pump();
    await tapText(tester, 'Save repair total');
    await tapText(tester, 'Refuse');

    expect(find.text('Amount owed: Rs. 500'), findsOneWidget);
    expect(find.text('Cash'), findsNothing);
    expect(find.text('JazzCash'), findsNothing);
    expect(find.text('Other'), findsNothing);

    await tapText(tester, 'Back to services');
    expect(find.text('What do you need fixed?'), findsOneWidget);

    await tapText(tester, 'Profile');
    await tapText(tester, 'Switch to provider mode');
    expect(find.text('Amount owed: Rs. 500'), findsOneWidget);
    expect(find.text('Accepted · Pipe leak'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('How can we help?'), findsOneWidget);
  });

  testWidgets('a new provider registers with a trade and lands on the dashboard', (
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
    expect(find.text('Which provider are you?'), findsOneWidget);
    expect(find.text('Provider dashboard'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Existing account'), findsOneWidget);
  });
}

class SilentSocketService extends EmergencySocketService {
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
  }) {}

  @override
  void disconnectProvider() {}

  @override
  void connectDomestic({
    required String requestId,
    required void Function(DomesticBooking booking) onBooking,
  }) {}

  @override
  void disconnectDomestic() {}

  @override
  void connect({
    required String requestId,
    required void Function(EmergencyOutcome outcome) onOutcome,
    void Function(EmergencyCompletion completion)? onCompleted,
    void Function()? onDisconnected,
    void Function()? onReconnected,
  }) {}

  @override
  void disconnect() {}
}

class FakeEmergencyService extends EmergencyService {
  var emergencyPosts = 0;
  var domesticPosts = 0;
  EmergencyCall? portalCall;
  final jobs = <DomesticBooking>[];

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
      ambulanceStatus: portalCall == null ? 'FREE' : 'BUSY',
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
          )
        : null,
  );
  return TestSession(
    api: api,
    state: EmergencyRequestState(
      emergencyService: api,
      socketService: SilentSocketService(),
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
