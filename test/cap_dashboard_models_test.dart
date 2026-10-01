import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/network/cap/cap_json.dart';
import 'package:access_log_plus/features/dashboard/data/models/dashboard_stats_models.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_list_models.dart';

void main() {
  test('DashboardStatsData.fromJson preserves double percentage', () {
    final json = <String, dynamic>{
      'totalIncidents': 10,
      'openIncidents': 4,
      'inProgress': 3,
      'completed': 5,
      'onHold': 1,
      'todaysActivities': 2,
      'needApproval': 0,
      'MonthSummary': {
        'Year': 2026,
        'Month': 8,
        'totalIncident': 10,
        'completed': 5,
        'percentage': 50.5,
      },
    };
    final stats = DashboardStatsData.fromJson(json);

    expect(stats.totalIncidents, 10);
    expect(stats.openIncidents, 4);
    expect(stats.inProgress, 3);
    expect(stats.completed, 5);
    expect(stats.onHold, 1);
    expect(stats.todaysActivities, 2);
    expect(stats.needApproval, 0);
    expect(stats.monthSummary.totalIncident, 10);
    expect(stats.monthSummary.completed, 5);
    expect(stats.monthSummary.percentage, 50.5);
  });

  test('IncidentListData.fromJson parses nested status and priority', () {
    final json = <String, dynamic>{
      'totalCount': 2,
      'page': 1,
      'pageSize': 100,
      'Data': [
        {
          'incidentId': 1,
          'incidentNo': 'INC-1',
          'description': 'd1',
          'locationName': 'S1',
          'areaName': 'A1',
          'regionName': 'R1',
          'incidentType': 'T1',
          'assignedTeam': 'Team',
          'status': {'id': 3, 'name': 'Pending'},
          'priority': {'id': 1, 'name': 'High'},
        },
      ],
    };
    final data = IncidentListData.parse(json);

    expect(data.totalCount, 2);
    expect(data.page, 1);
    expect(data.pageSize, 100);
    expect(data.incidents.length, 1);
    expect(data.incidents.first.statusId, 3);
    expect(data.incidents.first.statusName, 'Pending');
    expect(data.incidents.first.priorityId, 1);
    expect(data.incidents.first.priorityName, 'High');
  });

  test('formatCapDate formats yyyy-MM-dd', () {
    expect(formatCapDate(DateTime(2026, 8, 10)), '2026-08-10');
    expect(formatCapDate(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('GetIncidentList parses a bare array under data', () {
    final data = IncidentListData.parse([
      {'incidentId': 7, 'incidentNo': 'INC-7'},
    ]);

    expect(data.incidents.length, 1);
    expect(data.incidents.first.incidentNo, 'INC-7');
    expect(data.totalCount, 1);
  });

  test('GetIncidentList parses alternative array keys', () {
    for (final key in ['Items', 'Incidents', 'Rows']) {
      final data = IncidentListData.parse({
        key: [
          {'incidentId': 3, 'incidentNo': 'INC-$key'},
        ],
        'totalCount': 5,
      });

      expect(data.incidents.length, 1, reason: key);
      expect(data.incidents.first.incidentNo, 'INC-$key', reason: key);
      expect(data.totalCount, 5, reason: key);
    }
  });

  test('an unrecognised data shape yields no items instead of throwing', () {
    final data = IncidentListData.parse({'Unexpected': 'shape'});
    expect(data.incidents, isEmpty);
  });

  test('totalCount falls back to the item count when absent', () {
    final data = IncidentListData.parse({
      'Data': [
        {'incidentId': 1},
        {'incidentId': 2},
      ],
    });
    expect(data.totalCount, 2);
  });

  test('looksUnrecognised detects a changed stats payload shape', () {
    expect(DashboardStatsData.looksUnrecognised({'Something': 1}), isTrue);
    expect(
      DashboardStatsData.looksUnrecognised({'totalIncidents': 0}),
      isFalse,
    );
  });

  test('capJson readers tolerate string numerics', () {
    expect(capCount('42'), 42);
    expect(capDecimal('42.5'), 42.5);
    expect(capText(null), '');
    expect(capMap(<String, dynamic>{'a': 1})['a'], 1);
  });
}
