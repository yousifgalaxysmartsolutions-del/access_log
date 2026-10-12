// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestDetailsInput _$RequestDetailsInputFromJson(Map<String, dynamic> json) =>
    RequestDetailsInput(requestId: (json['RequestId'] as num).toInt());

Map<String, dynamic> _$RequestDetailsInputToJson(
  RequestDetailsInput instance,
) => <String, dynamic>{'RequestId': instance.requestId};

RequestDetailsData _$RequestDetailsDataFromJson(
  Map<String, dynamic> json,
) => RequestDetailsData(
  id: (json['id'] as num?)?.toInt(),
  incident: json['incident'] == null
      ? null
      : IncidentDetailsData.fromJson(json['incident'] as Map<String, dynamic>),
  requestType: json['requestType'] == null
      ? null
      : IdNameDto.fromJson(json['requestType'] as Map<String, dynamic>),
  requestStatus: json['requestStatus'] == null
      ? null
      : IdNameDto.fromJson(json['requestStatus'] as Map<String, dynamic>),
  remark: json['remark'] as String?,
  noOfMinute: json['NoOfMinute'] as num?,
  questionFormId: json['questionFormId'] as String?,
  formName: json['formName'] as String?,
  formDescription: json['formDescription'] as String?,
  createdDate: json['createdDate'] as String?,
  createdBy: json['createdBy'] == null
      ? null
      : IdNameDto.fromJson(json['createdBy'] as Map<String, dynamic>),
  lastModifiedBy: json['lastModifiedBy'] == null
      ? null
      : IdNameDto.fromJson(json['lastModifiedBy'] as Map<String, dynamic>),
  lastModifiedDate: json['lastModifiedDate'] as String?,
  formAnswers:
      (json['formAnswers'] as List<dynamic>?)
          ?.map((e) => RequestFormAnswerDto.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  timeline:
      (json['timeline'] as List<dynamic>?)
          ?.map(
            (e) => RequestTimelineEventDto.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$RequestDetailsDataToJson(RequestDetailsData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'incident': instance.incident?.toJson(),
      'requestType': instance.requestType?.toJson(),
      'requestStatus': instance.requestStatus?.toJson(),
      'createdBy': instance.createdBy?.toJson(),
      'lastModifiedBy': instance.lastModifiedBy?.toJson(),
      'remark': instance.remark,
      'questionFormId': instance.questionFormId,
      'formName': instance.formName,
      'formDescription': instance.formDescription,
      'createdDate': instance.createdDate,
      'lastModifiedDate': instance.lastModifiedDate,
      'NoOfMinute': instance.noOfMinute,
      'formAnswers': instance.formAnswers.map((e) => e.toJson()).toList(),
      'timeline': instance.timeline.map((e) => e.toJson()).toList(),
    };

RequestFormAnswerDto _$RequestFormAnswerDtoFromJson(
  Map<String, dynamic> json,
) => RequestFormAnswerDto(
  id: (json['id'] as num?)?.toInt(),
  questionId: (json['questionId'] as num?)?.toInt(),
  questionText: json['questionText'] as String?,
  questionType: json['questionType'] as String?,
  questionTypeInfo: json['questionTypeInfo'] == null
      ? null
      : IdNameDto.fromJson(json['questionTypeInfo'] as Map<String, dynamic>),
  mandatory: json['mandatory'] as bool?,
  orderNo: (json['orderNo'] as num?)?.toInt(),
  textAnswer: json['textAnswer'] as String?,
  optionAnswer: json['optionAnswer'],
  createdBy: json['createdBy'] == null
      ? null
      : IdNameDto.fromJson(json['createdBy'] as Map<String, dynamic>),
  createdDate: json['createdDate'] as String?,
  updatedDate: json['updatedDate'] as String?,
);

Map<String, dynamic> _$RequestFormAnswerDtoToJson(
  RequestFormAnswerDto instance,
) => <String, dynamic>{
  'id': instance.id,
  'questionId': instance.questionId,
  'orderNo': instance.orderNo,
  'questionText': instance.questionText,
  'questionType': instance.questionType,
  'textAnswer': instance.textAnswer,
  'createdDate': instance.createdDate,
  'updatedDate': instance.updatedDate,
  'questionTypeInfo': instance.questionTypeInfo?.toJson(),
  'createdBy': instance.createdBy?.toJson(),
  'mandatory': instance.mandatory,
  'optionAnswer': instance.optionAnswer,
};

RequestTimelineEventDto _$RequestTimelineEventDtoFromJson(
  Map<String, dynamic> json,
) => RequestTimelineEventDto(
  dateTime: json['dateTime'] as String?,
  actionType: json['actionType'] == null
      ? null
      : IdNameDto.fromJson(json['actionType'] as Map<String, dynamic>),
  eventType: json['eventType'] as String?,
  eventTitle: json['eventTitle'] as String?,
  eventDescription: json['eventDescription'] as String?,
  remark: json['remark'] as String?,
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

Map<String, dynamic> _$RequestTimelineEventDtoToJson(
  RequestTimelineEventDto instance,
) => <String, dynamic>{
  'dateTime': instance.dateTime,
  'eventType': instance.eventType,
  'eventTitle': instance.eventTitle,
  'eventDescription': instance.eventDescription,
  'remark': instance.remark,
  'actionType': instance.actionType?.toJson(),
  'oldValue': instance.oldValue?.toJson(),
  'newValue': instance.newValue?.toJson(),
  'performedBy': instance.performedBy?.toJson(),
  'referenceId': instance.referenceId,
};

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
