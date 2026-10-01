import '../../../../core/network/cap/cap_json.dart';
import '../../../../core/network/cap/cap_request.dart';

/// Body of `data` for `CAP/CapDashboard/GetDashboardStats`.
class DashboardStatsData {
  const DashboardStatsData({
    required this.totalIncidents,
    required this.openIncidents,
    required this.inProgress,
    required this.completed,
    required this.onHold,
    required this.todaysActivities,
    required this.needApproval,
    required this.monthSummary,
  });

  final int totalIncidents;
  final int openIncidents;
  final int inProgress;
  final int completed;
  final int onHold;
  final int todaysActivities;
  final int needApproval;
  final MonthSummary monthSummary;

  factory DashboardStatsData.fromJson(Map<String, dynamic> json) =>
      DashboardStatsData(
        totalIncidents: capCount(json['totalIncidents']),
        openIncidents: capCount(json['openIncidents']),
        inProgress: capCount(json['inProgress']),
        completed: capCount(json['completed']),
        onHold: capCount(json['onHold']),
        todaysActivities: capCount(json['todaysActivities']),
        needApproval: capCount(json['needApproval']),
        monthSummary: MonthSummary.fromJson(capMap(json['MonthSummary'])),
      );

  /// True when nothing at all was recognised in the payload, which usually
  /// means the response shape changed rather than that CAP reported zeros.
  static bool looksUnrecognised(Map<String, dynamic> json) {
    final known = const [
      'totalIncidents',
      'openIncidents',
      'inProgress',
      'completed',
      'onHold',
      'todaysActivities',
      'needApproval',
      'MonthSummary',
    ];
    return !json.keys.any(known.contains);
  }
}

/// Month-to-date totals backing the "This Month" card.
class MonthSummary {
  const MonthSummary({
    required this.year,
    required this.month,
    required this.totalIncident,
    required this.completed,
    required this.percentage,
  });

  final int year;
  final int month;
  final int totalIncident;
  final int completed;

  /// CAP sends this as a JSON decimal. It stays a `double` end to end so the UI
  /// never has to re-derive a ratio from rounded counts.
  final double percentage;

  factory MonthSummary.fromJson(Map<String, dynamic> json) => MonthSummary(
    year: capCount(json['Year']),
    month: capCount(json['Month']),
    totalIncident: capCount(json['totalIncident']),
    completed: capCount(json['completed']),
    percentage: capDecimal(json['percentage']),
  );
}

/// Body of `data` for `CAP/CapDashboard/GetDashboardStats`.
///
/// CAP capitalises the keys here, unlike the rest of the envelope.
class DashboardStatsRequestData implements CapPayload {
  const DashboardStatsRequestData({required this.month, required this.year});

  final int month;
  final int year;

  @override
  Map<String, dynamic> toJson() => {'Month': month, 'Year': year};
}
