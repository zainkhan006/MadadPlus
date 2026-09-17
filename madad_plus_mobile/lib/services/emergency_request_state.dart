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
}

class EmergencyRequestState extends ChangeNotifier {
  static const double demoLatitude = 24.8140;
  static const double demoLongitude = 67.0308;

  EmergencyRequestState({EmergencyService? emergencyService})
    : _emergencyService = emergencyService ?? EmergencyService();

  final EmergencyService _emergencyService;
  final EmergencySocketService _emergencySocketService =
      EmergencySocketService();

  EmergencyScreen currentScreen = EmergencyScreen.splash;
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
    notifyListeners();
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
