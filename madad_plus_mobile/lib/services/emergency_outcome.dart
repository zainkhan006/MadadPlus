import 'emergency_service.dart';

enum EmergencyOutcomeType {
  assigned,
  queued,
}

class EmergencyOutcome {
  const EmergencyOutcome({
    required this.type,
    required this.message,
  });

  final EmergencyOutcomeType type;
  final String message;
}

EmergencyOutcome createEmergencyOutcome(EmergencyRequestResult result) {
  if(result.status == 'QUEUED') {
    return const EmergencyOutcome(
      type: EmergencyOutcomeType.queued,
      message: 'No ambulance is available. Your request is in the queue.',
    );
  }

  final assignedAmbulance = result.assignedAmbulance!;
  final consideredNearest = result.consideredNearest;

  if(consideredNearest != null) {
    return EmergencyOutcome(
      type: EmergencyOutcomeType.assigned,
      message:
          '${consideredNearest.label} was closer but ${consideredNearest.status!.toLowerCase()}. '
          '${assignedAmbulance.label} was assigned instead.',
    );
  }

  return EmergencyOutcome(
    type: EmergencyOutcomeType.assigned,
    message: '${assignedAmbulance.label} was assigned.',
  );
}
