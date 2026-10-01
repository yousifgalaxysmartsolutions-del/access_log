// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incident_details_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IdNameDto _$IdNameDtoFromJson(Map<String, dynamic> json) =>
    IdNameDto(id: (json['id'] as num?)?.toInt(), name: json['name'] as String?);

Map<String, dynamic> _$IdNameDtoToJson(IdNameDto instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
};

IncidentLocationDto _$IncidentLocationDtoFromJson(Map<String, dynamic> json) =>
    IncidentLocationDto(
      id: json['id'] as String?,
      name: json['name'] as String?,
      region: json['region'] == null
          ? null
          : IdNameDto.fromJson(json['region'] as Map<String, dynamic>),
      area: json['area'] == null
          ? null
          : IdNameDto.fromJson(json['area'] as Map<String, dynamic>),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$IncidentLocationDtoToJson(
  IncidentLocationDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'region': instance.region,
  'area': instance.area,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};

IncidentDetailsData _$IncidentDetailsDataFromJson(
  Map<String, dynamic> json,
) => IncidentDetailsData(
  id: (json['id'] as num?)?.toInt(),
  incidentNo: json['incidentNo'] as String?,
  title: json['title'] as String?,
  description: json['description'] as String?,
  alarmId: CapIdentifierConverter.decode(json['alarmId']),
  alarmName: json['alarmName'] as String?,
  productName: json['productName'] as String?,
  nativeMoName: json['nativeMoName'] as String?,
  raisedTime: json['raisedTime'] as String?,
  clearedTime: json['clearedTime'] as String?,
  createdDate: json['createdDate'] as String?,
  startDate: json['startDate'] as String?,
  closedDate: json['closedDate'] as String?,
  lastModifiedDate: json['lastModifiedDate'] as String?,
  alarmType: json['alarmType'] == null
      ? null
      : IdNameDto.fromJson(json['alarmType'] as Map<String, dynamic>),
  incidentType: json['incidentType'] == null
      ? null
      : IdNameDto.fromJson(json['incidentType'] as Map<String, dynamic>),
  priority: json['priority'] == null
      ? null
      : IdNameDto.fromJson(json['priority'] as Map<String, dynamic>),
  status: json['status'] == null
      ? null
      : IdNameDto.fromJson(json['status'] as Map<String, dynamic>),
  notificationType: json['notificationType'] == null
      ? null
      : IdNameDto.fromJson(json['notificationType'] as Map<String, dynamic>),
  assignedEngineer: json['assignedEngineer'] == null
      ? null
      : IdNameDto.fromJson(json['assignedEngineer'] as Map<String, dynamic>),
  lastModifiedBy: json['lastModifiedBy'] == null
      ? null
      : IdNameDto.fromJson(json['lastModifiedBy'] as Map<String, dynamic>),
  location: json['location'] == null
      ? null
      : IncidentLocationDto.fromJson(json['location'] as Map<String, dynamic>),
);

Map<String, dynamic> _$IncidentDetailsDataToJson(
  IncidentDetailsData instance,
) => <String, dynamic>{
  'id': instance.id,
  'incidentNo': instance.incidentNo,
  'title': instance.title,
  'description': instance.description,
  'alarmId': instance.alarmId,
  'alarmName': instance.alarmName,
  'productName': instance.productName,
  'nativeMoName': instance.nativeMoName,
  'raisedTime': instance.raisedTime,
  'clearedTime': instance.clearedTime,
  'createdDate': instance.createdDate,
  'startDate': instance.startDate,
  'closedDate': instance.closedDate,
  'lastModifiedDate': instance.lastModifiedDate,
  'alarmType': instance.alarmType,
  'incidentType': instance.incidentType,
  'priority': instance.priority,
  'status': instance.status,
  'notificationType': instance.notificationType,
  'assignedEngineer': instance.assignedEngineer,
  'lastModifiedBy': instance.lastModifiedBy,
  'location': instance.location,
};

IncidentDetailsRequestData _$IncidentDetailsRequestDataFromJson(
  Map<String, dynamic> json,
) => IncidentDetailsRequestData(
  incidentId: (json['IncidentId'] as num).toInt(),
  incidentNo: json['IncidentNo'] as String? ?? '',
);

Map<String, dynamic> _$IncidentDetailsRequestDataToJson(
  IncidentDetailsRequestData instance,
) => <String, dynamic>{
  'IncidentId': instance.incidentId,
  'IncidentNo': instance.incidentNo,
};

IncidentTimelineRequestData _$IncidentTimelineRequestDataFromJson(
  Map<String, dynamic> json,
) => IncidentTimelineRequestData(
  incidentId: (json['IncidentId'] as num).toInt(),
);

Map<String, dynamic> _$IncidentTimelineRequestDataToJson(
  IncidentTimelineRequestData instance,
) => <String, dynamic>{'IncidentId': instance.incidentId};

IncidentRequestsRequestData _$IncidentRequestsRequestDataFromJson(
  Map<String, dynamic> json,
) => IncidentRequestsRequestData(
  incidentId: (json['IncidentId'] as num).toInt(),
);

Map<String, dynamic> _$IncidentRequestsRequestDataToJson(
  IncidentRequestsRequestData instance,
) => <String, dynamic>{'IncidentId': instance.incidentId};

IncidentRequestItemDto _$IncidentRequestItemDtoFromJson(
  Map<String, dynamic> json,
) => IncidentRequestItemDto(
  id: (json['id'] as num?)?.toInt(),
  requestType: json['requestType'] == null
      ? null
      : IdNameDto.fromJson(json['requestType'] as Map<String, dynamic>),
  requestStatus: json['requestStatus'] == null
      ? null
      : IdNameDto.fromJson(json['requestStatus'] as Map<String, dynamic>),
  remark: json['remark'] as String?,
  createdDate: json['createdDate'] as String?,
  createdBy: json['createdBy'] == null
      ? null
      : IdNameDto.fromJson(json['createdBy'] as Map<String, dynamic>),
  lastModifiedBy: json['lastModifiedBy'] == null
      ? null
      : IdNameDto.fromJson(json['lastModifiedBy'] as Map<String, dynamic>),
  lastModifiedDate: json['lastModifiedDate'] as String?,
);

Map<String, dynamic> _$IncidentRequestItemDtoToJson(
  IncidentRequestItemDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'requestType': instance.requestType,
  'requestStatus': instance.requestStatus,
  'remark': instance.remark,
  'createdDate': instance.createdDate,
  'createdBy': instance.createdBy,
  'lastModifiedBy': instance.lastModifiedBy,
  'lastModifiedDate': instance.lastModifiedDate,
};

IncidentRequestsData _$IncidentRequestsDataFromJson(
  Map<String, dynamic> json,
) => IncidentRequestsData(
  incidentId: (json['incidentId'] as num?)?.toInt(),
  incidentNo: json['incidentNo'] as String?,
  items: (json['items'] as List<dynamic>?)
      ?.map((e) => IncidentRequestItemDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$IncidentRequestsDataToJson(
  IncidentRequestsData instance,
) => <String, dynamic>{
  'incidentId': instance.incidentId,
  'incidentNo': instance.incidentNo,
  'items': instance.items,
};

IncidentTimelineEventDto _$IncidentTimelineEventDtoFromJson(
  Map<String, dynamic> json,
) => IncidentTimelineEventDto(
  dateTime: json['dateTime'] as String?,
  actionType: json['actionType'] == null
      ? null
      : IdNameDto.fromJson(json['actionType'] as Map<String, dynamic>),
  eventType: json['eventType'] as String?,
  eventTitle: json['eventTitle'] as String?,
  eventDescription: json['eventDescription'] as String?,
  oldValue: json['oldValue'] == null
      ? null
      : IdNameDto.fromJson(json['oldValue'] as Map<String, dynamic>),
  newValue: json['newValue'] == null
      ? null
      : IdNameDto.fromJson(json['newValue'] as Map<String, dynamic>),
  referenceId: json['referenceId'],
  performedBy: json['performedBy'] == null
      ? null
      : IdNameDto.fromJson(json['performedBy'] as Map<String, dynamic>),
);

Map<String, dynamic> _$IncidentTimelineEventDtoToJson(
  IncidentTimelineEventDto instance,
) => <String, dynamic>{
  'dateTime': instance.dateTime,
  'actionType': instance.actionType,
  'eventType': instance.eventType,
  'eventTitle': instance.eventTitle,
  'eventDescription': instance.eventDescription,
  'oldValue': instance.oldValue,
  'newValue': instance.newValue,
  'referenceId': instance.referenceId,
  'performedBy': instance.performedBy,
};

IncidentTimelineData _$IncidentTimelineDataFromJson(
  Map<String, dynamic> json,
) => IncidentTimelineData(
  incidentId: (json['incidentId'] as num?)?.toInt(),
  incidentNo: json['incidentNo'] as String?,
  events: (json['events'] as List<dynamic>?)
      ?.map((e) => IncidentTimelineEventDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$IncidentTimelineDataToJson(
  IncidentTimelineData instance,
) => <String, dynamic>{
  'incidentId': instance.incidentId,
  'incidentNo': instance.incidentNo,
  'events': instance.events,
};
