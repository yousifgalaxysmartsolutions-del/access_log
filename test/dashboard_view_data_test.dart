import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/localization/app_strings.dart';
import 'package:access_log_plus/features/dashboard/presentation/dashboard_view_data.dart';

void main() {
  test('formatCompletionRate drops trailing .0 and rounds', () {
    expect(DashboardViewData.formatCompletionRate(100), '100%');
    expect(DashboardViewData.formatCompletionRate(75.5), '75.5%');
    expect(DashboardViewData.formatCompletionRate(33.33), '33.3%');
    expect(DashboardViewData.formatCompletionRate(33.0), '33%');
  });

  test('dashboardMonthTitle is localized by locale', () {
    expect(
      dashboardMonthTitle(DateTime(2026, 8, 1), const AppStrings(Locale('en'))),
      'August 2026',
    );
    expect(
      dashboardMonthTitle(DateTime(2026, 9, 1), const AppStrings(Locale('ar'))),
      'سبتمبر 2026',
    );
  });
}
