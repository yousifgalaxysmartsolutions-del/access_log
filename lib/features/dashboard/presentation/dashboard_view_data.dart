import '../../../../core/localization/app_strings.dart';
import '../../../../models/models.dart';
import 'bloc/dashboard_bloc.dart';

/// Everything the dashboard renders, already resolved from the API payload.
///
/// The widget only formats strings; every backend-to-UI decision happens here so
/// the screen stays declarative.
class DashboardViewData {
  const DashboardViewData({
    required this.monthDate,
    required this.todayIncidents,
    this.totalIncidents = 0,
    this.openIncidents = 0,
    this.inProgress = 0,
    this.completed = 0,
    this.onHold = 0,
    this.todaysActivities = 0,
    this.needApproval = 0,
    this.monthTotal = 0,
    this.monthCompleted = 0,
    this.monthPercentage = 0,
  });

  factory DashboardViewData.fromState(
    DashboardState state, {
    required DateTime monthDate,
  }) {
    final stats = state.stats;
    final summary = stats?.monthSummary;
    return DashboardViewData(
      monthDate: monthDate,
      todayIncidents: state.todayIncidents,
      totalIncidents: stats?.totalIncidents ?? 0,
      openIncidents: stats?.openIncidents ?? 0,
      inProgress: stats?.inProgress ?? 0,
      completed: stats?.completed ?? 0,
      onHold: stats?.onHold ?? 0,
      todaysActivities: stats?.todaysActivities ?? 0,
      needApproval: stats?.needApproval ?? 0,
      monthTotal: summary?.totalIncident ?? 0,
      monthCompleted: summary?.completed ?? 0,
      monthPercentage: summary?.percentage ?? 0,
    );
  }

  final DateTime monthDate;
  final List<CapIncident> todayIncidents;
  final int totalIncidents;
  final int openIncidents;
  final int inProgress;
  final int completed;
  final int onHold;
  final int todaysActivities;
  final int needApproval;
  final int monthTotal;
  final int monthCompleted;

  /// True once at least one section has real data, which is what separates a
  /// genuine empty state from a screen that has not loaded yet.
  bool get hasContent => totalIncidents > 0 || todayIncidents.isNotEmpty;

  /// Completion ratio straight from CAP. Kept as a `double`; the value is only
  /// rounded here, at the last possible moment, for display.
  final double monthPercentage;

  String get monthCompletionLabel => formatCompletionRate(monthPercentage);

  /// Drops a trailing `.0` so whole numbers do not render as `100.0%`.
  static String formatCompletionRate(double value) {
    final rounded = value.round();
    final label = value == rounded ? '$rounded' : value.toStringAsFixed(1);
    return '$label%';
  }
}

const _monthNames = <int, (String, String)>{
  1: ('January', 'يناير'),
  2: ('February', 'فبراير'),
  3: ('March', 'مارس'),
  4: ('April', 'أبريل'),
  5: ('May', 'مايو'),
  6: ('June', 'يونيو'),
  7: ('July', 'يوليو'),
  8: ('August', 'أغسطس'),
  9: ('September', 'سبتمبر'),
  10: ('October', 'أكتوبر'),
  11: ('November', 'نوفمبر'),
  12: ('December', 'ديسمبر'),
};

/// Localized `Month Year` label, derived from the requested month.
String dashboardMonthTitle(DateTime date, AppStrings strings) {
  final (english, arabic) = _monthNames[date.month] ?? ('', '');
  return '${strings.isArabic ? arabic : english} ${date.year}';
}
