import 'package:access_log_plus/mock/mock_data.dart';
import 'package:access_log_plus/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('entry request decision follows the incident workflow', () {
    expect(
      statusAfterRequestDecision(
        current: CapIncidentStatus.pending,
        requestType: RelatedRequestType.intervention,
        approved: true,
      ),
      CapIncidentStatus.inProcess,
    );
    expect(
      statusAfterRequestDecision(
        current: CapIncidentStatus.pending,
        requestType: RelatedRequestType.intervention,
        approved: false,
      ),
      CapIncidentStatus.pending,
    );
    expect(
      statusAfterRequestDecision(
        current: CapIncidentStatus.inProcess,
        requestType: RelatedRequestType.renewal,
        approved: true,
      ),
      CapIncidentStatus.inProcess,
    );
  });

  test('central mock catalogue covers every incident and request state', () {
    expect(MockData.capIncidents, hasLength(greaterThanOrEqualTo(12)));
    expect(
      MockData.capIncidents.map((incident) => incident.status).toSet(),
      containsAll(CapIncidentStatus.values),
    );
    expect(
      MockData.myRequests.map((request) => request.status).toSet(),
      containsAll(MyRequestStatus.values),
    );
    expect(
      MockData.relatedRequests.map((request) => request.type).toSet(),
      containsAll(RelatedRequestType.values),
    );
    expect(
      MockData.notifications.map((notification) => notification.type).toSet(),
      containsAll(AppNotificationType.values),
    );
  });

  test('scenario and request relationships resolve to real mock incidents', () {
    final incidentNumbers = MockData.capIncidents
        .map((incident) => incident.number)
        .toSet();

    for (final scenario in MockData.prototypeScenarios) {
      expect(incidentNumbers, contains(scenario.incidentNumber));
      expect(
        MockData.incidentForScenario(scenario.type).number,
        scenario.incidentNumber,
      );
    }
    for (final request in MockData.myRequests) {
      expect(incidentNumbers, contains(request.incidentNumber));
    }
  });

  test('field engineer identity and supporting catalogues are complete', () {
    expect(MockData.engineer.name, 'Ahmed Mohamed');
    expect(MockData.companyName, 'Access Technical Services');
    expect(MockData.regionName, 'Cairo');
    expect(MockData.teamName, 'Field Team A');
    expect(MockData.teamMembers, hasLength(greaterThanOrEqualTo(5)));
    expect(MockData.incidentTimeline, hasLength(7));
    expect(MockData.questionnaireAnswers, isNotEmpty);
    expect(MockData.attachments, hasLength(greaterThanOrEqualTo(3)));
  });
}
