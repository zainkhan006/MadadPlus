import 'package:socket_io_client/socket_io_client.dart' as io;

import 'emergency_outcome.dart';
import 'emergency_service.dart';

String? callerMessageFrom(dynamic data) {
  if(data is! Map) {
    return null;
  }
  final message = data['callerMessage'];
  if(message is! String || message.trim().isEmpty) {
    return null;
  }
  return message;
}

AmbulanceAssignment? reassignedAmbulanceFrom(dynamic data) {
  if(data is! Map) {
    return null;
  }
  final ambulance = data['assignedAmbulance'];
  if(ambulance is! Map || ambulance['id'] is! String || ambulance['label'] is! String) {
    return null;
  }
  return AmbulanceAssignment.fromJson(Map<String, dynamic>.from(ambulance));
}

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
  io.Socket? _requestSocket;
  io.Socket? _driverSocket;
  io.Socket? _providerSocket;
  io.Socket? _domesticSocket;

  io.Socket _joinRoom(String joinEvent, String id) {
    final roomSocket = io.io(
      EmergencyService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    roomSocket.onConnect((_) {
      roomSocket.emit(joinEvent, id);
    });
    return roomSocket;
  }

  void connectDriver({
    required String driverId,
    required void Function(EmergencyCall call) onCall,
  }) {
    disconnectDriver();
    final driverSocket = _joinRoom('join:driver', driverId);
    for(final eventName in [
      'request.assigned',
      'request.reassigned',
      'request.queued',
      'request.enRoute',
      'request.pickedUp',
      'request.patientTransferred',
      'request.arrived',
      'request.completed',
    ]) {
      driverSocket.on(eventName, (data) {
        onCall(EmergencyCall.fromJson(Map<String, dynamic>.from(data as Map)));
      });
    }
    driverSocket.connect();
    _driverSocket = driverSocket;
  }

  void disconnectDriver() {
    _driverSocket?.dispose();
    _driverSocket = null;
  }

  void connectProvider({
    required String providerId,
    required void Function(DomesticBooking booking) onBooking,
  }) {
    disconnectProvider();
    final providerSocket = _joinRoom('join:provider', providerId);
    for(final eventName in [
      'domestic.requested',
      'domestic.accepted',
      'domestic.cost_submitted',
      'domestic.cost_decided',
    ]) {
      providerSocket.on(eventName, (data) {
        onBooking(
          DomesticBooking.fromJson(Map<String, dynamic>.from(data as Map)),
        );
      });
    }
    providerSocket.connect();
    _providerSocket = providerSocket;
  }

  void disconnectProvider() {
    _providerSocket?.dispose();
    _providerSocket = null;
  }

  void connectDomestic({
    required String requestId,
    required void Function(DomesticBooking booking) onBooking,
  }) {
    disconnectDomestic();
    final domesticSocket = _joinRoom('join:domestic-request', requestId);
    for(final eventName in [
      'domestic.accepted',
      'domestic.cost_submitted',
      'domestic.cost_decided',
    ]) {
      domesticSocket.on(eventName, (data) {
        onBooking(
          DomesticBooking.fromJson(Map<String, dynamic>.from(data as Map)),
        );
      });
    }
    domesticSocket.connect();
    _domesticSocket = domesticSocket;
  }

  void disconnectDomestic() {
    _domesticSocket?.dispose();
    _domesticSocket = null;
  }

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
  }) {
    disconnect();
    var hasConnected = false;

    final requestSocket = io.io(
      EmergencyService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    _requestSocket = requestSocket;

    requestSocket.onConnect((_) {
      requestSocket.emit('join:request', requestId);
      if(hasConnected) {
        onReconnected?.call();
      }
      else {
        hasConnected = true;
      }
    });

    requestSocket.onDisconnect((_) {
      onDisconnected?.call();
    });

    requestSocket.on('request.assigned', (data) {
      final result = EmergencyRequestResult.fromJson(
        Map<String, dynamic>.from(data as Map),
      );
      onOutcome(createEmergencyOutcome(result));
      onAssigned?.call(result);
    });

    requestSocket.on('request.queued', (data) {
      final message = callerMessageFrom(data);
      if(message != null) {
        onCallerMessage?.call(message, null);
      }
    });

    requestSocket.on('request.reassigned', (data) {
      final message = callerMessageFrom(data);
      if(message != null) {
        onCallerMessage?.call(message, reassignedAmbulanceFrom(data));
      }
    });

    requestSocket.on('request.pickedUp', (data) {
      onPickedUp?.call(
        EmergencyCall.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    });

    requestSocket.on('request.completed', (data) {
      final completion = EmergencyCompletion.fromJson(
        Map<String, dynamic>.from(data as Map),
      );
      onCompleted?.call(completion);
    });

    requestSocket.connect();
  }

  void disconnect() {
    _requestSocket?.dispose();
    _requestSocket = null;
  }
}
