import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/action_flow_components.dart';

enum TaskFlowType { start, hold, complete }

class AssignTaskFlow extends StatefulWidget {
  const AssignTaskFlow({super.key, required this.incident});
  final CapIncident incident;
  @override
  State<AssignTaskFlow> createState() => _AssignTaskFlowState();
}

class _AssignTaskFlowState extends State<AssignTaskFlow> {
  int step = 0;
  bool myself = true;
  String selected = MockData.engineer.name;
  final search = TextEditingController();
  static final members = MockData.teamMembers
      .map((member) => (member.name, member.role, member.area, member.initials))
      .toList(growable: false);

  CapIncidentStatus get resultStatus =>
      myself && MockData.autoApproveSelfAssignment
      ? CapIncidentStatus.pending
      : CapIncidentStatus.needApproval;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (step == 2) {
      return Scaffold(
        body: SafeArea(
          child: FlowSuccessView(
            title: context.tr('Assignment confirmed', 'تم تأكيد الإسناد'),
            message: context.tr(
              '${widget.incident.number} is assigned to $selected with status ${resultStatus.label}.',
              'تم إسناد البلاغ ${widget.incident.number} إلى $selected بحالة ${resultStatus.label}.',
            ),
            buttonLabel: context.tr('Return to Incident', 'العودة إلى البلاغ'),
            onDone: () => Navigator.pop(context, resultStatus),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Assign Task', 'إسناد المهمة'))),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: 0,
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  children: [
                    FlowPageHeading(
                      icon: Icons.person_add_alt,
                      title: context.tr(
                        'Who should handle this task?',
                        'من سينفذ هذه المهمة؟',
                      ),
                      subtitle: context.tr(
                        'Assign it to yourself or select an available team member.',
                        'أسندها لنفسك أو اختر أحد أعضاء الفريق المتاحين.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text(context.tr('Myself', 'نفسي')),
                          icon: const Icon(Icons.person),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text(context.tr('Team Member', 'عضو فريق')),
                          icon: const Icon(Icons.groups_outlined),
                        ),
                      ],
                      selected: {myself},
                      onSelectionChanged: (value) => setState(() {
                        myself = value.first;
                        selected = myself ? MockData.engineer.name : '';
                      }),
                    ),
                    const SizedBox(height: 18),
                    if (myself)
                      _EngineerTile(
                        member: members.first,
                        selected: true,
                        onTap: () => setState(() {
                          myself = true;
                          selected = MockData.engineer.name;
                        }),
                      )
                    else ...[
                      TextField(
                        controller: search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: context.tr(
                            'Search name, role, or area',
                            'ابحث بالاسم أو الدور أو المنطقة',
                          ),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...members
                          .where((member) {
                            final query = search.text.toLowerCase();
                            return query.isEmpty ||
                                member.$1.toLowerCase().contains(query) ||
                                member.$2.toLowerCase().contains(query) ||
                                member.$3.toLowerCase().contains(query);
                          })
                          .map(
                            (member) => Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: _EngineerTile(
                                member: member,
                                selected: selected == member.$1,
                                onTap: () =>
                                    setState(() => selected = member.$1),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
                _ConfirmationView(
                  title: context.tr('Confirm Assignment', 'تأكيد الإسناد'),
                  subtitle: context.tr(
                    'Review the task and selected engineer before assigning.',
                    'راجع المهمة والمهندس المختار قبل الإسناد.',
                  ),
                  rows: [
                    ('Incident', widget.incident.number),
                    ('Site', widget.incident.siteName),
                    ('Priority', widget.incident.priority.name.toUpperCase()),
                    ('Assign to', selected),
                    (
                      'Next status',
                      resultStatus == CapIncidentStatus.pending
                          ? 'Pending (Auto Approved)'
                          : 'Need Approval',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FlowNavigationBar(
        onBack: null,
        continueLabel: context.tr('Confirm Assignment', 'تأكيد الإسناد'),
        onContinue: () {
          if (!myself && selected.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr(
                    'Select an engineer to continue',
                    'اختر مهندسًا للمتابعة',
                  ),
                ),
              ),
            );
            return;
          }
          setState(() => step = 2);
        },
      ),
    );
  }
}

class AcceptIncidentFlow extends StatefulWidget {
  const AcceptIncidentFlow({super.key, required this.incident});
  final CapIncident incident;
  @override
  State<AcceptIncidentFlow> createState() => _AcceptIncidentFlowState();
}

class _AcceptIncidentFlowState extends State<AcceptIncidentFlow> {
  int step = 0;

  @override
  Widget build(BuildContext context) {
    if (step == 1) {
      return Scaffold(
        body: SafeArea(
          child: FlowSuccessView(
            title: context.tr(
              'Assignment approved',
              'تمت الموافقة على الإسناد',
            ),
            message: context.tr(
              'The assignment is approved and now waiting in Pending status.',
              'تمت الموافقة على الإسناد وأصبح البلاغ في حالة قيد الانتظار.',
            ),
            buttonLabel: context.tr('Return to Incident', 'العودة إلى البلاغ'),
            onDone: () => Navigator.pop(context, CapIncidentStatus.pending),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Approve Assignment', 'الموافقة على الإسناد')),
      ),
      body: Column(
        children: [
          Expanded(
            child: _ConfirmationView(
              title: context.tr('Confirm Approval', 'تأكيد الموافقة'),
              subtitle: context.tr(
                'This action changes the status from Need Approval to Pending.',
                'سيغير هذا الإجراء الحالة من بانتظار الموافقة إلى قيد الانتظار.',
              ),
              rows: [
                ('Incident', widget.incident.number),
                ('Site', widget.incident.siteName),
                ('Current Status', 'Need Approval'),
                ('Next Status', 'Pending'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FlowNavigationBar(
        onBack: null,
        continueLabel: context.tr('Approve', 'موافقة'),
        onContinue: () => setState(() => step = 1),
      ),
    );
  }
}

class RejectIncidentFlow extends StatefulWidget {
  const RejectIncidentFlow({super.key, required this.incident});
  final CapIncident incident;
  @override
  State<RejectIncidentFlow> createState() => _RejectIncidentFlowState();
}

class _RejectIncidentFlowState extends State<RejectIncidentFlow> {
  int step = 0;
  bool includeQuestionnaire = false;
  final remark = TextEditingController();
  bool showError = false;
  @override
  void dispose() {
    remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (step == 3) {
      return Scaffold(
        body: SafeArea(
          child: FlowSuccessView(
            title: context.tr('Rejection submitted', 'تم إرسال الرفض'),
            message: context.tr(
              'The incident has been returned to CAP dispatch with your remarks.',
              'تمت إعادة البلاغ إلى توزيع CAP مع ملاحظاتك.',
            ),
            buttonLabel: context.tr('Return to Incident', 'العودة إلى البلاغ'),
            onDone: () => Navigator.pop(context, CapIncidentStatus.needAssign),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Reject Incident', 'رفض البلاغ'))),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: 0,
              children: [
                ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    FlowPageHeading(
                      icon: Icons.cancel_outlined,
                      title: context.tr('Rejection Reason', 'سبب الرفض'),
                      subtitle: context.tr(
                        'A clear remark is required for dispatch and audit teams.',
                        'مطلوب توضيح واضح لفريقي التوزيع والمراجعة.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: remark,
                      maxLines: 5,
                      onChanged: (_) => setState(() => showError = false),
                      decoration: InputDecoration(
                        labelText: context.tr(
                          'Rejection Remark *',
                          'ملاحظة الرفض *',
                        ),
                        hintText: context.tr(
                          'Explain why you cannot accept this incident',
                          'وضح سبب عدم قدرتك على قبول البلاغ',
                        ),
                        alignLabelWithHint: true,
                        prefixIcon: const Icon(Icons.notes),
                        errorText: showError
                            ? context.tr(
                                'Rejection remark is required',
                                'ملاحظة الرفض مطلوبة',
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 13),
                    SwitchListTile(
                      value: includeQuestionnaire,
                      onChanged: (value) =>
                          setState(() => includeQuestionnaire = value),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      title: Text(
                        context.tr(
                          'Add rejection questionnaire',
                          'إضافة استبيان الرفض',
                        ),
                      ),
                      subtitle: Text(
                        context.tr(
                          'Optional mock step',
                          'خطوة محاكاة اختيارية',
                        ),
                      ),
                    ),
                    if (includeQuestionnaire) ...[
                      const SizedBox(height: 18),
                      _InlineActionSection(
                        number: 2,
                        title: context.tr(
                          'Rejection Questionnaire',
                          'استبيان الرفض',
                        ),
                        child: const DynamicQuestionnaireView(
                          preset: QuestionnairePreset.reject,
                        ),
                      ),
                    ],
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(18),
                  children: includeQuestionnaire
                      ? [
                          const DynamicQuestionnaireView(
                            preset: QuestionnairePreset.reject,
                          ),
                        ]
                      : [
                          FlowPageHeading(
                            icon: Icons.skip_next_outlined,
                            title: context.tr(
                              'Questionnaire skipped',
                              'تم تخطي الاستبيان',
                            ),
                            subtitle: context.tr(
                              'No optional questionnaire was requested.',
                              'لم يتم طلب الاستبيان الاختياري.',
                            ),
                          ),
                        ],
                ),
                _ConfirmationView(
                  title: context.tr('Confirm Rejection', 'تأكيد الرفض'),
                  subtitle: context.tr(
                    'Review the rejection details before submitting.',
                    'راجع تفاصيل الرفض قبل الإرسال.',
                  ),
                  rows: [
                    ('Incident', widget.incident.number),
                    ('Reason', remark.text),
                    (
                      'Questionnaire',
                      includeQuestionnaire ? 'Completed' : 'Skipped',
                    ),
                    ('Result', 'Return to CAP Dispatch'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FlowNavigationBar(
        onBack: null,
        continueLabel: context.tr('Confirm Rejection', 'تأكيد الرفض'),
        onContinue: () {
          if (remark.text.trim().isEmpty) {
            setState(() => showError = true);
            return;
          }
          setState(() => step = 3);
        },
      ),
    );
  }
}

class FieldTaskWizard extends StatefulWidget {
  const FieldTaskWizard({
    super.key,
    required this.incident,
    required this.type,
    this.initialStep = 0,
  });
  final CapIncident incident;
  final TaskFlowType type;
  final int initialStep;
  @override
  State<FieldTaskWizard> createState() => _FieldTaskWizardState();
}

class _FieldTaskWizardState extends State<FieldTaskWizard> {
  bool submitted = false;
  final holdReason = TextEditingController();
  bool reasonError = false;
  List<String> get labels => switch (widget.type) {
    TaskFlowType.start => [
      context.tr('Photos', 'الصور'),
      context.tr('Questionnaire', 'الاستبيان'),
      context.tr('Signature', 'التوقيع'),
    ],
    TaskFlowType.hold => [
      context.tr('Hold Reason', 'سبب التعليق'),
      context.tr('Photo', 'الصورة'),
      context.tr('Questionnaire', 'الاستبيان'),
    ],
    TaskFlowType.complete => [
      context.tr('Photos', 'الصور'),
      context.tr('Questionnaire', 'الاستبيان'),
      context.tr('Signature', 'التوقيع'),
      context.tr('Attachments', 'المرفقات'),
    ],
  };
  @override
  void dispose() {
    holdReason.dispose();
    super.dispose();
  }

  List<Widget> get pages => switch (widget.type) {
    TaskFlowType.start => [
      MockPhotoPicker(title: context.tr('Required Photos', 'الصور المطلوبة')),
      const DynamicQuestionnaireView(preset: QuestionnairePreset.start),
      const SignaturePadView(),
    ],
    TaskFlowType.hold => [
      _HoldReasonView(
        controller: holdReason,
        error: reasonError,
        onChanged: () => setState(() => reasonError = false),
      ),
      MockPhotoPicker(
        title: context.tr('Supporting Photo', 'صورة داعمة'),
        optional: true,
      ),
      const DynamicQuestionnaireView(preset: QuestionnairePreset.hold),
    ],
    TaskFlowType.complete => [
      MockPhotoPicker(title: context.tr('Completion Photos', 'صور الإكمال')),
      const DynamicQuestionnaireView(preset: QuestionnairePreset.complete),
      const SignaturePadView(),
      const AttachmentPickerView(),
    ],
  };

  String get title => switch (widget.type) {
    TaskFlowType.start => context.tr('Start Task', 'بدء المهمة'),
    TaskFlowType.hold => context.tr('Hold Task', 'تعليق المهمة'),
    TaskFlowType.complete => context.tr('Complete Task', 'إكمال المهمة'),
  };
  String get finalLabel => switch (widget.type) {
    TaskFlowType.start => context.tr('Start Intervention', 'بدء التدخل'),
    TaskFlowType.hold => context.tr('Put Task On Hold', 'تعليق المهمة'),
    TaskFlowType.complete => context.tr('Complete Task', 'إكمال المهمة'),
  };
  CapIncidentStatus get resultStatus => switch (widget.type) {
    TaskFlowType.start => CapIncidentStatus.inProcess,
    TaskFlowType.hold => CapIncidentStatus.hold,
    TaskFlowType.complete => CapIncidentStatus.completed,
  };

  @override
  Widget build(BuildContext context) {
    if (submitted) {
      final successTitle = switch (widget.type) {
        TaskFlowType.start => context.tr(
          'Intervention started',
          'تم بدء التدخل',
        ),
        TaskFlowType.hold => context.tr(
          'Task placed on hold',
          'تم تعليق المهمة',
        ),
        TaskFlowType.complete => context.tr(
          'Task completed',
          'تم إكمال المهمة',
        ),
      };
      return Scaffold(
        body: SafeArea(
          child: FlowSuccessView(
            title: successTitle,
            message: context.strings.isArabic
                ? 'تم تحديث ${widget.incident.number} بنجاح في مسار المحاكاة.'
                : '${widget.incident.number} was updated successfully in this simulated workflow.',
            buttonLabel: context.tr('Return to Incident', 'العودة إلى البلاغ'),
            onDone: () => Navigator.pop(context, resultStatus),
          ),
        ),
      );
    }
    final currentPages = pages;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: Center(
              child: Text(
                widget.incident.number,
                style: AppTypography.meta.copyWith(color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: currentPages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _InlineActionSection(
          number: index + 1,
          title: labels[index],
          child: currentPages[index],
        ),
      ),
      bottomNavigationBar: FlowNavigationBar(
        onBack: null,
        continueLabel: finalLabel,
        onContinue: () {
          if (widget.type == TaskFlowType.hold &&
              holdReason.text.trim().isEmpty) {
            setState(() => reasonError = true);
            return;
          }
          setState(() => submitted = true);
        },
      ),
    );
  }
}

class _HoldReasonView extends StatelessWidget {
  const _HoldReasonView({
    required this.controller,
    required this.error,
    required this.onChanged,
  });
  final TextEditingController controller;
  final bool error;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FlowPageHeading(
        icon: Icons.pause_circle_outline,
        title: context.tr('Hold Reason', 'سبب التعليق'),
        subtitle: context.tr(
          'Explain why field activity cannot continue. This information is required.',
          'وضح سبب تعذر استمرار النشاط الميداني. هذه المعلومة مطلوبة.',
        ),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        maxLines: 5,
        decoration: InputDecoration(
          labelText: context.tr('Hold Reason *', 'سبب التعليق *'),
          hintText: context.tr(
            'Describe the blocker, dependency, or required approval',
            'صف العائق أو الاعتماد أو الموافقة المطلوبة',
          ),
          alignLabelWithHint: true,
          prefixIcon: const Icon(Icons.notes),
          errorText: error
              ? context.tr('Hold reason is required', 'سبب التعليق مطلوب')
              : null,
        ),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: 'Awaiting spare part',
        decoration: InputDecoration(
          labelText: context.tr('Reason category', 'تصنيف السبب'),
          prefixIcon: const Icon(Icons.category_outlined),
        ),
        items:
            [
                  'Awaiting spare part',
                  'Access unavailable',
                  'Safety concern',
                  'Approval required',
                ]
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
        onChanged: (value) {
          if (value != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.strings.isArabic
                      ? 'تم اختيار: $value'
                      : 'Selected: $value',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    ],
  );
}

class _InlineActionSection extends StatelessWidget {
  const _InlineActionSection({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: AppTypography.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: AppTypography.section)),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({
    required this.title,
    required this.subtitle,
    required this.rows,
  });
  final String title, subtitle;
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      FlowPageHeading(
        icon: Icons.verified_user_outlined,
        title: title,
        subtitle: subtitle,
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: rows
              .map(
                (row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          row.$1,
                          style: AppTypography.meta.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          row.$2,
                          textAlign: TextAlign.end,
                          style: AppTypography.label,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppColors.info, size: 20),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'This is a simulated prototype action. No server data will be changed.',
                style: AppTypography.meta,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _EngineerTile extends StatelessWidget {
  const _EngineerTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });
  final (String, String, String, String) member;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
      side: BorderSide(
        color: selected ? AppColors.orange : AppColors.border,
        width: selected ? 1.5 : 1,
      ),
    ),
    tileColor: selected
        ? AppColors.orange.withValues(alpha: .05)
        : Theme.of(context).cardColor,
    leading: CircleAvatar(
      backgroundColor: selected ? AppColors.orange : const Color(0xFFF0F0ED),
      child: Text(
        member.$4,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    title: Text(member.$1, style: AppTypography.label),
    subtitle: Text(
      '${member.$2} • ${member.$3}',
      style: AppTypography.meta.copyWith(color: AppColors.muted),
    ),
    trailing: Icon(
      selected ? Icons.check_circle : Icons.circle_outlined,
      color: selected ? AppColors.orange : AppColors.muted,
    ),
  );
}
