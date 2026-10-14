import '../../../../core/network/cap/cap_request.dart';
import '../../../incidents/data/models/incident_details_models.dart';
import 'incident_report_models.dart';

class RequestsPathReportFilter implements CapPayload {
  const RequestsPathReportFilter({
    required this.fromDate,
    required this.toDate,
    this.regionId = -1,
    this.areaId = -1,
    this.locationCode = '',
    this.requestTypeId = -1,
    this.requestStatusId = -1,
    this.page = 1,
    this.pageSize = 100,
    this.range = IncidentReportDateRange.month,
  });
  factory RequestsPathReportFilter.currentMonth(DateTime now) =>
      RequestsPathReportFilter(
        fromDate: DateTime(now.year, now.month),
        toDate: DateTime(now.year, now.month + 1, 0),
      );
  final DateTime fromDate, toDate;
  final int regionId, areaId, requestTypeId, requestStatusId, page, pageSize;
  final String locationCode;
  final IncidentReportDateRange range;
  bool get active =>
      range != IncidentReportDateRange.month ||
      regionId != -1 ||
      areaId != -1 ||
      locationCode.isNotEmpty ||
      requestTypeId != -1 ||
      requestStatusId != -1;
  RequestsPathReportFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    int? regionId,
    int? areaId,
    String? locationCode,
    int? requestTypeId,
    int? requestStatusId,
    int? page,
    int? pageSize,
    IncidentReportDateRange? range,
  }) => RequestsPathReportFilter(
    fromDate: fromDate ?? this.fromDate,
    toDate: toDate ?? this.toDate,
    regionId: regionId ?? this.regionId,
    areaId: areaId ?? this.areaId,
    locationCode: locationCode ?? this.locationCode,
    requestTypeId: requestTypeId ?? this.requestTypeId,
    requestStatusId: requestStatusId ?? this.requestStatusId,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    range: range ?? this.range,
  );
  @override
  Map<String, dynamic> toJson() => {
    'FromDate': IncidentReportFilter.date(fromDate),
    'ToDate': IncidentReportFilter.date(toDate),
    'RegionId': regionId, 'AreaId': areaId, 'LocationCode': locationCode,
    // Backend-confirmed naming: requestType.id is sent as IncidentTypeId.
    'IncidentTypeId': requestTypeId,
    'StatusId': requestStatusId,
    'Page': page,
    'PageSize': pageSize,
  };
}

class RequestsPathReportSummary {
  const RequestsPathReportSummary({
    this.approvedCount,
    this.pendingDecisionCount,
    this.completedCount,
    this.rejectedCount,
  });
  final int? approvedCount, pendingDecisionCount, completedCount, rejectedCount;
  factory RequestsPathReportSummary.fromJson(Map<String, dynamic> json) =>
      RequestsPathReportSummary(
        approvedCount: json['approvedCount'] as int?,
        pendingDecisionCount: json['pendingDecisionCount'] as int?,
        completedCount: json['completedCount'] as int?,
        rejectedCount: json['rejectedCount'] as int?,
      );
}

class RequestsPathReportStep {
  const RequestsPathReportStep({
    this.key,
    this.titleEn,
    this.titleAr,
    this.state,
    this.dateTime,
  });
  final String? key, titleEn, titleAr, state, dateTime;
  factory RequestsPathReportStep.fromJson(Map<String, dynamic> json) =>
      RequestsPathReportStep(
        key: json['key'] as String?,
        titleEn: json['titleEn'] as String?,
        titleAr: json['titleAr'] as String?,
        state: json['state'] as String?,
        dateTime: json['dateTime'] as String?,
      );
}

class RequestsPathReportItem {
  RequestsPathReportItem({
    this.id,
    this.requestCode,
    this.incidentNo,
    this.locationName,
    this.requestType,
    this.requestStatus,
    List<RequestsPathReportStep> steps = const [],
  }) : steps = List.unmodifiable(steps);
  final int? id;
  final String? requestCode, incidentNo, locationName;
  final IdNameDto? requestType, requestStatus;
  final List<RequestsPathReportStep> steps;
  factory RequestsPathReportItem.fromJson(Map<String, dynamic> json) =>
      RequestsPathReportItem(
        id: json['id'] as int?,
        requestCode: json['requestCode'] as String?,
        incidentNo: json['incidentNo'] as String?,
        locationName: json['locationName'] as String?,
        requestType: json['requestType'] == null
            ? null
            : IdNameDto.fromJson(
                Map<String, dynamic>.from(json['requestType'] as Map),
              ),
        requestStatus: json['requestStatus'] == null
            ? null
            : IdNameDto.fromJson(
                Map<String, dynamic>.from(json['requestStatus'] as Map),
              ),
        steps: (json['steps'] as List? ?? [])
            .map(
              (e) => RequestsPathReportStep.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
}

class RequestsPathReportData {
  RequestsPathReportData({
    this.summary,
    List<RequestsPathReportItem> items = const [],
    this.totalCount = 0,
    this.page = 1,
    this.pageSize = 100,
  }) : items = List.unmodifiable(items);
  final RequestsPathReportSummary? summary;
  final List<RequestsPathReportItem> items;
  final int totalCount, page, pageSize;
  factory RequestsPathReportData.fromJson(Map<String, dynamic> json) =>
      RequestsPathReportData(
        summary: json['summary'] == null
            ? null
            : RequestsPathReportSummary.fromJson(
                Map<String, dynamic>.from(json['summary'] as Map),
              ),
        items: (json['items'] as List? ?? [])
            .map(
              (e) => RequestsPathReportItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
        totalCount: json['totalCount'] as int? ?? 0,
        page: json['page'] as int? ?? 1,
        pageSize: json['pageSize'] as int? ?? 100,
      );
}
