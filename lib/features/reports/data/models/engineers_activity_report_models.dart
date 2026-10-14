import '../../../../core/network/cap/cap_request.dart';
import '../../../incidents/data/models/incident_details_models.dart';
import 'engineer_locations_report_models.dart';
import 'incident_report_models.dart';

enum EngineersActivityGroup {
  engineer('Engineer'),
  region('City');

  const EngineersActivityGroup(this.wireValue);
  final String wireValue;
  static EngineersActivityGroup parse(String value) => values.firstWhere(
    (e) => e.wireValue == value,
    orElse: () =>
        throw const FormatException('Unknown engineers activity grouping'),
  );
}

class EngineersActivityReportFilter implements CapPayload {
  const EngineersActivityReportFilter({
    required this.fromDate,
    required this.toDate,
    this.regionId = -1,
    this.areaId = -1,
    this.groupBy = EngineersActivityGroup.engineer,
    this.engineerUserId = -1,
    this.locationCode = '',
    this.page = 1,
    this.pageSize = 100,
    this.range = IncidentReportDateRange.month,
  });
  factory EngineersActivityReportFilter.currentMonth(DateTime now) =>
      EngineersActivityReportFilter(
        fromDate: DateTime(now.year, now.month),
        toDate: DateTime(now.year, now.month + 1, 0),
      );
  final DateTime fromDate, toDate;
  final int regionId, areaId, engineerUserId, page, pageSize;
  final EngineersActivityGroup groupBy;
  final String locationCode;
  final IncidentReportDateRange range;
  bool get hasFilters =>
      regionId != -1 ||
      areaId != -1 ||
      engineerUserId != -1 ||
      locationCode.isNotEmpty ||
      range != IncidentReportDateRange.month;
  EngineersActivityReportFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    int? regionId,
    int? areaId,
    int? engineerUserId,
    EngineersActivityGroup? groupBy,
    String? locationCode,
    int? page,
    int? pageSize,
    IncidentReportDateRange? range,
  }) => EngineersActivityReportFilter(
    fromDate: fromDate ?? this.fromDate,
    toDate: toDate ?? this.toDate,
    regionId: regionId ?? this.regionId,
    areaId: areaId ?? this.areaId,
    engineerUserId: engineerUserId ?? this.engineerUserId,
    groupBy: groupBy ?? this.groupBy,
    locationCode: locationCode ?? this.locationCode,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    range: range ?? this.range,
  );
  @override
  Map<String, dynamic> toJson() => {
    'FromDate': IncidentReportFilter.date(fromDate),
    'ToDate': IncidentReportFilter.date(toDate),
    'RegionId': regionId,
    'AreaId': areaId,
    'GroupBy': groupBy.wireValue,
    'EngineerUserId': engineerUserId,
    'LocationCode': locationCode,
    'Page': page,
    'PageSize': pageSize,
  };
}

class EngineersActivityReportItem {
  EngineersActivityReportItem({
    this.engineerId,
    this.engineerName,
    this.team,
    this.jobTitle,
    this.city,
    List<ReportLocationInfo> locations = const [],
    List<IdNameDto> engineers = const [],
    this.onHoldCount,
    this.completedCount,
    this.inProgressCount,
    this.assignedCount,
  }) : locations = List.unmodifiable(locations),
       engineers = List.unmodifiable(engineers);
  final int? engineerId,
      onHoldCount,
      completedCount,
      inProgressCount,
      assignedCount;
  final String? engineerName;
  final Object? team, jobTitle;
  final IdNameDto? city;
  final List<ReportLocationInfo> locations;
  final List<IdNameDto> engineers;
  factory EngineersActivityReportItem.fromJson(
    Map<String, dynamic> json,
  ) => EngineersActivityReportItem(
    engineerId: json['engineerId'] as int?,
    engineerName: json['engineerName'] as String?,
    team: json['team'],
    jobTitle: json['jobTitle'],
    city: json['city'] == null
        ? null
        : IdNameDto.fromJson(Map<String, dynamic>.from(json['city'] as Map)),
    locations: (json['locations'] as List? ?? [])
        .map(
          (e) =>
              ReportLocationInfo.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    engineers: (json['engineers'] as List? ?? [])
        .map((e) => IdNameDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    onHoldCount: json['onHoldCount'] as int?,
    completedCount: json['completedCount'] as int?,
    inProgressCount: json['inProgressCount'] as int?,
    assignedCount: json['assignedCount'] as int?,
  );
}

class EngineersActivityReportData {
  EngineersActivityReportData({
    required this.groupBy,
    List<EngineersActivityReportItem> items = const [],
    this.totalCount = 0,
    this.page = 1,
    this.pageSize = 100,
  }) : items = List.unmodifiable(items);
  final EngineersActivityGroup groupBy;
  final List<EngineersActivityReportItem> items;
  final int totalCount, page, pageSize;
  factory EngineersActivityReportData.fromJson(Map<String, dynamic> json) =>
      EngineersActivityReportData(
        groupBy: EngineersActivityGroup.parse(json['groupBy'] as String),
        items: (json['items'] as List? ?? [])
            .map(
              (e) => EngineersActivityReportItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
        totalCount: json['totalCount'] as int? ?? 0,
        page: json['page'] as int? ?? 1,
        pageSize: json['pageSize'] as int? ?? 100,
      );
}
