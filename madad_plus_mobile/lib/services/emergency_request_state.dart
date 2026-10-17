import 'dart:async';
import 'dart:convert';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'emergency_outcome.dart';
import 'emergency_service.dart';
import 'emergency_socket_service.dart';

enum EmergencyScreen {
  splash,
  onboarding,
  login,
  otp,
  home,
  emergencyType,
  emergencyLocation,
  emergencySpeak,
  emergencyDetails,
  emergencyConfirm,
  emergencySearch,
  emergencyAssigned,
  emergencyBusy,
  emergencyEnRoute,
  emergencyApproaching,
  emergencyArrived,
  emergencyComplete,
  roleChoice,
  register,
  driverJob,
  services,
  requests,
  profile,
  tradeDetail,
  serviceDescription,
  serviceLocation,
  serviceSchedule,
  serviceConfirm,
  domesticJob,
  costReview,
  providerDashboard,
  providerRequest,
  providerAccepted,
  providerJob,
}

enum AccountPath { signIn, driver, user, provider }

enum DomesticJob {
  idle,
  searching,
  assigned,
  enRoute,
  inProgress,
  costReview,
  refused,
  complete,
}

enum ProviderDuty { offline, available, onJob }

class EmergencyRequestState extends ChangeNotifier {
  static const double demoLatitude = 24.8140;
  static const double demoLongitude = 67.0308;
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const geminiTranscribeModel = 'gemini-3.5-transcribe';
  static const geminiTextModel = 'gemini-3.5-flash';
  static const _nominatimAgent = 'MadadPlus-mobile/1.0';
  static const _incidents = {'Cardiac', 'Accident', 'Injury', 'Medical'};
  static const _closedCallStatuses = {'COMPLETED', 'CANCELLED'};

  EmergencyRequestState({
    EmergencyService? emergencyService,
    EmergencySocketService? socketService,
    String? demoUserId,
  }) : _emergencyService = emergencyService ?? EmergencyService(),
       _emergencySocketService = socketService ?? EmergencySocketService(),
       demoUserId = demoUserId ?? const String.fromEnvironment('DEMO_USER_ID');

  final EmergencyService _emergencyService;
  final EmergencySocketService _emergencySocketService;
  final String demoUserId;

  EmergencyScreen currentScreen = EmergencyScreen.splash;
  AccountPath accountPath = AccountPath.signIn;
  bool otpFromRegistration = false;
  String registerTrade = 'Plumber';

  String domesticTrade = 'Plumber';
  String domesticIssue = 'Pipe leak';
  String domesticSpecificIssue = 'Water leak';
  bool domesticPhotoAttached = false;
  String domesticDescription = '';
  String domesticAddress = '';
  DateTime? domesticScheduledAt;
  DomesticJob domesticJob = DomesticJob.idle;
  bool costFromProvider = false;
  String? savedRepairTotal;
  String? domesticNotice;
  String? amountOwed;
  final List<({String label, String owed})> domesticHistory = [];

  List<ProviderRow> providers = [];
  bool providersLoading = false;
  String? providersError;
  ProviderRow? chosenProvider;
  DomesticBooking? domesticBooking;
  bool domesticSending = false;

  ProviderDuty providerDuty = ProviderDuty.available;
  bool providerFromProfile = false;
  bool providerDemo = false;
  String? providerTrade;
  ProviderRow? providerProfile;
  List<DomesticBooking> providerJobs = [];
  bool providerJobsLoading = false;
  final Set<String> declinedJobIds = {};
  String? openedJobId;
  String? activeJobId;

  List<AmbulanceRow> driverAmbulances = [];
  String? driverId;
  String? driverAmbulanceLabel;
  String? driverAmbulanceStatus;
  EmergencyCall? driverCall;
  bool driverLoading = false;
  String? driverError;

  double? pinLatitude;
  double? pinLongitude;
  String? resolvedAddress;
  String? selectedDetail;
  int? peopleNeedingHelp;
  String? additionalDetails;
  bool detailsFromSpeech = false;
  String? detailsNotice;
  String? requestId;
  EmergencyOutcome? outcome;
  EmergencyRequestResult? result;
  String? errorMessage;
  String? hospitalName;
  String? hospitalAddress;
  String? callerMessage;
  String? hospitalError;
  int routeLeg = 0;
  double? routeFromLat;
  double? routeFromLng;
  double? routeToLat;
  double? routeToLng;
  DateTime? routeStartedAt;
  String? routeError;
  double? driverAmbulanceLat;
  double? driverAmbulanceLng;
  int remainingSeconds = 15;
  bool isRequesting = false;
  bool isCompleting = false;

  Timer? _arrivalTimer;
  Timer? _routeTimer;
  bool _socketConnected = false;

  static const _hospitalLegStatuses = {
    'PICKED_UP',
    'EN_ROUTE_HOSPITAL',
    'ARRIVED',
  };

  double routeProgress() {
    final started = routeStartedAt;
    if(started == null) {
      return 0;
    }
    final raw = DateTime.now().difference(started).inMilliseconds / 15000;
    return Curves.easeInOut.transform(raw.clamp(0.0, 1.0));
  }

  void clearRoute() {
    _routeTimer?.cancel();
    _routeTimer = null;
    routeLeg = 0;
    routeFromLat = null;
    routeFromLng = null;
    routeToLat = null;
    routeToLng = null;
    routeStartedAt = null;
    routeError = null;
  }

  void startRouteLeg({
    required int leg,
    required double? fromLat,
    required double? fromLng,
    required double? toLat,
    required double? toLng,
  }) {
    if(leg == 1 && routeLeg == 1) {
      return;
    }
    if(fromLat == null || fromLng == null || toLat == null || toLng == null) {
      clearRoute();
      routeError = 'The location was not sent.';
      notifyListeners();
      return;
    }

    _routeTimer?.cancel();
    routeLeg = leg;
    routeFromLat = fromLat;
    routeFromLng = fromLng;
    routeToLat = toLat;
    routeToLng = toLng;
    routeStartedAt = DateTime.now();
    routeError = null;
    _routeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if(routeProgress() >= 1) {
        timer.cancel();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void beginCallerLeg(EmergencyRequestResult incoming) {
    final ambulance = incoming.assignedAmbulance;
    startRouteLeg(
      leg: 1,
      fromLat: ambulance?.latitude,
      fromLng: ambulance?.longitude,
      toLat: incoming.pickupLatitude,
      toLng: incoming.pickupLongitude,
    );
  }

  void syncDriverRoute() {
    final call = driverCall;
    if(call == null) {
      return;
    }
    if(_hospitalLegStatuses.contains(call.status)) {
      if(routeLeg == 2) {
        return;
      }
      startRouteLeg(
        leg: 2,
        fromLat: call.pickupLatitude,
        fromLng: call.pickupLongitude,
        toLat: call.hospitalLatitude,
        toLng: call.hospitalLongitude,
      );
      return;
    }
    startRouteLeg(
      leg: 1,
      fromLat: call.ambulanceLatitude ?? driverAmbulanceLat,
      fromLng: call.ambulanceLongitude ?? driverAmbulanceLng,
      toLat: call.pickupLatitude,
      toLng: call.pickupLongitude,
    );
  }

  void updateRequest({
    required String requestId,
    required EmergencyOutcome outcome,
  }) {
    this.requestId = requestId;
    this.outcome = outcome;
    notifyListeners();
  }

  void goTo(EmergencyScreen screen) {
    currentScreen = screen;
    errorMessage = null;
    domesticNotice = null;
    notifyListeners();
  }

  void continueSignIn() {
    accountPath = AccountPath.signIn;
    otpFromRegistration = false;
    goTo(EmergencyScreen.otp);
  }

  void continueDriverSignIn() {
    accountPath = AccountPath.driver;
    otpFromRegistration = false;
    goTo(EmergencyScreen.otp);
  }

  void continueProviderSignIn() {
    accountPath = AccountPath.provider;
    otpFromRegistration = false;
    providerDemo = false;
    goTo(EmergencyScreen.otp);
  }

  void openProviderDemo() {
    providerDemo = true;
    providerTrade = null;
    _emergencySocketService.disconnectProvider();
    providerProfile = null;
    providerJobs = [];
    declinedJobIds.clear();
    activeJobId = null;
    openedJobId = null;
    startProviderMode(fromProfile: false, demo: true);
  }

  void chooseAccount(AccountPath path) {
    accountPath = path;
    goTo(EmergencyScreen.register);
  }

  void selectRegisterTrade(String trade) {
    registerTrade = trade;
    notifyListeners();
  }

  void continueRegistration() {
    otpFromRegistration = true;
    goTo(EmergencyScreen.otp);
  }

  void verifyCode() {
    if(accountPath == AccountPath.driver) {
      openDriverPortal();
      return;
    }

    if(accountPath == AccountPath.provider) {
      startProviderMode(fromProfile: false);
      return;
    }

    goTo(EmergencyScreen.home);
  }

  void backFromOtp() {
    if(otpFromRegistration) {
      goTo(EmergencyScreen.register);
      return;
    }

    goTo(EmergencyScreen.login);
  }

  void showDomesticNotice(String notice) {
    domesticNotice = notice;
    notifyListeners();
  }

  void openTrade(String trade) {
    domesticTrade = trade;
    domesticIssue = trade == 'Plumber' ? 'Pipe leak' : 'Other';
    domesticSpecificIssue = 'Water leak';
    domesticPhotoAttached = false;
    chosenProvider = null;
    goTo(EmergencyScreen.tradeDetail);
    loadProviders();
  }

  List<ProviderRow> get providersForTrade {
    final trade = domesticTrade.toLowerCase();
    return providers
        .where((row) => row.specialisationName?.toLowerCase() == trade)
        .toList();
  }

  List<String> get providerTradeNames {
    final names = <String>[];
    for(final provider in providers) {
      final name = provider.specialisationName;
      if(name == null || name.isEmpty) {
        continue;
      }
      final alreadyListed = names.any(
        (listed) => listed.toLowerCase() == name.toLowerCase(),
      );
      if(alreadyListed) {
        continue;
      }
      names.add(name);
    }
    return names;
  }

  List<ProviderRow> providersForSignInTrade(String trade) {
    final wanted = trade.toLowerCase();
    return providers
        .where((row) => row.specialisationName?.toLowerCase() == wanted)
        .toList();
  }

  void chooseProviderTrade(String trade) {
    providerTrade = trade;
    notifyListeners();
  }

  void clearProviderTrade() {
    providerTrade = null;
    notifyListeners();
  }

  Future<void> loadProviders() async {
    providersLoading = true;
    providersError = null;
    notifyListeners();

    try {
      providers = await _emergencyService.listProviders();
    } on ApiException catch (error) {
      providersError = error.message;
    } on TimeoutException {
      providersError = 'The provider list took too long to load. Try again.';
    } catch (_) {
      providersError = 'The provider list could not be loaded. Try again.';
    } finally {
      providersLoading = false;
      notifyListeners();
    }
  }

  void chooseProvider(ProviderRow provider) {
    chosenProvider = provider;
    notifyListeners();
  }

  void setDomesticDescription(String value) {
    domesticDescription = value;
  }

  void setDomesticAddress(String value) {
    domesticAddress = value;
    notifyListeners();
  }

  String get domesticRequestText {
    final typed = domesticDescription.trim();
    return [
      domesticIssue,
      if(domesticTrade == 'Plumber') domesticSpecificIssue,
      if(typed.isNotEmpty) typed,
    ].join(' · ');
  }

  double? get currentInspectionFee {
    return activeJob?.inspectionFee ??
        domesticBooking?.inspectionFee ??
        chosenProvider?.inspectionFee;
  }

  String get inspectionFeeText {
    final fee = currentInspectionFee;
    return fee == null ? 'x' : 'Rs. ${fee.toStringAsFixed(0)}';
  }

  void selectDomesticIssue(String issue) {
    domesticIssue = issue;
    notifyListeners();
  }

  void selectSpecificIssue(String issue) {
    domesticSpecificIssue = issue;
    notifyListeners();
  }

  void attachDomesticPhoto() {
    domesticPhotoAttached = true;
    notifyListeners();
  }

  void scheduleDomestic(DateTime? scheduledAt) {
    domesticScheduledAt = scheduledAt;
    notifyListeners();
  }

  Future<void> confirmDomestic() async {
    if(domesticSending) {
      return;
    }

    final provider = chosenProvider;
    if(demoUserId.isEmpty) {
      showDomesticNotice(
        'The demo user id is missing, so the booking was not sent. '
        'Run the app with --dart-define=DEMO_USER_ID.',
      );
      return;
    }
    if(provider == null || provider.specialisationId == null) {
      showDomesticNotice('Choose a provider before booking.');
      return;
    }

    domesticSending = true;
    domesticNotice = null;
    notifyListeners();

    try {
      final booking = await _emergencyService.createDomesticRequest(
        userId: demoUserId,
        providerId: provider.id,
        specialisationId: provider.specialisationId!,
        description: domesticRequestText,
        address: domesticAddress.trim(),
      );
      domesticBooking = booking;
      domesticJob = DomesticJob.searching;
      _emergencySocketService.connectDomestic(
        requestId: booking.requestId,
        onBooking: _receiveUserBooking,
      );
      currentScreen = EmergencyScreen.domesticJob;
    } on ApiException catch (error) {
      domesticNotice = error.message;
    } on TimeoutException {
      domesticNotice = 'The server did not answer in time. Try again.';
    } catch (_) {
      domesticNotice = 'The booking could not be sent. Try again.';
    } finally {
      domesticSending = false;
      notifyListeners();
    }
  }

  void _receiveUserBooking(DomesticBooking booking) {
    if(booking.requestId != domesticBooking?.requestId) {
      return;
    }

    domesticBooking = booking;
    if(booking.status == 'ACCEPTED' && domesticJob == DomesticJob.searching) {
      domesticJob = DomesticJob.assigned;
    }
    notifyListeners();
  }

  void cancelDomestic() {
    _emergencySocketService.disconnectDomestic();
    domesticBooking = null;
    domesticJob = DomesticJob.idle;
    goTo(EmergencyScreen.services);
  }

  void cancelAssignedProvider() {
    _finishProviderJob();
    cancelDomestic();
  }

  void trackProvider() {
    domesticJob = DomesticJob.enRoute;
    goTo(EmergencyScreen.domesticJob);
  }

  void startProviderWork() {
    domesticJob = DomesticJob.inProgress;
    notifyListeners();
  }

  void openCostReview({required bool fromProvider}) {
    savedRepairTotal = null;
    costFromProvider = fromProvider;
    domesticJob = DomesticJob.costReview;
    goTo(EmergencyScreen.costReview);
  }

  void saveRepairTotal(String total) {
    savedRepairTotal = total;
    notifyListeners();
  }

  void backFromCostReview() {
    domesticJob = DomesticJob.inProgress;
    goTo(
      costFromProvider ? EmergencyScreen.providerJob : EmergencyScreen.domesticJob,
    );
  }

  void acceptRepairTotal(String repairTotal) {
    amountOwed = 'Amount owed: $inspectionFeeText + $repairTotal';
    domesticHistory.add((label: '$domesticTrade · Completed', owed: amountOwed!));
    _finishProviderJob();
    domesticJob = DomesticJob.complete;
    goTo(EmergencyScreen.domesticJob);
  }

  void refuseRepairTotal() {
    amountOwed = 'Amount owed: $inspectionFeeText';
    domesticHistory.add(
      (label: '$domesticTrade · Inspection fee only', owed: amountOwed!),
    );
    _finishProviderJob();
    domesticJob = DomesticJob.refused;
    goTo(EmergencyScreen.domesticJob);
  }

  void finishDomestic(EmergencyScreen screen) {
    domesticJob = DomesticJob.idle;
    goTo(screen);
  }

  void startProviderMode({required bool fromProfile, bool demo = false}) {
    providerFromProfile = fromProfile;
    providerDemo = demo;
    if(providerProfile == null && !demo) {
      if(otpFromRegistration && accountPath == AccountPath.provider) {
        providerTrade = registerTrade;
      }
      else {
        providerTrade = null;
      }
    }
    if(activeJobId == null) {
      providerDuty = ProviderDuty.available;
    }
    goTo(EmergencyScreen.providerDashboard);
    if(providerProfile == null) {
      loadProviders();
    }
    else {
      loadProviderJobs();
    }
  }

  void leaveProviderMode() {
    providerDemo = false;
    providerTrade = null;
    goTo(providerFromProfile ? EmergencyScreen.home : EmergencyScreen.login);
  }

  void setProviderOnline(bool online) {
    providerDuty = online ? ProviderDuty.available : ProviderDuty.offline;
    notifyListeners();
  }

  void chooseProviderProfile(ProviderRow provider) {
    providerProfile = provider;
    providerJobs = [];
    declinedJobIds.clear();
    activeJobId = null;
    providerDuty = ProviderDuty.available;
    _emergencySocketService.connectProvider(
      providerId: provider.id,
      onBooking: _receiveProviderBooking,
    );
    loadProviderJobs();
  }

  void changeProviderProfile() {
    _emergencySocketService.disconnectProvider();
    providerProfile = null;
    providerJobs = [];
    activeJobId = null;
    providerDuty = ProviderDuty.available;
    if(!providerDemo) {
      providerTrade = null;
    }
    goTo(EmergencyScreen.providerDashboard);
    loadProviders();
  }

  Future<void> loadProviderJobs() async {
    final provider = providerProfile;
    if(provider == null) {
      return;
    }

    providerJobsLoading = true;
    notifyListeners();

    try {
      providerJobs = await _emergencyService.listProviderRequests(provider.id);
    } on ApiException catch (error) {
      domesticNotice = error.message;
    } on TimeoutException {
      domesticNotice = 'The job list took too long to load. Try again.';
    } catch (_) {
      domesticNotice = 'The job list could not be loaded. Try again.';
    } finally {
      providerJobsLoading = false;
      notifyListeners();
    }
  }

  void _receiveProviderBooking(DomesticBooking booking) {
    final index = providerJobs.indexWhere(
      (job) => job.requestId == booking.requestId,
    );
    if(index >= 0) {
      providerJobs[index] = booking;
    }
    else {
      providerJobs.insert(0, booking);
    }
    notifyListeners();
  }

  Future<void> saveInspectionFee(String typedFee) async {
    final provider = providerProfile;
    final fee = double.tryParse(typedFee.trim());
    if(provider == null) {
      return;
    }
    if(fee == null || fee < 0) {
      showDomesticNotice('Type the inspection fee as a number.');
      return;
    }

    try {
      final saved = await _emergencyService.setInspectionFee(
        providerId: provider.id,
        inspectionFee: fee,
      );
      providerProfile = provider.withFee(saved);
      providers = [
        for(final row in providers) row.id == provider.id ? row.withFee(saved) : row,
      ];
      domesticNotice = 'Inspection fee saved: Rs. ${saved.toStringAsFixed(0)}.';
    } on ApiException catch (error) {
      domesticNotice = error.message;
    } on TimeoutException {
      domesticNotice = 'The fee took too long to save. Try again.';
    } catch (_) {
      domesticNotice = 'The inspection fee could not be saved. Try again.';
    }
    notifyListeners();
  }

  List<DomesticBooking> get incomingJobs {
    return providerJobs
        .where(
          (job) => job.status == 'PENDING' && !declinedJobIds.contains(job.requestId),
        )
        .toList();
  }

  List<DomesticBooking> get acceptedJobs {
    return providerJobs.where((job) => job.status == 'ACCEPTED').toList();
  }

  DomesticBooking? _jobById(String? requestId) {
    for(final job in providerJobs) {
      if(job.requestId == requestId) {
        return job;
      }
    }
    return null;
  }

  DomesticBooking? get openedJob => _jobById(openedJobId);

  DomesticBooking? get activeJob => _jobById(activeJobId);

  void openJob(String requestId) {
    openedJobId = requestId;
    goTo(EmergencyScreen.providerRequest);
  }

  void openActiveJob(String requestId) {
    activeJobId = requestId;
    providerDuty = ProviderDuty.onJob;
    goTo(EmergencyScreen.providerJob);
  }

  void declineJob() {
    final requestId = openedJobId;
    if(requestId != null) {
      declinedJobIds.add(requestId);
    }
    goTo(EmergencyScreen.providerDashboard);
  }

  Future<void> acceptJob() async {
    final provider = providerProfile;
    final requestId = openedJobId;
    if(provider == null || requestId == null) {
      showDomesticNotice('There is no job open to accept.');
      return;
    }

    try {
      final accepted = await _emergencyService.acceptProviderRequest(
        providerId: provider.id,
        requestId: requestId,
      );
      _receiveProviderBooking(accepted);
      if(domesticBooking?.requestId == accepted.requestId) {
        domesticBooking = accepted;
      }
      activeJobId = accepted.requestId;
      providerDuty = ProviderDuty.onJob;
      domesticJob = DomesticJob.assigned;
      goTo(EmergencyScreen.providerAccepted);
    } on ApiException catch (error) {
      showDomesticNotice(error.message);
    } on TimeoutException {
      showDomesticNotice('The server did not answer in time. Try again.');
    } catch (_) {
      showDomesticNotice('The job could not be accepted. Try again.');
    }
  }

  void _finishProviderJob() {
    if(activeJobId == null) {
      return;
    }

    activeJobId = null;
    providerDuty = ProviderDuty.available;
  }

  void openDriverPortal() {
    goTo(EmergencyScreen.driverJob);
    if(driverId == null) {
      loadDriverAmbulances();
    }
    else {
      loadDriverPortal();
    }
  }

  Future<void> loadDriverAmbulances() async {
    driverLoading = true;
    driverError = null;
    notifyListeners();

    try {
      driverAmbulances = await _emergencyService.listAmbulances();
    } on ApiException catch (error) {
      driverError = error.message;
    } on TimeoutException {
      driverError = 'The ambulance list took too long to load. Try again.';
    } catch (_) {
      driverError = 'The ambulance list could not be loaded. Try again.';
    } finally {
      driverLoading = false;
      notifyListeners();
    }
  }

  void chooseDriverAmbulance(AmbulanceRow ambulance) {
    final id = ambulance.driverId;
    if(id == null) {
      driverError = '${ambulance.label} has no driver on record.';
      notifyListeners();
      return;
    }

    driverId = id;
    driverAmbulanceLabel = ambulance.label;
    driverAmbulanceStatus = ambulance.status;
    driverAmbulanceLat = ambulance.latitude;
    driverAmbulanceLng = ambulance.longitude;
    driverCall = null;
    clearRoute();
    _emergencySocketService.connectDriver(
      driverId: id,
      onCall: _receiveDriverCall,
    );
    loadDriverPortal();
  }

  void changeDriverAmbulance() {
    _emergencySocketService.disconnectDriver();
    driverId = null;
    driverAmbulanceLabel = null;
    driverAmbulanceStatus = null;
    driverAmbulanceLat = null;
    driverAmbulanceLng = null;
    driverCall = null;
    clearRoute();
    loadDriverAmbulances();
  }

  void markDriverUnavailable() {
    if(driverCall != null || driverAmbulanceStatus != 'FREE') {
      return;
    }

    driverAmbulanceStatus = 'UNAVAILABLE';
    notifyListeners();
  }

  void markDriverAvailable() {
    if(driverCall != null || driverAmbulanceStatus != 'UNAVAILABLE') {
      return;
    }

    driverAmbulanceStatus = 'FREE';
    notifyListeners();
  }

  Future<void> loadDriverPortal() async {
    final id = driverId;
    if(id == null) {
      return;
    }

    driverLoading = true;
    driverError = null;
    notifyListeners();

    try {
      final portal = await _emergencyService.loadDriverPortal(id);
      driverAmbulanceLabel = portal.ambulanceLabel ?? driverAmbulanceLabel;
      final call = portal.activeRequest;
      final openCall = call == null || _closedCallStatuses.contains(call.status)
          ? null
          : call;
      final portalStatus = portal.ambulanceStatus;
      final keepLocalFree = openCall == null
          && driverAmbulanceStatus == 'FREE'
          && portalStatus == 'UNAVAILABLE';
      if(!keepLocalFree) {
        driverAmbulanceStatus = portalStatus;
      }
      driverCall = openCall;
      syncDriverRoute();
    } on ApiException catch (error) {
      driverError = error.message;
    } on TimeoutException {
      driverError = 'The driver portal took too long to load. Try again.';
    } catch (_) {
      driverError = 'The driver portal could not be loaded. Try again.';
    } finally {
      driverLoading = false;
      notifyListeners();
    }
  }

  void _receiveDriverCall(EmergencyCall call) {
    final forThisDriver = call.assignedDriverId == driverId;
    if(forThisDriver && !_closedCallStatuses.contains(call.status)) {
      driverCall = call;
      driverAmbulanceStatus = 'BUSY';
      syncDriverRoute();
    }
    else if(driverCall?.requestId == call.requestId) {
      driverCall = null;
      clearRoute();
      if(call.status == 'COMPLETED') {
        driverAmbulanceStatus = 'FREE';
      }
    }
    notifyListeners();
  }

  Future<bool> sendDriverUpdate(String action) async {
    final id = driverId;
    final call = driverCall;
    if(id == null || call == null) {
      driverError = 'There is no active call to update.';
      notifyListeners();
      return false;
    }

    driverLoading = true;
    driverError = null;
    notifyListeners();

    try {
      final updated = await _emergencyService.updateDriverRequest(
        driverId: id,
        requestId: call.requestId,
        action: action,
      );
      if(_closedCallStatuses.contains(updated.status)) {
        driverCall = null;
        driverAmbulanceStatus = 'FREE';
        clearRoute();
      }
      else {
        driverCall = updated;
        syncDriverRoute();
      }
      return true;
    } on ApiException catch (error) {
      driverError = error.message;
    } on TimeoutException {
      driverError = 'The server did not answer in time. Try again.';
    } catch (_) {
      driverError = 'The $action update could not be sent. Try again.';
    } finally {
      driverLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> reassignDriverRequest() async {
    final id = driverId;
    final call = driverCall;
    if(id == null || call == null || driverLoading) {
      return false;
    }

    driverLoading = true;
    driverError = null;
    notifyListeners();

    try {
      final reassigned = await _emergencyService.reassignDriverRequest(
        driverId: id,
        requestId: call.requestId,
        lat: driverAmbulanceLat,
        lng: driverAmbulanceLng,
      );
      driverAmbulanceStatus = reassigned.status;
      driverCall = null;
      clearRoute();
      return true;
    } on ApiException catch (error) {
      if(error.statusCode == 404) {
        driverError =
            'This call is no longer assigned to your ambulance. Tap Refresh to see your current call.';
      }
      else if(error.statusCode == 409) {
        driverError =
            'This call can no longer be handed over. Tap Refresh to see its current status.';
      }
      else {
        driverError = error.message;
      }
    } on TimeoutException {
      driverError = 'The server did not answer in time. Try again.';
    } catch (_) {
      driverError = 'The ambulance could not be marked unavailable. Try again.';
    } finally {
      driverLoading = false;
      notifyListeners();
    }
    return false;
  }

  void selectDetail(String detail) {
    selectedDetail = detail;
    notifyListeners();
  }

  void selectPeopleNeedingHelp(int count) {
    peopleNeedingHelp = count;
    notifyListeners();
  }

  void setAdditionalDetails(String value) {
    additionalDetails = value;
  }

  void setEmergencyPin({
    required double latitude,
    required double longitude,
    required String address,
  }) {
    pinLatitude = latitude;
    pinLongitude = longitude;
    resolvedAddress = address;
    notifyListeners();
  }

  void setTestAmbulanceRequest({
    required double latitude,
    required double longitude,
    required String address,
    required String incident,
    required int people,
  }) {
    pinLatitude = latitude;
    pinLongitude = longitude;
    resolvedAddress = address;
    selectedDetail = incident;
    peopleNeedingHelp = people;
    additionalDetails = null;
    detailsFromSpeech = false;
    detailsNotice = null;
    notifyListeners();
  }

  String? takeDetailsNotice() {
    final notice = detailsNotice;
    detailsNotice = null;
    return notice;
  }

  void typeDetailsInstead() {
    selectedDetail = null;
    peopleNeedingHelp = null;
    additionalDetails = null;
    detailsFromSpeech = false;
    detailsNotice = 'Fill in what happened and how many people need help.';
    currentScreen = EmergencyScreen.emergencyDetails;
    notifyListeners();
  }

  Future<({double latitude, double longitude, String address})?> lookupAddress(
    String query,
  ) async {
    final trimmed = query.trim();
    if(trimmed.isEmpty) {
      return null;
    }

    final response = await http
        .get(
          Uri.https('nominatim.openstreetmap.org', '/search', {
            'format': 'jsonv2',
            'limit': '1',
            'q': trimmed,
          }),
          headers: {'User-Agent': _nominatimAgent},
        )
        .timeout(const Duration(seconds: 20));
    if(response.statusCode != 200) {
      throw Exception('The address lookup did not finish.');
    }

    final decoded = jsonDecode(response.body);
    if(decoded is! List || decoded.isEmpty || decoded.first is! Map) {
      return null;
    }

    final place = decoded.first as Map;
    final latitude = double.tryParse('${place['lat']}');
    final longitude = double.tryParse('${place['lon']}');
    if(latitude == null || longitude == null) {
      return null;
    }

    final name = place['display_name'];
    return (
      latitude: latitude,
      longitude: longitude,
      address: name is String && name.isNotEmpty ? name : trimmed,
    );
  }

  Future<String> labelForCoordinates(double latitude, double longitude) async {
    try {
      final response = await http
          .get(
            Uri.https('nominatim.openstreetmap.org', '/reverse', {
              'format': 'jsonv2',
              'lat': '$latitude',
              'lon': '$longitude',
            }),
            headers: {'User-Agent': _nominatimAgent},
          )
          .timeout(const Duration(seconds: 20));
      if(response.statusCode != 200) {
        return 'Current location';
      }

      final decoded = jsonDecode(response.body);
      if(decoded is Map &&
          decoded['display_name'] is String &&
          (decoded['display_name'] as String).isNotEmpty) {
        return decoded['display_name'] as String;
      }
    } catch (_) {
      return 'Current location';
    }

    return 'Current location';
  }

  Future<void> submitSpeech(List<int> bytes) async {
    if(geminiApiKey.isEmpty) {
      typeDetailsInstead();
      return;
    }

    try {
      final transcript = await _transcribeClip(bytes);
      if(transcript == null || transcript.trim().isEmpty) {
        typeDetailsInstead();
        return;
      }

      var parsed = _readSpeechJson(transcript);
      if(parsed == null) {
        final mapped = await _geminiText(geminiTextModel, [
          {
            'text':
                'Return JSON only with keys incident, people, and details. '
                'incident is Cardiac, Accident, Injury, Medical, or null. '
                'people is 1, 2, 3, 4, or null. Use 4 when four or more people need help. '
                'details is a short extra note or null. Speech: $transcript',
          },
        ]);
        if(mapped != null) {
          parsed = _readSpeechJson(mapped);
        }
      }
      if(parsed == null) {
        typeDetailsInstead();
        return;
      }

      final incident = _allowedIncident(parsed['incident']);
      final people = _allowedPeople(parsed['people']);
      final details = _allowedDetails(parsed['details']);
      selectedDetail = incident;
      peopleNeedingHelp = people;
      additionalDetails = incident == null && people == null ? null : details;
      detailsFromSpeech = incident != null || people != null;
      detailsNotice = _noticeFor(incident, people);
      currentScreen = EmergencyScreen.emergencyDetails;
      notifyListeners();
    } catch (_) {
      typeDetailsInstead();
    }
  }

  Future<void> requestAmbulance() async {
    if(isRequesting) {
      return;
    }

    final latitude = pinLatitude;
    final longitude = pinLongitude;
    final address = resolvedAddress;
    if(latitude == null || longitude == null || address == null) {
      errorMessage = 'Set a location before requesting an ambulance.';
      notifyListeners();
      return;
    }
    final description = selectedDetail;
    final peopleCount = peopleNeedingHelp;
    if(description == null || peopleCount == null) {
      errorMessage = 'Choose what happened and how many people need help.';
      notifyListeners();
      return;
    }

    _arrivalTimer?.cancel();
    _arrivalTimer = null;
    hospitalName = null;
    hospitalAddress = null;
    hospitalError = null;
    callerMessage = null;
    isRequesting = true;
    errorMessage = null;
    currentScreen = EmergencyScreen.emergencySearch;
    notifyListeners();

    try {
      result = await _emergencyService.createEmergencyRequest(
        lat: latitude,
        lng: longitude,
        address: address,
        description: description,
        peopleCount: peopleCount,
        inputMethod: detailsFromSpeech ? 'VOICE' : 'MANUAL',
        additionalDetails: additionalDetails,
      );
      updateRequest(
        requestId: result!.requestId,
        outcome: createEmergencyOutcome(result!),
      );

      if(result!.status == 'QUEUED') {
        currentScreen = EmergencyScreen.emergencyBusy;
      }
      else {
        currentScreen = EmergencyScreen.emergencyAssigned;
        beginCallerLeg(result!);
        _connectToRequest(result!.requestId);
        _startArrivalSimulation();
      }
    } on TimeoutException {
        currentScreen = EmergencyScreen.emergencyConfirm;
        errorMessage =
            'The server was asleep and is waking up now, so tap request again.';
      } on ApiException catch (error) {
        currentScreen = EmergencyScreen.emergencyConfirm;
        errorMessage = error.message;
      } catch (_) {
        currentScreen = EmergencyScreen.emergencyConfirm;
        errorMessage =
            'We could not send the emergency request. Please try again.'; 

    } finally {
      isRequesting = false;
      notifyListeners();
    }
  }

  Future<void> retryCompletion() {
    return _completeEmergencyRequest();
  }

  void reset() {
    _arrivalTimer?.cancel();
    _disconnectFromRequest();
    currentScreen = EmergencyScreen.home;
    requestId = null;
    outcome = null;
    result = null;
    errorMessage = null;
    callerMessage = null;
    hospitalName = null;
    hospitalAddress = null;
    hospitalError = null;
    clearRoute();
    driverAmbulanceLat = null;
    driverAmbulanceLng = null;
    remainingSeconds = 15;
    isRequesting = false;
    isCompleting = false;
    pinLatitude = null;
    pinLongitude = null;
    resolvedAddress = null;
    selectedDetail = null;
    peopleNeedingHelp = null;
    additionalDetails = null;
    detailsFromSpeech = false;
    detailsNotice = null;
    notifyListeners();
  }

  String? _noticeFor(String? incident, int? people) {
    if(incident == null && people == null) {
      return 'Fill in what happened and how many people need help.';
    }
    if(incident == null) {
      return 'Fill in what happened.';
    }
    if(people == null) {
      return 'Fill in how many people need help.';
    }
    return null;
  }

  String? _allowedIncident(Object? value) {
    if(value is String && _incidents.contains(value)) {
      return value;
    }
    return null;
  }

  int? _allowedPeople(Object? value) {
    final count = value is num ? value.toInt() : int.tryParse('$value');
    if(count == null || count < 1 || count > 4) {
      return null;
    }
    return count;
  }

  String? _allowedDetails(Object? value) {
    if(value is! String) {
      return null;
    }
    final trimmed = value.trim();
    if(trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }
    return trimmed;
  }

  Map<String, dynamic>? _readSpeechJson(String raw) {
    var text = raw.trim();
    if(text.startsWith('```')) {
      final firstLine = text.indexOf('\n');
      if(firstLine >= 0) {
        text = text.substring(firstLine + 1);
      }
      if(text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
      text = text.trim();
    }

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if(start < 0 || end <= start) {
      return null;
    }

    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if(decoded is Map<String, dynamic>) {
        return decoded;
      }
      if(decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<String?> _transcribeClip(List<int> bytes) async {
    final upload = await http
        .post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/upload/v1beta/files',
          ),
          headers: {
            'x-goog-api-key': geminiApiKey,
            'X-Goog-Upload-Protocol': 'raw',
            'X-Goog-Upload-Command': 'upload, finalize',
            'X-Goog-Upload-Header-Content-Length': '${bytes.length}',
            'X-Goog-Upload-Header-Content-Type': 'audio/mp4',
            'Content-Type': 'audio/mp4',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 45));
    final uploaded = upload.statusCode == 200
        ? jsonDecode(upload.body)
        : null;
    final file = uploaded is Map ? uploaded['file'] : null;
    final uri = file is Map ? file['uri'] : null;
    if(uri is! String || uri.isEmpty) {
      return null;
    }

    final response = await http
        .post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/interactions',
          ),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': geminiApiKey,
          },
          body: jsonEncode({
            'model': geminiTranscribeModel,
            'input': [
              {
                'type': 'audio',
                'uri': uri,
                'mime_type': 'audio/mp4',
              },
            ],
            'generation_config': {
              'transcription_config': {
                'language_codes': ['en-US', 'ur-PK'],
              },
            },
          }),
        )
        .timeout(const Duration(seconds: 45));
    final decodedOk = response.statusCode == 200
        ? jsonDecode(response.body)
        : null;
    if(decodedOk is! Map) {
      return null;
    }

    final outputText = decodedOk['output_text'];
    if(outputText is String && outputText.trim().isNotEmpty) {
      return outputText.trim();
    }

    final buffer = StringBuffer();
    final steps = decodedOk['steps'];
    if(steps is List) {
      for(final step in steps) {
        if(step is! Map) {
          continue;
        }
        final content = step['content'];
        if(content is! List) {
          continue;
        }
        for(final item in content) {
          if(item is Map && item['text'] is String) {
            buffer.write(item['text']);
          }
        }
      }
    }
    final text = buffer.toString().trim();
    if(text.isEmpty) {
      return null;
    }
    return text;
  }

  Future<String?> _geminiText(
    String model,
    List<Map<String, dynamic>> parts,
  ) async {
    final response = await http
        .post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
          ).replace(queryParameters: {'key': geminiApiKey}),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {'parts': parts},
            ],
          }),
        )
        .timeout(const Duration(seconds: 45));
    if(response.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if(decoded is! Map) {
      return null;
    }
    final candidates = decoded['candidates'];
    if(candidates is! List || candidates.isEmpty || candidates.first is! Map) {
      return null;
    }
    final content = (candidates.first as Map)['content'];
    if(content is! Map) {
      return null;
    }
    final responseParts = content['parts'];
    if(responseParts is! List) {
      return null;
    }

    final buffer = StringBuffer();
    for(final part in responseParts) {
      if(part is Map && part['text'] is String) {
        buffer.write(part['text']);
      }
    }
    final text = buffer.toString().trim();
    if(text.isEmpty) {
      return null;
    }
    return text;
  }

  void _connectToRequest(String id) {
    _socketConnected = true;
    _emergencySocketService.connect(
      requestId: id,
      onOutcome: (newOutcome) {
        outcome = newOutcome;
        notifyListeners();
      },
      onAssigned: (incoming) {
        if(incoming.requestId != requestId) {
          return;
        }
        result = incoming;
        beginCallerLeg(incoming);
        notifyListeners();
      },
      onPickedUp: receivePickup,
      onCallerMessage: (message, assignment) {
        receiveCallerMessage(message, assignment: assignment);
      },
      onCompleted: (_) {
        _arrivalTimer?.cancel();
        isCompleting = false;
        currentScreen = EmergencyScreen.emergencyComplete;
        _disconnectFromRequest();
        notifyListeners();
      },
    );
  }

  void receiveCallerMessage(String message, {AmbulanceAssignment? assignment}) {
    callerMessage = message;
    final current = result;
    if(assignment != null && current != null) {
      result = EmergencyRequestResult(
        requestId: current.requestId,
        status: current.status,
        assignedAmbulance: assignment,
        consideredNearest: current.consideredNearest,
        pickupLatitude: current.pickupLatitude,
        pickupLongitude: current.pickupLongitude,
      );
    }
    notifyListeners();
  }

  void receivePickup(EmergencyCall call) {
    if(call.requestId != requestId) {
      return;
    }

    final name = call.hospitalName?.trim() ?? '';
    final address = call.hospitalAddress?.trim() ?? '';
    if(name.isEmpty || address.isEmpty) {
      hospitalError = 'The ambulance picked you up, but the hospital was not sent.';
      notifyListeners();
      return;
    }

    _arrivalTimer?.cancel();
    hospitalName = name;
    hospitalAddress = address;
    hospitalError = null;
    currentScreen = EmergencyScreen.emergencyArrived;
    startRouteLeg(
      leg: 2,
      fromLat: call.pickupLatitude ?? result?.pickupLatitude,
      fromLng: call.pickupLongitude ?? result?.pickupLongitude,
      toLat: call.hospitalLatitude,
      toLng: call.hospitalLongitude,
    );
    notifyListeners();
  }

  void _startArrivalSimulation() {
    _arrivalTimer?.cancel();
    remainingSeconds = 15;
    _arrivalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds = 15 - timer.tick;

      if (remainingSeconds == 12) {
        currentScreen = EmergencyScreen.emergencyEnRoute;
      }
      else if(remainingSeconds <= 4 && remainingSeconds > 0) {
        currentScreen = EmergencyScreen.emergencyApproaching;
      }
      else if(remainingSeconds <= 0) {
        remainingSeconds = 0;
        timer.cancel();
        currentScreen = EmergencyScreen.emergencyApproaching;
        notifyListeners();
        return;
      }

      notifyListeners();
    });
  }

  Future<void> _completeEmergencyRequest() async {
    final id = requestId;
    if(id == null ||
        isCompleting && currentScreen != EmergencyScreen.emergencyArrived) {
      return;
    }

    isCompleting = true;
    errorMessage = null;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      await _emergencyService.completeEmergencyRequest(requestId: id);
      isCompleting = false;
      currentScreen = EmergencyScreen.emergencyComplete;
      _disconnectFromRequest();
    } catch (_) {
      isCompleting = false;
      errorMessage = 'The ambulance arrived, but the request could not be completed. Try again.';
    }

    notifyListeners();
  }

  void _disconnectFromRequest() {
    if(_socketConnected) {
      _emergencySocketService.disconnect();
      _socketConnected = false;
    }
  }

  @override
  void dispose() {
    _arrivalTimer?.cancel();
    _routeTimer?.cancel();
    _disconnectFromRequest();
    _emergencySocketService.disconnectDriver();
    _emergencySocketService.disconnectProvider();
    _emergencySocketService.disconnectDomestic();
    super.dispose();
  }
}
