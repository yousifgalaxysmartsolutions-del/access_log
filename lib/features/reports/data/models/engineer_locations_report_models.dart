import '../../../../core/network/cap/cap_request.dart';
import '../../../incidents/data/models/incident_details_models.dart';
import 'incident_report_models.dart';

class EngineerLocationsReportFilter implements CapPayload {
  const EngineerLocationsReportFilter({
    required this.fromDate,
    required this.toDate,
    required this.engineerUserId,
  });
  factory EngineerLocationsReportFilter.currentMonth(
    DateTime now,
    int engineerUserId,
  ) => EngineerLocationsReportFilter(
    fromDate: DateTime(now.year, now.month),
    toDate: DateTime(now.year, now.month + 1, 0),
    engineerUserId: engineerUserId,
  );
  final DateTime fromDate, toDate;
  final int engineerUserId;
  EngineerLocationsReportFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    int? engineerUserId,
  }) => EngineerLocationsReportFilter(
    fromDate: fromDate ?? this.fromDate,
    toDate: toDate ?? this.toDate,
    engineerUserId: engineerUserId ?? this.engineerUserId,
  );
  @override
  Map<String, dynamic> toJson() => {
    'FromDate': IncidentReportFilter.date(fromDate),
    'ToDate': IncidentReportFilter.date(toDate),
    'EngineerUserId': engineerUserId,
  };
}

class ReportLocationInfo {
  const ReportLocationInfo({this.id, this.name, this.code});
  final String? id, name, code;
  factory ReportLocationInfo.fromJson(Map<String, dynamic> json) =>
      ReportLocationInfo(
        id: json['id'] as String?,
        name: json['name'] as String?,
        code: json['code'] as String?,
      );
}

class EngineerLocationReportItem {
  const EngineerLocationReportItem({
    this.location,
    this.region,
    this.area,
    this.requestsCount,
    this.incidentsCount,
    this.lastActivityDate,
  });
  final ReportLocationInfo? location;
  final IdNameDto? region, area;
  final int? requestsCount, incidentsCount;
  final String? lastActivityDate;
  factory EngineerLocationReportItem.fromJson(
    Map<String, dynamic> json,
  ) => EngineerLocationReportItem(
    location: json['location'] == null
        ? null
        : ReportLocationInfo.fromJson(
            Map<String, dynamic>.from(json['location'] as Map),
          ),
    region: json['region'] == null
        ? null
        : IdNameDto.fromJson(Map<String, dynamic>.from(json['region'] as Map)),
    area: json['area'] == null
        ? null
        : IdNameDto.fromJson(Map<String, dynamic>.from(json['area'] as Map)),
    requestsCount: json['requestsCount'] as int?,
    incidentsCount: json['incidentsCount'] as int?,
    lastActivityDate: json['lastActivityDate'] as String?,
  );
}

class EngineerLocationsReportData {
  EngineerLocationsReportData({
    this.engineer,
    this.team,
    this.jobTitle,
    this.requestsCount,
    this.incidentsCount,
    this.locationsCount,
    List<EngineerLocationReportItem> locations = const [],
  }) : locations = List.unmodifiable(locations);
  final IdNameDto? engineer;
  // Only null is currently confirmed for these fields. Preserve unknown wire
  // values without guessing a schema or displaying serialized JSON to users.
  final Object? team, jobTitle;
  final int? requestsCount, incidentsCount, locationsCount;
  final List<EngineerLocationReportItem> locations;
  factory EngineerLocationsReportData.fromJson(Map<String, dynamic> json) =>
      EngineerLocationsReportData(
        engineer: json['engineer'] == null
            ? null
            : IdNameDto.fromJson(
                Map<String, dynamic>.from(json['engineer'] as Map),
              ),
        team: json['team'],
        jobTitle: json['jobTitle'],
        requestsCount: json['requestsCount'] as int?,
        incidentsCount: json['incidentsCount'] as int?,
        locationsCount: json['locationsCount'] as int?,
        locations: (json['locations'] as List? ?? [])
            .map(
              (e) => EngineerLocationReportItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
}
