import '../../../../core/network/result.dart';
import '../../../../mock/mock_data.dart';
import '../../../../models/models.dart';
import '../../data/models/incident_details_models.dart';
import '../../domain/repositories/incident_details_repository.dart';

/// Prototype incident details, used while the app runs in mock-auth mode.
///
/// Mirrors [DemoIncidentRepository]: same interface, same prototype data source,
/// so the details screen, its bloc and its tests behave identically in mock and
/// real builds. All three panels return payloads shaped like the real API
/// responses.
class DemoIncidentDetailsRepository implements IncidentDetailsRepository {
  @override
  Future<Result<IncidentDetailsData>> getIncidentDetails({
    required int incidentId,
    required String incidentNo,
  }) async => Success(detailsFor(incidentId, incidentNo));

  @override
  Future<Result<IncidentTimelineData>> getIncidentTimeline({
    required int incidentId,
  }) async => Success(prototypeTimeline);

  @override
  Future<Result<IncidentRequestsData>> getIncidentRequests({
    required int incidentId,
  }) async => Success(prototypeRequests);

  /// Projects the matching `CapIncident` onto the details payload so the demo
  /// keeps showing the incident the user actually opened.
  static IncidentDetailsData detailsFor(int incidentId, String incidentNo) {
    // Matched on the incident number first: prototype incidents all share the
    // placeholder `incidentId` of 0, so the id cannot identify one.
    final match = MockData.capIncidents.cast<CapIncident?>().firstWhere(
      (item) => item?.number == incidentNo,
      orElse: () => MockData.capIncidents.cast<CapIncident?>().firstWhere(
        (item) => item?.incidentId == incidentId,
        orElse: () => null,
      ),
    );
    if (match == null) {
      return IncidentDetailsData(id: incidentId, incidentNo: incidentNo);
    }
    return IncidentDetailsData(
      id: match.incidentId,
      incidentNo: match.number,
      title: match.title,
      description: match.description,
      productName: match.productName,
      nativeMoName: match.nativeMoName,
      notificationType: IdNameDto(name: match.notificationType),
      status: IdNameDto(name: match.status.name),
      priority: IdNameDto(name: match.priority.name),
      incidentType: IdNameDto(name: match.type),
      assignedEngineer: IdNameDto(name: match.currentUser),
      createdDate: match.dateTime.toIso8601String(),
      location: IncidentLocationDto(
        id: match.siteCode,
        name: match.siteName,
        region: IdNameDto(name: match.region),
        area: IdNameDto(name: match.area),
      ),
    );
  }

  /// Shaped like a real `GetIncidentTimeline` payload, including the nullable
  /// `referenceId` and the `oldValue`/`newValue` transition pair.
  static IncidentTimelineData get prototypeTimeline => IncidentTimelineData(
    incidentId: MockData.capIncidents.first.incidentId,
    incidentNo: MockData.capIncidents.first.number,
    events: const [
      IncidentTimelineEventDto(
        dateTime: '2026-08-10T08:15:00',
        actionType: IdNameDto(id: 1, name: 'Assign'),
        eventType: 'Assign',
        eventTitle: 'Incident Assigned',
        eventDescription: 'Incident assigned to the field operations team.',
        oldValue: IdNameDto(id: 1, name: 'Need Assign'),
        newValue: IdNameDto(id: 2, name: 'Need Approval'),
        performedBy: IdNameDto(id: 4098, name: 'gsm manager'),
      ),
      IncidentTimelineEventDto(
        dateTime: '2026-08-10T09:02:00',
        actionType: IdNameDto(id: 3, name: 'Approve'),
        eventType: 'StatusChange',
        eventTitle: 'Incident Status Changed',
        eventDescription: 'Status changed from Need Approval to Pending',
        oldValue: IdNameDto(id: 2, name: 'Need Approval'),
        newValue: IdNameDto(id: 3, name: 'Pending'),
        performedBy: IdNameDto(id: 4099, name: 'engineer 1'),
      ),
    ],
  );

  /// Shaped exactly like a real `GetIncidentRequests` payload, including the
  /// numeric `id` that the UI labels as a request id rather than a number.
  static IncidentRequestsData get prototypeRequests => IncidentRequestsData(
    incidentId: MockData.capIncidents.first.incidentId,
    incidentNo: MockData.capIncidents.first.number,
    items: const [
      IncidentRequestItemDto(
        id: 1,
        requestType: IdNameDto(id: 1, name: 'Intervention Request'),
        requestStatus: IdNameDto(id: 2, name: 'Approved'),
        remark: 'Site access and intervention requirements were confirmed.',
        createdDate: '2026-09-05T00:00:00',
        createdBy: IdNameDto(id: 4089, name: 'offline user'),
        lastModifiedBy: IdNameDto(id: 4098, name: 'gsm manager'),
        lastModifiedDate: '2026-09-06T23:37:17.22',
      ),
      IncidentRequestItemDto(
        id: 2,
        requestType: IdNameDto(id: 2, name: 'Renewal Request'),
        requestStatus: IdNameDto(id: 3, name: 'Rejected'),
        remark: 'Additional intervention time was requested for field work.',
        createdDate: '2026-09-05T00:00:00',
        createdBy: IdNameDto(id: 4089, name: 'offline user'),
        lastModifiedBy: IdNameDto(id: 4098, name: 'gsm manager'),
        lastModifiedDate: '2026-09-07T01:33:42.047',
      ),
    ],
  );
}
