import 'dart:async';

import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';
import '../core/theme/app_tokens.dart';
import '../mock/mock_data.dart';
import '../screens/auth/auth_screens.dart';
import 'app_button.dart';

void navigateToSecureLogin(BuildContext context) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}

Future<void> showSessionExpirationWarning(
  BuildContext context, {
  int initialSeconds = MockData.sessionWarningSeconds,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      SessionExpirationWarningDialog(initialSeconds: initialSeconds),
);

Future<void> showSessionExpiredDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const SessionExpiredDialog(),
);

Future<bool> showActiveInterventionLogoutWarning(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ActiveInterventionLogoutDialog(),
    ) ??
    false;

class SessionExpirationWarningDialog extends StatefulWidget {
  const SessionExpirationWarningDialog({
    super.key,
    this.initialSeconds = MockData.sessionWarningSeconds,
  });

  final int initialSeconds;

  @override
  State<SessionExpirationWarningDialog> createState() =>
      _SessionExpirationWarningDialogState();
}

class _SessionExpirationWarningDialogState
    extends State<SessionExpirationWarningDialog> {
  late int seconds = widget.initialSeconds;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (seconds <= 1) {
        timer?.cancel();
        final navigator = Navigator.of(context);
        navigator.pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigator.mounted) showSessionExpiredDialog(navigator.context);
        });
      } else {
        setState(() => seconds--);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: _SessionDialogFrame(
      icon: Icons.timer_outlined,
      color: AppColors.warning,
      title: context.tr('Session Expiring Soon', 'ستنتهي الجلسة قريبًا'),
      message: context.tr(
        'Your session will expire due to inactivity.',
        'ستنتهي جلستك بسبب عدم وجود نشاط.',
      ),
      detail: context.tr(
        'Prototype timeout: ${MockData.sessionTimeoutMinutes} minutes',
        'مهلة النموذج: ${MockData.sessionTimeoutMinutes} دقيقة',
      ),
      countdown: _countdown(seconds),
      primaryLabel: context.tr('Stay Logged In', 'البقاء مسجلًا'),
      primaryIcon: Icons.refresh,
      onPrimary: () {
        timer?.cancel();
        Navigator.pop(context);
      },
      secondaryLabel: context.tr('Logout', 'تسجيل الخروج'),
      onSecondary: () => navigateToSecureLogin(context),
    ),
  );
}

class SessionExpiredDialog extends StatelessWidget {
  const SessionExpiredDialog({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: _SessionDialogFrame(
      icon: Icons.lock_clock_outlined,
      color: AppColors.error,
      title: context.tr('Session Expired', 'انتهت الجلسة'),
      message: context.tr(
        'Your session has expired due to inactivity.',
        'انتهت جلستك بسبب عدم وجود نشاط.',
      ),
      detail: context.tr(
        'Sign in again to continue securely.',
        'سجّل الدخول مرة أخرى للمتابعة بأمان.',
      ),
      primaryLabel: context.tr('Login Again', 'تسجيل الدخول مجددًا'),
      primaryIcon: Icons.login,
      onPrimary: () => navigateToSecureLogin(context),
    ),
  );
}

class ActiveInterventionLogoutDialog extends StatelessWidget {
  const ActiveInterventionLogoutDialog({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: _SessionDialogFrame(
      icon: Icons.engineering_outlined,
      color: AppColors.orange,
      title: context.tr('Active Intervention', 'تدخل نشط'),
      message: context.tr(
        'You currently have an active intervention. Logging out will return you to the login screen.',
        'لديك تدخل نشط حاليًا. سيعيدك تسجيل الخروج إلى شاشة الدخول.',
      ),
      detail:
          '${MockData.capIncidents.first.number} • ${MockData.capIncidents.first.siteName}',
      primaryLabel: context.tr('Cancel', 'إلغاء'),
      primaryStyle: AppButtonStyle.outline,
      onPrimary: () => Navigator.pop(context, false),
      secondaryLabel: context.tr('Logout', 'تسجيل الخروج'),
      onSecondary: () => Navigator.pop(context, true),
      secondaryDestructive: true,
    ),
  );
}

class SessionExpiredScreen extends StatelessWidget {
  const SessionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  _StatusIcon(
                    icon: Icons.lock_clock_outlined,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.tr('Session Expired', 'انتهت الجلسة'),
                    textAlign: TextAlign.center,
                    style: AppTypography.display,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr(
                      'Your session has expired due to inactivity.',
                      'انتهت جلستك بسبب عدم وجود نشاط.',
                    ),
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Session timeout is configured to ${MockData.sessionTimeoutMinutes} minutes for this prototype.',
                      'مهلة الجلسة مضبوطة على ${MockData.sessionTimeoutMinutes} دقيقة في هذا النموذج.',
                    ),
                    textAlign: TextAlign.center,
                    style: AppTypography.meta.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 28),
                  AppButton(
                    label: context.tr('Login Again', 'تسجيل الدخول مجددًا'),
                    icon: Icons.login,
                    expanded: true,
                    onPressed: () => navigateToSecureLogin(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SessionReturnSimulationScreen extends StatefulWidget {
  const SessionReturnSimulationScreen({super.key});

  @override
  State<SessionReturnSimulationScreen> createState() =>
      _SessionReturnSimulationScreenState();
}

class _SessionReturnSimulationScreenState
    extends State<SessionReturnSimulationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showSessionExpiredDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Access Log+'),
    ),
    body: IgnorePointer(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            context.tr('Returning to application…', 'جارٍ العودة إلى التطبيق…'),
            style: AppTypography.title,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Simulated background inactivity state',
              'حالة محاكاة لعدم النشاط في الخلفية',
            ),
            style: AppTypography.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          const LinearProgressIndicator(color: AppColors.orange),
        ],
      ),
    ),
  );
}

class _SessionDialogFrame extends StatelessWidget {
  const _SessionDialogFrame({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.detail,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.primaryStyle = AppButtonStyle.primary,
    this.countdown,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryDestructive = false,
  });

  final IconData icon;
  final Color color;
  final String title, message, detail, primaryLabel;
  final String? countdown, secondaryLabel;
  final IconData? primaryIcon;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;
  final AppButtonStyle primaryStyle;
  final bool secondaryDestructive;

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusIcon(icon: icon, color: color),
            const SizedBox(height: 17),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: color.withValues(alpha: .18)),
              ),
              child: Text(
                detail,
                textAlign: TextAlign.center,
                style: AppTypography.label.copyWith(color: color),
              ),
            ),
            if (countdown != null) ...[
              const SizedBox(height: 17),
              Semantics(
                label: context.tr('$countdown remaining', 'متبقي $countdown'),
                liveRegion: true,
                child: Text(
                  countdown!,
                  textDirection: TextDirection.ltr,
                  style: AppTypography.display.copyWith(
                    fontSize: 38,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            AppButton(
              label: primaryLabel,
              icon: primaryIcon,
              style: primaryStyle,
              expanded: true,
              onPressed: onPrimary,
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 9),
              AppButton(
                label: secondaryLabel!,
                style: secondaryDestructive
                    ? AppButtonStyle.destructive
                    : AppButtonStyle.text,
                expanded: true,
                onPressed: onSecondary,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 70,
    height: 70,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: .1),
      border: Border.all(color: color.withValues(alpha: .22)),
    ),
    child: Icon(icon, color: color, size: 34),
  );
}

String _countdown(int seconds) {
  if (seconds <= MockData.sessionWarningSeconds) {
    return '00:${seconds.toString().padLeft(2, '0')}';
  }
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}
