import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';
import '../core/theme/app_tokens.dart';
import 'app_button.dart';
export 'evidence_collection.dart';
export 'dynamic_questionnaire.dart';
export 'location_validation.dart';

class FlowProgress extends StatelessWidget {
  const FlowProgress({super.key, required this.labels, required this.current});
  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            context.strings.isArabic
                ? 'الخطوة ${current + 1} من ${labels.length}'
                : 'STEP ${current + 1} OF ${labels.length}',
            style: AppTypography.meta.copyWith(
              color: AppColors.orange,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              labels[current],
              textAlign: TextAlign.end,
              style: AppTypography.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: (current + 1) / labels.length,
          minHeight: 6,
          color: AppColors.orange,
          backgroundColor: AppColors.border,
        ),
      ),
      const SizedBox(height: 11),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            labels.length,
            (index) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 7),
              child: Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: index <= current
                      ? AppColors.orange
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: index <= current
                        ? AppColors.orange
                        : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: index < current
                      ? const Icon(Icons.check, color: Colors.white, size: 15)
                      : Text(
                          '${index + 1}',
                          style: AppTypography.meta.copyWith(
                            color: index <= current
                                ? Colors.white
                                : AppColors.muted,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class FlowNavigationBar extends StatelessWidget {
  const FlowNavigationBar({
    super.key,
    required this.onContinue,
    this.onBack,
    this.continueLabel = 'Continue',
    this.loading = false,
  });
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final String continueLabel;
  final bool loading;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .04),
          blurRadius: 18,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          if (onBack != null) ...[
            Expanded(
              child: AppButton(
                label: context.tr('Previous', 'السابق'),
                icon: Icons.arrow_back,
                style: AppButtonStyle.outline,
                expanded: true,
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: onBack == null ? 1 : 2,
            child: AppButton(
              label: continueLabel == 'Continue'
                  ? context.tr('Continue', 'متابعة')
                  : continueLabel,
              icon: Icons.arrow_forward,
              loading: loading,
              expanded: true,
              onPressed: onContinue,
            ),
          ),
        ],
      ),
    ),
  );
}

class FlowReviewView extends StatelessWidget {
  const FlowReviewView({super.key, required this.title, required this.items});
  final String title;
  final List<(IconData, String, String)> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FlowPageHeading(
        icon: Icons.verified_outlined,
        title: title,
        subtitle: context.tr(
          'Review the captured information before confirming this action.',
          'راجع المعلومات المسجلة قبل تأكيد هذا الإجراء.',
        ),
      ),
      const SizedBox(height: 18),
      ...items.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: .09),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Icon(item.$1, color: AppColors.muted, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$2, style: AppTypography.label),
                      Text(
                        item.$3,
                        style: AppTypography.meta.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class FlowSuccessView extends StatelessWidget {
  const FlowSuccessView({
    super.key,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onDone,
  });
  final String title, message, buttonLabel;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 52,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 25),
          Text(
            title,
            style: AppTypography.display,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          AppButton(
            label: buttonLabel,
            icon: Icons.arrow_back,
            expanded: true,
            onPressed: onDone,
          ),
        ],
      ),
    ),
  );
}

class FlowPageHeading extends StatelessWidget {
  const FlowPageHeading({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.orange),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.title),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.body.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    ],
  );
}
