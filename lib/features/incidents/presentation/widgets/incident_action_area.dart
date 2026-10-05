import 'package:flutter/material.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../widgets/app_button.dart';
import '../../domain/actions/incident_available_action.dart';

/// Presentation only. No status rules, lookup access or execution logic.
class IncidentActionArea extends StatelessWidget {
  const IncidentActionArea({
    super.key,
    required this.actions,
    required this.onActionSelected,
    this.loading = false,
  });
  final List<IncidentAvailableAction> actions;
  final bool loading;
  final ValueChanged<IncidentAvailableAction> onActionSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .05),
          blurRadius: 18,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: loading
          ? Semantics(
              label: context.tr('Loading actions', 'جارٍ تحميل الإجراءات'),
              child: const Center(
                heightFactor: 1,
                child: SizedBox(
                  width: 120,
                  height: 4,
                  child: LinearProgressIndicator(),
                ),
              ),
            )
          : actions.isEmpty
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, color: AppColors.muted),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    context.tr('No available actions', 'لا توجد إجراءات متاحة'),
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(color: AppColors.muted),
                  ),
                ),
              ],
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                return Wrap(
                  spacing: 9,
                  runSpacing: 8,
                  children: [
                    for (var index = 0; index < actions.length; index++)
                      SizedBox(
                        width:
                            stacked ||
                                actions.length == 1 ||
                                (actions.length.isOdd &&
                                    index == actions.length - 1)
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 9) / 2,
                        child: _button(context, actions[index]),
                      ),
                  ],
                );
              },
            ),
    ),
  );

  Widget _button(BuildContext context, IncidentAvailableAction action) {
    final (english, arabic, icon, style) = switch (action.type) {
      IncidentAction.assign => (
        'Assign',
        'إسناد',
        Icons.person_add_alt,
        AppButtonStyle.primary,
      ),
      IncidentAction.cancel => (
        'Cancel',
        'إلغاء',
        Icons.close,
        AppButtonStyle.outline,
      ),
      IncidentAction.approve => (
        'Approve',
        'موافقة',
        Icons.approval_outlined,
        AppButtonStyle.primary,
      ),
      IncidentAction.reject => (
        'Reject',
        'رفض',
        Icons.close,
        AppButtonStyle.outline,
      ),
      IncidentAction.hold => (
        'Hold',
        'تعليق',
        Icons.pause,
        AppButtonStyle.outline,
      ),
      IncidentAction.interventionRequest => (
        'New Request',
        'طلب جديد',
        Icons.login,
        AppButtonStyle.primary,
      ),
      IncidentAction.renewalRequest => (
        'New Request (Renewal)',
        'طلب تجديد',
        Icons.autorenew,
        AppButtonStyle.secondary,
      ),
      IncidentAction.complete => (
        'Complete',
        'إكمال',
        Icons.task_alt,
        AppButtonStyle.primary,
      ),
      IncidentAction.departureRequest => (
        'New Request (Departure)',
        'طلب مغادرة',
        Icons.logout,
        AppButtonStyle.primary,
      ),
    };
    return AppButton(
      key: ValueKey(action.type),
      label: context.tr(english, arabic),
      icon: icon,
      style: style,
      expanded: true,
      onPressed: () => onActionSelected(action),
    );
  }
}
