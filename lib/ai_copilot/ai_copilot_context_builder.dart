import '../mock/mock_data.dart';
import '../models/models.dart';
import 'ai_copilot_models.dart';

class AiCopilotContextBuilder {
  const AiCopilotContextBuilder();

  CompletionReadiness readiness(CapIncident incident) {
    final active =
        incident.status == CapIncidentStatus.inProcess ||
        incident.status == CapIncidentStatus.hold ||
        incident.status == CapIncidentStatus.completed;
    final completed = incident.status == CapIncidentStatus.completed;
    return CompletionReadiness(
      locationVerified: active,
      photosAttached: active ? 2 : 0,
      requiredPhotos: 2,
      questionnaireCompleted: active,
      signatureCaptured: completed,
      attachmentsAdded: completed,
    );
  }

  String build(CapIncident incident) {
    final state = readiness(incident);
    final similar =
        MockData.capIncidents
            .where(
              (item) =>
                  item.number != incident.number && item.type == incident.type,
            )
            .toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final lastSimilar = similar.isEmpty
        ? 'Not available'
        : '${similar.first.dateTime.day}/${similar.first.dateTime.month}/${similar.first.dateTime.year}';

    return '''
CURRENT FIELD SERVICE CONTEXT

Incident:
ID: ${incident.number}
Type: ${incident.type}
Site: ${incident.siteName}
Site Code: ${incident.siteCode}
Region: ${incident.region}
Area: ${incident.area}
Priority: ${incident.priority.name}
Status: ${incident.status.label}

Issue:
Title: ${incident.title}
Description: ${incident.description}

Engineer:
Name: ${MockData.engineer.name}
Company: ${MockData.companyName}
Team: ${MockData.teamName}

Intervention:
Active: ${incident.status == CapIncidentStatus.inProcess}
Started: ${incident.status == CapIncidentStatus.inProcess ? '09:30 AM (mock)' : 'Not available'}
Latest action: ${_latestAction(incident.status)}

Completion Requirements:
Location Verification: ${_done(state.locationVerified)}
Completion Photos: ${state.photosAttached}/${state.requiredPhotos}
Questionnaire: ${_done(state.questionnaireCompleted)}
Engineer Signature: ${_done(state.signatureCaptured)}
Required Attachment: ${_done(state.attachmentsAdded)}
Remaining Requirements: ${state.remaining}

Site History:
Similar incidents of this type: ${similar.length}
Most common resolution: Not available in current incident data
Last similar incident: $lastSimilar
''';
  }

  String _done(bool value) => value ? 'Completed' : 'Missing';

  String _latestAction(CapIncidentStatus status) => switch (status) {
    CapIncidentStatus.needAssign => 'Awaiting assignment',
    CapIncidentStatus.needApproval => 'Awaiting assignment approval',
    CapIncidentStatus.pending => 'Awaiting engineer decision',
    CapIncidentStatus.inProcess =>
      'Verification photo captured at 10:30 AM (mock)',
    CapIncidentStatus.hold => 'Task placed on hold',
    CapIncidentStatus.completed => 'Task completion submitted',
    CapIncidentStatus.cancelled => 'Incident cancelled',
  };
}
