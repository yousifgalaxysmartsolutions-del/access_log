// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestLookupData _$RequestLookupDataFromJson(
  Map<String, dynamic> json,
) => RequestLookupData(
  requestType:
      (json['requestType'] as List<dynamic>?)
          ?.map((e) => RequestLookupItemDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  requestStatus:
      (json['requestStatus'] as List<dynamic>?)
          ?.map((e) => RequestLookupItemDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  requestActionType:
      (json['requestActionType'] as List<dynamic>?)
          ?.map((e) => RequestLookupItemDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$RequestLookupDataToJson(RequestLookupData instance) =>
    <String, dynamic>{
      'requestType': instance.requestType.map((e) => e.toJson()).toList(),
      'requestStatus': instance.requestStatus.map((e) => e.toJson()).toList(),
      'requestActionType': instance.requestActionType
          .map((e) => e.toJson())
          .toList(),
    };

RequestLookupItemDto _$RequestLookupItemDtoFromJson(
  Map<String, dynamic> json,
) => RequestLookupItemDto(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String?,
  code: json['code'] as String?,
);

Map<String, dynamic> _$RequestLookupItemDtoToJson(
  RequestLookupItemDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'code': instance.code,
};

RequestListRequestData _$RequestListRequestDataFromJson(
  Map<String, dynamic> json,
) => RequestListRequestData(
  fromDate: json['FromDate'] as String,
  toDate: json['ToDate'] as String,
  requestTypeId: (json['RequestTypeId'] as num).toInt(),
  requestStatusId: (json['RequestStatusId'] as num).toInt(),
  locationCode: json['LocationCode'] as String,
  incidentNo: json['IncidentNo'] as String,
  page: (json['Page'] as num).toInt(),
  pageSize: (json['PageSize'] as num).toInt(),
);

Map<String, dynamic> _$RequestListRequestDataToJson(
  RequestListRequestData instance,
) => <String, dynamic>{
  'FromDate': instance.fromDate,
  'ToDate': instance.toDate,
  'RequestTypeId': instance.requestTypeId,
  'RequestStatusId': instance.requestStatusId,
  'LocationCode': instance.locationCode,
  'IncidentNo': instance.incidentNo,
  'Page': instance.page,
  'PageSize': instance.pageSize,
};

RequestListData _$RequestListDataFromJson(Map<String, dynamic> json) =>
    RequestListData(
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) => RequestListItemDto.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      totalCount: (json['totalCount'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['pageSize'] as num).toInt(),
    );

Map<String, dynamic> _$RequestListDataToJson(RequestListData instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'totalCount': instance.totalCount,
      'page': instance.page,
      'pageSize': instance.pageSize,
    };

RequestListItemDto _$RequestListItemDtoFromJson(Map<String, dynamic> json) =>
    RequestListItemDto(
      id: (json['id'] as num?)?.toInt(),
      incidentId: (json['incidentId'] as num?)?.toInt(),
      incidentNo: json['incidentNo'] as String?,
      locationCode: json['locationCode'] as String?,
      locationName: json['locationName'] as String?,
      requestType: json['requestType'] == null
          ? null
          : IdNameDto.fromJson(json['requestType'] as Map<String, dynamic>),
      requestStatus: json['requestStatus'] == null
          ? null
          : IdNameDto.fromJson(json['requestStatus'] as Map<String, dynamic>),
      remark: json['remark'] as String?,
      questionFormId: json['questionFormId'] as String?,
      createdDate: json['createdDate'] as String?,
      createdBy: json['createdBy'] == null
          ? null
          : IdNameDto.fromJson(json['createdBy'] as Map<String, dynamic>),
      lastModifiedBy: json['lastModifiedBy'] == null
          ? null
          : IdNameDto.fromJson(json['lastModifiedBy'] as Map<String, dynamic>),
      lastModifiedDate: json['lastModifiedDate'] as String?,
    );

Map<String, dynamic> _$RequestListItemDtoToJson(RequestListItemDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'incidentId': instance.incidentId,
      'incidentNo': instance.incidentNo,
      'locationCode': instance.locationCode,
      'locationName': instance.locationName,
      'requestType': instance.requestType?.toJson(),
      'requestStatus': instance.requestStatus?.toJson(),
      'remark': instance.remark,
      'questionFormId': instance.questionFormId,
      'createdDate': instance.createdDate,
      'createdBy': instance.createdBy?.toJson(),
      'lastModifiedBy': instance.lastModifiedBy?.toJson(),
      'lastModifiedDate': instance.lastModifiedDate,
    };

RequestApproveData _$RequestApproveDataFromJson(Map<String, dynamic> json) =>
    RequestApproveData(
      requestId: (json['RequestId'] as num).toInt(),
      remark: json['Remark'] as String,
    );

Map<String, dynamic> _$RequestApproveDataToJson(RequestApproveData instance) =>
    <String, dynamic>{
      'RequestId': instance.requestId,
      'Remark': instance.remark,
    };

RequestRejectData _$RequestRejectDataFromJson(Map<String, dynamic> json) =>
    RequestRejectData(
      requestId: (json['RequestId'] as num).toInt(),
      reason: json['Reason'] as String,
    );

Map<String, dynamic> _$RequestRejectDataToJson(RequestRejectData instance) =>
    <String, dynamic>{
      'RequestId': instance.requestId,
      'Reason': instance.reason,
    };

RequestDecisionData _$RequestDecisionDataFromJson(Map<String, dynamic> json) =>
    RequestDecisionData(
      id: (json['id'] as num?)?.toInt(),
      requestStatus: json['requestStatus'] == null
          ? null
          : IdNameDto.fromJson(json['requestStatus'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RequestDecisionDataToJson(
  RequestDecisionData instance,
) => <String, dynamic>{
  'id': instance.id,
  'requestStatus': instance.requestStatus?.toJson(),
};
