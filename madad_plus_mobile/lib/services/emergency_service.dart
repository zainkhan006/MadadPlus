import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

double? _coord(dynamic value) {
  if(value is num) {
    return value.toDouble();
  }
  return null;
}

DateTime? _time(dynamic value) {
  if(value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

({double lat, double lng})? _point(dynamic value) {
  if(value is! Map) {
    return null;
  }
  final lat = _coord(value['lat']);
  final lng = _coord(value['lng']);
  if(lat == null || lng == null) {
    return null;
  }
  return (lat: lat, lng: lng);
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AmbulanceAssignment {
  const AmbulanceAssignment({
    required this.id,
    required this.label,
    this.distanceKm,
    this.status,
    this.driverName,
    this.driverPhone,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String label;
  final double? distanceKm;
  final String? status;
  final String? driverName;
  final String? driverPhone;
  final double? latitude;
  final double? longitude;

  factory AmbulanceAssignment.fromJson(Map<String, dynamic> json) {
    final distance = json['distanceKm'];
    final driver = json['driver'];
    final location = _point(json['location']);
    return AmbulanceAssignment(
      id: json['id'] as String,
      label: json['label'] as String,
      distanceKm: distance is num ? distance.toDouble() : null,
      status: json['status'] as String?,
      driverName: driver is Map ? driver['name'] as String? : null,
      driverPhone: driver is Map ? driver['phone'] as String? : null,
      latitude: location?.lat,
      longitude: location?.lng,
    );
  }
}

class EmergencyRequestResult {
  const EmergencyRequestResult({
    required this.requestId,
    required this.status,
    required this.assignedAmbulance,
    required this.consideredNearest,
    this.pickupLatitude,
    this.pickupLongitude,
  });

  final String requestId;
  final String status;
  final AmbulanceAssignment? assignedAmbulance;
  final AmbulanceAssignment? consideredNearest;
  final double? pickupLatitude;
  final double? pickupLongitude;

  factory EmergencyRequestResult.fromJson(Map<String, dynamic> json) {
    final pickup = _point(json['pickupLocation']);
    return EmergencyRequestResult(
      requestId: json['requestId'] as String,
      status: json['status'] as String,
      pickupLatitude: pickup?.lat,
      pickupLongitude: pickup?.lng,
      assignedAmbulance: json['assignedAmbulance'] == null
          ? null
          : AmbulanceAssignment.fromJson(
              Map<String, dynamic>.from(json['assignedAmbulance'] as Map),
            ),
      consideredNearest: json['consideredNearest'] == null
          ? null
          : AmbulanceAssignment.fromJson(
              Map<String, dynamic>.from(json['consideredNearest'] as Map),
            ),
    );
  }
}

class AmbulanceRow {
  const AmbulanceRow({
    required this.id,
    required this.label,
    required this.status,
    required this.driverId,
    required this.driverName,
    this.driverPhone,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String label;
  final String status;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final double? latitude;
  final double? longitude;

  factory AmbulanceRow.fromJson(Map<String, dynamic> json) {
    return AmbulanceRow(
      id: json['id'] as String,
      label: json['label'] as String,
      status: json['status'] as String,
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      driverPhone: json['driverPhone'] as String?,
      latitude: _coord(json['lat']),
      longitude: _coord(json['lng']),
    );
  }
}

class EmergencyCall {
  const EmergencyCall({
    required this.requestId,
    required this.status,
    required this.pickupAddress,
    required this.emergencyDescription,
    required this.peopleCount,
    required this.callerPhone,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.assignedDriverId,
    this.pickupLatitude,
    this.pickupLongitude,
    this.ambulanceLatitude,
    this.ambulanceLongitude,
    this.hospitalLatitude,
    this.hospitalLongitude,
    this.additionalDetails,
  });

  final String requestId;
  final String status;
  final String? pickupAddress;
  final String? additionalDetails;
  final String? emergencyDescription;
  final int? peopleCount;
  final String? callerPhone;
  final String? hospitalName;
  final String? hospitalAddress;
  final String? assignedDriverId;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? ambulanceLatitude;
  final double? ambulanceLongitude;
  final double? hospitalLatitude;
  final double? hospitalLongitude;

  factory EmergencyCall.fromJson(Map<String, dynamic> json) {
    final hospital = json['hospital'];
    final ambulance = json['assignedAmbulance'];
    final driver = ambulance is Map ? ambulance['driver'] : null;
    final people = json['peopleCount'];
    final pickup = _point(json['pickupLocation']);
    final ambulancePoint = ambulance is Map ? _point(ambulance['location']) : null;
    final hospitalPoint = hospital is Map ? _point(hospital['location']) : null;
    return EmergencyCall(
      requestId: json['requestId'] as String,
      status: json['status'] as String,
      pickupAddress: json['pickupAddress'] as String?,
      emergencyDescription: json['emergencyDescription'] as String?,
      peopleCount: people is num ? people.toInt() : null,
      callerPhone: json['callerPhone'] as String?,
      hospitalName: hospital is Map ? hospital['name'] as String? : null,
      hospitalAddress: hospital is Map
          ? hospital['address'] as String?
          : json['hospitalAddress'] as String?,
      assignedDriverId: driver is Map ? driver['id'] as String? : null,
      pickupLatitude: pickup?.lat,
      pickupLongitude: pickup?.lng,
      ambulanceLatitude: ambulancePoint?.lat,
      ambulanceLongitude: ambulancePoint?.lng,
      hospitalLatitude: hospitalPoint?.lat,
      hospitalLongitude: hospitalPoint?.lng,
      additionalDetails: json['additionalDetails'] as String?,
    );
  }
}

class DriverReassignment {
  const DriverReassignment({
    required this.ambulanceId,
    required this.status,
    required this.replacementRequestId,
    required this.reassignmentStatus,
    required this.callerMessage,
    required this.request,
  });

  final String ambulanceId;
  final String status;
  final String? replacementRequestId;
  final String reassignmentStatus;
  final String? callerMessage;
  final EmergencyCall? request;

  factory DriverReassignment.fromJson(Map<String, dynamic> json) {
    final request = json['request'];
    return DriverReassignment(
      ambulanceId: json['ambulanceId'] as String,
      status: json['status'] as String,
      replacementRequestId: json['replacementRequestId'] as String?,
      reassignmentStatus: json['reassignmentStatus'] as String,
      callerMessage: json['callerMessage'] as String?,
      request: request is Map
          ? EmergencyCall.fromJson(Map<String, dynamic>.from(request))
          : null,
    );
  }
}

class DriverPortal {
  const DriverPortal({
    required this.driverName,
    required this.ambulanceLabel,
    required this.ambulanceStatus,
    required this.activeRequest,
  });

  final String? driverName;
  final String? ambulanceLabel;
  final String? ambulanceStatus;
  final EmergencyCall? activeRequest;

  factory DriverPortal.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'];
    final ambulance = json['ambulance'];
    final active = json['activeRequest'];
    return DriverPortal(
      driverName: driver is Map ? driver['name'] as String? : null,
      ambulanceLabel: ambulance is Map ? ambulance['label'] as String? : null,
      ambulanceStatus: ambulance is Map ? ambulance['status'] as String? : null,
      activeRequest: active is Map
          ? EmergencyCall.fromJson(Map<String, dynamic>.from(active))
          : null,
    );
  }
}

class ProviderRow {
  const ProviderRow({
    required this.id,
    required this.name,
    required this.status,
    required this.rating,
    required this.inspectionFee,
    required this.specialisationId,
    required this.specialisationName,
    this.phone,
  });

  final String id;
  final String name;
  final String? status;
  final double rating;
  final double inspectionFee;
  final String? specialisationId;
  final String? specialisationName;
  final String? phone;

  ProviderRow withFee(double fee) {
    return ProviderRow(
      id: id,
      name: name,
      status: status,
      rating: rating,
      inspectionFee: fee,
      specialisationId: specialisationId,
      specialisationName: specialisationName,
      phone: phone,
    );
  }

  ProviderRow withRating(double nextRating) {
    return ProviderRow(
      id: id,
      name: name,
      status: status,
      rating: nextRating,
      inspectionFee: inspectionFee,
      specialisationId: specialisationId,
      specialisationName: specialisationName,
      phone: phone,
    );
  }

  factory ProviderRow.fromJson(Map<String, dynamic> json) {
    return ProviderRow(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      inspectionFee: (json['inspectionFee'] as num?)?.toDouble() ?? 0,
      specialisationId: json['specialisationId'] as String?,
      specialisationName: json['specialisationName'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

class CallerRow {
  const CallerRow({
    required this.id,
    required this.name,
    this.phone,
  });

  final String id;
  final String name;
  final String? phone;

  factory CallerRow.fromJson(Map<String, dynamic> json) {
    return CallerRow(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
    );
  }
}

class DomesticBooking {
  const DomesticBooking({
    required this.requestId,
    required this.status,
    required this.description,
    required this.address,
    required this.userName,
    required this.providerName,
    required this.providerRating,
    required this.inspectionFee,
    required this.specialisationName,
    this.quotedTotal,
    this.receiptInspectionFee,
    this.finalTotal,
    this.receiptStatus,
    this.finishedAt,
  });

  final String requestId;
  final String status;
  final String description;
  final String address;
  final String? userName;
  final String? providerName;
  final double? providerRating;
  final double? inspectionFee;
  final String? specialisationName;
  final double? quotedTotal;
  final double? receiptInspectionFee;
  final double? finalTotal;
  final String? receiptStatus;
  final DateTime? finishedAt;

  factory DomesticBooking.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final provider = json['provider'];
    final specialisation = json['specialisation'];
    return DomesticBooking(
      requestId: json['requestId'] as String,
      status: json['status'] as String,
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      userName: user is Map ? user['name'] as String? : null,
      providerName: provider is Map ? provider['name'] as String? : null,
      providerRating: provider is Map
          ? (provider['rating'] as num?)?.toDouble()
          : null,
      inspectionFee: provider is Map
          ? (provider['inspectionFee'] as num?)?.toDouble()
          : null,
      specialisationName: specialisation is Map
          ? specialisation['name'] as String?
          : null,
      quotedTotal: (json['quotedTotal'] as num?)?.toDouble(),
      receiptInspectionFee: (json['inspectionFee'] as num?)?.toDouble(),
      finalTotal: (json['finalTotal'] as num?)?.toDouble(),
      receiptStatus: json['receiptStatus'] as String?,
      finishedAt: _time(json['finishedAt']),
    );
  }
}

class EmergencyService {
  static const baseUrl = String.fromEnvironment(
    'MADAD_BACKEND_URL',
    defaultValue: 'https://madadplus.onrender.com',
  );

  static const requestTimeout = Duration(seconds: 45);

  static const _headers = {
    'Authorization': 'Bearer demo-token',
    'Content-Type': 'application/json',
  };

  Future<dynamic> _send(
    Future<http.Response> request,
    String fallbackError,
  ) async {
    final response = await request.timeout(requestTimeout);
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }

    if(response.statusCode < 200 || response.statusCode > 299) {
      final error = decoded is Map ? decoded['error'] : null;
      throw ApiException(
        error is String && error.isNotEmpty ? error : fallbackError,
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<EmergencyRequestResult> createEmergencyRequest({
    required double lat,
    required double lng,
    required String address,
    required String description,
    required int peopleCount,
    required String inputMethod,
    String? additionalDetails,
  }) async {
    final details = additionalDetails?.trim() ?? '';
    final decoded = await _send(
      http.post(
        Uri.parse('$baseUrl/api/v1/emergency-requests'),
        headers: _headers,
        body: jsonEncode({
          'lat': lat,
          'lng': lng,
          'type': 'ambulance',
          'address': address,
          'description': description,
          'peopleCount': peopleCount,
          'inputMethod': inputMethod,
          if(details.isNotEmpty) 'additionalDetails': details,
        }),
      ),
      'The emergency request could not be sent.',
    );

    return EmergencyRequestResult.fromJson(
      Map<String, dynamic>.from(decoded as Map),
    );
  }

  Future<void> completeEmergencyRequest({required String requestId}) async {
    await _send(
      http.patch(
        Uri.parse('$baseUrl/api/v1/emergency-requests/$requestId/complete'),
        headers: _headers,
      ),
      'The emergency request could not be completed.',
    );
  }

  Future<EmergencyCall> loadEmergencyRequest(String requestId) async {
    final decoded = await _send(
      http.get(
        Uri.parse('$baseUrl/api/v1/emergency-requests/$requestId'),
        headers: _headers,
      ),
      'The emergency request could not be loaded.',
    );
    return EmergencyCall.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  Future<List<AmbulanceRow>> listAmbulances() async {
    final decoded = await _send(
      http.get(Uri.parse('$baseUrl/api/v1/ambulances'), headers: _headers),
      'The ambulance list could not be loaded.',
    );
    return (decoded as List)
        .map((row) => AmbulanceRow.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<String> setDriverAvailability({
    required String driverId,
    required bool available,
  }) async {
    final action = available ? 'available' : 'unavailable';
    final decoded = await _send(
      http.patch(
        Uri.parse('$baseUrl/api/v1/drivers/$driverId/$action'),
        headers: _headers,
        body: available
            ? null
            : jsonEncode({'reason': 'Marked unavailable by driver'}),
      ),
      available
          ? 'The ambulance could not be marked available.'
          : 'The ambulance could not be marked unavailable.',
    );
    if(decoded is Map && decoded['status'] is String) {
      return decoded['status'] as String;
    }
    return available ? 'FREE' : 'UNAVAILABLE';
  }

  Future<DriverPortal> loadDriverPortal(String driverId) async {
    final decoded = await _send(
      http.get(
        Uri.parse('$baseUrl/api/v1/drivers/$driverId/portal'),
        headers: _headers,
      ),
      'The driver portal could not be loaded.',
    );
    return DriverPortal.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  Future<EmergencyCall> updateDriverRequest({
    required String driverId,
    required String requestId,
    required String action,
  }) async {
    final decoded = await _send(
      http.patch(
        Uri.parse('$baseUrl/api/v1/drivers/$driverId/requests/$requestId/$action'),
        headers: _headers,
      ),
      'The $action update could not be sent.',
    );
    return EmergencyCall.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  Future<DriverReassignment> reassignDriverRequest({
    required String driverId,
    required String requestId,
    double? lat,
    double? lng,
  }) async {
    final decoded = await _send(
      http.patch(
        Uri.parse('$baseUrl/api/v1/drivers/$driverId/requests/$requestId/reassign'),
        headers: _headers,
        body: lat != null && lng != null
            ? jsonEncode({'lat': lat, 'lng': lng})
            : null,
      ),
      'The ambulance could not be marked unavailable.',
    );
    return DriverReassignment.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  Future<List<CallerRow>> listCallers() async {
    final decoded = await _send(
      http.get(Uri.parse('$baseUrl/api/v1/callers'), headers: _headers),
      'The caller list could not be loaded.',
    );
    return (decoded as List)
        .map((row) => CallerRow.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<ProviderRow>> listProviders() async {
    final decoded = await _send(
      http.get(Uri.parse('$baseUrl/api/v1/providers'), headers: _headers),
      'The provider list could not be loaded.',
    );
    return (decoded as List)
        .map((row) => ProviderRow.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<double> setInspectionFee({
    required String providerId,
    required double inspectionFee,
  }) async {
    final decoded = await _send(
      http.patch(
        Uri.parse('$baseUrl/api/v1/providers/$providerId/inspection-fee'),
        headers: _headers,
        body: jsonEncode({'inspectionFee': inspectionFee}),
      ),
      'The inspection fee could not be saved.',
    );
    return ((decoded as Map)['inspectionFee'] as num).toDouble();
  }

  Future<double> setProviderRating({
    required String providerId,
    required int rating,
  }) async {
    final decoded = await _send(
      http.patch(
        Uri.parse('$baseUrl/api/v1/providers/$providerId/rating'),
        headers: _headers,
        body: jsonEncode({'rating': rating}),
      ),
      'The rating could not be saved.',
    );
    return ((decoded as Map)['rating'] as num).toDouble();
  }

  Future<DomesticBooking> createDomesticRequest({
    required String userId,
    required String providerId,
    required String specialisationId,
    required String description,
    required String address,
  }) async {
    final decoded = await _send(
      http.post(
        Uri.parse('$baseUrl/api/v1/domestic-requests'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'providerId': providerId,
          'specialisationId': specialisationId,
          'description': description,
          'address': address,
        }),
      ),
      'The booking could not be sent.',
    );
    return DomesticBooking.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  Future<List<DomesticBooking>> listProviderRequests(String providerId) async {
    final decoded = await _send(
      http.get(
        Uri.parse('$baseUrl/api/v1/providers/$providerId/requests'),
        headers: _headers,
      ),
      'The job list could not be loaded.',
    );
    return (decoded as List)
        .map(
          (row) => DomesticBooking.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<DomesticBooking> acceptProviderRequest({
    required String providerId,
    required String requestId,
  }) async {
    final decoded = await _send(
      http.patch(
        Uri.parse(
          '$baseUrl/api/v1/providers/$providerId/requests/$requestId/accept',
        ),
        headers: _headers,
      ),
      'The job could not be accepted.',
    );
    return DomesticBooking.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  Future<DomesticBooking> submitRepairCost({
    required String providerId,
    required String requestId,
    required double quotedTotal,
  }) async {
    final decoded = await _send(
      http.post(
        Uri.parse(
          '$baseUrl/api/v1/providers/$providerId/requests/$requestId/cost',
        ),
        headers: _headers,
        body: jsonEncode({'quotedTotal': quotedTotal}),
      ),
      'The repair total could not be sent.',
    );
    return DomesticBooking.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  Future<DomesticBooking> decideRepairCost({
    required String requestId,
    required bool accept,
  }) async {
    final decoded = await _send(
      http.post(
        Uri.parse('$baseUrl/api/v1/domestic-requests/$requestId/cost-decision'),
        headers: _headers,
        body: jsonEncode({'decision': accept ? 'ACCEPT' : 'REFUSE'}),
      ),
      'The decision could not be sent.',
    );
    return DomesticBooking.fromJson(Map<String, dynamic>.from(decoded as Map));
  }
}
