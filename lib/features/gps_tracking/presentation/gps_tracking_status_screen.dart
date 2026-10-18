import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:async';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/localization/app_strings.dart';
import '../domain/background_location_service.dart';
import '../domain/gps_tracking_manager.dart';
import '../domain/gps_tracking_sync_service.dart';
import 'gps_tracking_cubit.dart';

/// Status/permission surface for continuous background tracking.
///
/// It only displays manager state and forwards user intents. The tracking
/// engine is native and never attached to this screen's lifecycle.
class GpsTrackingStatusScreen extends StatefulWidget {
  const GpsTrackingStatusScreen({super.key, this.cubit});
  final GpsTrackingCubit? cubit;

  @override
  State<GpsTrackingStatusScreen> createState() =>
      _GpsTrackingStatusScreenState();
}

class _GpsTrackingStatusScreenState extends State<GpsTrackingStatusScreen> {
  late final GpsTrackingCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit =
        widget.cubit ??
        (services.isRegistered<GpsTrackingCubit>()
            ? services<GpsTrackingCubit>()
            : throw StateError('GPS tracking is not configured'));
  }

  @override
  void dispose() {
    // The factory-provided cubit belongs to this screen; an injected one is
    // owned by the caller.
    if (widget.cubit == null) unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('GPS Tracking', 'تتبع الموقع')),
        ),
        body: SafeArea(
          child: BlocBuilder<GpsTrackingCubit, GpsTrackingViewState>(
            builder: (context, state) => ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _StatusCard(state: state),
                const SizedBox(height: AppSpacing.md),
                _Explanation(),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: state.busy ? null : _cubit.enable,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    context.tr('Enable tracking', 'تشغيل التتبع'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: state.busy ? null : _cubit.reconcile,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(
                    context.tr(
                      'Reconcile with configuration',
                      'المزامنة مع الإعدادات',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: _cubit.syncNow,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    context.tr(
                      'Sync captured points now',
                      'إرسال النقاط المخزّنة الآن',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton.icon(
                  onPressed: state.busy ? null : _cubit.stop,
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(context.tr('Stop tracking', 'إيقاف التتبع')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});
  final GpsTrackingViewState state;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _appearance(state.status);
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _statusLabel(context, state.status),
                    style: AppTypography.title,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _row(
              context,
              context.tr('Native tracker', 'متتبع النظام'),
              state.nativeTracking
                  ? context.tr('Running', 'يعمل')
                  : context.tr('Stopped', 'متوقف'),
            ),
            _row(
              context,
              context.tr('Permission', 'الصلاحية'),
              _permissionLabel(context, state.permission),
            ),
            _row(
              context,
              context.tr('Pending upload', 'بانتظار الإرسال'),
              '${state.pendingCount}',
            ),
            _row(
              context,
              context.tr('Server sync', 'المزامنة مع الخادم'),
              _syncLabel(context, state.syncStatus),
            ),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _appearance(GpsTrackingStatus status) => switch (status) {
    GpsTrackingStatus.running => (AppColors.success, Icons.gps_fixed_rounded),
    GpsTrackingStatus.awaitingPermission => (
      AppColors.warning,
      Icons.privacy_tip_outlined,
    ),
    GpsTrackingStatus.disabledByConfiguration => (
      AppColors.muted,
      Icons.gps_off_rounded,
    ),
    GpsTrackingStatus.error => (AppColors.error, Icons.error_outline_rounded),
    GpsTrackingStatus.stopped => (AppColors.muted, Icons.gps_off_rounded),
    GpsTrackingStatus.unknown => (AppColors.info, Icons.help_outline_rounded),
  };

  String _statusLabel(BuildContext context, GpsTrackingStatus status) =>
      switch (status) {
        GpsTrackingStatus.running => context.tr(
          'Tracking is running',
          'التتبع يعمل',
        ),
        GpsTrackingStatus.awaitingPermission => context.tr(
          'Waiting for background permission',
          'بانتظار صلاحية التتبع في الخلفية',
        ),
        GpsTrackingStatus.disabledByConfiguration => context.tr(
          'Disabled by system configuration',
          'معطّل حسب إعدادات النظام',
        ),
        GpsTrackingStatus.error => context.tr(
          'Tracking unavailable',
          'التتبع غير متاح',
        ),
        GpsTrackingStatus.stopped => context.tr('Tracking stopped', 'التتبع متوقف'),
        GpsTrackingStatus.unknown => context.tr('Unknown state', 'حالة غير معروفة'),
      };

  String _permissionLabel(
    BuildContext context,
    LocationPermissionStatus permission,
  ) => switch (permission) {
    LocationPermissionStatus.always => context.tr(
      'Always (background)',
      'دائمًا (في الخلفية)',
    ),
    LocationPermissionStatus.whenInUse => context.tr(
      'While using the app',
      'أثناء استخدام التطبيق',
    ),
    LocationPermissionStatus.notDetermined => context.tr(
      'Not requested',
      'لم يتم الطلب',
    ),
    LocationPermissionStatus.denied => context.tr('Denied', 'مرفوضة'),
    LocationPermissionStatus.restricted => context.tr(
      'Restricted',
      'مقيّدة',
    ),
    LocationPermissionStatus.serviceDisabled => context.tr(
      'Location services off',
      'خدمة الموقع متوقفة',
    ),
    LocationPermissionStatus.unknown => context.tr('Unknown', 'غير معروفة'),
  };

  String _syncLabel(BuildContext context, GpsSyncStatus status) =>
      switch (status) {
        GpsSyncStatus.idle => context.tr('Idle', 'خامل'),
        GpsSyncStatus.syncing => context.tr('Syncing…', 'جارٍ الإرسال…'),
        GpsSyncStatus.synced => context.tr('Up to date', 'تم الإرسال'),
        GpsSyncStatus.offline => context.tr('Offline', 'غير متصل'),
        GpsSyncStatus.unauthenticated => context.tr(
          'Sign in required',
          'يتطلب تسجيل الدخول',
        ),
        GpsSyncStatus.failed => context.tr('Retry pending', 'بانتظار إعادة المحاولة'),
      };

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xxs),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.body.copyWith(color: AppColors.muted),
        ),
        Text(value, style: AppTypography.label),
      ],
    ),
  );
}

class _Explanation extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(
    context.tr(
      'Continuous tracking reads the system configuration. Location points are '
          'always stored on the device first, online or offline, and are only '
          'removed after the server confirms them.',
      'يقرأ التتبع المستمر إعدادات النظام. يتم تخزين نقاط الموقع على الجهاز '
          'أولًا، سواء كان متصلًا أو غير متصل، ولا يتم حذفها إلا بعد تأكيد '
          'الخادم.',
    ),
    style: AppTypography.body.copyWith(color: AppColors.muted),
  );
}
