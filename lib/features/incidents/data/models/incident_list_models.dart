import 'package:flutter/foundation.dart';

import '../../../../core/network/cap/cap_json.dart';
import '../../../../core/network/cap/cap_request.dart';

/// Body of `data` for `CAP/CapIncident/GetIncidentList`.
class IncidentListRequestData implements CapPayload {
  const IncidentListRequestData({
    required this.fromDate,
    required this.toDate,
    this.regionId = -1,
    this.areaId = -1,
    this.locationCode = '',
    this.incidentNo = '',
    this.incidentTypeId = -1,
    this.statusId = -1,
    this.priorityId = -1,
    this.page = 1,
    this.pageSize = todayIncidentsPageSize,
  });

  /// Dashboard preview size. Needs Verification: the dashboard renders the whole
  /// list with no "view more" affordance, so this matches the CAP contract
  /// sample but has never been exercised against a day with more incidents.
  static const int todayIncidentsPageSize = 100;

  final String fromDate;
  final String toDate;
  final int regionId;
  final int areaId;
  final String locationCode;
  final String incidentNo;
  final int incidentTypeId;
  final int statusId;
  final int priorityId;
  final int page;
  final int pageSize;

  @override
  Map<String, dynamic> toJson() => {
    'FromDate': fromDate,
    'ToDate': toDate,
    'RegionId': regionId,
    'AreaId': areaId,
    'LocationCode': locationCode,
    'IncidentNo': incidentNo,
    'IncidentTypeId': incidentTypeId,
    'StatusId': statusId,
    'PriorityId': priorityId,
    'Page': page,
    'PageSize': pageSize,
  };
}

/// Payload of `data` for `CAP/CapIncident/GetIncidentList`.
class IncidentListData {
  const IncidentListData({
    required this.incidents,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<IncidentListItem> incidents;
  final int totalCount;
  final int page;
  final int pageSize;

  /// Keys CAP wraps the incident array in, most specific first.
  ///
  /// `items` is the key observed on the live `GetIncidentList` response; the
  /// remaining entries are tolerated so an older or regional CAP build cannot
  /// turn a populated response into a silently empty list.
  static const _listKeys = ['items', 'Items', 'Data', 'Incidents', 'Rows'];

  /// Parses the `data` value.
  ///
  /// Tolerates both container shapes: an object wrapping the array, or the array
  /// itself. When no array is found the available keys are logged, because an
  /// unrecognised shape would otherwise look exactly like "no incidents today".
  factory IncidentListData.parse(Object? raw) {
    if (raw is List) {
      return IncidentListData(
        incidents: _readItems(raw),
        totalCount: raw.length,
        page: 1,
        pageSize: raw.length,
      );
    }
    final json = capMap(raw);
    for (final key in _listKeys) {
      final value = json[key];
      if (value is List) {
        return IncidentListData(
          incidents: _readItems(value),
          totalCount: capCount(json['totalCount']) == 0
              ? value.length
              : capCount(json['totalCount']),
          page: capCount(json['page']),
          pageSize: capCount(json['pageSize']),
        );
      }
    }
    debugPrint(
      '[CAP] GetIncidentList returned no known array. '
      'data keys: ${json.keys.toList()}',
    );
    return IncidentListData(
      incidents: const [],
      totalCount: capCount(json['totalCount']),
      page: capCount(json['page']),
      pageSize: capCount(json['pageSize']),
    );
  }

  static List<IncidentListItem> _readItems(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => IncidentListItem.fromJson(capMap(item)))
        .toList(growable: false);
  }
}

/// One row of `CAP/CapIncident/GetIncidentList`.
class IncidentListItem {
  const IncidentListItem({
    required this.incidentId,
    required this.incidentNo,
    required this.description,
    required this.locationName,
    required this.areaName,
    required this.regionName,
    required this.incidentType,
    required this.assignedTeam,
    required this.statusName,
    required this.statusId,
    required this.priorityName,
    required this.priorityId,
    this.occurredAt,
    this.locationCode = '',
    this.latitude,
    this.longitude,
  });

  final int incidentId;
  final String incidentNo;
  final String description;
  final String locationName;
  final String locationCode;
  final String areaName;
  final String regionName;
  final String incidentType;
  final String assignedTeam;
  final String statusName;
  final int statusId;
  final String priorityName;
  final int priorityId;

  /// Creation date returned by CAP, without changing its timezone.
  final DateTime? occurredAt;
  final double? latitude, longitude;

  factory IncidentListItem.fromJson(
    Map<String, dynamic> json,
  ) => IncidentListItem(
    incidentId: capCount(json['incidentId']),
    incidentNo: _firstText(json, ['incidentNo', 'incidentNumber']),
    // The live payload titles a row with `incidentTitle` and carries no
    // `description`, so the title is the only text the tile can show.
    description: _firstText(json, ['incidentTitle', 'title', 'description']),
    locationName: _firstText(json, ['locationName', 'location', 'siteName']),
    locationCode: _firstText(json, ['locationCode', 'locationId']),
    areaName: _firstText(json, ['areaName', 'area']),
    regionName: _firstText(json, ['regionName', 'region']),
    incidentType: _firstText(json, ['incidentType', 'incidentTypeName']),
    assignedTeam: _firstText(json, ['currentUser', 'assignedTeam', 'teamName']),
    statusName: _firstText(capMap(json['status']), ['name', 'statusName']),
    statusId: capCount(capMap(json['status'])['id']),
    priorityName: _firstText(capMap(json['priority']), [
      'name',
      'priorityName',
    ]),
    priorityId: capCount(capMap(json['priority'])['id']),
    occurredAt: _readOccurredAt(json),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );

  static const _dateKeys = [
    'createdDate',
    'incidentDate',
    'incident_date',
    'created_date',
    'date',
  ];

  /// Returns the first key holding a non-empty string, so a response that uses
  /// one spelling still renders instead of showing a blank row.
  static String _firstText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final raw = json[key];
      final value = raw is String
          ? raw
          : raw is Map && raw['name'] is String
          ? raw['name'] as String
          : '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static DateTime? _readOccurredAt(Map<String, dynamic> json) {
    for (final key in _dateKeys) {
      final raw = json[key];
      if (raw == null) continue;
      final parsed = DateTime.tryParse(capText(raw));
      if (parsed != null) return parsed;
    }
    return null;
  }
}
