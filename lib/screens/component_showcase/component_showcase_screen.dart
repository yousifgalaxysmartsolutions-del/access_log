import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/action_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/attachment_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/incident_card.dart';
import '../../widgets/info_row.dart';
import '../../widgets/questionnaire_field.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/step_indicator.dart';
import '../../widgets/timeline_item.dart';

class ComponentShowcaseScreen extends StatelessWidget {
  const ComponentShowcaseScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.strings.t('showcase')),
      actions: [
        TextButton(
          onPressed: () => AccessLogApp.of(context).toggleLocale(),
          child: Text(context.strings.t('language')),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        _Hero(),
        const SizedBox(height: 24),
        const _Label('WORKFLOW', 'Incident progress'),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Current progress',
          icon: Icons.route_outlined,
          child: StepIndicator(
            current: 2,
            steps: ['Assigned', 'Accepted', 'Traveling', 'On site', 'Work'],
          ),
        ),
        const SizedBox(height: 24),
        const _Label('ACTIONS', 'Buttons & controls'),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Button variants',
          child: Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              AppButton(
                label: 'Primary',
                icon: Icons.arrow_forward,
                onPressed: () => _demo(context, 'Primary action'),
              ),
              AppButton(
                label: 'Secondary',
                style: AppButtonStyle.secondary,
                onPressed: () => _demo(context, 'Secondary action'),
              ),
              AppButton(
                label: 'Outline',
                style: AppButtonStyle.outline,
                onPressed: () => _demo(context, 'Outline action'),
              ),
              AppButton(
                label: 'Delete',
                style: AppButtonStyle.destructive,
                icon: Icons.delete_outline,
                onPressed: () => _demo(context, 'Destructive action'),
              ),
              const AppButton(label: 'Loading', loading: true),
              const AppButton(label: 'Disabled'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: ActionCard(
                icon: Icons.navigation_outlined,
                title: 'Navigate',
                subtitle: '12 min away',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: ActionCard(
                icon: Icons.login,
                title: 'Check in',
                subtitle: 'At site',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _Label('STATUS', 'Operational states'),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Status chips',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: IncidentStatus.values
                .map((s) => StatusChip(status: s))
                .toList(),
          ),
        ),
        const SizedBox(height: 24),
        const _Label('ASSIGNMENT', 'Incident card'),
        const SizedBox(height: 10),
        IncidentCard(incident: MockData.incidents[1], onAction: () {}),
        const SizedBox(height: 24),
        const _Label('FORM', 'Field inputs'),
        const SizedBox(height: 10),
        const SectionCard(
          title: 'Site details',
          child: Column(
            children: [
              AppTextField(
                label: 'Search incidents',
                hint: 'ID, site, or location',
                icon: Icons.search,
              ),
              SizedBox(height: 12),
              AppTextField(
                label: 'Access notes',
                hint: 'Add information for the next engineer',
                icon: Icons.edit_note,
                multiline: true,
              ),
              SizedBox(height: 12),
              AppTextField(
                label: 'Access type',
                hint: 'Select access type',
                icon: Icons.badge_outlined,
                suffix: Icons.expand_more,
              ),
              SizedBox(height: 12),
              AppTextField(
                label: 'Site ID',
                hint: 'CAI-CORE-014',
                icon: Icons.tag,
                enabled: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _Label('INFORMATION', 'Structured metadata'),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Assignment information',
          icon: Icons.info_outline,
          child: Column(
            children: [
              InfoRow(
                icon: Icons.cell_tower,
                label: 'Site ID',
                value: 'CAI-CORE-014',
              ),
              InfoRow(
                icon: Icons.schedule,
                label: 'Scheduled time',
                value: '10 Aug 2026 • 09:30 AM',
              ),
              InfoRow(
                icon: Icons.security,
                label: 'Access type',
                value: 'NOC approval required',
              ),
              InfoRow(
                icon: Icons.engineering,
                label: 'Engineer',
                value: MockData.engineer.name,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _Label('HISTORY', 'Timeline'),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Latest activity',
          child: Column(
            children: List.generate(
              MockData.timeline.length,
              (i) => TimelineItem(
                event: MockData.timeline[i],
                isLast: i == MockData.timeline.length - 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _Label('FILES', 'Attachments'),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Site evidence',
          action: const Icon(Icons.add_circle, color: AppColors.orange),
          child: Column(
            children: MockData.attachments
                .map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AttachmentCard(attachment: a),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 24),
        const _Label('CHECKLIST', 'Questionnaire'),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Safety & site check',
          child: Column(
            children: MockData.questions
                .map(
                  (q) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: QuestionnaireField(item: q),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 24),
        const _Label('EMPTY STATE', 'No pending items'),
        const SizedBox(height: 10),
        const Card(
          child: EmptyState(
            icon: Icons.task_alt,
            title: 'You’re all caught up',
            description:
                'New assignments will appear here when dispatched by the NOC.',
            actionLabel: 'Refresh',
          ),
        ),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'FOUNDATION 01',
            style: AppTypography.meta.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Built for the field.\nDesigned for clarity.',
          style: AppTypography.display.copyWith(
            color: Colors.white,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Access Log+ enterprise mobile design system',
          style: AppTypography.body.copyWith(color: Colors.white60),
        ),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.eyebrow, this.title);
  final String eyebrow, title;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: AppTypography.meta.copyWith(
          color: AppColors.orange,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 4),
      Text(title, style: AppTypography.title),
    ],
  );
}

void _demo(BuildContext context, String action) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$action • ${context.tr('prototype feedback', 'استجابة تجريبية')}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
