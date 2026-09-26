import 'dart:async';

import 'package:flutter/foundation.dart';

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

  EmergencyRequestState({EmergencyService? emergencyService})
    : _emergencyService = emergencyService ?? EmergencyService();

  final EmergencyService _emergencyService;
  final EmergencySocketService _emergencySocketService =
      EmergencySocketService();

  static const demoRequests = [
    (
      title: 'Pipe leak repair',
      issue: 'Pipe leak',
      area: 'DHA Phase 5',
      address: 'DHA Phase 5, Street 12',
      location: 'DHA Phase 5, Street 12 · Near XYZ Mall',
    ),
    (
      title: 'Tap install',
      issue: 'Tap install',
      area: 'Gulshan-e-Iqbal',
      address: 'Gulshan-e-Iqbal',
      location: 'Gulshan-e-Iqbal',
    ),
    (
      title: 'Water motor',
      issue: 'Water motor',
      area: 'Shahrah-e-Faisal',
      address: 'Shahrah-e-Faisal',
      location: 'Shahrah-e-Faisal',
    ),
  ];

  EmergencyScreen currentScreen = EmergencyScreen.splash;
  AccountPath accountPath = AccountPath.signIn;
  bool otpFromRegistration = false;
  String registerTrade = 'Plumber';

  String domesticTrade = 'Plumber';
  String domesticIssue = 'Pipe leak';
  String domesticSpecificIssue = 'Water leak';
  bool domesticPhotoAttached = false;
  String domesticPlace = 'Home · DHA Phase 5';
  DateTime? domesticScheduledAt;
  DomesticJob domesticJob = DomesticJob.idle;
  bool costFromProvider = false;
  String? savedRepairTotal;
  String? domesticNotice;
  String? amountOwed;
  final List<({String label, String owed})> domesticHistory = [];

  ProviderDuty providerDuty = ProviderDuty.available;
  bool providerFromProfile = false;
  List<int> incomingRequests = [0];
  int nextRequest = 1;
  int? activeRequest;
  int? pendingRequest;
  int openedRequest = 0;
  final Set<int> blockedRequests = {};
  String selectedDetail = 'Cardiac';
  int peopleNeedingHelp = 1;
  String? requestId;
  EmergencyOutcome? outcome;
  EmergencyRequestResult? result;
  String? errorMessage;
  int remainingSeconds = 15;
  bool isRequesting = false;
  bool isCompleting = false;

  Timer? _arrivalTimer;
  bool _socketConnected = false;

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
    goTo(EmergencyScreen.otp);
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
      goTo(EmergencyScreen.driverJob);
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
    goTo(EmergencyScreen.tradeDetail);
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

  void selectDomesticPlace(String place) {
    domesticPlace = place;
    notifyListeners();
  }

  void scheduleDomestic(DateTime? scheduledAt) {
    domesticScheduledAt = scheduledAt;
    notifyListeners();
  }

  void confirmDomestic() {
    domesticJob = DomesticJob.searching;
    goTo(EmergencyScreen.domesticJob);
  }

  void cancelDomestic() {
    domesticJob = DomesticJob.idle;
    goTo(EmergencyScreen.services);
  }

  void cancelAssignedProvider() {
    final request = activeRequest ?? 0;
    blockedRequests.add(request);
    if(activeRequest != null) {
      activeRequest = null;
      providerDuty = ProviderDuty.available;
      incomingRequests.add(request);
    }

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
    amountOwed = 'Amount owed: x + $repairTotal';
    domesticHistory.add((label: '$domesticTrade · Completed', owed: amountOwed!));
    _finishProviderJob();
    domesticJob = DomesticJob.complete;
    goTo(EmergencyScreen.domesticJob);
  }

  void refuseRepairTotal() {
    amountOwed = 'Amount owed: x';
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

  void startProviderMode({required bool fromProfile}) {
    providerFromProfile = fromProfile;
    providerDuty = ProviderDuty.available;
    activeRequest = null;
    pendingRequest = null;
    incomingRequests = [0];
    nextRequest = 1;
    goTo(EmergencyScreen.providerDashboard);
  }

  void leaveProviderMode() {
    goTo(providerFromProfile ? EmergencyScreen.home : EmergencyScreen.login);
  }

  void setProviderOnline(bool online) {
    providerDuty = online ? ProviderDuty.available : ProviderDuty.offline;
    notifyListeners();
  }

  void openRequest(int request) {
    openedRequest = request;
    goTo(EmergencyScreen.providerRequest);
  }

  void declineRequest() {
    incomingRequests.remove(openedRequest);
    goTo(EmergencyScreen.providerDashboard);
  }

  void acceptRequest() {
    final request = openedRequest;
    incomingRequests.remove(request);

    if(providerDuty == ProviderDuty.onJob) {
      pendingRequest = request;
      _offerNextRequest();
      goTo(EmergencyScreen.providerJob);
      return;
    }

    if(pendingRequest == request) {
      pendingRequest = null;
    }
    activeRequest = request;
    providerDuty = ProviderDuty.onJob;
    domesticTrade = 'Plumber';
    domesticIssue = demoRequests[request].issue;
    domesticJob = DomesticJob.assigned;
    _offerNextRequest();
    goTo(EmergencyScreen.providerAccepted);
  }

  void cancelPendingRequest() {
    final request = pendingRequest!;
    pendingRequest = null;
    blockedRequests.add(request);
    incomingRequests.add(request);
    notifyListeners();
  }

  void _finishProviderJob() {
    if(activeRequest == null) {
      return;
    }

    activeRequest = null;
    providerDuty = ProviderDuty.available;
  }

  void _offerNextRequest() {
    if(nextRequest < demoRequests.length) {
      incomingRequests.add(nextRequest);
      nextRequest++;
    }
  }

  void selectDetail(String detail) {
    selectedDetail = detail;
    notifyListeners();
  }

  void selectPeopleNeedingHelp(int count) {
    peopleNeedingHelp = count;
    notifyListeners();
  }

  Future<void> requestAmbulance() async {
    if(isRequesting) {
      return;
    }

    isRequesting = true;
    errorMessage = null;
    currentScreen = EmergencyScreen.emergencySearch;
    notifyListeners();

    try {
      result = await _emergencyService.createEmergencyRequest(
        lat: demoLatitude,
        lng: demoLongitude,
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
        _connectToRequest(result!.requestId);
        _startArrivalSimulation();
      }
    } on TimeoutException {
        currentScreen = EmergencyScreen.emergencyConfirm;
        errorMessage =
            'The server was asleep and is waking up now, so tap request again.';
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
    remainingSeconds = 15;
    isRequesting = false;
    isCompleting = false;
    notifyListeners();
  }

  void _connectToRequest(String id) {
    _socketConnected = true;
    _emergencySocketService.connect(
      requestId: id,
      onOutcome: (newOutcome) {
        outcome = newOutcome;
        notifyListeners();
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
        timer.cancel();
        currentScreen = EmergencyScreen.emergencyArrived;
        isCompleting = true;
        notifyListeners();
        _completeEmergencyRequest();
        return;
      }

      notifyListeners();
    });
  }

  Future<void> _completeEmergencyRequest() async {
    if(requestId == null ||
        isCompleting && currentScreen != EmergencyScreen.emergencyArrived) {
      return;
    }

    isCompleting = true;
    errorMessage = null;
    notifyListeners();

    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      await _emergencyService.completeEmergencyRequest(requestId: requestId!);
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
    _disconnectFromRequest();
    super.dispose();
  }
}
