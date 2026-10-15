import 'package:flutter/material.dart';
import '../../../core/di/injection.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/routes/app_routes.dart';
import '../../../models/models.dart';
import '../../incidents/data/incident_lookup_store.dart';
import '../../incidents/data/models/incident_lookup_models.dart';

/// Matches semantic codes/names, but always takes the numeric ID from Lookup.
class DashboardIncidentNavigation {
  static IncidentListFilter? resolve(
    CapIncidentStatus status,
    IncidentLookupData lookup, {
    DateTime? month,
  }) {
    final codes = switch (status) {
      CapIncidentStatus.needAssign => {'needassign'},
      CapIncidentStatus.needApproval => {'needapproval'},
      CapIncidentStatus.pending => {'pending'},
      CapIncidentStatus.inProcess => {'inprocess', 'inprogress'},
      CapIncidentStatus.hold => {'hold', 'onhold'},
      CapIncidentStatus.completed => {'completed'},
      CapIncidentStatus.cancelled => {'cancelled', 'canceled'},
    };
    String normalize(String? value) =>
        (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final matches = lookup.status
        .where(
          (item) =>
              item.id != null &&
              item.id! > 0 &&
              (codes.contains(normalize(item.code)) ||
                  codes.contains(normalize(item.name))),
        )
        .toList();
    if (matches.length != 1) return null;
    final period = month == null ? null : monthFilter(month);
    return IncidentListFilter(
      status: status,
      statusId: matches.single.id,
      from: period?.from,
      to: period?.to,
    );
  }

  static IncidentListFilter monthFilter(DateTime month) => IncidentListFilter(
    from: DateTime(month.year, month.month),
    to: DateTime(month.year, month.month + 1, 0),
  );

  static Future<void> open(
    BuildContext context,
    CapIncidentStatus? status, {
    required DateTime month,
  }) async {
    IncidentListFilter? filter;
    if (status == null) {
      filter = monthFilter(month);
    } else if (services.isRegistered<IncidentLookupStore>()) {
      final store = services<IncidentLookupStore>();
      if (store.current == null) await store.refresh();
      final lookup = store.current;
      if (lookup != null) filter = resolve(status, lookup, month: month);
    }
    if (!context.mounted) return;
    if (filter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'This status is unavailable in Incident Lookup. Please refresh and retry.',
              'هذه الحالة غير متاحة في قائمة حالات البلاغات. حدّث البيانات وحاول مجددًا.',
            ),
          ),
        ),
      );
      return;
    }
    debugPrint(
      '[Dashboard -> IncidentList] status=${status?.name ?? "all"}, StatusId=${filter.statusId ?? -1}',
    );
    Navigator.pushNamed(context, AppRoutes.incidentList, arguments: filter);
  }
}
