import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'emergency_outcome.dart';
import 'emergency_service.dart';
import 'emergency_socket_service.dart';
import 'provider_notifier.dart';

enum EmergencyScreen {
  splash,
  onboarding,
  login,
  staffSignIn,
  otp,
  home,
  homeLocation,
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
  providerIncoming,
  providerNameMatch,
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
  static const defaultHomeTitle = 'Karachi, DHA Phase 5';
  static const _homePlacesKey = 'homePlaces';
  static const _homeChosenKey = 'homeChosen';
  static const _emergencyRequestsKey = 'emergencyRequests';
  static const _domesticHistoryKey = 'domesticHistory';
  static const _declinedJobsKey = 'declinedProviderJobs';

  EmergencyRequestState({
    EmergencyService? emergencyService,
    EmergencySocketService? socketService,
    ProviderNotifier? providerNotifier,
    String? demoUserId,
  }) : _emergencyService = emergencyService ?? EmergencyService(),
       _emergencySocketService = socketService ?? EmergencySocketService(),
       _providerNotifier = providerNotifier,
       demoUserId = demoUserId ?? const String.fromEnvironment('DEMO_USER_ID') {
    loadHomePlaces();
    _historyLoad = loadRequestHistory();
  }

  late final Future<void> _historyLoad;
  final EmergencyService _emergencyService;
  final EmergencySocketService _emergencySocketService;
  final ProviderNotifier? _providerNotifier;
  final String demoUserId;

  EmergencyScreen currentScreen = EmergencyScreen.splash;
  AccountPath accountPath = AccountPath.signIn;
  bool otpFromRegistration = false;
  String registerTrade = 'Plumber';

  String domesticTrade = 'Plumber';
  String domesticIssue = 'Pipe leak';
  Set<String> electricianFilters = {};
  String domesticSpecificIssue = 'Water leak';
  bool domesticPhotoAttached = false;
  String domesticDescription = '';
  String domesticAddress = '';
  double? domesticPinLatitude;
  double? domesticPinLongitude;
  DateTime? domesticScheduledAt;
  DomesticJob domesticJob = DomesticJob.idle;
  bool costFromProvider = false;
  bool costWaiting = false;
  String? settledCostRequestId;
  String? domesticNotice;
  String? amountOwed;
  final List<({
    String id,
    String trade,
    String status,
    String issue,
    String address,
    String owed,
  })> domesticHistory = [];
  final List<({
    String id,
    String? address,
    String? happened,
    int? people,
    String status,
  })> emergencyRequests = [];

  List<ProviderRow> providers = [];
  bool providersLoading = false;
  String? providersError;
  String? staffSignInNotice;
  String? callerSignInNotice;
  String? signedInUserId;
  String? signedInUserName;
  String? registerNotice;
  bool registerBusy = false;
  bool callerSignInBusy = false;
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
  String? finishedJobId;

  List<AmbulanceRow> driverAmbulances = [];
  String? driverId;
  String? driverAmbulanceLabel;
  String? driverAmbulanceStatus;
  EmergencyCall? driverCall;
  bool driverLoading = false;
  String? driverError;
  AmbulanceRow? matchedDriver;
  ProviderRow? matchedProvider;
  List<ProviderRow> providerNameMatches = [];
  bool providerMatchCanCreate = false;
  String pendingProviderName = '';
  String pendingProviderPhone = '';
  String pendingProviderCnic = '';
  bool staffSignInBusy = false;

  final List<({String address, double latitude, double longitude})>
  homePlaces = [];
  String? homeAddress;
  double? homeLatitude;
  double? homeLongitude;
  String? locationProblem;

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
  List<LatLng>? routePoints;
  double routeDurationMs = 15000;
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
    final raw = DateTime.now().difference(started).inMilliseconds / routeDurationMs;
    return raw.clamp(0.0, 1.0);
  }

  double driveDurationMs(double fromLat, double fromLng, double toLat, double toLng) {
    const earthRadiusKm = 6371.0;
    final dLat = (toLat - fromLat) * math.pi / 180;
    final dLng = (toLng - fromLng) * math.pi / 180;
    final lat1 = fromLat * math.pi / 180;
    final lat2 = toLat * math.pi / 180;
    final x = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
    final km = 2 * earthRadiusKm * math.asin(math.sqrt(x));
    return math.min(45000.0, math.max(8000.0, (km / 55) * 3600000));
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
    routePoints = null;
    routeDurationMs = 15000;
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
    routePoints = [LatLng(fromLat, fromLng), LatLng(toLat, toLng)];
    routeDurationMs = driveDurationMs(fromLat, fromLng, toLat, toLng);
    final startedAt = DateTime.now();
    routeStartedAt = startedAt;
    routeError = null;
    _routeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if(routeProgress() >= 1) {
        timer.cancel();
      }
      notifyListeners();
    });
    notifyListeners();
    _loadRoadRoute(startedAt, fromLat, fromLng, toLat, toLng);
  }

  Future<void> _loadRoadRoute(
    DateTime startedAt,
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) async {
    if(Platform.environment['FLUTTER_TEST'] == 'true') {
      return;
    }
    try {
      final response = await http
          .get(Uri.parse(
            'https://router.project-osrm.org/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson',
          ))
          .timeout(const Duration(seconds: 5));
      if(response.statusCode != 200) {
        throw Exception('OSRM request failed: ${response.statusCode}');
      }
      final routes = (jsonDecode(response.body) as Map<String, dynamic>)['routes'] as List;
      if(routes.isEmpty) {
        throw Exception('No route found');
      }
      if(!identical(routeStartedAt, startedAt)) {
        return;
      }
      final coordinates = routes.first['geometry']['coordinates'] as List;
      routePoints = [
        for(final point in coordinates)
          LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble()),
      ];
      notifyListeners();
    } catch (error) {
      debugPrint('could not get a road route, so the ambulance will drive in a straight line: $error');
    }
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

  String get callerUserId {
    final signedIn = signedInUserId?.trim() ?? '';
    if(signedIn.isNotEmpty) {
      return signedIn;
    }
    return demoUserId;
  }

  Future<void> submitCallerSignIn(String raw) async {
    if(callerSignInBusy) {
      return;
    }
    final typed = raw.trim();
    callerSignInNotice = null;
    if(typed.isEmpty) {
      callerSignInNotice = 'Enter the name or phone number you registered with.';
      notifyListeners();
      return;
    }

    callerSignInBusy = true;
    signedInUserId = null;
    signedInUserName = null;
    notifyListeners();
    try {
      final callers = await _emergencyService.listCallers();
      CallerRow? match;
      for(final row in callers) {
        if(_sameStaffName(row.name, typed) || _sameStaffPhone(row.phone, typed)) {
          match = row;
          break;
        }
      }
      if(match == null) {
        callerSignInNotice =
            'Nobody was found with that name or number. Type the name you registered with, or your phone number.';
        return;
      }
      signedInUserId = match.id;
      signedInUserName = match.name;
      accountPath = AccountPath.signIn;
      otpFromRegistration = false;
      goTo(EmergencyScreen.otp);
    } on ApiException catch (error) {
      callerSignInNotice = error.message;
    } on TimeoutException {
      callerSignInNotice = 'The caller list took too long to load. Try again.';
    } catch (_) {
      callerSignInNotice = 'The caller list could not be loaded. Try again.';
    }
    finally {
      callerSignInBusy = false;
      notifyListeners();
    }
  }

  void continueDriverSignIn() {
    accountPath = AccountPath.driver;
    otpFromRegistration = false;
    matchedDriver = null;
    matchedProvider = null;
    staffSignInNotice = null;
    goTo(EmergencyScreen.staffSignIn);
  }

  void continueProviderSignIn() {
    accountPath = AccountPath.provider;
    otpFromRegistration = false;
    providerDemo = false;
    matchedDriver = null;
    matchedProvider = null;
    staffSignInNotice = null;
    goTo(EmergencyScreen.staffSignIn);
  }

  Future<void> submitStaffSignIn(String raw) async {
    if(staffSignInBusy) {
      return;
    }
    final typed = raw.trim();
    staffSignInNotice = null;
    matchedDriver = null;
    matchedProvider = null;
    if(typed.isEmpty) {
      staffSignInNotice = 'Enter the name or phone number you registered with.';
      notifyListeners();
      return;
    }

    staffSignInBusy = true;
    notifyListeners();
    try {
      if(accountPath == AccountPath.driver) {
        await loadDriverAmbulances();
        if(driverError != null) {
          return;
        }
        AmbulanceRow? match;
        for(final row in driverAmbulances) {
          if(_sameStaffName(row.driverName, typed) || _sameStaffPhone(row.driverPhone, typed)) {
            match = row;
            break;
          }
        }
        if(match == null) {
          staffSignInNotice = 'Nobody was found with that name or number.';
          return;
        }
        matchedDriver = match;
        goTo(EmergencyScreen.otp);
        return;
      }

      await loadProviders();
      if(providersError != null) {
        return;
      }
      ProviderRow? match;
      for(final row in providers) {
        if(_sameStaffName(row.name, typed) || _sameStaffPhone(row.phone, typed)) {
          match = row;
          break;
        }
      }
      if(match == null) {
        final letters = RegExp(r'[A-Za-z]');
        if(letters.hasMatch(typed)) {
          try {
            final matches = await _emergencyService.checkProviderName(name: typed);
            if(matches.isNotEmpty) {
              providerNameMatches = matches;
              providerMatchCanCreate = false;
              goTo(EmergencyScreen.providerNameMatch);
              return;
            }
          } on ApiException catch (error) {
            if(error.statusCode == 409) {
              final wanted = typed.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
              for(final row in providers) {
                final saved = row.name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
                if(saved == wanted) {
                  matchedProvider = row;
                  goTo(EmergencyScreen.otp);
                  return;
                }
              }
            }
            staffSignInNotice = error.statusCode == 409
                ? 'Nobody was found with that name or number.'
                : error.message;
            return;
          } on TimeoutException {
            staffSignInNotice = 'The provider list took too long to load. Try again.';
            return;
          }
        }
        staffSignInNotice = 'Nobody was found with that name or number.';
        return;
      }
      matchedProvider = match;
      goTo(EmergencyScreen.otp);
    }
    finally {
      staffSignInBusy = false;
      notifyListeners();
    }
  }

  bool _sameStaffName(String? recorded, String typed) {
    final left = recorded?.trim().toLowerCase() ?? '';
    return left.isNotEmpty && left == typed.trim().toLowerCase();
  }

  bool _sameStaffPhone(String? recorded, String typed) {
    final left = _staffDigits(recorded ?? '');
    final right = _staffDigits(typed);
    return left.isNotEmpty && right.isNotEmpty && left == right;
  }

  String _staffDigits(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
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
    registerNotice = null;
    matchedProvider = null;
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

  Future<void> registerCaller(String name, String phone) async {
    if(registerBusy) {
      return;
    }
    final typedName = name.trim();
    final typedPhone = phone.trim();
    registerNotice = null;
    if(typedName.isEmpty || typedPhone.isEmpty) {
      registerNotice = 'Enter your name and phone number.';
      notifyListeners();
      return;
    }

    registerBusy = true;
    notifyListeners();
    try {
      final created = await _emergencyService.registerCaller(
        name: typedName,
        phone: typedPhone,
      );
      signedInUserId = created.id;
      signedInUserName = created.name;
      continueRegistration();
    } on ApiException catch (error) {
      registerNotice = error.message;
    } on TimeoutException {
      registerNotice = 'Creating your account took too long. Try again.';
    } catch (_) {
      registerNotice = 'Your account could not be created. Try again.';
    }
    finally {
      registerBusy = false;
      notifyListeners();
    }
  }

  Future<void> registerDriver(String name, String phone, String ambulance) async {
    if(registerBusy) {
      return;
    }
    final typedName = name.trim();
    final typedPhone = phone.trim();
    final typedAmbulance = ambulance.trim();
    registerNotice = null;
    if(typedName.isEmpty || typedPhone.isEmpty || typedAmbulance.isEmpty) {
      registerNotice = 'Enter your name, phone number, and ambulance number.';
      notifyListeners();
      return;
    }

    registerBusy = true;
    notifyListeners();
    try {
      matchedDriver = await _emergencyService.registerDriver(
        name: typedName,
        phone: typedPhone,
        ambulanceLabel: typedAmbulance,
      );
      continueRegistration();
    } on ApiException catch (error) {
      registerNotice = error.message;
    } on TimeoutException {
      registerNotice = 'Creating your account took too long. Try again.';
    } catch (_) {
      registerNotice = 'Your account could not be created. Try again.';
    }
    finally {
      registerBusy = false;
      notifyListeners();
    }
  }

  Future<void> registerProvider(String name, String phone, String cnic) async {
    if(registerBusy) {
      return;
    }
    final typedName = name.trim();
    final typedPhone = phone.trim();
    final typedCnic = cnic.trim();
    registerNotice = null;
    if(typedName.isEmpty || typedPhone.isEmpty || typedCnic.isEmpty) {
      registerNotice = 'Enter your name, phone number, and CNIC.';
      notifyListeners();
      return;
    }

    registerBusy = true;
    notifyListeners();
    try {
      final matches = await _emergencyService.checkProviderName(
        name: typedName,
        trade: registerTrade,
      );
      if(matches.isNotEmpty) {
        pendingProviderName = typedName;
        pendingProviderPhone = typedPhone;
        pendingProviderCnic = typedCnic;
        providerNameMatches = matches;
        providerMatchCanCreate = true;
        goTo(EmergencyScreen.providerNameMatch);
        return;
      }
      await _createProvider(typedName, typedPhone, typedCnic);
    } on ApiException catch (error) {
      registerNotice = error.message;
    } on TimeoutException {
      registerNotice = 'Creating your account took too long. Try again.';
    } catch (_) {
      registerNotice = 'Your account could not be created. Try again.';
    }
    finally {
      registerBusy = false;
      notifyListeners();
    }
  }

  Future<void> _createProvider(String name, String phone, String cnic) async {
    matchedProvider = await _emergencyService.registerProvider(
      name: name,
      phone: phone,
      cnic: cnic,
      trade: registerTrade,
    );
    continueRegistration();
  }

  Future<void> confirmProviderRegistration() async {
    if(registerBusy) {
      return;
    }
    registerNotice = null;
    registerBusy = true;
    notifyListeners();
    try {
      await _createProvider(
        pendingProviderName,
        pendingProviderPhone,
        pendingProviderCnic,
      );
    } on ApiException catch (error) {
      registerNotice = error.message;
    } on TimeoutException {
      registerNotice = 'Creating your account took too long. Try again.';
    } catch (_) {
      registerNotice = 'Your account could not be created. Try again.';
    }
    finally {
      registerBusy = false;
      notifyListeners();
    }
  }

  void chooseExistingProvider(ProviderRow provider) {
    providerNameMatches = [];
    chooseProviderProfile(provider);
    startProviderMode(fromProfile: false);
  }

  void chooseSignInProvider(ProviderRow provider) {
    providerNameMatches = [];
    matchedProvider = provider;
    goTo(EmergencyScreen.otp);
  }

  void verifyCode() {
    if(accountPath == AccountPath.driver) {
      final matched = matchedDriver;
      if(matched != null) {
        chooseDriverAmbulance(matched);
        goTo(EmergencyScreen.driverJob);
        return;
      }
      openDriverPortal();
      return;
    }

    if(accountPath == AccountPath.provider) {
      final matched = matchedProvider;
      if(otpFromRegistration && matched == null) {
        startProviderMode(fromProfile: false);
        return;
      }
      if(matched != null) {
        chooseProviderProfile(matched);
        startProviderMode(fromProfile: false, demo: true);
        return;
      }
      openProviderDemo();
      return;
    }

    goTo(EmergencyScreen.home);
  }

  void backFromOtp() {
    if(otpFromRegistration) {
      goTo(EmergencyScreen.register);
      return;
    }
    if(accountPath == AccountPath.driver || accountPath == AccountPath.provider) {
      goTo(EmergencyScreen.staffSignIn);
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
    electricianFilters = {};
    domesticSpecificIssue = 'Water leak';
    domesticPhotoAttached = false;
    chosenProvider = null;
    goTo(EmergencyScreen.tradeDetail);
    loadProviders();
  }

  List<ProviderRow> get providersForTrade {
    final trade = domesticTrade.toLowerCase();
    return providers.where((row) {
      final name = row.specialisationName?.toLowerCase() ?? '';
      if(trade == 'electrician') {
        if(name != 'electrician' && name != 'ac technician') {
          return false;
        }
        return electricianFilters.isEmpty || electricianFilters.contains(name);
      }
      return name == trade;
    }).toList();
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

  void setDomesticPin({
    required double latitude,
    required double longitude,
    required String address,
  }) {
    domesticPinLatitude = latitude;
    domesticPinLongitude = longitude;
    domesticAddress = address;
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

  void setElectricianFilters(Set<String> trades) {
    electricianFilters = trades;
    final chosen = chosenProvider;
    if(chosen != null &&
        !providersForTrade.any((row) => row.id == chosen.id)) {
      chosenProvider = null;
    }
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
    final userId = callerUserId;
    if(userId.isEmpty) {
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
        userId: userId,
        providerId: provider.id,
        specialisationId: provider.specialisationId!,
        description: domesticRequestText,
        address: domesticAddress.trim(),
      );
      domesticBooking = booking;
      final existing = domesticHistory.indexWhere(
        (item) => item.id.isNotEmpty && item.id == booking.requestId,
      );
      final ongoing = (
        id: booking.requestId,
        trade: domesticTrade,
        status: 'Ongoing',
        issue: domesticRequestText,
        address: domesticAddress.trim(),
        owed: '',
      );
      if(existing >= 0) {
        domesticHistory[existing] = ongoing;
      }
      else {
        domesticHistory.add(ongoing);
      }
      saveDomesticHistory();
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
    if(booking.status == 'CANCELLED') {
      _emergencySocketService.disconnectDomestic();
      domesticBooking = null;
      domesticJob = DomesticJob.idle;
      goTo(EmergencyScreen.services);
      return;
    }
    if(booking.status == 'ACCEPTED' && domesticJob == DomesticJob.searching) {
      domesticJob = DomesticJob.assigned;
    }
    if(booking.finalTotal != null) {
      _settleUserCost(booking);
      return;
    }
    if(booking.receiptStatus == 'NEGOTIABLE' &&
        domesticJob != DomesticJob.costReview) {
      openCostReview(fromProvider: false);
      return;
    }
    notifyListeners();
  }

  void _settleUserCost(DomesticBooking booking) {
    if(settledCostRequestId == booking.requestId) {
      return;
    }

    settledCostRequestId = booking.requestId;
    final accepted = booking.receiptStatus == 'ACCEPTED';
    amountOwed = 'Amount owed: Rs. ${booking.finalTotal!.toStringAsFixed(0)}';
    final status = accepted ? 'Completed' : 'Inspection fee only';
    final index = domesticHistory.indexWhere(
      (item) => item.id.isNotEmpty && item.id == booking.requestId,
    );
    if(index >= 0) {
      final current = domesticHistory[index];
      domesticHistory[index] = (
        id: current.id,
        trade: current.trade,
        status: status,
        issue: current.issue,
        address: current.address,
        owed: amountOwed!,
      );
    }
    else {
      domesticHistory.add((
        id: booking.requestId,
        trade: domesticTrade,
        status: status,
        issue: domesticRequestText,
        address: domesticAddress.trim(),
        owed: amountOwed!,
      ));
    }
    saveDomesticHistory();
    domesticJob = accepted ? DomesticJob.complete : DomesticJob.refused;
    goTo(EmergencyScreen.domesticJob);
  }

  Future<void> _cancelPendingBooking(String requestId) async {
    try {
      await _emergencyService.cancelDomesticRequest(requestId);
    }
    catch(_) {
      debugPrint('the server could not cancel that request');
    }
  }

  void cancelDomestic() {
    final booking = domesticBooking;
    if(booking != null && booking.status == 'PENDING') {
      _cancelPendingBooking(booking.requestId);
    }
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
    costFromProvider = fromProvider;
    costWaiting = false;
    amountOwed = null;
    domesticJob = DomesticJob.costReview;
    goTo(EmergencyScreen.costReview);
  }

  void backFromCostReview() {
    if(costFromProvider && activeJobId == null) {
      goTo(EmergencyScreen.providerDashboard);
      return;
    }
    domesticJob = DomesticJob.inProgress;
    goTo(
      costFromProvider ? EmergencyScreen.providerJob : EmergencyScreen.domesticJob,
    );
  }

  Future<void> submitRepairTotal(String typedTotal) async {
    final provider = providerProfile;
    final requestId = activeJobId;
    final total = double.tryParse(typedTotal.trim());
    if(provider == null || requestId == null) {
      showDomesticNotice('There is no active job to send a repair total for.');
      return;
    }
    if(total == null || total < 0) {
      showDomesticNotice('Type the repair total as a number.');
      return;
    }

    costWaiting = true;
    domesticNotice = null;
    notifyListeners();

    try {
      final submitted = await _emergencyService.submitRepairCost(
        providerId: provider.id,
        requestId: requestId,
        quotedTotal: total,
      );
      _receiveProviderBooking(submitted);
    } on ApiException catch (error) {
      costWaiting = false;
      showDomesticNotice(error.message);
    } on TimeoutException {
      costWaiting = false;
      showDomesticNotice('The server did not answer in time. Try again.');
    } catch (_) {
      costWaiting = false;
      showDomesticNotice('The repair total could not be sent. Try again.');
    }
  }

  Future<void> decideRepairTotal({required bool accept}) async {
    final requestId = domesticBooking?.requestId;
    if(requestId == null) {
      showDomesticNotice('There is no booking to decide on.');
      return;
    }

    try {
      final decided = await _emergencyService.decideRepairCost(
        requestId: requestId,
        accept: accept,
      );
      _receiveUserBooking(decided);
    } on ApiException catch (error) {
      showDomesticNotice(error.message);
    } on TimeoutException {
      showDomesticNotice('The server did not answer in time. Try again.');
    } catch (_) {
      showDomesticNotice('The decision could not be sent. Try again.');
    }
  }

  void finishDomestic(EmergencyScreen screen) {
    domesticJob = DomesticJob.idle;
    goTo(screen);
  }

  Future<void> submitProviderRating(int stars) async {
    final provider = chosenProvider;
    if(provider == null || stars < 1 || stars > 5) {
      return;
    }
    try {
      final saved = await _emergencyService.setProviderRating(
        providerId: provider.id,
        rating: stars,
      );
      _applyProviderRating(provider.id, saved);
    } on ApiException catch (error) {
      showDomesticNotice(error.message);
    } on TimeoutException {
      showDomesticNotice('The rating took too long to save. Try again.');
    } catch (_) {
      showDomesticNotice('The rating could not be saved. Try again.');
    }
  }

  void _applyProviderRating(String providerId, double rating) {
    if(chosenProvider?.id == providerId) {
      chosenProvider = chosenProvider!.withRating(rating);
    }
    if(providerProfile?.id == providerId) {
      providerProfile = providerProfile!.withRating(rating);
    }
    providers = [
      for(final row in providers)
        row.id == providerId ? row.withRating(rating) : row,
    ];
    notifyListeners();
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
    _providerNotifier?.start(onTap: openIncomingRequests);
    _restoreProviderJobs(provider.id);
  }

  void openIncomingRequests() {
    if(providerProfile == null) {
      return;
    }
    goTo(EmergencyScreen.providerIncoming);
  }

  Future<void> _readDeclinedJobs(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_declinedJobsKey);
    final decoded = raw == null ? null : jsonDecode(raw);
    declinedJobIds.clear();
    if(decoded is! Map) {
      return;
    }
    final saved = decoded[providerId];
    if(saved is! List) {
      return;
    }
    for(final id in saved) {
      if(id is String) {
        declinedJobIds.add(id);
      }
    }
  }

  Future<void> _writeDeclinedJobs(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_declinedJobsKey);
    final decoded = raw == null ? null : jsonDecode(raw);
    final stored = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    stored[providerId] = declinedJobIds.toList();
    await prefs.setString(_declinedJobsKey, jsonEncode(stored));
  }

  Future<void> _restoreProviderJobs(String providerId) async {
    await _readDeclinedJobs(providerId);
    await loadProviderJobs();
  }

  void signOutProvider() {
    _emergencySocketService.disconnectProvider();
    providerProfile = null;
    providerJobs = [];
    activeJobId = null;
    providerDuty = ProviderDuty.available;
    providerDemo = false;
    providerTrade = null;
    matchedProvider = null;
    goTo(EmergencyScreen.login);
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
      final rows = await _emergencyService.listProviders();
      for(final row in rows) {
        if(row.id == provider.id) {
          providerProfile = provider.withRating(row.rating);
          break;
        }
      }
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
      if(booking.status == 'PENDING' &&
          !declinedJobIds.contains(booking.requestId) &&
          currentScreen != EmergencyScreen.providerIncoming) {
        _providerNotifier?.showNewJobs();
      }
    }
    if(booking.finalTotal != null && booking.requestId == activeJobId) {
      costWaiting = false;
      amountOwed = 'Amount owed: Rs. ${booking.finalTotal!.toStringAsFixed(0)}';
      _finishProviderJob();
      if(booking.receiptStatus == 'ACCEPTED') {
        goTo(EmergencyScreen.providerDashboard);
      }
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

  DomesticBooking? get finishedJob => _jobById(finishedJobId);

  void openJob(String requestId) {
    openedJobId = requestId;
    goTo(EmergencyScreen.providerRequest);
  }

  void openFinishedJob(String requestId) {
    finishedJobId = requestId;
    goTo(EmergencyScreen.providerJob);
  }

  void closeFinishedJob() {
    finishedJobId = null;
    goTo(EmergencyScreen.providerDashboard);
  }

  void openActiveJob(String requestId) {
    finishedJobId = null;
    activeJobId = requestId;
    providerDuty = ProviderDuty.onJob;
    goTo(EmergencyScreen.providerJob);
  }

  void declineJob() {
    _declineRequest(openedJobId);
    goTo(EmergencyScreen.providerDashboard);
  }

  void declineIncomingJob(String requestId) {
    _declineRequest(requestId);
    notifyListeners();
  }

  void _declineRequest(String? requestId) {
    final providerId = providerProfile?.id;
    if(requestId == null) {
      return;
    }
    declinedJobIds.add(requestId);
    if(providerId != null) {
      _writeDeclinedJobs(providerId);
    }
    _cancelPendingBooking(requestId);
  }

  void acceptIncomingJob(String requestId) {
    openedJobId = requestId;
    acceptJob();
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
      finishedJobId = null;
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
    if(driverId == null) {
      goTo(EmergencyScreen.home);
      return;
    }
    goTo(EmergencyScreen.driverJob);
    loadDriverPortal();
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

  void signOutDriver() {
    _emergencySocketService.disconnectDriver();
    driverId = null;
    driverAmbulanceLabel = null;
    driverAmbulanceStatus = null;
    driverAmbulanceLat = null;
    driverAmbulanceLng = null;
    driverCall = null;
    matchedDriver = null;
    clearRoute();
    goTo(EmergencyScreen.login);
  }

  Future<void> markDriverUnavailable() {
    return _setDriverAvailability(available: false);
  }

  Future<void> markDriverAvailable() {
    return _setDriverAvailability(available: true);
  }

  Future<void> _setDriverAvailability({required bool available}) async {
    final id = driverId;
    final requiredStatus = available ? 'UNAVAILABLE' : 'FREE';
    if(id == null || driverCall != null || driverAmbulanceStatus != requiredStatus || driverLoading) {
      return;
    }

    driverLoading = true;
    driverError = null;
    notifyListeners();
    try {
      driverAmbulanceStatus = await _emergencyService.setDriverAvailability(
        driverId: id,
        available: available,
      );
    } on ApiException catch (error) {
      driverError = error.message;
    } on TimeoutException {
      driverError = 'The server did not answer in time. Try again.';
    } catch (_) {
      driverError = available
          ? 'The ambulance could not be marked available. Try again.'
          : 'The ambulance could not be marked unavailable. Try again.';
    } finally {
      driverLoading = false;
      notifyListeners();
    }
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

  String get homeTitle => homeAddress ?? defaultHomeTitle;

  Future<void> loadHomePlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_homePlacesKey);
    final decoded = raw == null ? null : jsonDecode(raw);
    if(decoded is List) {
      for(final item in decoded) {
        if(item is Map &&
            item['address'] is String &&
            item['latitude'] is num &&
            item['longitude'] is num) {
          homePlaces.add((
            address: item['address'] as String,
            latitude: (item['latitude'] as num).toDouble(),
            longitude: (item['longitude'] as num).toDouble(),
          ));
        }
      }
    }
    final chosen = prefs.getString(_homeChosenKey);
    for(final place in homePlaces) {
      if(place.address == chosen) {
        homeAddress = place.address;
        homeLatitude = place.latitude;
        homeLongitude = place.longitude;
      }
    }
    notifyListeners();
  }

  Future<void> saveHomePlace({
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    homePlaces.removeWhere((place) => place.address == address);
    homePlaces.insert(0, (
      address: address,
      latitude: latitude,
      longitude: longitude,
    ));
    homeAddress = address;
    homeLatitude = latitude;
    homeLongitude = longitude;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _writeHomePlaces(prefs);
    await prefs.setString(_homeChosenKey, address);
  }

  Future<void> _writeHomePlaces(SharedPreferences prefs) async {
    await prefs.setString(
      _homePlacesKey,
      jsonEncode([
        for(final place in homePlaces)
          {
            'address': place.address,
            'latitude': place.latitude,
            'longitude': place.longitude,
          },
      ]),
    );
  }

  Future<void> selectHomePlace(
    ({String address, double latitude, double longitude}) place,
  ) async {
    homeAddress = place.address;
    homeLatitude = place.latitude;
    homeLongitude = place.longitude;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_homeChosenKey, place.address);
  }

  Future<({double latitude, double longitude, String address})?>
  locateDevice() async {
    locationProblem = null;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if(!serviceEnabled) {
      locationProblem = 'Location is turned off. Type the address instead.';
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if(permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if(permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      locationProblem = 'Location permission is off. Type the address instead.';
      return null;
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 15),
      );
    } on TimeoutException {
      locationProblem = 'Your location took too long to find. Type the address instead.';
      return null;
    }
    final address = await labelForCoordinates(
      position.latitude,
      position.longitude,
    );
    return (
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
    );
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

      rememberEmergencyRequest();
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

  void rememberEmergencyRequest() {
    final sent = result;
    if(sent == null) {
      return;
    }
    final entry = (
      id: sent.requestId,
      address: resolvedAddress,
      happened: selectedDetail,
      people: peopleNeedingHelp,
      status: sent.status,
    );
    final index = emergencyRequests.indexWhere((item) => item.id == sent.requestId);
    if(index >= 0) {
      emergencyRequests[index] = entry;
    }
    else {
      emergencyRequests.add(entry);
    }
    saveEmergencyRequests();
  }

  ({
    String id,
    String trade,
    String status,
    String issue,
    String address,
    String owed,
  })? _domesticHistoryEntry(Object? item) {
    if(item is! Map) {
      return null;
    }
    final trade = item['trade'];
    final status = item['status'];
    if(trade is String && status is String) {
      return (
        id: item['id'] is String ? item['id'] as String : '',
        trade: trade,
        status: status,
        issue: item['issue'] is String ? item['issue'] as String : '',
        address: item['address'] is String ? item['address'] as String : '',
        owed: item['owed'] is String ? item['owed'] as String : '',
      );
    }
    final label = item['label'];
    final owed = item['owed'];
    if(label is! String || owed is! String) {
      return null;
    }
    final splitAt = label.indexOf(' · ');
    return (
      id: '',
      trade: splitAt < 0 ? label : label.substring(0, splitAt),
      status: splitAt < 0 ? '' : label.substring(splitAt + ' · '.length),
      issue: '',
      address: '',
      owed: owed,
    );
  }

  Future<void> loadRequestHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawEmergency = prefs.getString(_emergencyRequestsKey);
    final decodedEmergency = rawEmergency == null ? null : jsonDecode(rawEmergency);
    if(decodedEmergency is List) {
      final stored = [
        for(final item in decodedEmergency)
          if(item is Map &&
              item['id'] is String &&
              item['status'] is String &&
              !emergencyRequests.any((request) => request.id == item['id']))
            (
              id: item['id'] as String,
              address: item['address'] is String ? item['address'] as String : null,
              happened: item['happened'] is String ? item['happened'] as String : null,
              people: item['people'] is int ? item['people'] as int : null,
              status: item['status'] as String,
            ),
      ];
      emergencyRequests.insertAll(0, stored);
    }

    final rawDomestic = prefs.getString(_domesticHistoryKey);
    final decodedDomestic = rawDomestic == null ? null : jsonDecode(rawDomestic);
    if(decodedDomestic is List) {
      final stored = [
        for(final item in decodedDomestic)
          if(_domesticHistoryEntry(item) case final entry?) entry,
      ];
      domesticHistory.insertAll(0, stored);
    }
    notifyListeners();
  }

  Future<void> saveEmergencyRequests() async {
    await _historyLoad;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _emergencyRequestsKey,
      jsonEncode([
        for(final request in emergencyRequests)
          {
            'id': request.id,
            'address': request.address,
            'happened': request.happened,
            'people': request.people,
            'status': request.status,
          },
      ]),
    );
  }

  Future<void> saveDomesticHistory() async {
    await _historyLoad;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _domesticHistoryKey,
      jsonEncode([
        for(final entry in domesticHistory)
          {
            'id': entry.id,
            'trade': entry.trade,
            'status': entry.status,
            'issue': entry.issue,
            'address': entry.address,
            'owed': entry.owed,
          },
      ]),
    );
  }

  void reset() {
    rememberEmergencyRequest();
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
        rememberEmergencyRequest();
        beginCallerLeg(incoming);
        notifyListeners();
      },
      onPickedUp: receivePickup,
      onReconnected: () {
        _catchUpAfterReconnect();
      },
      onCallerMessage: (message, assignment) {
        receiveCallerMessage(message, assignment: assignment);
      },
      onCompleted: (_) {
        final current = result;
        if(current != null) {
          result = EmergencyRequestResult(
            requestId: current.requestId,
            status: 'COMPLETED',
            assignedAmbulance: current.assignedAmbulance,
            consideredNearest: current.consideredNearest,
            pickupLatitude: current.pickupLatitude,
            pickupLongitude: current.pickupLongitude,
          );
          rememberEmergencyRequest();
        }
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
    if(routeLeg >= 2) {
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

  Future<void> _catchUpAfterReconnect() async {
    final id = requestId;
    if(id == null || routeLeg >= 2) {
      return;
    }

    try {
      final call = await _emergencyService.loadEmergencyRequest(id);
      if(requestId != id || routeLeg >= 2) {
        return;
      }
      if(!_hospitalLegStatuses.contains(call.status)) {
        return;
      }
      receivePickup(call);
    } catch(_) {
    }
  }

  void _startArrivalSimulation() {
    _arrivalTimer?.cancel();
    final durationMs = routeDurationMs;
    remainingSeconds = (durationMs / 1000).ceil();
    var lastElapsedMs = 0;
    _arrivalTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final elapsedMs = timer.tick * 100;
      final leftMs = durationMs - elapsedMs;
      final enRouteAtMs = durationMs * 3 / 15;
      final reachedEnRoute = lastElapsedMs < enRouteAtMs && elapsedMs >= enRouteAtMs;
      lastElapsedMs = elapsedMs;
      final screenBefore = currentScreen;
      final secondsBefore = remainingSeconds;

      if(leftMs <= 0) {
        remainingSeconds = 0;
        timer.cancel();
        currentScreen = EmergencyScreen.emergencyApproaching;
        notifyListeners();
        return;
      }
      else if(leftMs <= durationMs * 4 / 15) {
        currentScreen = EmergencyScreen.emergencyApproaching;
      }
      else if(reachedEnRoute) {
        currentScreen = EmergencyScreen.emergencyEnRoute;
      }
      remainingSeconds = (leftMs / 1000).ceil();

      if(currentScreen != screenBefore || remainingSeconds != secondsBefore) {
        notifyListeners();
      }
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
