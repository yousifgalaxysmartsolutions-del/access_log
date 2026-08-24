import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';
import '../core/theme/app_tokens.dart';
import 'app_button.dart';

enum QuestionnairePreset {
  accept,
  reject,
  start,
  hold,
  complete,
  intervention,
  renewal,
  departure,
}

class DynamicQuestionnaireView extends StatefulWidget {
  const DynamicQuestionnaireView({
    super.key,
    this.preset = QuestionnairePreset.start,
  });

  final QuestionnairePreset preset;

  @override
  State<DynamicQuestionnaireView> createState() =>
      _DynamicQuestionnaireViewState();
}

class _DynamicQuestionnaireViewState extends State<DynamicQuestionnaireView> {
  int section = 0;
  bool damaged = false;
  bool safetyChecked = true;
  bool photoAdded = false;
  bool attachmentAdded = false;
  bool signed = false;
  DateTime inspectionDate = DateTime(2026, 8, 11);
  TimeOfDay inspectionTime = const TimeOfDay(hour: 10, minute: 30);
  String condition = 'Good';
  String equipmentStatus = 'Working';
  String singleChoice = 'Electrical';
  final Set<String> checks = {'PPE', 'Power isolated'};
  final Set<String> multiChoice = {'Cabinet', 'Power unit'};

  String _presetTitle(BuildContext context) => switch (widget.preset) {
    QuestionnairePreset.accept => context.tr(
      'Acceptance Questionnaire',
      'استبيان القبول',
    ),
    QuestionnairePreset.reject => context.tr(
      'Rejection Questionnaire',
      'استبيان الرفض',
    ),
    QuestionnairePreset.hold => context.tr(
      'Hold Questionnaire',
      'استبيان التعليق',
    ),
    QuestionnairePreset.complete => context.tr(
      'Completion Questionnaire',
      'استبيان الإكمال',
    ),
    QuestionnairePreset.intervention => context.tr(
      'Intervention Form',
      'نموذج التدخل',
    ),
    QuestionnairePreset.renewal => context.tr(
      'Renewal Questionnaire',
      'استبيان التجديد',
    ),
    QuestionnairePreset.departure => context.tr(
      'Departure Questionnaire',
      'استبيان المغادرة',
    ),
    QuestionnairePreset.start => context.tr(
      'Field Questionnaire',
      'الاستبيان الميداني',
    ),
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.dynamic_form_outlined,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_presetTitle(context), style: AppTypography.title),
                const SizedBox(height: 3),
                Text(
                  context.tr(
                    'Local mock form • Drafts stay on this device',
                    'نموذج محاكى محلي • تحفظ المسودة على هذا الجهاز',
                  ),
                  style: AppTypography.meta.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _QuestionProgress(current: section),
      const SizedBox(height: 18),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: section == 0
            ? _OperationalSection(
                key: const ValueKey('operational'),
                damaged: damaged,
                safetyChecked: safetyChecked,
                condition: condition,
                inspectionDate: inspectionDate,
                inspectionTime: inspectionTime,
                checks: checks,
                onDamaged: (value) => setState(() => damaged = value),
                onSafety: (value) => setState(() => safetyChecked = value),
                onCondition: (value) => setState(() => condition = value),
                onDate: () => _pickDate(context),
                onTime: () => _pickTime(context),
                onCheck: (value, selected) => setState(
                  () => selected ? checks.add(value) : checks.remove(value),
                ),
              )
            : _EvidenceSection(
                key: const ValueKey('evidence'),
                equipmentStatus: equipmentStatus,
                singleChoice: singleChoice,
                multiChoice: multiChoice,
                photoAdded: photoAdded,
                attachmentAdded: attachmentAdded,
                signed: signed,
                onStatus: (value) => setState(() => equipmentStatus = value),
                onSingleChoice: (value) => setState(() => singleChoice = value),
                onMultiChoice: (value, selected) => setState(
                  () => selected
                      ? multiChoice.add(value)
                      : multiChoice.remove(value),
                ),
                onPhoto: () => setState(() => photoAdded = !photoAdded),
                onAttachment: () =>
                    setState(() => attachmentAdded = !attachmentAdded),
                onSignature: () => setState(() => signed = !signed),
              ),
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Draft saved locally (mock)',
                'تم حفظ المسودة محليًا (محاكاة)',
              ),
            ),
          ),
        ),
        icon: const Icon(Icons.save_outlined),
        label: Text(context.tr('Save Draft', 'حفظ كمسودة')),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          if (section > 0) ...[
            Expanded(
              child: AppButton(
                label: context.tr('Previous', 'السابق'),
                icon: Icons.arrow_back,
                style: AppButtonStyle.outline,
                expanded: true,
                onPressed: () => setState(() => section--),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: section > 0 ? 2 : 1,
            child: AppButton(
              label: section == 0
                  ? context.tr('Continue', 'متابعة')
                  : context.tr('Questionnaire Ready', 'الاستبيان جاهز'),
              icon: section == 0 ? Icons.arrow_forward : Icons.check,
              expanded: true,
              onPressed: () {
                if (section == 0) {
                  setState(() => section = 1);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.tr(
                          'Questionnaire completed (mock)',
                          'تم إكمال الاستبيان (محاكاة)',
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    ],
  );

  Future<void> _pickDate(BuildContext context) async {
    final result = await showDatePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2027),
      initialDate: inspectionDate,
    );
    if (result != null) setState(() => inspectionDate = result);
  }

  Future<void> _pickTime(BuildContext context) async {
    final result = await showTimePicker(
      context: context,
      initialTime: inspectionTime,
    );
    if (result != null) setState(() => inspectionTime = result);
  }
}

class _QuestionProgress extends StatelessWidget {
  const _QuestionProgress({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              context.tr(
                'FORM STEP ${current + 1} OF 2',
                'خطوة النموذج ${current + 1} من 2',
              ),
              style: AppTypography.meta.copyWith(
                color: AppColors.orange,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              current == 0
                  ? context.tr('Operational details', 'البيانات التشغيلية')
                  : context.tr('Condition & evidence', 'الحالة والأدلة'),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.meta,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: (current + 1) / 2,
        minHeight: 6,
        borderRadius: BorderRadius.circular(8),
        color: AppColors.orange,
        backgroundColor: AppColors.border,
      ),
    ],
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      children: [
        Icon(icon, size: 19, color: AppColors.orange),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: AppTypography.section)),
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Expanded(child: Text(text, style: AppTypography.label)),
        Text(
          required
              ? context.tr('Required', 'مطلوب')
              : context.tr('Optional', 'اختياري'),
          style: AppTypography.meta.copyWith(
            color: required ? AppColors.error : AppColors.muted,
          ),
        ),
      ],
    ),
  );
}

class _OperationalSection extends StatelessWidget {
  const _OperationalSection({
    super.key,
    required this.damaged,
    required this.safetyChecked,
    required this.condition,
    required this.inspectionDate,
    required this.inspectionTime,
    required this.checks,
    required this.onDamaged,
    required this.onSafety,
    required this.onCondition,
    required this.onDate,
    required this.onTime,
    required this.onCheck,
  });

  final bool damaged, safetyChecked;
  final String condition;
  final DateTime inspectionDate;
  final TimeOfDay inspectionTime;
  final Set<String> checks;
  final ValueChanged<bool> onDamaged, onSafety;
  final ValueChanged<String> onCondition;
  final VoidCallback onDate, onTime;
  final void Function(String, bool) onCheck;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHeader(
        icon: Icons.engineering_outlined,
        title: context.tr('Operational Details', 'البيانات التشغيلية'),
      ),
      _FieldLabel(
        text: context.tr('Technician observation', 'ملاحظة الفني'),
        required: true,
      ),
      TextField(
        decoration: InputDecoration(
          hintText: context.tr(
            'Enter a short observation',
            'أدخل ملاحظة قصيرة',
          ),
          helperText: context.tr(
            'Use clear, field-service terminology.',
            'استخدم وصفًا ميدانيًا واضحًا.',
          ),
          prefixIcon: const Icon(Icons.short_text),
        ),
      ),
      const SizedBox(height: 14),
      _FieldLabel(text: context.tr('Detailed remarks', 'ملاحظات تفصيلية')),
      TextField(
        maxLines: 3,
        decoration: InputDecoration(
          hintText: context.tr(
            'Add supporting details',
            'أضف التفاصيل الداعمة',
          ),
          alignLabelWithHint: true,
          prefixIcon: const Icon(Icons.notes_outlined),
        ),
      ),
      const SizedBox(height: 14),
      _FieldLabel(
        text: context.tr('Measured voltage', 'الجهد المقاس'),
        required: true,
      ),
      TextField(
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: '220',
          suffixText: 'V',
          prefixIcon: const Icon(Icons.numbers),
          errorText: context.tr(
            'Enter a value between 180 and 250 V',
            'أدخل قيمة بين 180 و‏250 فولت',
          ),
        ),
      ),
      const SizedBox(height: 14),
      _FieldLabel(
        text: context.tr('Equipment condition', 'حالة المعدات'),
        required: true,
      ),
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: condition,
        decoration: const InputDecoration(prefixIcon: Icon(Icons.tune)),
        items: ['Good', 'Needs attention', 'Critical']
            .map(
              (value) => DropdownMenuItem(
                value: value,
                child: Text(switch (value) {
                  'Good' => context.tr('Good', 'جيدة'),
                  'Needs attention' => context.tr(
                    'Needs attention',
                    'تحتاج متابعة',
                  ),
                  _ => context.tr('Critical', 'حرجة'),
                }),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onCondition(value);
        },
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _PickerField(
              label: context.tr('Inspection date', 'تاريخ الفحص'),
              value:
                  '${inspectionDate.day}/${inspectionDate.month}/${inspectionDate.year}',
              icon: Icons.calendar_today_outlined,
              onTap: onDate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PickerField(
              label: context.tr('Inspection time', 'وقت الفحص'),
              value: inspectionTime.format(context),
              icon: Icons.schedule_outlined,
              onTap: onTime,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _SectionHeader(
        icon: Icons.health_and_safety_outlined,
        title: context.tr('Safety Checks', 'فحوصات السلامة'),
      ),
      _FieldLabel(
        text: context.tr('Completed safety checks', 'فحوصات السلامة المكتملة'),
        required: true,
      ),
      ...['PPE', 'Power isolated', 'Area secured'].map(
        (value) => CheckboxListTile(
          value: checks.contains(value),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(switch (value) {
            'PPE' => context.tr(
              'Personal protective equipment',
              'معدات الحماية الشخصية',
            ),
            'Power isolated' => context.tr('Power isolated', 'تم عزل الطاقة'),
            _ => context.tr('Work area secured', 'تم تأمين منطقة العمل'),
          }),
          onChanged: (selected) => onCheck(value, selected ?? false),
        ),
      ),
      const SizedBox(height: 8),
      _FieldLabel(
        text: context.tr('Was any equipment damaged?', 'هل تضررت أي معدات؟'),
        required: true,
      ),
      SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: true, label: Text(context.tr('Yes', 'نعم'))),
          ButtonSegment(value: false, label: Text(context.tr('No', 'لا'))),
        ],
        selected: {damaged},
        onSelectionChanged: (value) => onDamaged(value.first),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        child: damaged
            ? Padding(
                padding: const EdgeInsets.only(top: 14),
                child: TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr(
                      'Describe the damage *',
                      'صف الضرر *',
                    ),
                    helperText: context.tr(
                      'Include affected part and severity.',
                      'اذكر الجزء المتأثر ودرجة الضرر.',
                    ),
                    prefixIcon: const Icon(Icons.report_problem_outlined),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
      SwitchListTile(
        value: safetyChecked,
        contentPadding: EdgeInsets.zero,
        title: Text(
          context.tr('Site is safe to operate', 'الموقع آمن للتشغيل'),
        ),
        subtitle: Text(context.tr('Required confirmation', 'تأكيد مطلوب')),
        onChanged: onSafety,
      ),
    ],
  );
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({
    super.key,
    required this.equipmentStatus,
    required this.singleChoice,
    required this.multiChoice,
    required this.photoAdded,
    required this.attachmentAdded,
    required this.signed,
    required this.onStatus,
    required this.onSingleChoice,
    required this.onMultiChoice,
    required this.onPhoto,
    required this.onAttachment,
    required this.onSignature,
  });

  final String equipmentStatus, singleChoice;
  final Set<String> multiChoice;
  final bool photoAdded, attachmentAdded, signed;
  final ValueChanged<String> onStatus, onSingleChoice;
  final void Function(String, bool) onMultiChoice;
  final VoidCallback onPhoto, onAttachment, onSignature;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHeader(
        icon: Icons.settings_suggest_outlined,
        title: context.tr('Equipment Assessment', 'تقييم المعدات'),
      ),
      _FieldLabel(
        text: context.tr('Equipment Status', 'حالة المعدات'),
        required: true,
      ),
      RadioGroup<String>(
        groupValue: equipmentStatus,
        onChanged: (value) {
          if (value != null) onStatus(value);
        },
        child: Column(
          children: ['Working', 'Partially Working', 'Not Working']
              .map(
                (value) => RadioListTile<String>(
                  value: value,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(switch (value) {
                    'Working' => context.tr('Working', 'تعمل'),
                    'Partially Working' => context.tr(
                      'Partially Working',
                      'تعمل جزئيًا',
                    ),
                    _ => context.tr('Not Working', 'لا تعمل'),
                  }),
                ),
              )
              .toList(),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        child: equipmentStatus == 'Not Working'
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.tr('Failure Reason *', 'سبب العطل *'),
                      errorText: context.tr(
                        'Failure reason is required',
                        'سبب العطل مطلوب',
                      ),
                      prefixIcon: const Icon(Icons.build_circle_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MockUploadField(
                    icon: Icons.add_a_photo_outlined,
                    title: context.tr(
                      'Required failure photo',
                      'صورة العطل مطلوبة',
                    ),
                    subtitle: photoAdded
                        ? context.tr(
                            'failure_photo_01.jpg attached',
                            'تم إرفاق failure_photo_01.jpg',
                          )
                        : context.tr(
                            'Tap to add mock photo',
                            'اضغط لإضافة صورة محاكاة',
                          ),
                    complete: photoAdded,
                    onTap: onPhoto,
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
      const SizedBox(height: 16),
      _FieldLabel(
        text: context.tr('Primary fault category', 'تصنيف العطل الرئيسي'),
        required: true,
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ['Electrical', 'Mechanical', 'Network']
            .map(
              (value) => ChoiceChip(
                label: Text(switch (value) {
                  'Electrical' => context.tr('Electrical', 'كهربائي'),
                  'Mechanical' => context.tr('Mechanical', 'ميكانيكي'),
                  _ => context.tr('Network', 'شبكة'),
                }),
                selected: singleChoice == value,
                onSelected: (_) => onSingleChoice(value),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      _FieldLabel(
        text: context.tr('Components inspected', 'المكونات التي تم فحصها'),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ['Cabinet', 'Power unit', 'Antenna', 'Cables']
            .map(
              (value) => FilterChip(
                label: Text(switch (value) {
                  'Cabinet' => context.tr('Cabinet', 'الكابينة'),
                  'Power unit' => context.tr('Power unit', 'وحدة الطاقة'),
                  'Antenna' => context.tr('Antenna', 'الهوائي'),
                  _ => context.tr('Cables', 'الكابلات'),
                }),
                selected: multiChoice.contains(value),
                onSelected: (selected) => onMultiChoice(value, selected),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 18),
      _SectionHeader(
        icon: Icons.lock_outline,
        title: context.tr('System Information', 'بيانات النظام'),
      ),
      TextFormField(
        initialValue: 'INC-2026-1048',
        readOnly: true,
        decoration: InputDecoration(
          labelText: context.tr(
            'Incident Number • Read-only',
            'رقم البلاغ • للقراءة فقط',
          ),
          prefixIcon: const Icon(Icons.tag),
          helperText: context.tr(
            'Provided automatically by the incident.',
            'يتم تعبئته تلقائيًا من البلاغ.',
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        initialValue: context.tr(
          'Auto-calculated after completion',
          'يحسب تلقائيًا بعد الإكمال',
        ),
        enabled: false,
        decoration: InputDecoration(
          labelText: context.tr(
            'Resolution duration • Disabled',
            'مدة الحل • معطل',
          ),
          prefixIcon: const Icon(Icons.timer_outlined),
        ),
      ),
      const SizedBox(height: 18),
      _SectionHeader(
        icon: Icons.attach_file,
        title: context.tr('Evidence & Confirmation', 'الأدلة والتأكيد'),
      ),
      _MockUploadField(
        icon: Icons.add_a_photo_outlined,
        title: context.tr('Site overview photo', 'صورة عامة للموقع'),
        subtitle: photoAdded
            ? context.tr(
                'site_overview.jpg attached',
                'تم إرفاق site_overview.jpg',
              )
            : context.tr('Optional • JPG or PNG', 'اختياري • JPG أو PNG'),
        complete: photoAdded,
        onTap: onPhoto,
      ),
      const SizedBox(height: 10),
      _MockUploadField(
        icon: Icons.upload_file_outlined,
        title: context.tr('Supporting attachment', 'مرفق داعم'),
        subtitle: attachmentAdded
            ? context.tr(
                'inspection_sheet.pdf attached',
                'تم إرفاق inspection_sheet.pdf',
              )
            : context.tr(
                'Optional • PDF, DOC or image',
                'اختياري • PDF أو DOC أو صورة',
              ),
        complete: attachmentAdded,
        onTap: onAttachment,
      ),
      const SizedBox(height: 10),
      _MockUploadField(
        icon: Icons.draw_outlined,
        title: context.tr('Engineer signature', 'توقيع المهندس'),
        subtitle: signed
            ? context.tr('Mock signature captured', 'تم تسجيل التوقيع المحاكى')
            : context.tr('Tap to sign • Optional', 'اضغط للتوقيع • اختياري'),
        complete: signed,
        onTap: onSignature,
      ),
    ],
  );
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  final String label, value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.control),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      child: Text(value, overflow: TextOverflow.ellipsis),
    ),
  );
}

class _MockUploadField extends StatelessWidget {
  const _MockUploadField({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.complete,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.control),
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(
          color: complete ? AppColors.success : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: complete ? AppColors.success : AppColors.orange),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.label),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTypography.meta.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Icon(
            complete ? Icons.check_circle : Icons.add_circle_outline,
            color: complete ? AppColors.success : AppColors.muted,
          ),
        ],
      ),
    ),
  );
}
