import 'dart:async';
import 'dart:convert';

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
  double? pinLatitude;
  double? pinLongitude;
  String? resolvedAddress;
  String? selectedDetail;
  int? peopleNeedingHelp;
  String? additionalDetails;
  String? detailsNotice;
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
    if(latitude == null || longitude == null) {
      errorMessage = 'Set a location before requesting an ambulance.';
      notifyListeners();
      return;
    }

    isRequesting = true;
    errorMessage = null;
    currentScreen = EmergencyScreen.emergencySearch;
    notifyListeners();

    try {
      result = await _emergencyService.createEmergencyRequest(
        lat: latitude,
        lng: longitude,
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
    pinLatitude = null;
    pinLongitude = null;
    resolvedAddress = null;
    selectedDetail = null;
    peopleNeedingHelp = null;
    additionalDetails = null;
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
