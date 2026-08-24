import '../models/models.dart';

/// The single source of truth for every person, incident and evidence sample
/// used by the clickable prototype. Widgets may derive local UI state from
/// these values, but should not invent business data of their own.
abstract final class MockData {
  static const companyName = 'Access Technical Services';
  static const regionName = 'Cairo';
  static const teamName = 'Field Team A';
  static const mobileNumber = '+20 100 555 0148';
  static const email = 'ahmed.mohamed@accessts.example';
  static const activeInterventionNumber = 'INT-2026-0064';
  static const confirmationSerialNumber = 'ATS-DEP-784201';
  static const sessionTimeoutMinutes = 30;
  static const sessionWarningSeconds = 60;
  static const autoApproveSelfAssignment = true;

  static const engineer = Engineer(
    name: 'Ahmed Mohamed',
    role: 'Senior Field Engineer',
    initials: 'AM',
  );

  static const teamMembers = [
    TeamMember(
      name: 'Ahmed Mohamed',
      role: 'Senior Field Engineer',
      area: 'Nasr City',
      initials: 'AM',
    ),
    TeamMember(
      name: 'Mina Adel',
      role: 'Field Engineer',
      area: 'New Cairo',
      initials: 'MA',
    ),
    TeamMember(
      name: 'Sara Samir',
      role: 'Transmission Engineer',
      area: 'Giza',
      initials: 'SS',
    ),
    TeamMember(
      name: 'Karim Nabil',
      role: 'Fiber Engineer',
      area: 'Heliopolis',
      initials: 'KN',
      available: false,
    ),
    TeamMember(
      name: 'Nour Khaled',
      role: 'Power Engineer',
      area: 'Maadi',
      initials: 'NK',
    ),
  ];

  static const sites = [
    Site(
      name: 'Cairo Central Site',
      id: 'CAI-CORE-014',
      location: 'Nasr City, Cairo',
    ),
    Site(name: 'Maadi Exchange', id: 'CAI-EXC-207', location: 'Maadi, Cairo'),
    Site(
      name: 'Giza Radio Site 08',
      id: 'GIZ-RAN-008',
      location: 'Dokki, Giza',
    ),
  ];

  static const towerSites = [
    TowerSite(
      name: 'Cairo Central Site',
      code: 'CAI-CORE-014',
      region: 'Cairo',
      area: 'Nasr City',
      latitude: 30.0561,
      longitude: 31.3301,
    ),
    TowerSite(
      name: 'Maadi Exchange',
      code: 'CAI-EXC-207',
      region: 'Cairo',
      area: 'Maadi',
      latitude: 29.9602,
      longitude: 31.2569,
    ),
    TowerSite(
      name: 'Giza Radio Site 08',
      code: 'GIZ-RAN-008',
      region: 'Giza',
      area: 'Dokki',
      latitude: 30.0384,
      longitude: 31.2122,
    ),
    TowerSite(
      name: 'New Cairo Hub 03',
      code: 'CAI-HUB-003',
      region: 'Cairo',
      area: 'New Cairo',
      latitude: 30.0074,
      longitude: 31.4913,
    ),
    TowerSite(
      name: 'October MSC',
      code: 'GIZ-MSC-002',
      region: 'Giza',
      area: '6th of October',
      latitude: 29.9723,
      longitude: 30.9448,
    ),
    TowerSite(
      name: 'Heliopolis RAN 21',
      code: 'CAI-RAN-021',
      region: 'Cairo',
      area: 'Heliopolis',
      latitude: 30.0918,
      longitude: 31.3239,
    ),
    TowerSite(
      name: 'Alexandria Exchange 01',
      code: 'ALX-EXC-001',
      region: 'Alexandria',
      area: 'Smouha',
      latitude: 31.2156,
      longitude: 29.9427,
    ),
    TowerSite(
      name: 'Mansoura Core 02',
      code: 'MAN-CORE-002',
      region: 'Delta',
      area: 'Mansoura',
      latitude: 31.0409,
      longitude: 31.3785,
    ),
    TowerSite(
      name: 'Shubra Hub 05',
      code: 'CAI-HUB-005',
      region: 'Cairo',
      area: 'Shubra',
      latitude: 30.0778,
      longitude: 31.2453,
    ),
    TowerSite(
      name: 'Smart Village POP',
      code: 'GIZ-POP-011',
      region: 'Giza',
      area: 'Smart Village',
      latitude: 30.0718,
      longitude: 30.9866,
    ),
    TowerSite(
      name: 'Ramses Exchange',
      code: 'CAI-EXC-101',
      region: 'Cairo',
      area: 'Downtown',
      latitude: 30.0626,
      longitude: 31.2461,
    ),
    TowerSite(
      name: 'Banha Aggregation 04',
      code: 'DEL-AGG-004',
      region: 'Delta',
      area: 'Banha',
      latitude: 30.4668,
      longitude: 31.1848,
    ),
  ];

  static final incidents = [
    Incident(
      number: 'INC-2026-1001',
      site: sites[0],
      priority: Priority.critical,
      status: IncidentStatus.inProgress,
      scheduledTime: '09:30 AM',
      description: 'Core router power module degradation detected.',
    ),
    Incident(
      number: 'INC-2026-1002',
      site: sites[1],
      priority: Priority.high,
      status: IncidentStatus.assigned,
      scheduledTime: '12:15 PM',
      description: 'Fiber attenuation above operational threshold.',
    ),
    Incident(
      number: 'INC-2026-1005',
      site: sites[2],
      priority: Priority.medium,
      status: IncidentStatus.completed,
      scheduledTime: 'Yesterday',
      description: 'Preventive cabinet and battery inspection.',
    ),
  ];

  static final capIncidents = [
    _incident(
      'INC-2026-1001',
      'Power Alarm',
      'Cairo Central Site',
      'CAI-CORE-014',
      'Cairo',
      'Nasr City',
      'Abbas El Akkad Street',
      'Rectifier module output below threshold',
      Priority.critical,
      DateTime(2026, 8, 10, 9, 30),
      CapIncidentStatus.inProcess,
      engineer.name,
      approval: true,
      description:
          'The main rectifier is reporting unstable DC output and requires on-site diagnostics.',
    ),
    _incident(
      'INC-2026-1002',
      'Fiber Degradation',
      'Maadi Exchange',
      'CAI-EXC-207',
      'Cairo',
      'Maadi',
      'Road 9',
      'High attenuation on aggregation link',
      Priority.high,
      DateTime(2026, 8, 10, 10, 15),
      CapIncidentStatus.pending,
      'NOC Approval Queue',
    ),
    _incident(
      'INC-2026-1003',
      'Site Access',
      'Giza Radio Site 08',
      'GIZ-RAN-008',
      'Giza',
      'Dokki',
      'Tahrir Street',
      'Access coordination required for cabinet inspection',
      Priority.medium,
      DateTime(2026, 8, 10, 11),
      CapIncidentStatus.needAssign,
      'Dispatch Team',
    ),
    _incident(
      'INC-2026-1004',
      'Transmission',
      'New Cairo Hub 03',
      'CAI-HUB-003',
      'Cairo',
      'New Cairo',
      'Fifth Settlement',
      'Microwave link showing intermittent packet loss',
      Priority.high,
      DateTime(2026, 8, 10, 8, 20),
      CapIncidentStatus.hold,
      'Mina Adel',
    ),
    _incident(
      'INC-2026-1005',
      'Preventive Maintenance',
      'October MSC',
      'GIZ-MSC-002',
      'Giza',
      '6th of October',
      'Industrial Zone',
      'Quarterly battery bank health inspection',
      Priority.low,
      DateTime(2026, 8, 10, 7, 45),
      CapIncidentStatus.completed,
      'Sara Samir',
    ),
    _incident(
      'INC-2026-1006',
      'Environmental Alarm',
      'Heliopolis RAN 21',
      'CAI-RAN-021',
      'Cairo',
      'Heliopolis',
      'El Nozha Street',
      'Shelter temperature sensor inconsistency',
      Priority.medium,
      DateTime(2026, 8, 10, 6, 55),
      CapIncidentStatus.cancelled,
      'Karim Nabil',
    ),
    _incident(
      'INC-2026-1007',
      'Generator Failure',
      'Alexandria Exchange 01',
      'ALX-EXC-001',
      'Alexandria',
      'Smouha',
      'Victor Emanuel Square',
      'Backup generator failed automatic startup test',
      Priority.critical,
      DateTime(2026, 8, 9, 17, 40),
      CapIncidentStatus.inProcess,
      'Youssef Ali',
      approval: true,
    ),
    _incident(
      'INC-2026-1008',
      'Cooling System',
      'Mansoura Core 02',
      'MAN-CORE-002',
      'Delta',
      'Mansoura',
      'El Gomhoria Street',
      'HVAC unit two requires corrective maintenance',
      Priority.high,
      DateTime(2026, 8, 9, 14, 10),
      CapIncidentStatus.completed,
      'Nour Khaled',
    ),
    _incident(
      'INC-2026-1009',
      'Battery Alarm',
      'Shubra Hub 05',
      'CAI-HUB-005',
      'Cairo',
      'Shubra',
      'Ahmed Helmy Street',
      'Battery string voltage imbalance detected',
      Priority.high,
      DateTime(2026, 8, 9, 12, 25),
      CapIncidentStatus.pending,
      engineer.name,
    ),
    _incident(
      'INC-2026-1010',
      'Fiber Cut',
      'Smart Village POP',
      'GIZ-POP-011',
      'Giza',
      'Smart Village',
      'Technology Park',
      'Enterprise feeder fiber requires emergency splice',
      Priority.critical,
      DateTime(2026, 8, 8, 22, 5),
      CapIncidentStatus.needAssign,
      'Dispatch Team',
    ),
    _incident(
      'INC-2026-1011',
      'Door Alarm',
      'Ramses Exchange',
      'CAI-EXC-101',
      'Cairo',
      'Downtown',
      'Ramses Square',
      'Equipment room access sensor remains open',
      Priority.medium,
      DateTime(2026, 8, 8, 16, 35),
      CapIncidentStatus.hold,
      'Hassan Emad',
    ),
    _incident(
      'INC-2026-1012',
      'Transmission',
      'Banha Aggregation 04',
      'DEL-AGG-004',
      'Delta',
      'Banha',
      'Corniche Road',
      'Aggregation ring protection switch investigation',
      Priority.medium,
      DateTime(2026, 8, 7, 13, 50),
      CapIncidentStatus.needApproval,
      'Quality Review Team',
    ),
    _incident(
      'INC-2026-1013',
      'Power Maintenance',
      'Cairo Airport Radio Site',
      'CAI-RAN-033',
      'Cairo',
      'Heliopolis',
      'Airport Road',
      'Approve field assignment for rectifier inspection',
      Priority.high,
      DateTime(2026, 8, 10, 8, 45),
      CapIncidentStatus.needApproval,
      engineer.name,
      approval: true,
      description:
          'The incident has been assigned to the field engineer and is waiting for assignment approval before work can begin.',
    ),
  ];

  static CapIncident _incident(
    String number,
    String type,
    String siteName,
    String siteCode,
    String region,
    String area,
    String location,
    String title,
    Priority priority,
    DateTime dateTime,
    CapIncidentStatus status,
    String currentUser, {
    bool approval = false,
    String description =
        'Network monitoring generated this incident for field assessment and corrective action.',
  }) => CapIncident(
    number: number,
    type: type,
    siteName: siteName,
    siteCode: siteCode,
    region: region,
    area: area,
    location: location,
    title: title,
    priority: priority,
    dateTime: dateTime,
    status: status,
    currentUser: currentUser,
    needsApproval: approval,
    description: description,
  );

  static final incidentTimeline = [
    IncidentHistoryEvent(
      action: 'Created',
      dateTime: DateTime(2026, 8, 10, 8, 35),
      user: 'Network Monitoring',
      remarks: 'Critical rectifier alarm generated the incident.',
    ),
    IncidentHistoryEvent(
      action: 'Assigned',
      dateTime: DateTime(2026, 8, 10, 8, 41),
      user: 'Mariam Adel • NOC',
      remarks: 'Assigned to Cairo Field Team A.',
    ),
    IncidentHistoryEvent(
      action: 'Started',
      dateTime: DateTime(2026, 8, 10, 9, 42),
      user: engineer.name,
      remarks: 'Site access confirmed and field intervention started.',
    ),
    IncidentHistoryEvent(
      action: 'On Hold',
      dateTime: DateTime(2026, 8, 10, 10, 18),
      user: engineer.name,
      remarks: 'Replacement rectifier module approval was required.',
    ),
    IncidentHistoryEvent(
      action: 'Renewed',
      dateTime: DateTime(2026, 8, 10, 10, 46),
      user: 'Mariam Adel • NOC',
      remarks: 'Intervention window extended by two hours.',
    ),
    IncidentHistoryEvent(
      action: 'Completed',
      dateTime: DateTime(2026, 8, 10, 12, 20),
      user: engineer.name,
      remarks: 'Module replaced and DC readings returned to normal.',
      completed: false,
    ),
    IncidentHistoryEvent(
      action: 'Closed',
      dateTime: DateTime(2026, 8, 10, 13, 5),
      user: 'Quality Review Team',
      remarks: 'Evidence reviewed and incident formally closed.',
      completed: false,
    ),
  ];

  static final relatedRequests = [
    RelatedRequest(
      number: activeInterventionNumber,
      type: RelatedRequestType.intervention,
      status: 'Approved',
      dateTime: DateTime(2026, 8, 10, 9, 48),
      createdBy: engineer.name,
    ),
    RelatedRequest(
      number: 'REN-2026-0021',
      type: RelatedRequestType.renewal,
      status: 'Pending Approval',
      dateTime: DateTime(2026, 8, 10, 10, 31),
      createdBy: engineer.name,
    ),
    RelatedRequest(
      number: 'DEP-2026-0018',
      type: RelatedRequestType.departure,
      status: 'Draft',
      dateTime: DateTime(2026, 8, 10, 11, 55),
      createdBy: engineer.name,
    ),
  ];

  static final notifications = [
    AppNotification(
      type: AppNotificationType.newAssignment,
      title: 'New critical assignment',
      description:
          '${capIncidents[0].number} at ${capIncidents[0].siteName} was assigned to you.',
      time: '2 min ago',
    ),
    const AppNotification(
      type: AppNotificationType.renewalReminder,
      title: 'Intervention renewal due',
      description: 'The approved intervention window expires in 20 minutes.',
      time: '12 min ago',
    ),
    AppNotification(
      type: AppNotificationType.departureReminder,
      title: 'Departure request required',
      description:
          'Submit departure clearance before leaving ${capIncidents[0].siteName}.',
      time: '28 min ago',
    ),
    const AppNotification(
      type: AppNotificationType.gpsWarning,
      title: 'Location validation warning',
      description:
          'Your latest simulated check is outside the permitted radius.',
      time: '45 min ago',
    ),
    const AppNotification(
      type: AppNotificationType.photoReminder,
      title: 'Verification photo required',
      description:
          'Capture the scheduled evidence photo for the active intervention.',
      time: '1 hr ago',
      isRead: true,
    ),
    const AppNotification(
      type: AppNotificationType.socMessage,
      title: 'Message from SOC',
      description:
          'Maintain site access restrictions during the planned intervention.',
      time: '2 hrs ago',
      isRead: true,
    ),
    const AppNotification(
      type: AppNotificationType.systemAnnouncement,
      title: 'Planned maintenance notice',
      description:
          'Access Log+ prototype services will be unavailable tonight at 11:00 PM.',
      time: 'Yesterday',
      isRead: true,
    ),
  ];

  static final myRequests = [
    MyRequest(
      number: activeInterventionNumber,
      type: RelatedRequestType.intervention,
      status: MyRequestStatus.approved,
      incidentNumber: capIncidents[0].number,
      siteName: capIncidents[0].siteName,
      siteCode: capIncidents[0].siteCode,
      createdDate: DateTime(2026, 8, 10, 9, 48),
      createdBy: engineer.name,
      questionnaireSummary: 'Site access confirmed; equipment safely isolated.',
      attachments: const ['site_permission.pdf', 'rectifier_before.jpg'],
    ),
    MyRequest(
      number: 'REN-2026-0021',
      type: RelatedRequestType.renewal,
      status: MyRequestStatus.pending,
      incidentNumber: capIncidents[0].number,
      siteName: capIncidents[0].siteName,
      siteCode: capIncidents[0].siteCode,
      createdDate: DateTime(2026, 8, 10, 10, 31),
      createdBy: engineer.name,
      questionnaireSummary:
          'Additional time required to replace and test the rectifier.',
      renewalMinutes: 60,
    ),
    MyRequest(
      number: 'DEP-2026-0018',
      type: RelatedRequestType.departure,
      status: MyRequestStatus.completed,
      incidentNumber: capIncidents[4].number,
      siteName: capIncidents[4].siteName,
      siteCode: capIncidents[4].siteCode,
      createdDate: DateTime(2026, 8, 10, 11, 55),
      createdBy: engineer.name,
      questionnaireSummary:
          'Work area cleared, cabinet locked and site secured.',
      confirmationSerial: confirmationSerialNumber,
      attachments: const ['departure_evidence.jpg'],
    ),
    MyRequest(
      number: 'INT-2026-0057',
      type: RelatedRequestType.intervention,
      status: MyRequestStatus.rejected,
      incidentNumber: capIncidents[6].number,
      siteName: capIncidents[6].siteName,
      siteCode: capIncidents[6].siteCode,
      createdDate: DateTime(2026, 8, 9, 18, 5),
      createdBy: engineer.name,
      questionnaireSummary:
          'Generator access requested during restricted hours.',
      attachments: const ['access_letter.pdf'],
    ),
    MyRequest(
      number: 'REN-2026-0019',
      type: RelatedRequestType.renewal,
      status: MyRequestStatus.approved,
      incidentNumber: capIncidents[7].number,
      siteName: capIncidents[7].siteName,
      siteCode: capIncidents[7].siteCode,
      createdDate: DateTime(2026, 8, 9, 15, 20),
      createdBy: engineer.name,
      questionnaireSummary:
          'HVAC testing required an extended observation window.',
      renewalMinutes: 90,
    ),
    MyRequest(
      number: 'DEP-2026-0014',
      type: RelatedRequestType.departure,
      status: MyRequestStatus.approved,
      incidentNumber: capIncidents[3].number,
      siteName: capIncidents[3].siteName,
      siteCode: capIncidents[3].siteCode,
      createdDate: DateTime(2026, 8, 8, 16, 40),
      createdBy: engineer.name,
      questionnaireSummary:
          'Transmission checks completed and all tools removed.',
      confirmationSerial: 'ATS-DEP-771903',
    ),
  ];

  static const attachments = [
    AppAttachment(
      name: 'rectifier_before.jpg',
      type: 'Image',
      size: '2.4 MB',
      state: AttachmentState.uploaded,
    ),
    AppAttachment(
      name: 'site_access_permit.pdf',
      type: 'PDF',
      size: '840 KB',
      state: AttachmentState.uploaded,
    ),
    AppAttachment(
      name: 'dc_voltage_readings.docx',
      type: 'Document',
      size: '118 KB',
      state: AttachmentState.uploading,
    ),
    AppAttachment(
      name: 'failed_upload.jpg',
      type: 'Image',
      size: '3.1 MB',
      state: AttachmentState.failed,
    ),
  ];

  static const questionnaireAnswers = [
    MockQuestionnaireAnswer(
      question: 'Cabinet condition',
      answer: 'Needs attention',
      section: 'Site inspection',
    ),
    MockQuestionnaireAnswer(
      question: 'Is site access secure?',
      answer: 'Yes',
      section: 'Safety',
    ),
    MockQuestionnaireAnswer(
      question: 'Input voltage',
      answer: '218 V',
      section: 'Electrical readings',
    ),
    MockQuestionnaireAnswer(
      question: 'Was any equipment damaged?',
      answer: 'No',
      section: 'Damage assessment',
    ),
    MockQuestionnaireAnswer(
      question: 'Equipment status',
      answer: 'Partially Working',
      section: 'Equipment assessment',
    ),
  ];

  static const timeline = [
    TimelineEvent(
      title: 'Journey started',
      time: '08:48 AM',
      description: 'Engineer is travelling to Cairo Central Site.',
    ),
    TimelineEvent(
      title: 'Incident accepted',
      time: '08:41 AM',
      description: 'Assignment acknowledged by Ahmed Mohamed.',
    ),
    TimelineEvent(
      title: 'Incident assigned',
      time: '08:35 AM',
      description: 'Dispatched by the Network Operations Center.',
    ),
  ];

  static const questions = [
    QuestionnaireItem(
      label: 'Cabinet condition',
      type: QuestionType.dropdown,
      options: ['Good', 'Needs attention', 'Critical'],
    ),
    QuestionnaireItem(
      label: 'Is site access secure?',
      type: QuestionType.yesNo,
    ),
    QuestionnaireItem(label: 'Input voltage', type: QuestionType.number),
    QuestionnaireItem(
      label: 'Safety checklist completed',
      type: QuestionType.checkbox,
    ),
  ];

  static const prototypeScenarios = [
    PrototypeScenario(
      type: PrototypeScenarioType.newAssignment,
      title: 'New Assignment',
      description: 'Unassigned site-access incident ready for dispatch.',
      incidentNumber: 'INC-2026-1003',
    ),
    PrototypeScenario(
      type: PrototypeScenarioType.pendingApproval,
      title: 'Pending Approval',
      description: 'Fiber incident awaiting the engineer decision.',
      incidentNumber: 'INC-2026-1002',
    ),
    PrototypeScenario(
      type: PrototypeScenarioType.activeIntervention,
      title: 'Active Intervention',
      description: 'Critical power incident currently being worked.',
      incidentNumber: 'INC-2026-1001',
    ),
    PrototypeScenario(
      type: PrototypeScenarioType.taskOnHold,
      title: 'Task On Hold',
      description: 'Transmission task paused while parts are arranged.',
      incidentNumber: 'INC-2026-1004',
    ),
    PrototypeScenario(
      type: PrototypeScenarioType.readyToComplete,
      title: 'Ready To Complete',
      description: 'Active work with evidence ready for completion.',
      incidentNumber: 'INC-2026-1007',
    ),
  ];

  static CapIncident incidentForScenario(PrototypeScenarioType type) {
    final scenario = prototypeScenarios.firstWhere((item) => item.type == type);
    return capIncidents.firstWhere(
      (item) => item.number == scenario.incidentNumber,
    );
  }
}
