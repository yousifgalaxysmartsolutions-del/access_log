import '../../../../core/network/cap/cap_request.dart';
import '../../../incidents/data/models/incident_details_models.dart';

enum IncidentReportDateRange { today, week, month, custom }

enum IncidentReportSort { newest, oldest, priority }

/// Immutable report filter and exact CAP payload. All defaults live here.
class IncidentReportFilter implements CapPayload {
  const IncidentReportFilter({
    required this.fromDate,
    required this.toDate,
    this.regionId = -1,
    this.areaId = -1,
    this.locationCode = '',
    this.incidentTypeId = -1,
    this.statusId = -1,
    this.priorityId = -1,
    this.searchKeyword = '',
    this.page = 1,
    this.pageSize = 100,
    this.range = IncidentReportDateRange.month,
  });
  factory IncidentReportFilter.currentMonth(DateTime now) =>
      IncidentReportFilter(
        fromDate: DateTime(now.year, now.month),
        toDate: DateTime(now.year, now.month + 1, 0),
      );
  final DateTime fromDate, toDate;
  final int regionId,
      areaId,
      incidentTypeId,
      statusId,
      priorityId,
      page,
      pageSize;
  final String locationCode, searchKeyword;
  final IncidentReportDateRange range;
  IncidentReportFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    int? regionId,
    int? areaId,
    String? locationCode,
    int? incidentTypeId,
    int? statusId,
    int? priorityId,
    String? searchKeyword,
    int? page,
    int? pageSize,
    IncidentReportDateRange? range,
  }) => IncidentReportFilter(
    fromDate: fromDate ?? this.fromDate,
    toDate: toDate ?? this.toDate,
    regionId: regionId ?? this.regionId,
    areaId: areaId ?? this.areaId,
    locationCode: locationCode ?? this.locationCode,
    incidentTypeId: incidentTypeId ?? this.incidentTypeId,
    statusId: statusId ?? this.statusId,
    priorityId: priorityId ?? this.priorityId,
    searchKeyword: searchKeyword ?? this.searchKeyword,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    range: range ?? this.range,
  );
  static String date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  @override
  Map<String, dynamic> toJson() => {
    'FromDate': date(fromDate),
    'ToDate': date(toDate),
    'RegionId': regionId,
    'AreaId': areaId,
    'LocationCode': locationCode,
    'IncidentTypeId': incidentTypeId,
    'StatusId': statusId,
    'PriorityId': priorityId,
    'SearchKeyword': searchKeyword,
    'Page': page,
    'PageSize': pageSize,
  };
}

class IncidentReportSummary {
  const IncidentReportSummary({
    this.totalCount,
    this.openCount,
    this.completedCount,
    this.cancelledCount,
    this.onHoldCount,
    this.inProgressCount,
  });
  final int? totalCount,
      openCount,
      completedCount,
      cancelledCount,
      onHoldCount,
      inProgressCount;
  factory IncidentReportSummary.fromJson(Map<String, dynamic> json) =>
      IncidentReportSummary(
        totalCount: json['totalCount'] as int?,
        openCount: json['openCount'] as int?,
        completedCount: json['completedCount'] as int?,
        cancelledCount: json['cancelledCount'] as int?,
        onHoldCount: json['onHoldCount'] as int?,
        inProgressCount: json['inProgressCount'] as int?,
      );
}

class IncidentReportBreakdown {
  const IncidentReportBreakdown({this.info, this.count});
  final IdNameDto? info;
  final int? count;
  factory IncidentReportBreakdown.fromJson(Map<String, dynamic> json) =>
      IncidentReportBreakdown(
        info: json['info'] == null
            ? null
            : IdNameDto.fromJson(
                Map<String, dynamic>.from(json['info'] as Map),
              ),
        count: json['count'] as int?,
      );
}

class IncidentReportItem {
  const IncidentReportItem({
    this.id,
    this.incidentNo,
    this.title,
    this.status,
    this.priority,
    this.locationName,
    this.locationCode,
    this.region,
    this.area,
    this.raisedTime,
    this.assignedToLabel,
  });
  final int? id;
  final String? incidentNo,
      title,
      locationName,
      locationCode,
      raisedTime,
      assignedToLabel;
  final IdNameDto? status, priority, region, area;
  factory IncidentReportItem.fromJson(Map<String, dynamic> json) {
    IdNameDto? info(String key) => json[key] == null
        ? null
        : IdNameDto.fromJson(Map<String, dynamic>.from(json[key] as Map));
    return IncidentReportItem(
      id: json['id'] as int?,
      incidentNo: json['incidentNo'] as String?,
      title: json['title'] as String?,
      status: info('status'),
      priority: info('priority'),
      region: info('region'),
      area: info('area'),
      locationName: json['locationName'] as String?,
      locationCode: json['locationCode'] as String?,
      raisedTime: json['raisedTime'] as String?,
      assignedToLabel: json['assignedToLabel'] as String?,
    );
  }
}

class IncidentReportData {
  IncidentReportData({
    this.summary,
    List<IncidentReportBreakdown> statusBreakdown = const [],
    List<IncidentReportBreakdown> priorityBreakdown = const [],
    List<IncidentReportItem> items = const [],
    this.totalCount = 0,
    this.page = 1,
    this.pageSize = 100,
  }) : statusBreakdown = List.unmodifiable(statusBreakdown),
       priorityBreakdown = List.unmodifiable(priorityBreakdown),
       items = List.unmodifiable(items);
  final IncidentReportSummary? summary;
  final List<IncidentReportBreakdown> statusBreakdown, priorityBreakdown;
  final List<IncidentReportItem> items;
  final int totalCount, page, pageSize;
  factory IncidentReportData.fromJson(
    Map<String, dynamic> json,
  ) => IncidentReportData(
    summary: json['summary'] == null
        ? null
        : IncidentReportSummary.fromJson(
            Map<String, dynamic>.from(json['summary'] as Map),
          ),
    statusBreakdown: (json['statusBreakdown'] as List? ?? [])
        .map(
          (e) => IncidentReportBreakdown.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(),
    priorityBreakdown: (json['priorityBreakdown'] as List? ?? [])
        .map(
          (e) => IncidentReportBreakdown.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList(),
    items: (json['items'] as List? ?? [])
        .map(
          (e) =>
              IncidentReportItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    totalCount: json['totalCount'] as int? ?? 0,
    page: json['page'] as int? ?? 1,
    pageSize: json['pageSize'] as int? ?? 100,
  );
}
