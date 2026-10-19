import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/periodic_photo_gate.dart';

/// The single blocking screen for the periodic photo requirement.
///
/// Presentation only: it renders [state] and forwards user intents. It never
/// talks to the coordinator, the camera or the API, and it owns no timer.
///
/// There is deliberately **no dismiss/skip/close action**: while the gate is
/// blocking, CAP stays blocked until the photo is captured and CAP accepts it.
/// The camera only opens when the user taps the button — never automatically
/// on a deadline, on resume, or from the background.
class PeriodicPhotoBlockingScreen extends StatelessWidget {
  const PeriodicPhotoBlockingScreen({
    super.key,
    required this.state,
    required this.busy,
    required this.error,
    required this.onTakePhoto,
    required this.onRetry,
    required this.onRetake,
  });

  final PeriodicPhotoGateState state;
  final bool busy;
  final String? error;
  final Future<void> Function() onTakePhoto;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRetake;

  @override
  Widget build(BuildContext context) {
    final content = _content(context);
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
                      child: Icon(content.icon, size: 46, color: content.color),
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
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: busy ? null : content.primaryAction,
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
                          : Icon(content.primaryIcon),
                      label: Text(content.primaryLabel),
                    ),
                    if (content.secondaryAction != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: busy ? null : content.secondaryAction,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.orange,
                          side: BorderSide(color: AppColors.orange),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                        ),
                        icon: Icon(content.secondaryIcon),
                        label: Text(content.secondaryLabel!),
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

  _PhotoContent _content(BuildContext context) => switch (state) {
    PeriodicPhotoGateState.submitting => _PhotoContent(
      icon: Icons.photo_camera_outlined,
      color: AppColors.info,
      title: context.tr('Uploading Photo…', 'جارٍ رفع الصورة…'),
      body: context.tr(
        'Submitting your required photo to CAP.',
        'جارٍ إرسال الصورة المطلوبة إلى CAP.',
      ),
      primaryLabel: context.tr('Uploading…', 'جارٍ الرفع…'),
      primaryIcon: Icons.cloud_upload_outlined,
      primaryAction: null,
    ),
    PeriodicPhotoGateState.submitFailed => _PhotoContent(
      icon: Icons.cloud_off_rounded,
      color: AppColors.warning,
      title: context.tr('Photo Not Uploaded', 'لم يتم رفع الصورة'),
      body: error == null
          ? context.tr(
              'Your photo was captured but could not be uploaded. '
              'It is kept for you — retry without taking it again.',
              'تم التقاط الصورة لكن تعذّر رفعها. تم حفظها — أعد المحاولة '
              'دون التقاط صورة جديدة.',
            )
          : '${context.tr(
              'Your photo was captured but could not be uploaded. '
              'It is kept for you — retry without taking it again.',
              'تم التقاط الصورة لكن تعذّر رفعها. تم حفظها — أعد المحاولة '
              'دون التقاط صورة جديدة.',
            )}\n\n$error',
      primaryLabel: context.tr('Retry Upload', 'إعادة الرفع'),
      primaryIcon: Icons.cloud_upload_outlined,
      primaryAction: onRetry,
      secondaryLabel: context.tr('Retake Photo', 'إعادة التقاط الصورة'),
      secondaryIcon: Icons.photo_camera_outlined,
      secondaryAction: onRetake,
    ),
    PeriodicPhotoGateState.due => _PhotoContent(
      icon: Icons.photo_camera_outlined,
      color: AppColors.orange,
      title: context.tr('Photo Required', 'صورة مطلوبة'),
      body: context.tr(
        'A periodic photo is required. Take the photo to continue using CAP.',
        'صورة دورية مطلوبة. التقط الصورة لمتابعة استخدام CAP.',
      ),
      primaryLabel: context.tr('Take Photo', 'التقاط صورة'),
      primaryIcon: Icons.photo_camera_outlined,
      primaryAction: onTakePhoto,
    ),
    // Never rendered: the guard only mounts this screen while blocking.
    PeriodicPhotoGateState.checking ||
    PeriodicPhotoGateState.disabledByConfiguration ||
    PeriodicPhotoGateState.waiting => _PhotoContent(
      icon: Icons.photo_camera_outlined,
      color: AppColors.info,
      title: context.tr('Photo Required', 'صورة مطلوبة'),
      body: '',
      primaryLabel: context.tr('Take Photo', 'التقاط صورة'),
      primaryIcon: Icons.photo_camera_outlined,
      primaryAction: onTakePhoto,
    ),
  };
}

class _PhotoContent {
  const _PhotoContent({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.primaryAction,
    this.secondaryLabel,
    this.secondaryIcon,
    this.secondaryAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String primaryLabel;
  final IconData primaryIcon;
  final Future<void> Function()? primaryAction;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final Future<void> Function()? secondaryAction;
}
