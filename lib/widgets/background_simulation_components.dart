import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';
import '../core/theme/app_tokens.dart';
import '../mock/mock_data.dart';
import 'app_button.dart';
import 'location_validation.dart';

enum MockLocationState { checking, inside, outside, unavailable }

class ActiveInterventionBanner extends StatelessWidget {
  const ActiveInterventionBanner({
    super.key,
    required this.site,
    required this.onLocationTap,
    required this.onPhotoTap,
    required this.onWarningTap,
  });
  final String site;
  final VoidCallback onLocationTap, onPhotoTap, onWarningTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1A1A), Color(0xFF292929)],
      ),
      borderRadius: BorderRadius.circular(AppRadius.card),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .12),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.radar, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Active Intervention', 'تدخل نشط'),
                    style: AppTypography.section.copyWith(color: Colors.white),
                  ),
                  Text(
                    context.tr(
                      'Simulated background tracking',
                      'تتبع خلفي محاكى',
                    ),
                    style: AppTypography.meta.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.tr(
                'Simulate geofence warning',
                'محاكاة تحذير النطاق',
              ),
              visualDensity: VisualDensity.compact,
              onPressed: onWarningTap,
              icon: const Badge(
                backgroundColor: AppColors.error,
                smallSize: 8,
                child: Icon(Icons.warning_amber, color: AppColors.warning),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _BannerRow(label: context.tr('Site', 'الموقع'), value: site),
        _BannerRow(
          label: context.tr('Duration', 'المدة'),
          value: context.tr('01h 24m', 'ساعة و24 دقيقة'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _BannerAction(
                icon: Icons.my_location,
                label: context.tr('Location Tracking', 'تتبع الموقع'),
                value: context.tr('Active', 'نشط'),
                onTap: onLocationTap,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _BannerAction(
                icon: Icons.add_a_photo_outlined,
                label: context.tr('Next Photo', 'الصورة التالية'),
                value: '08:30',
                onTap: onPhotoTap,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BannerRow extends StatelessWidget {
  const _BannerRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(
          '$label: ',
          style: AppTypography.meta.copyWith(color: Colors.white54),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.meta.copyWith(color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _BannerAction extends StatelessWidget {
  const _BannerAction({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.orange, size: 19),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.meta.copyWith(
                    color: Colors.white54,
                    fontSize: 9,
                  ),
                ),
                Text(
                  value,
                  style: AppTypography.meta.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class LocationValidationComponent extends StatelessWidget {
  const LocationValidationComponent({
    super.key,
    required this.state,
    this.onStateChanged,
    this.siteName = 'Cairo Core Site 14',
  });
  final MockLocationState state;
  final ValueChanged<MockLocationState>? onStateChanged;
  final String siteName;

  @override
  Widget build(BuildContext context) {
    final (color, icon, title) = switch (state) {
      MockLocationState.checking => (
        AppColors.info,
        Icons.location_searching,
        context.tr('Checking location', 'جارٍ التحقق من الموقع'),
      ),
      MockLocationState.inside => (
        AppColors.success,
        Icons.check_circle,
        context.tr('Inside Geofence', 'داخل النطاق الجغرافي'),
      ),
      MockLocationState.outside => (
        AppColors.error,
        Icons.gps_off,
        context.tr('Outside Geofence', 'خارج النطاق الجغرافي'),
      ),
      MockLocationState.unavailable => (
        AppColors.muted,
        Icons.location_disabled,
        context.tr('Location unavailable', 'الموقع غير متاح'),
      ),
    };
    final distance = switch (state) {
      MockLocationState.checking => context.tr('Calculating…', 'جارٍ الحساب…'),
      MockLocationState.inside => context.tr('18 metres', '18 مترًا'),
      MockLocationState.outside => context.tr('248 metres', '248 مترًا'),
      MockLocationState.unavailable => '—',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 155,
          decoration: BoxDecoration(
            color: const Color(0xFFE7EBE5),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(double.infinity, 155),
                painter: _MockMapPainter(),
              ),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: .35)),
                ),
              ),
              state == MockLocationState.checking
                  ? CircularProgressIndicator(color: color, strokeWidth: 3)
                  : Icon(Icons.location_pin, color: color, size: 44),
              PositionedDirectional(
                top: 10,
                start: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    context.tr('SIMULATED GPS', 'GPS محاكى'),
                    style: AppTypography.meta.copyWith(fontSize: 9),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withValues(alpha: .2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.section.copyWith(color: color),
                ),
              ),
              Text(distance, style: AppTypography.label),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GpsRow(
          label: context.tr('Current GPS', 'GPS الحالي'),
          value: state == MockLocationState.unavailable
              ? '—'
              : '30.0566, 31.3301',
        ),
        _GpsRow(
          label: context.tr('Site GPS', 'GPS المحطة'),
          value: '30.0568, 31.3302',
        ),
        _GpsRow(label: context.tr('Distance', 'المسافة'), value: distance),
        _GpsRow(
          label: context.tr('Allowed Radius', 'النطاق المسموح'),
          value: context.tr('100 metres', '100 متر'),
        ),
        if (onStateChanged != null) ...[
          const SizedBox(height: 13),
          DropdownButtonFormField<MockLocationState>(
            isExpanded: true,
            initialValue: state,
            decoration: InputDecoration(
              labelText: context.tr('Simulation state', 'حالة المحاكاة'),
              prefixIcon: const Icon(Icons.science_outlined),
            ),
            items: MockLocationState.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_locationStateLabel(context, value)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onStateChanged!(value);
            },
          ),
        ],
      ],
    );
  }
}

class _GpsRow extends StatelessWidget {
  const _GpsRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.meta.copyWith(color: AppColors.muted),
          ),
        ),
        Text(value, style: AppTypography.label),
      ],
    ),
  );
}

class EvidencePhotoCard extends StatelessWidget {
  const EvidencePhotoCard({
    super.key,
    required this.index,
    required this.site,
    required this.interventionId,
    this.onDelete,
  });
  final int index;
  final String site, interventionId;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 106,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey.shade300, Colors.blueGrey.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.cell_tower,
                    color: Colors.white54,
                    size: 36,
                  ),
                ),
                PositionedDirectional(
                  bottom: 6,
                  start: 6,
                  child: Text(
                    context.strings.isArabic
                        ? 'دليل $index'
                        : 'EVIDENCE $index',
                    style: AppTypography.meta.copyWith(
                      color: Colors.white,
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('Captured photo', 'صورة ملتقطة'),
                        style: AppTypography.label,
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 19,
                          color: AppColors.error,
                        ),
                      ),
                  ],
                ),
                _EvidenceMeta(
                  icon: Icons.schedule,
                  value: '10 Aug 2026 • 10:42 AM',
                ),
                const _EvidenceMeta(
                  icon: Icons.my_location,
                  value: '30.0566, 31.3301',
                ),
                const _EvidenceMeta(
                  icon: Icons.badge_outlined,
                  value: 'USR-OH-2041',
                ),
                _EvidenceMeta(icon: Icons.cell_tower, value: site),
                _EvidenceMeta(
                  icon: Icons.build_outlined,
                  value: interventionId,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EvidenceMeta extends StatelessWidget {
  const _EvidenceMeta({required this.icon, required this.value});
  final IconData icon;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: AppTypography.meta.copyWith(
              color: AppColors.muted,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Future<void> showGeofenceWarning(
  BuildContext context, {
  required String siteName,
  required VoidCallback onViewIncident,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    icon: Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: .1),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.gps_off, color: AppColors.error, size: 32),
    ),
    title: Text(
      context.tr(
        'You are outside the permitted site area.',
        'أنت خارج النطاق المسموح للموقع.',
      ),
      textAlign: TextAlign.center,
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogInfo(
          label: context.tr('Current distance', 'المسافة الحالية'),
          value: context.tr('248 metres', '248 مترًا'),
        ),
        _DialogInfo(
          label: context.tr('Allowed radius', 'النطاق المسموح'),
          value: context.tr('100 metres', '100 متر'),
        ),
        _DialogInfo(
          label: context.tr('Site name', 'اسم الموقع'),
          value: siteName,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: Text(context.tr('Dismiss', 'تجاهل')),
      ),
      FilledButton(
        onPressed: () {
          Navigator.pop(dialogContext);
          onViewIncident();
        },
        child: Text(context.tr('View Incident', 'عرض البلاغ')),
      ),
    ],
  ),
);

Future<void> showPhotoReminder(
  BuildContext context, {
  required String incidentNumber,
  required String site,
  required VoidCallback onCapture,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    icon: const Icon(
      Icons.add_a_photo_outlined,
      color: AppColors.orange,
      size: 38,
    ),
    title: Text(
      context.tr('Photo verification required', 'مطلوب التحقق بصورة'),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogInfo(
          label: context.tr('Incident Number', 'رقم البلاغ'),
          value: incidentNumber,
        ),
        _DialogInfo(label: context.tr('Site', 'الموقع'), value: site),
        _DialogInfo(
          label: context.tr('Due time', 'وقت الاستحقاق'),
          value: '08:30',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: Text(context.tr('Later', 'لاحقًا')),
      ),
      FilledButton.icon(
        onPressed: () {
          Navigator.pop(dialogContext);
          onCapture();
        },
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(context.tr('Capture Photo', 'التقاط صورة')),
      ),
    ],
  ),
);

class _DialogInfo extends StatelessWidget {
  const _DialogInfo({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.meta.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.label,
          ),
        ),
      ],
    ),
  );
}

class MockEvidenceCaptureScreen extends StatelessWidget {
  const MockEvidenceCaptureScreen({super.key, required this.site});
  final String site;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Capture Evidence', 'التقاط دليل'))),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        EvidencePhotoCard(
          index: 1,
          site: site,
          interventionId: MockData.activeInterventionNumber,
        ),
        const SizedBox(height: 14),
        Container(
          height: 170,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.orange),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_a_photo_outlined,
                color: AppColors.orange,
                size: 34,
              ),
              const SizedBox(height: 9),
              Text(
                context.tr('Add another mock photo', 'إضافة صورة محاكاة أخرى'),
                style: AppTypography.label,
              ),
              Text(
                context.tr(
                  'No camera integration',
                  'لا يوجد تكامل مع الكاميرا',
                ),
                style: AppTypography.meta.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: context.tr('Save Evidence', 'حفظ الدليل'),
          icon: Icons.check,
          expanded: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

class LocationSimulationScreen extends StatelessWidget {
  const LocationSimulationScreen({super.key, required this.site});
  final String site;
  @override
  Widget build(BuildContext context) => LocationValidationScreen(site: site);
}

String _locationStateLabel(BuildContext context, MockLocationState state) =>
    switch (state) {
      MockLocationState.checking => context.tr(
        'Checking location',
        'جارٍ التحقق من الموقع',
      ),
      MockLocationState.inside => context.tr(
        'Inside Geofence',
        'داخل النطاق الجغرافي',
      ),
      MockLocationState.outside => context.tr(
        'Outside Geofence',
        'خارج النطاق الجغرافي',
      ),
      MockLocationState.unavailable => context.tr(
        'Location unavailable',
        'الموقع غير متاح',
      ),
    };

class _MockMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD2D8D0)
      ..strokeWidth = 2;
    for (double y = 20; y < size.height; y += 35) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 20), paint);
    }
    for (double x = 20; x < size.width; x += 65) {
      canvas.drawLine(Offset(x, 0), Offset(x + 20, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
