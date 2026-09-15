import 'package:socket_io_client/socket_io_client.dart' as io;

import 'emergency_outcome.dart';
import 'emergency_service.dart';

class CompletedAmbulance {
  const CompletedAmbulance({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  factory CompletedAmbulance.fromJson(Map<String, dynamic> json) {
    return CompletedAmbulance(
      id: json['id'] as String,
      label: json['label'] as String,
    );
  }
}

class AmbulanceLocation {
  const AmbulanceLocation({
    required this.lat,
    required this.lng,
  });

  final double lat;
  final double lng;

  factory AmbulanceLocation.fromJson(Map<String, dynamic> json) {
    return AmbulanceLocation(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class EmergencyCompletion {
  const EmergencyCompletion({
    required this.requestId,
    required this.status,
    required this.assignedAmbulance,
    required this.ambulanceLocation,
  });

  final String requestId;
  final String status;
  final CompletedAmbulance? assignedAmbulance;
  final AmbulanceLocation? ambulanceLocation;

  factory EmergencyCompletion.fromJson(Map<String, dynamic> json) {
    return EmergencyCompletion(
      requestId: json['requestId'] as String,
      status: json['status'] as String,
      assignedAmbulance: json['assignedAmbulance'] == null
          ? null
          : CompletedAmbulance.fromJson(
              Map<String, dynamic>.from(json['assignedAmbulance'] as Map),
            ),
      ambulanceLocation: json['ambulanceLocation'] == null
          ? null
          : AmbulanceLocation.fromJson(
              Map<String, dynamic>.from(json['ambulanceLocation'] as Map),
            ),
    );
  }
}

class EmergencySocketService {
  late final io.Socket socket;

  void connect({
    required String requestId,
    required void Function(EmergencyOutcome outcome) onOutcome,
    void Function(EmergencyCompletion completion)? onCompleted,
    void Function()? onDisconnected,
    void Function()? onReconnected,
  }) {
    var hasConnected = false;

    socket = io.io(
      EmergencyService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      socket.emit('join:request', requestId);
      if(hasConnected) {
        onReconnected?.call();
      }
      else {
        hasConnected = true;
      }
    });

    socket.onDisconnect((_) {
      onDisconnected?.call();
    });

    for(final eventName in ['request.assigned', 'request.queued']) {
      socket.on(eventName, (data) {
        final result = EmergencyRequestResult.fromJson(
          Map<String, dynamic>.from(data as Map),
        );
        onOutcome(createEmergencyOutcome(result));
      });
    }

    socket.on('request.completed', (data) {
      final completion = EmergencyCompletion.fromJson(
        Map<String, dynamic>.from(data as Map),
      );
      onCompleted?.call(completion);
    });

    socket.connect();
  }

  void disconnect() {
    socket.disconnect();
  }
}
