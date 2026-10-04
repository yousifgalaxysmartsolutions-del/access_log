import 'package:json_annotation/json_annotation.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../../../incidents/data/models/incident_details_models.dart'
    show IdNameDto;

part 'request_models.g.dart';

@JsonSerializable(explicitToJson: true)
class RequestLookupData {
  const RequestLookupData({
    this.requestType = const [],
    this.requestStatus = const [],
    this.requestActionType = const [],
  });
  final List<RequestLookupItemDto> requestType;
  final List<RequestLookupItemDto> requestStatus;

  /// Global lookup, not a per-request allowed-actions list.
  final List<RequestLookupItemDto> requestActionType;
  factory RequestLookupData.fromJson(Map<String, dynamic> json) =>
      _$RequestLookupDataFromJson(json);
  Map<String, dynamic> toJson() => _$RequestLookupDataToJson(this);
}

@JsonSerializable()
class RequestLookupItemDto {
  const RequestLookupItemDto({this.id, this.name, this.code});
  final int? id;
  final String? name;
  final String? code;
  factory RequestLookupItemDto.fromJson(Map<String, dynamic> json) =>
      _$RequestLookupItemDtoFromJson(json);
  Map<String, dynamic> toJson() => _$RequestLookupItemDtoToJson(this);
}

@JsonSerializable()
class RequestListRequestData implements CapPayload {
  const RequestListRequestData({
    required this.fromDate,
    required this.toDate,
    required this.requestTypeId,
    required this.requestStatusId,
    required this.locationCode,
    required this.incidentNo,
    required this.page,
    required this.pageSize,
  });
  @JsonKey(name: 'FromDate')
  final String fromDate;
  @JsonKey(name: 'ToDate')
  final String toDate;
  @JsonKey(name: 'RequestTypeId')
  final int requestTypeId;
  @JsonKey(name: 'RequestStatusId')
  final int requestStatusId;
  @JsonKey(name: 'LocationCode')
  final String locationCode;
  @JsonKey(name: 'IncidentNo')
  final String incidentNo;
  @JsonKey(name: 'Page')
  final int page;
  @JsonKey(name: 'PageSize')
  final int pageSize;
  factory RequestListRequestData.fromJson(Map<String, dynamic> json) =>
      _$RequestListRequestDataFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$RequestListRequestDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class RequestListData {
  const RequestListData({
    this.items = const [],
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });
  final List<RequestListItemDto> items;
  final int totalCount;
  final int page;
  final int pageSize;
  factory RequestListData.fromJson(Map<String, dynamic> json) =>
      _$RequestListDataFromJson(json);
  Map<String, dynamic> toJson() => _$RequestListDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class RequestListItemDto {
  const RequestListItemDto({
    this.id,
    this.incidentId,
    this.incidentNo,
    this.locationCode,
    this.locationName,
    this.requestType,
    this.requestStatus,
    this.remark,
    this.questionFormId,
    this.createdDate,
    this.createdBy,
    this.lastModifiedBy,
    this.lastModifiedDate,
  });
  final int? id;
  final int? incidentId;
  final String? incidentNo;
  final String? locationCode;
  final String? locationName;
  final IdNameDto? requestType;
  final IdNameDto? requestStatus;
  final String? remark;
  final String? questionFormId;
  final String? createdDate;
  final IdNameDto? createdBy;
  final IdNameDto? lastModifiedBy;
  final String? lastModifiedDate;
  RequestListItemDto withRequestStatus(IdNameDto status) => RequestListItemDto(
    id: id,
    incidentId: incidentId,
    incidentNo: incidentNo,
    locationCode: locationCode,
    locationName: locationName,
    requestType: requestType,
    requestStatus: status,
    remark: remark,
    questionFormId: questionFormId,
    createdDate: createdDate,
    createdBy: createdBy,
    lastModifiedBy: lastModifiedBy,
    lastModifiedDate: lastModifiedDate,
  );
  factory RequestListItemDto.fromJson(Map<String, dynamic> json) =>
      _$RequestListItemDtoFromJson(json);
  Map<String, dynamic> toJson() => _$RequestListItemDtoToJson(this);
}

@JsonSerializable()
class RequestApproveData implements CapPayload {
  const RequestApproveData({required this.requestId, required this.remark});
  @JsonKey(name: 'RequestId')
  final int requestId;
  @JsonKey(name: 'Remark')
  final String remark;
  factory RequestApproveData.fromJson(Map<String, dynamic> json) =>
      _$RequestApproveDataFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$RequestApproveDataToJson(this);
}

@JsonSerializable()
class RequestRejectData implements CapPayload {
  const RequestRejectData({required this.requestId, required this.reason});
  @JsonKey(name: 'RequestId')
  final int requestId;
  @JsonKey(name: 'Reason')
  final String reason;
  factory RequestRejectData.fromJson(Map<String, dynamic> json) =>
      _$RequestRejectDataFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$RequestRejectDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class RequestDecisionData {
  const RequestDecisionData({this.id, this.requestStatus});
  final int? id;
  final IdNameDto? requestStatus;
  factory RequestDecisionData.fromJson(Map<String, dynamic> json) =>
      _$RequestDecisionDataFromJson(json);
  Map<String, dynamic> toJson() => _$RequestDecisionDataToJson(this);
}
