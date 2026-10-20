import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/gps_requirement_gate.dart';

/// The blocking screen for the GPS requirement.
///
/// Presentation only: it renders [state] and forwards one user intent. It never
/// talks to the platform and never owns the requirement logic. The decision
/// *whether* to block — and which requirement wins when both GPS and the
/// periodic photo are outstanding — belongs to the app-level
/// `AppRequirementGuard`, so only this single screen is ever mounted.
class GpsBlockingScreen extends StatelessWidget {
  const GpsBlockingScreen({
    super.key,
    required this.state,
    required this.busy,
    required this.onAction,
  });

  final GpsGateState state;
  final bool busy;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    final content = _content(context, state);
    return Material(
      color: AppColors.background,
      child: Directionality(
        textDirection: Directionality.of(context),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: content.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child:
                          content.leading ??
                          Icon(content.icon, size: 46, color: content.color),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      content.title,
                      textAlign: TextAlign.center,
                      style: AppTypography.title,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      content.body,
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    if (content.action != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: busy ? null : onAction,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(content.actionIcon ?? content.icon),
                        label: Text(content.action!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _GateContent _content(
    BuildContext context,
    GpsGateState state,
  ) => switch (state) {
    GpsGateState.permissionRequired => _GateContent(
      icon: Icons.location_on_outlined,
      color: AppColors.orange,
      title: context.tr('Location Permission Required', 'صلاحية الموقع مطلوبة'),
      body: context.tr(
        'Allow location access, then select “Allow all the time” on Android or “Always” on iPhone. “While using the app” is not enough for background tracking. If the option is missing, open your device Settings → Apps → CAP → Permissions → Location.',
        'اسمح بالوصول إلى الموقع، ثم اختر «السماح طوال الوقت / Allow all the time» على أندرويد أو «دائمًا / Always» على آيفون. خيار «أثناء استخدام التطبيق» لا يكفي للتتبع في الخلفية. إذا لم يظهر الخيار، افتح إعدادات الجهاز ← التطبيقات ← CAP ← الأذونات ← الموقع.',
      ),
      action: context.tr('Allow Location', 'السماح بالموقع'),
    ),
    GpsGateState.backgroundPermissionRequired => _GateContent(
      icon: Icons.my_location_rounded,
      color: AppColors.orange,
      title: context.tr(
        'Background Location Required',
        'الموقع في الخلفية مطلوب',
      ),
      body: context.tr(
        'Location is currently allowed only while using the app. In device Settings → CAP → Location permissions, choose “Allow all the time” (Android) or “Always” (iPhone), then return to CAP. No new login is needed.',
        'صلاحية الموقع الحالية تسمح به أثناء استخدام التطبيق فقط. من إعدادات الجهاز ← CAP ← أذونات الموقع، اختر «السماح طوال الوقت / Allow all the time» على أندرويد أو «دائمًا / Always» على آيفون، ثم ارجع للتطبيق. لا تحتاج لتسجيل الدخول مجددًا.',
      ),
      action: context.tr(
        'Allow all the time / Always',
        'السماح بالموقع طوال الوقت',
      ),
    ),
    GpsGateState.locationServicesDisabled => _GateContent(
      icon: Icons.gps_off_rounded,
      color: AppColors.warning,
      title: context.tr('Location Services Required', 'خدمة الموقع مطلوبة'),
      body: context.tr(
        'Please enable Location Services to continue using CAP.',
        'يرجى تفعيل خدمة الموقع لمتابعة استخدام CAP.',
      ),
      action: context.tr('Enable Location', 'تفعيل الموقع'),
      actionIcon: Icons.open_in_new_rounded,
    ),
    GpsGateState.error => _GateContent(
      icon: Icons.error_outline_rounded,
      color: AppColors.error,
      title: context.tr('Location Unavailable', 'الموقع غير متاح'),
      body: context.tr(
        'CAP could not start location tracking. Check permissions and try again.',
        'تعذّر تشغيل تتبع الموقع. تحقق من الصلاحيات وحاول مجددًا.',
      ),
      action: context.tr('Try Again', 'إعادة المحاولة'),
      actionIcon: Icons.refresh_rounded,
    ),
    GpsGateState.checking || GpsGateState.startingTracker => _GateContent(
      icon: Icons.location_searching_rounded,
      color: AppColors.info,
      title: context.tr('Checking Location…', 'جارٍ التحقق من الموقع…'),
      body: context.tr(
        'CAP is verifying the device location requirements.',
        'يتحقق CAP من متطلبات موقع الجهاز.',
      ),
      leading: const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    ),
    GpsGateState.ready || GpsGateState.disabledByConfiguration => _GateContent(
      icon: Icons.check_circle_outline_rounded,
      color: AppColors.success,
      title: context.tr('Ready', 'جاهز'),
      body: '',
    ),
  };
}

class _GateContent {
  const _GateContent({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.action,
    this.actionIcon,
    this.leading,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String? action;
  final IconData? actionIcon;
  final Widget? leading;
}
