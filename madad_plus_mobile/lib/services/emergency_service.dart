import 'dart:convert';

import 'package:http/http.dart' as http;

class AmbulanceAssignment {
  const AmbulanceAssignment({
    required this.id,
    required this.label,
    required this.distanceKm,
    this.status,
  });

  final String id;
  final String label;
  final double distanceKm;
  final String? status;

  factory AmbulanceAssignment.fromJson(Map<String, dynamic> json) {
    return AmbulanceAssignment(
      id: json['id'] as String,
      label: json['label'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      status: json['status'] as String?,
    );
  }
}

class EmergencyRequestResult {
  const EmergencyRequestResult({
    required this.requestId,
    required this.status,
    required this.assignedAmbulance,
    required this.consideredNearest,
  });

  final String requestId;
  final String status;
  final AmbulanceAssignment? assignedAmbulance;
  final AmbulanceAssignment? consideredNearest;

  factory EmergencyRequestResult.fromJson(Map<String, dynamic> json) {
    return EmergencyRequestResult(
      requestId: json['requestId'] as String,
      status: json['status'] as String,
      assignedAmbulance: json['assignedAmbulance'] == null
          ? null
          : AmbulanceAssignment.fromJson(
              json['assignedAmbulance'] as Map<String, dynamic>,
            ),
      consideredNearest: json['consideredNearest'] == null
          ? null
          : AmbulanceAssignment.fromJson(
              json['consideredNearest'] as Map<String, dynamic>,
            ),
    );
  }
}

class EmergencyService {
  static const baseUrl = String.fromEnvironment(
    'MADAD_BACKEND_URL',
    defaultValue: 'http://192.168.10.4:3000',
  );

  Future<EmergencyRequestResult> createEmergencyRequest({
    required double lat,
    required double lng,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/emergency-requests'),
      headers: {
        'Authorization': 'Bearer demo-token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'lat': lat, 'lng': lng, 'type': 'ambulance'}),
    );

    if (response.statusCode != 201) {
      throw Exception('The emergency request could not be sent.');
    }

    return EmergencyRequestResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> completeEmergencyRequest({required String requestId}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/v1/emergency-requests/$requestId/complete'),
      headers: {
        'Authorization': 'Bearer demo-token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('The emergency request could not be completed.');
    }
  }
}
