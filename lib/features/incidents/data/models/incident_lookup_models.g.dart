// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incident_lookup_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IncidentLookupItem _$IncidentLookupItemFromJson(Map<String, dynamic> json) =>
    IncidentLookupItem(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      code: json['code'] as String?,
    );

IncidentLookupData _$IncidentLookupDataFromJson(
  Map<String, dynamic> json,
) => IncidentLookupData(
  incidentType:
      (json['incidentType'] as List<dynamic>?)
          ?.map((e) => IncidentLookupItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  status:
      (json['status'] as List<dynamic>?)
          ?.map((e) => IncidentLookupItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  priority:
      (json['priority'] as List<dynamic>?)
          ?.map((e) => IncidentLookupItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  alarmType:
      (json['alarmType'] as List<dynamic>?)
          ?.map((e) => IncidentLookupItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  notificationType:
      (json['notificationType'] as List<dynamic>?)
          ?.map((e) => IncidentLookupItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  actionType:
      (json['actionType'] as List<dynamic>?)
          ?.map((e) => IncidentLookupItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);
