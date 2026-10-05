import 'package:json_annotation/json_annotation.dart';

part 'incident_lookup_models.g.dart';

@JsonSerializable(createToJson: false)
class IncidentLookupItem {
  const IncidentLookupItem({this.id, this.name, this.code});
  final int? id;
  final String? name;
  final String? code;
  factory IncidentLookupItem.fromJson(Map<String, dynamic> json) =>
      _$IncidentLookupItemFromJson(json);
}

@JsonSerializable(createToJson: false)
class IncidentLookupData {
  IncidentLookupData({
    List<IncidentLookupItem> incidentType = const [],
    List<IncidentLookupItem> status = const [],
    List<IncidentLookupItem> priority = const [],
    List<IncidentLookupItem> alarmType = const [],
    List<IncidentLookupItem> notificationType = const [],
    List<IncidentLookupItem> actionType = const [],
  }) : incidentType = List.unmodifiable(incidentType),
       status = List.unmodifiable(status),
       priority = List.unmodifiable(priority),
       alarmType = List.unmodifiable(alarmType),
       notificationType = List.unmodifiable(notificationType),
       actionType = List.unmodifiable(actionType);

  final List<IncidentLookupItem> incidentType,
      status,
      priority,
      alarmType,
      notificationType,
      actionType;
  factory IncidentLookupData.fromJson(Map<String, dynamic> json) =>
      _$IncidentLookupDataFromJson(json);
}
