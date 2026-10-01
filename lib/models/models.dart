import 'package:flutter/material.dart';

enum IncidentStatus {
  assigned,
  accepted,
  enRoute,
  onSite,
  inProgress,
  pending,
  completed,
  rejected,
  escalated,
  overdue,
}

enum Priority { low, medium, high, critical }

enum CapIncidentStatus {
  needAssign,
  needApproval,
  pending,
  inProcess,
  hold,
  completed,
  cancelled,
}

extension CapIncidentStatusX on CapIncidentStatus {
  String get label => switch (this) {
    CapIncidentStatus.needAssign => 'Need Assign',
    CapIncidentStatus.needApproval => 'Need Approval',
    CapIncidentStatus.pending => 'Pending',
    CapIncidentStatus.inProcess => 'In Process',
    CapIncidentStatus.hold => 'On Hold',
    CapIncidentStatus.completed => 'Completed',
    CapIncidentStatus.cancelled => 'Cancelled',
  };
}

CapIncidentStatus statusAfterRequestDecision({
  required CapIncidentStatus current,
  required RelatedRequestType requestType,
  required bool approved,
}) {
  if (current == CapIncidentStatus.pending &&
      requestType == RelatedRequestType.intervention &&
      approved) {
    return CapIncidentStatus.inProcess;
  }
  return current;
}

enum AttachmentState { uploading, uploaded, failed }

enum QuestionType { text, yesNo, dropdown, multiChoice, number, date, checkbox }

class Engineer {
  const Engineer({
    required this.name,
    required this.role,
    required this.initials,
  });
  final String name, role, initials;
}

class TeamMember {
  const TeamMember({
    required this.name,
    required this.role,
    required this.area,
    required this.initials,
    this.available = true,
  });

  final String name, role, area, initials;
  final bool available;
}

class MockQuestionnaireAnswer {
  const MockQuestionnaireAnswer({
    required this.question,
    required this.answer,
    this.section = 'Field Assessment',
  });

  final String question, answer, section;
}

enum PrototypeScenarioType {
  newAssignment,
  pendingApproval,
  activeIntervention,
  taskOnHold,
  readyToComplete,
}

class PrototypeScenario {
  const PrototypeScenario({
    required this.type,
    required this.title,
    required this.description,
    required this.incidentNumber,
  });

  final PrototypeScenarioType type;
  final String title, description, incidentNumber;
}

class Site {
  const Site({required this.name, required this.id, required this.location});
  final String name, id, location;
}

class TowerSite {
  const TowerSite({
    required this.name,
    required this.code,
    required this.region,
    required this.area,
    required this.latitude,
    required this.longitude,
  });

  final String name, code, region, area;
  final double latitude, longitude;
}

class ContactPerson {
  const ContactPerson({
    required this.name,
    required this.phone,
    required this.role,
  });
  final String name, phone, role;
}

class Incident {
  const Incident({
    required this.number,
    required this.site,
    required this.priority,
    required this.status,
    required this.scheduledTime,
    required this.description,
  });
  final String number, scheduledTime, description;
  final Site site;
  final Priority priority;
  final IncidentStatus status;
}

class CapIncident {
  const CapIncident({
    /// Real CAP `incidentId` from `GetIncidentList`.
    ///
    /// Required so every construction site has to decide what the id is: detail
    /// endpoints such as `GetIncidentDetails` need this value, and it cannot be
    /// recovered from [number] or from a list position.
    required this.incidentId,
    required this.number,
    required this.type,
    required this.siteName,
    required this.siteCode,
    required this.region,
    required this.area,
    required this.location,
    required this.title,
    required this.priority,
    required this.dateTime,
    required this.status,
    required this.currentUser,
    this.hasRealDate = true,
    this.needsApproval = false,
    this.description =
        'Network monitoring generated this CAP incident for field assessment and corrective action.',
    this.productName = 'Mobile Network Infrastructure',
    this.nativeMoName = 'CAP-NETWORK-MO',
    this.notificationType = 'Operational Alarm',
  });

  final int incidentId;
  final bool hasRealDate;
  final String number;
  final String type;
  final String siteName;
  final String siteCode;
  final String region;
  final String area;
  final String location;
  final String title;
  final Priority priority;
  final DateTime dateTime;
  final CapIncidentStatus status;
  final String currentUser;
  final bool needsApproval;
  final String description;
  final String productName;
  final String nativeMoName;
  final String notificationType;
}

enum RelatedRequestType { intervention, renewal, departure }

enum AppNotificationType {
  newAssignment,
  renewalReminder,
  departureReminder,
  gpsWarning,
  photoReminder,
  socMessage,
  systemAnnouncement,
}

class AppNotification {
  const AppNotification({
    required this.type,
    required this.title,
    required this.description,
    required this.time,
    this.isRead = false,
  });
  final AppNotificationType type;
  final String title, description, time;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    type: type,
    title: title,
    description: description,
    time: time,
    isRead: isRead ?? this.isRead,
  );
}

extension RelatedRequestTypeX on RelatedRequestType {
  String get label => switch (this) {
    RelatedRequestType.intervention => 'Intervention Request',
    RelatedRequestType.renewal => 'Renewal Request',
    RelatedRequestType.departure => 'Departure Request',
  };
}

class IncidentHistoryEvent {
  const IncidentHistoryEvent({
    required this.action,
    required this.dateTime,
    required this.user,
    required this.remarks,
    this.completed = true,
  });
  final String action, user, remarks;
  final DateTime dateTime;
  final bool completed;
}

class RelatedRequest {
  const RelatedRequest({
    required this.number,
    required this.type,
    required this.status,
    required this.dateTime,
    required this.createdBy,
  });
  final String number, status, createdBy;
  final RelatedRequestType type;
  final DateTime dateTime;

  RelatedRequest copyWith({String? status}) => RelatedRequest(
    number: number,
    type: type,
    status: status ?? this.status,
    dateTime: dateTime,
    createdBy: createdBy,
  );
}

enum MyRequestStatus { pending, approved, rejected, completed }

class MyRequest {
  const MyRequest({
    required this.number,
    required this.type,
    required this.status,
    required this.incidentNumber,
    required this.siteName,
    required this.siteCode,
    required this.createdDate,
    required this.createdBy,
    required this.questionnaireSummary,
    this.renewalMinutes,
    this.confirmationSerial,
    this.attachments = const [],
  });
  final String number;
  final RelatedRequestType type;
  final MyRequestStatus status;
  final String incidentNumber, siteName, siteCode, createdBy;
  final DateTime createdDate;
  final String questionnaireSummary;
  final int? renewalMinutes;
  final String? confirmationSerial;
  final List<String> attachments;

  MyRequest copyWith({MyRequestStatus? status}) => MyRequest(
    number: number,
    type: type,
    status: status ?? this.status,
    incidentNumber: incidentNumber,
    siteName: siteName,
    siteCode: siteCode,
    createdDate: createdDate,
    createdBy: createdBy,
    questionnaireSummary: questionnaireSummary,
    renewalMinutes: renewalMinutes,
    confirmationSerial: confirmationSerial,
    attachments: attachments,
  );
}

class IncidentListFilter {
  const IncidentListFilter({
    this.status,
    this.priority,
    this.region,
    this.area,
    this.site,
    this.incidentNumber,
    this.type,
    this.location,
    this.from,
    this.to,
  });

  final CapIncidentStatus? status;
  final Priority? priority;
  final String? region, area, site, incidentNumber, type, location;
  final DateTime? from, to;

  IncidentListFilter withoutStatus() => IncidentListFilter(
    priority: priority,
    region: region,
    area: area,
    site: site,
    incidentNumber: incidentNumber,
    type: type,
    location: location,
    from: from,
    to: to,
  );

  bool get isActive =>
      status != null ||
      priority != null ||
      [
        region,
        area,
        site,
        incidentNumber,
        type,
        location,
      ].any((value) => value != null && value.isNotEmpty) ||
      from != null ||
      to != null;
}

class AppAttachment {
  const AppAttachment({
    required this.name,
    required this.type,
    required this.size,
    required this.state,
  });
  final String name, type, size;
  final AttachmentState state;
}

class TimelineEvent {
  const TimelineEvent({
    required this.title,
    required this.time,
    required this.description,
    this.icon = Icons.check,
  });
  final String title, time, description;
  final IconData icon;
}

class QuestionnaireItem {
  const QuestionnaireItem({
    required this.label,
    required this.type,
    this.options = const [],
  });
  final String label;
  final QuestionType type;
  final List<String> options;
}
