import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/mock_content_localization.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/models.dart';
import '../../widgets/app_button.dart';
import '../../widgets/evidence_collection.dart';
import '../../widgets/identity_verification_mock.dart';
import '../../widgets/location_validation.dart';
import '../../widgets/section_card.dart';
import 'incident_action_flows.dart';
import 'new_request_flows.dart';

const activeInterventionNumber = 'INC-2026-1001';
const activeInterventionDuration = '01:42:18';

class ActiveInterventionScreen extends StatefulWidget {
  const ActiveInterventionScreen({super.key, required this.incident});
  final CapIncident incident;

  @override
  State<ActiveInterventionScreen> createState() =>
      _ActiveInterventionScreenState();
}

class _ActiveInterventionScreenState extends State<ActiveInterventionScreen> {
  Timer? identityTimer;
  bool dialogOpen = false;
  bool verified = false;

  CapIncident get incident => widget.incident;

  @override
  void initState() {
    super.initState();
    identityTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _showIdentityCheck(),
    );
  }

  @override
  void dispose() {
    identityTimer?.cancel();
    super.dispose();
  }

  Future<void> _showIdentityCheck() async {
    if (!mounted || dialogOpen || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    dialogOpen = true;
    final result = await showMockIdentityVerification(context);
    if (mounted) setState(() => verified = result == true);
    dialogOpen = false;
  }

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Active Intervention', 'التدخل النشط')),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        _ActiveHeader(incident: incident),
        const SizedBox(height: 14),
        _ActivityStatusCard(incident: incident),
        const SizedBox(height: 14),
        SectionCard(
          title: context.tr('Location Status', 'حالة الموقع'),
          icon: Icons.my_location,
          child: Column(
            children: [
              MiniLocationCard(
                site: context.mockText(incident.siteName),
                distance: '45 m',
              ),
              const SizedBox(height: 12),
              _InfoLine(
                label: context.tr('Location Tracking', 'تتبع الموقع'),
                value: context.tr('Inside Geofence', 'داخل النطاق'),
              ),
              _InfoLine(
                label: context.tr('Distance', 'المسافة'),
                value: context.tr('45 meters', '45 مترًا'),
              ),
              _InfoLine(
                label: context.tr('Allowed Radius', 'النطاق المسوح'),
                value: context.tr('100 meters', '100 متر'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: context.tr('Photo Status', 'حالة الصور'),
          icon: Icons.photo_camera_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoLine(
                label: context.tr('Last Photo', 'آخر صورة'),
                value: '10:30 AM',
              ),
              _InfoLine(
                label: context.tr('Next Photo', 'الصورة التالية'),
                value: '11:00 AM',
              ),
              const SizedBox(height: 10),
              AppButton(
                label: context.tr(
                  'Capture Verification Photo',
                  'التقاط صورة تحقق',
                ),
                icon: Icons.add_a_photo_outlined,
                expanded: true,
                onPressed: () async {
                  final photo = await Navigator.push<MockEvidencePhoto>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PhotoCaptureScreen(),
                    ),
                  );
                  if (photo != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.tr(
                            'Verification photo added (mock)',
                            'تمت إضافة صورة التحقق (محاكاة)',
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.tr('Quick Actions', 'إجراءات سريعة'),
          style: AppTypography.title,
        ),
        const SizedBox(height: 11),
        _QuickActions(
          onHold: () => _open(
            context,
            FieldTaskWizard(incident: incident, type: TaskFlowType.hold),
          ),
          onRenew: () => _open(
            context,
            NewRequestWizard(
              incident: incident,
              type: RelatedRequestType.renewal,
            ),
          ),
          onDeparture: () => _open(
            context,
            NewRequestWizard(
              incident: incident,
              type: RelatedRequestType.departure,
            ),
          ),
          onComplete: () => _open(
            context,
            FieldTaskWizard(incident: incident, type: TaskFlowType.complete),
          ),
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: context.tr(
            'Periodic Identity Check',
            'التحقق الدوري من الهوية',
          ),
          icon: Icons.verified_user_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoLine(
                label: context.tr('Security Status', 'حالة الأمان'),
                value: verified
                    ? context.tr('Identity Verified', 'تم التحقق')
                    : context.tr('Check Scheduled', 'التحقق مجدول'),
              ),
              _InfoLine(
                label: context.tr('Verification Interval', 'فترة التحقق'),
                value: context.tr(
                  'Every 5 minutes (mock)',
                  'كل 5 دقائق (محاكاة)',
                ),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: context.tr(
                  'Try Identity Check',
                  'تجربة التحقق من الهوية',
                ),
                icon: Icons.face_retouching_natural,
                expanded: true,
                onPressed: _showIdentityCheck,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.tr('Activity Timeline', 'الخط الزمني للنشاط'),
          style: AppTypography.title,
        ),
        const SizedBox(height: 11),
        const _RecentActivity(
          time: '09:30',
          titleEn: 'Task Started',
          titleAr: 'بدء المهمة',
          icon: Icons.play_arrow,
        ),
        const _RecentActivity(
          time: '10:00',
          titleEn: 'Location Verified',
          titleAr: 'تم التحقق من الموقع',
          icon: Icons.location_on_outlined,
        ),
        const _RecentActivity(
          time: '10:30',
          titleEn: 'Photo Captured',
          titleAr: 'تم التقاط صورة',
          icon: Icons.photo_camera_outlined,
          last: true,
        ),
      ],
    ),
  );
}

class ActiveInterventionIndicator extends StatelessWidget {
  const ActiveInterventionIndicator({
    super.key,
    required this.incident,
    this.margin = EdgeInsets.zero,
  });
  final CapIncident incident;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(AppRadius.control),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .08),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveInterventionScreen(incident: incident),
        ),
      ),
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: .18),
                    shape: BoxShape.circle,
                  ),
                ),
                const Icon(
                  Icons.engineering,
                  color: AppColors.orange,
                  size: 22,
                ),
                const PositionedDirectional(
                  top: 1,
                  end: 1,
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Active Intervention', 'تدخل نشط'),
                    style: AppTypography.label.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activeInterventionNumber,
                    style: AppTypography.meta.copyWith(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              activeInterventionDuration,
              style: AppTypography.label.copyWith(color: Colors.white),
            ),
            const SizedBox(width: 5),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_back_ios_new
                  : Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 14,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActiveHeader extends StatelessWidget {
  const _ActiveHeader({required this.incident});
  final CapIncident incident;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF111111), Color(0xFF292929)],
      ),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.tr('IN PROCESS', 'قيد التنفيذ'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                activeInterventionNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: AppTypography.label.copyWith(color: AppColors.orange),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          context.mockText(incident.title),
          style: AppTypography.title.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 13),
        Text(
          '${context.mockText(incident.siteName)} • ${incident.siteCode}',
          style: AppTypography.body.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            const Icon(Icons.flag_outlined, color: AppColors.orange, size: 18),
            const SizedBox(width: 7),
            Text(
              '${context.tr('Priority', 'الأولوية')}: ${incident.priority.name.toUpperCase()}',
              style: AppTypography.meta.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ActivityStatusCard extends StatelessWidget {
  const _ActivityStatusCard({required this.incident});
  final CapIncident incident;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: context.tr('Activity Status', 'حالة النشاط'),
    icon: Icons.timer_outlined,
    child: Column(
      children: [
        _InfoLine(
          label: context.tr('Status', 'الحالة'),
          value: context.tr('In Process', 'قيد التنفيذ'),
        ),
        _InfoLine(label: context.tr('Started At', 'بدأ في'), value: '09:30 AM'),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer, color: AppColors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('Duration', 'المدة'),
                  style: AppTypography.label,
                ),
              ),
              Text(
                activeInterventionDuration,
                style: AppTypography.title.copyWith(color: AppColors.orange),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onHold,
    required this.onRenew,
    required this.onDeparture,
    required this.onComplete,
  });
  final VoidCallback onHold, onRenew, onDeparture, onComplete;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    childAspectRatio: 1.65,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    children: [
      _QuickAction(
        icon: Icons.pause_circle_outline,
        label: context.tr('Hold Task', 'تعليق المهمة'),
        color: AppColors.warning,
        onTap: onHold,
      ),
      _QuickAction(
        icon: Icons.autorenew,
        label: context.tr('Renew Intervention', 'تجديد التدخل'),
        color: AppColors.info,
        onTap: onRenew,
      ),
      _QuickAction(
        icon: Icons.logout,
        label: context.tr('Departure Request', 'طلب مغادرة'),
        color: AppColors.purple,
        onTap: onDeparture,
      ),
      _QuickAction(
        icon: Icons.task_alt,
        label: context.tr('Complete Task', 'إكمال المهمة'),
        color: AppColors.success,
        onTap: onComplete,
      ),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(label, style: AppTypography.label, maxLines: 2),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.time,
    required this.titleEn,
    required this.titleAr,
    required this.icon,
    this.last = false,
  });
  final String time, titleEn, titleAr;
  final IconData icon;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            time,
            style: AppTypography.meta.copyWith(color: AppColors.muted),
          ),
        ),
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.orange, size: 17),
            ),
            if (!last)
              Expanded(child: Container(width: 2, color: AppColors.border)),
          ],
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5, bottom: 22),
            child: Text(
              context.tr(titleEn, titleAr),
              style: AppTypography.label,
            ),
          ),
        ),
      ],
    ),
  );
}
