import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/action_flow_components.dart';

class NewRequestTypeScreen extends StatelessWidget {
  const NewRequestTypeScreen({
    super.key,
    required this.incident,
    this.allowedTypes = RelatedRequestType.values,
  });
  final CapIncident incident;
  final List<RelatedRequestType> allowedTypes;

  Future<void> _open(BuildContext context, RelatedRequestType type) async {
    final request = await Navigator.push<RelatedRequest>(
      context,
      MaterialPageRoute(
        builder: (_) => NewRequestWizard(incident: incident, type: type),
      ),
    );
    if (request != null && context.mounted) Navigator.pop(context, request);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('New Request', 'طلب جديد'))),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        Text(
          context.tr('Choose request type', 'اختر نوع الطلب'),
          style: AppTypography.display,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'Create a request linked to ${incident.number}.',
            'أنشئ طلبًا مرتبطًا بالبلاغ ${incident.number}.',
          ),
          style: AppTypography.body.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        if (allowedTypes.contains(RelatedRequestType.intervention))
          _RequestTypeCard(
            icon: Icons.build_circle_outlined,
            title: context.tr('Intervention Request', 'طلب تدخل'),
            description: context.tr(
              'Request permission to begin a controlled field intervention.',
              'اطلب تصريحًا لبدء تدخل ميداني منظم.',
            ),
            color: AppColors.orange,
            onTap: () => _open(context, RelatedRequestType.intervention),
          ),
        if (allowedTypes.contains(RelatedRequestType.renewal)) ...[
          const SizedBox(height: 12),
          _RequestTypeCard(
            icon: Icons.autorenew,
            title: context.tr('Renewal Request', 'طلب تجديد'),
            description: context.tr(
              'Extend the approved work window for an active intervention.',
              'مدد نافذة العمل المعتمدة لتدخل نشط.',
            ),
            color: AppColors.info,
            badge: context.tr('ACTIVE INTERVENTION', 'تدخل نشط'),
            onTap: () => _open(context, RelatedRequestType.renewal),
          ),
        ],
        if (allowedTypes.contains(RelatedRequestType.departure)) ...[
          const SizedBox(height: 12),
          _RequestTypeCard(
            icon: Icons.logout,
            title: context.tr('Departure Request', 'طلب مغادرة'),
            description: context.tr(
              'Confirm completed site activity and request departure clearance.',
              'أكد اكتمال نشاط الموقع واطلب تصريح المغادرة.',
            ),
            color: AppColors.success,
            onTap: () => _open(context, RelatedRequestType.departure),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: AppColors.info, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.tr(
                    'All validation, GPS, camera, and submission states are simulated.',
                    'جميع حالات التحقق والموقع والكاميرا والإرسال محاكاة فقط.',
                  ),
                  style: AppTypography.meta,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RequestTypeCard extends StatelessWidget {
  const _RequestTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final String title, description;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: AppTypography.meta.copyWith(
                          color: AppColors.success,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                  ],
                  Text(title, style: AppTypography.section),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: AppTypography.body.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.arrow_back
                    : Icons.arrow_forward,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NewRequestWizard extends StatefulWidget {
  const NewRequestWizard({
    super.key,
    required this.incident,
    required this.type,
  });
  final CapIncident incident;
  final RelatedRequestType type;
  @override
  State<NewRequestWizard> createState() => _NewRequestWizardState();
}

class _NewRequestWizardState extends State<NewRequestWizard> {
  bool submitted = false;
  bool departurePhotoRequired = false;

  List<String> get labels => switch (widget.type) {
    RelatedRequestType.intervention => [
      context.tr('Form', 'النموذج'),
      context.tr('Attachments', 'المرفقات'),
    ],
    RelatedRequestType.renewal => [
      context.tr('Intervention', 'التدخل'),
      context.tr('Questionnaire', 'الاستبيان'),
    ],
    RelatedRequestType.departure => [
      context.tr('Serial', 'الرقم المسلسل'),
      context.tr('Questionnaire', 'الاستبيان'),
      context.tr('Photo', 'الصورة'),
    ],
  };

  String get title => switch (widget.type) {
    RelatedRequestType.intervention => context.tr(
      'Intervention Request',
      'طلب تدخل',
    ),
    RelatedRequestType.renewal => context.tr('Renewal Request', 'طلب تجديد'),
    RelatedRequestType.departure => context.tr(
      'Departure Request',
      'طلب مغادرة',
    ),
  };

  String get prefix => switch (widget.type) {
    RelatedRequestType.intervention => 'INT',
    RelatedRequestType.renewal => 'REN',
    RelatedRequestType.departure => 'DEP',
  };

  List<Widget> get pages => switch (widget.type) {
    RelatedRequestType.intervention => [
      const DynamicQuestionnaireView(preset: QuestionnairePreset.intervention),
      const AttachmentPickerView(),
    ],
    RelatedRequestType.renewal => [
      _ActiveInterventionInfo(incident: widget.incident),
      const DynamicQuestionnaireView(preset: QuestionnairePreset.renewal),
    ],
    RelatedRequestType.departure => [
      const _SerialNumberValidation(),
      const DynamicQuestionnaireView(preset: QuestionnairePreset.departure),
      _DeparturePhoto(
        required: departurePhotoRequired,
        onChanged: (value) => setState(() => departurePhotoRequired = value),
      ),
    ],
  };

  RelatedRequest _result() => RelatedRequest(
    number:
        '$prefix-260810-${(100 + DateTime.now().millisecond % 899).toString().padLeft(4, '0')}',
    type: widget.type,
    status: 'Pending Approval',
    dateTime: DateTime(2026, 8, 10, 12, 35),
    createdBy: MockData.engineer.name,
  );

  @override
  Widget build(BuildContext context) {
    if (submitted) {
      return Scaffold(
        body: SafeArea(
          child: FlowSuccessView(
            title: context.tr('Request submitted', 'تم إرسال الطلب'),
            message: context.tr(
              '$title was created successfully and linked to the incident.',
              'تم إنشاء $title بنجاح وربطه بالبلاغ.',
            ),
            buttonLabel: context.tr(
              'View Related Requests',
              'عرض الطلبات المرتبطة',
            ),
            onDone: () => Navigator.pop(context, _result()),
          ),
        ),
      );
    }
    final flowPages = pages;
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
        itemCount: flowPages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _RequestFormSection(
          number: index + 1,
          title: labels[index],
          child: flowPages[index],
        ),
      ),
      bottomNavigationBar: FlowNavigationBar(
        onBack: null,
        continueLabel: context.tr('Confirm Request', 'تأكيد الطلب'),
        onContinue: () => setState(() => submitted = true),
      ),
    );
  }
}

class _RequestFormSection extends StatelessWidget {
  const _RequestFormSection({
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

class _ActiveInterventionInfo extends StatelessWidget {
  const _ActiveInterventionInfo({required this.incident});
  final CapIncident incident;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FlowPageHeading(
        icon: Icons.play_circle_outline,
        title: context.tr('Current Intervention', 'التدخل الحالي'),
        subtitle: context.tr(
          'Renewal is available because this incident has an active intervention.',
          'التجديد متاح لأن هذا البلاغ يحتوي على تدخل نشط.',
        ),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    MockData.activeInterventionNumber,
                    style: AppTypography.section.copyWith(color: Colors.white),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    context.tr('ACTIVE', 'نشط'),
                    style: AppTypography.meta.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              incident.title,
              style: AppTypography.label.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Approved window: 09:30 AM – 11:30 AM',
                'النافذة المعتمدة: 09:30 ص – 11:30 ص',
              ),
              style: AppTypography.meta.copyWith(color: Colors.white60),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SerialNumberValidation extends StatelessWidget {
  const _SerialNumberValidation();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FlowPageHeading(
        icon: Icons.confirmation_number_outlined,
        title: context.tr('Confirmation Serial Number', 'رقم التأكيد المسلسل'),
        subtitle: context.tr(
          'Enter the mock serial supplied by site security or NOC.',
          'أدخل الرقم المسلسل المحاكى المقدم من أمن الموقع أو NOC.',
        ),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: TextEditingController(
          text: MockData.confirmationSerialNumber,
        ),
        decoration: InputDecoration(
          labelText: context.tr('Serial Number *', 'الرقم المسلسل *'),
          prefixIcon: const Icon(Icons.qr_code),
          suffixIcon: const Icon(Icons.check_circle, color: AppColors.success),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        context.tr(
          'Serial validated successfully (mock state).',
          'تم التحقق من الرقم بنجاح (حالة محاكاة).',
        ),
        style: AppTypography.meta.copyWith(color: AppColors.success),
      ),
    ],
  );
}

class _DeparturePhoto extends StatelessWidget {
  const _DeparturePhoto({required this.required, required this.onChanged});
  final bool required;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FlowPageHeading(
        icon: Icons.photo_camera_outlined,
        title: context.tr('Departure Photo', 'صورة المغادرة'),
        subtitle: context.tr(
          'This requirement is configurable for each incident type.',
          'هذا المتطلب قابل للضبط حسب نوع البلاغ.',
        ),
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        value: required,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          context.tr(
            'Photo required by configuration',
            'الصورة مطلوبة حسب الإعداد',
          ),
        ),
        subtitle: Text(
          required
              ? context.tr(
                  'A simulated photo must be attached.',
                  'يجب إرفاق صورة محاكاة.',
                )
              : context.tr(
                  'Photo is optional for this departure.',
                  'الصورة اختيارية لهذه المغادرة.',
                ),
        ),
      ),
      const SizedBox(height: 14),
      MockPhotoPicker(
        title: context.tr('Departure Evidence', 'دليل المغادرة'),
        optional: !required,
      ),
    ],
  );
}
