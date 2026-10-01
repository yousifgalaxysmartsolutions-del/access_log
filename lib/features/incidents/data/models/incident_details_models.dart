import 'package:json_annotation/json_annotation.dart';

import '../../../../core/network/cap/cap_request.dart';

part 'incident_details_models.g.dart';

/// CAP's most common nested shape: an id paired with a display name.
///
/// Shared by alarm, incident type, priority, status, notification type, users,
/// regions, areas and request types so one mapping covers all of them.
@JsonSerializable()
class IdNameDto {
  factory IdNameDto.fromJson(Map<String, dynamic> json) =>
      _$IdNameDtoFromJson(json);

  const IdNameDto({this.id, this.name});

  final int? id;
  final String? name;

  Map<String, dynamic> toJson() => _$IdNameDtoToJson(this);
}

/// Location block of the incident details payload.
///
/// The location id is a site code such as `D10739`, not a numeric key, which is
/// why this does not reuse [IdNameDto].
@JsonSerializable()
class IncidentLocationDto {
  factory IncidentLocationDto.fromJson(Map<String, dynamic> json) =>
      _$IncidentLocationDtoFromJson(json);

  const IncidentLocationDto({
    this.id,
    this.name,
    this.region,
    this.area,
    this.latitude,
    this.longitude,
  });

  final String? id;
  final String? name;
  final IdNameDto? region;
  final IdNameDto? area;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => _$IncidentLocationDtoToJson(this);
}

/// Normalizes an identifier that CAP may send as a number or as a string.
///
/// The live `GetIncidentDetails` response returned `"alarmId": "1"` as a JSON
/// string, while the sibling numeric ids in the same payload arrive as numbers.
/// A field typed `int?` throws on the string form and a field typed `String?`
/// throws on the number form, so neither is safe on its own. This converter
/// accepts either wire form and hands back one stable type.
///
/// Anything that is not an identifier (a bool, a nested object) decodes to null
/// rather than throwing: one malformed field should not fail the whole screen,
/// which matches how `capMap` already treats an unexpected `data` block.
class CapIdentifierConverter implements JsonConverter<String?, Object?> {
  const CapIdentifierConverter();

  /// Exposed as a tear-off because `@JsonKey(fromJson: ...)` takes a function
  /// rather than a converter instance.
  static String? decode(Object? json) => switch (json) {
    null => null,
    final String value => value,
    // A whole-number JSON value keeps no trailing `.0` once parsed as an int.
    final num value =>
      value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString(),
    _ => null,
  };

  @override
  String? fromJson(Object? json) => decode(json);

  @override
  Object? toJson(String? object) => object;
}

/// `data` payload of `CAP/CapIncident/GetIncidentDetails`.
///
/// Every field is nullable because CAP omits or nulls values depending on the
/// incident's state, and a missing key must not fail the whole screen. Dates stay
/// as [String]: the project has no shared `DateTime` converter, and CAP mixes
/// `2026-09-30T14:22:14` with `2026-09-11T23:31:26.983`, so parsing is left to
/// the consumer that knows the field semantics.
@JsonSerializable()
class IncidentDetailsData {
  factory IncidentDetailsData.fromJson(Map<String, dynamic> json) =>
      _$IncidentDetailsDataFromJson(json);

  const IncidentDetailsData({
    this.id,
    this.incidentNo,
    this.title,
    this.description,
    this.alarmId,
    this.alarmName,
    this.productName,
    this.nativeMoName,
    this.raisedTime,
    this.clearedTime,
    this.createdDate,
    this.startDate,
    this.closedDate,
    this.lastModifiedDate,
    this.alarmType,
    this.incidentType,
    this.priority,
    this.status,
    this.notificationType,
    this.assignedEngineer,
    this.lastModifiedBy,
    this.location,
  });

  final int? id;
  final String? incidentNo;
  final String? title;
  final String? description;

  /// An identifier, not a quantity: the backend sends it as a JSON string.
  @JsonKey(fromJson: CapIdentifierConverter.decode)
  final String? alarmId;

  final String? alarmName;
  final String? productName;
  final String? nativeMoName;
  final String? raisedTime;
  final String? clearedTime;
  final String? createdDate;
  final String? startDate;
  final String? closedDate;
  final String? lastModifiedDate;
  final IdNameDto? alarmType;
  final IdNameDto? incidentType;
  final IdNameDto? priority;
  final IdNameDto? status;
  final IdNameDto? notificationType;
  final IdNameDto? assignedEngineer;
  final IdNameDto? lastModifiedBy;
  final IncidentLocationDto? location;

  Map<String, dynamic> toJson() => _$IncidentDetailsDataToJson(this);
}

/// Request body for `CAP/CapIncident/GetIncidentDetails`.
///
/// Implements [CapPayload] so the shared CAP envelope can serialize it, matching
/// the convention used by the other incident endpoints.
@JsonSerializable()
class IncidentDetailsRequestData implements CapPayload {
  factory IncidentDetailsRequestData.fromJson(Map<String, dynamic> json) =>
      _$IncidentDetailsRequestDataFromJson(json);

  const IncidentDetailsRequestData({
    required this.incidentId,
    this.incidentNo = '',
  });

  @JsonKey(name: 'IncidentId')
  final int incidentId;

  @JsonKey(name: 'IncidentNo')
  final String incidentNo;

  @override
  Map<String, dynamic> toJson() => _$IncidentDetailsRequestDataToJson(this);
}

/// Request body for `CAP/CapIncident/GetIncidentTimeline`.
///
/// The response is modeled by [IncidentTimelineData].
@JsonSerializable()
class IncidentTimelineRequestData implements CapPayload {
  factory IncidentTimelineRequestData.fromJson(Map<String, dynamic> json) =>
      _$IncidentTimelineRequestDataFromJson(json);

  const IncidentTimelineRequestData({required this.incidentId});

  @JsonKey(name: 'IncidentId')
  final int incidentId;

  @override
  Map<String, dynamic> toJson() => _$IncidentTimelineRequestDataToJson(this);
}

/// Request body for `CAP/CapIncident/GetIncidentRequests`.
@JsonSerializable()
class IncidentRequestsRequestData implements CapPayload {
  factory IncidentRequestsRequestData.fromJson(Map<String, dynamic> json) =>
      _$IncidentRequestsRequestDataFromJson(json);

  const IncidentRequestsRequestData({required this.incidentId});

  @JsonKey(name: 'IncidentId')
  final int incidentId;

  @override
  Map<String, dynamic> toJson() => _$IncidentRequestsRequestDataToJson(this);
}

/// One row of `data.items` from `CAP/CapIncident/GetIncidentRequests`.
@JsonSerializable()
class IncidentRequestItemDto {
  factory IncidentRequestItemDto.fromJson(Map<String, dynamic> json) =>
      _$IncidentRequestItemDtoFromJson(json);

  const IncidentRequestItemDto({
    this.id,
    this.requestType,
    this.requestStatus,
    this.remark,
    this.createdDate,
    this.createdBy,
    this.lastModifiedBy,
    this.lastModifiedDate,
  });

  final int? id;
  final IdNameDto? requestType;
  final IdNameDto? requestStatus;
  final String? remark;
  final String? createdDate;
  final IdNameDto? createdBy;
  final IdNameDto? lastModifiedBy;
  final String? lastModifiedDate;

  Map<String, dynamic> toJson() => _$IncidentRequestItemDtoToJson(this);
}

/// `data` payload of `CAP/CapIncident/GetIncidentRequests`.
@JsonSerializable()
class IncidentRequestsData {
  factory IncidentRequestsData.fromJson(Map<String, dynamic> json) =>
      _$IncidentRequestsDataFromJson(json);

  const IncidentRequestsData({this.incidentId, this.incidentNo, this.items});

  final int? incidentId;
  final String? incidentNo;
  final List<IncidentRequestItemDto>? items;

  Map<String, dynamic> toJson() => _$IncidentRequestsDataToJson(this);
}

/// One entry of `data.events` from `CAP/CapIncident/GetIncidentTimeline`.
///
/// `referenceId` is deliberately typed [Object?]. The supplied payload only shows
/// the key being `null`, so narrowing it to `int` or `String` would be a guess
/// that breaks the moment the backend sends the other form. Nothing reads it yet,
/// so the cost of staying untyped is lower than the cost of being wrong.
///
/// `dateTime` stays a [String] for the same reason as [IncidentDetailsData]:
/// there is no shared `DateTime` converter in the project and CAP mixes
/// `2026-09-11T23:24:31.963` with `2026-09-30T14:22:14` precision.
@JsonSerializable()
class IncidentTimelineEventDto {
  factory IncidentTimelineEventDto.fromJson(Map<String, dynamic> json) =>
      _$IncidentTimelineEventDtoFromJson(json);

  const IncidentTimelineEventDto({
    this.dateTime,
    this.actionType,
    this.eventType,
    this.eventTitle,
    this.eventDescription,
    this.oldValue,
    this.newValue,
    this.referenceId,
    this.performedBy,
  });

  final String? dateTime;
  final IdNameDto? actionType;
  final String? eventType;
  final String? eventTitle;
  final String? eventDescription;
  final IdNameDto? oldValue;
  final IdNameDto? newValue;

  /// Unverified scalar reference to whatever the event is about, if anything.
  final Object? referenceId;

  final IdNameDto? performedBy;

  Map<String, dynamic> toJson() => _$IncidentTimelineEventDtoToJson(this);
}

/// `data` payload of `CAP/CapIncident/GetIncidentTimeline`.
///
/// Every field is nullable so a partially populated event cannot fail the whole
/// tab, and so an event missing an optional block still renders.
@JsonSerializable()
class IncidentTimelineData {
  factory IncidentTimelineData.fromJson(Map<String, dynamic> json) =>
      _$IncidentTimelineDataFromJson(json);

  const IncidentTimelineData({this.incidentId, this.incidentNo, this.events});

  final int? incidentId;
  final String? incidentNo;

  /// Back-end order is preserved as received; the tab does not re-sort it.
  final List<IncidentTimelineEventDto>? events;

  Map<String, dynamic> toJson() => _$IncidentTimelineDataToJson(this);
}
