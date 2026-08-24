import 'dart:async';

import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';
import '../core/localization/mock_content_localization.dart';
import '../core/theme/app_tokens.dart';
import '../models/models.dart';
import '../screens/incidents/incident_list_screen.dart';
import '../widgets/dynamic_questionnaire.dart';
import '../widgets/evidence_collection.dart';
import 'ai_copilot_controller.dart';
import 'ai_copilot_models.dart';
import 'ai_copilot_prompts.dart';
import 'ai_copilot_service.dart';

class AiCopilotScreen extends StatefulWidget {
  const AiCopilotScreen({super.key, required this.incident, this.client});

  final CapIncident incident;
  final AiCopilotClient? client;

  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  late final AiCopilotController controller = AiCopilotController(
    incident: widget.incident,
    client: widget.client ?? AiCopilotService.fromEnvironment(),
  );
  final input = TextEditingController();
  final scroll = ScrollController();
  bool listening = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_updated);
  }

  @override
  void dispose() {
    controller.removeListener(_updated);
    controller.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _updated() {
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  void _scrollToLatest() {
    if (!scroll.hasClients) return;
    scroll.animateTo(
      scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send([String? prompt]) async {
    final text = prompt ?? input.text;
    if (text.trim().isEmpty || controller.loading) return;
    input.clear();
    await controller.send(text);
  }

  Future<void> _simulateVoice() async {
    if (controller.loading || listening) return;
    setState(() => listening = true);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    setState(() => listening = false);
    await _send(context.tr('What should I do next?', 'ما الخطوة التالية؟'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('AI Field Copilot', 'مساعد المهندس الذكي'),
            style: AppTypography.section,
          ),
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 11, color: AppColors.orange),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  context.tr('Powered by AI', 'مدعوم بالذكاء الاصطناعي'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.orangeDark,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: _ModeBadge(mode: controller.client.mode),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              children: [
                _IncidentContextCard(incident: widget.incident),
                const SizedBox(height: 12),
                CompletionReadinessCard(readiness: controller.readiness),
                const SizedBox(height: 14),
                Text(
                  context.tr('Suggested prompts', 'أسئلة مقترحة'),
                  style: AppTypography.label,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: AiCopilotPrompts.suggested
                        .map(
                          (prompt) => Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ActionChip(
                              avatar: const Icon(Icons.auto_awesome, size: 15),
                              label: Text(_promptLabel(context, prompt)),
                              onPressed: controller.loading
                                  ? null
                                  : () => _send(_promptLabel(context, prompt)),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 17),
                ...controller.messages.map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _MessageBubble(
                      message: message,
                      onRetry: controller.retry,
                      onAction: _openAction,
                    ),
                  ),
                ),
                if (controller.loading) const _ThinkingCard(),
                if (listening) const _ListeningCard(),
              ],
            ),
          ),
          _Composer(
            controller: input,
            enabled: !controller.loading && !listening,
            listening: listening,
            onSend: _send,
            onMic: _simulateVoice,
          ),
        ],
      ),
    ),
  );

  void _openAction(AiLocalAction action) {
    final page = switch (action) {
      AiLocalAction.continueQuestionnaire => _ToolScreen(
        title: context.tr('Questionnaire', 'الاستبيان'),
        child: const DynamicQuestionnaireView(
          preset: QuestionnairePreset.complete,
        ),
      ),
      AiLocalAction.captureSignature => _ToolScreen(
        title: context.tr('Signature', 'التوقيع'),
        child: const SignaturePadView(),
      ),
      AiLocalAction.addAttachment => _ToolScreen(
        title: context.tr('Attachments', 'المرفقات'),
        child: const AttachmentPickerView(),
      ),
      AiLocalAction.viewSimilarIncidents => IncidentListScreen(
        initialFilter: IncidentListFilter(type: widget.incident.type),
      ),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class CompletionReadinessCard extends StatelessWidget {
  const CompletionReadinessCard({super.key, required this.readiness});
  final CompletionReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final photoComplete = readiness.photosAttached >= readiness.requiredPhotos;
    final rows = [
      (
        context.tr('Location', 'الموقع'),
        context.tr('Verified', 'تم التحقق'),
        readiness.locationVerified,
      ),
      (
        context.tr('Photos', 'الصور'),
        '${readiness.photosAttached} / ${readiness.requiredPhotos}',
        photoComplete,
      ),
      (
        context.tr('Questionnaire', 'الاستبيان'),
        context.tr('Completed', 'مكتمل'),
        readiness.questionnaireCompleted,
      ),
      (
        context.tr('Signature', 'التوقيع'),
        readiness.signatureCaptured
            ? context.tr('Captured', 'تم الالتقاط')
            : context.tr('Required', 'مطلوب'),
        readiness.signatureCaptured,
      ),
      (
        context.tr('Attachments', 'المرفقات'),
        readiness.attachmentsAdded
            ? context.tr('Added', 'تمت الإضافة')
            : context.tr('Required', 'مطلوبة'),
        readiness.attachmentsAdded,
      ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.fact_check_outlined, color: AppColors.orange),
        title: Text(
          context.tr('Completion Readiness', 'جاهزية الإكمال'),
          style: AppTypography.section,
        ),
        subtitle: Text(
          context.strings.isArabic
              ? '${readiness.remaining} متطلبات متبقية'
              : '${readiness.remaining} requirements remaining',
          style: AppTypography.meta.copyWith(
            color: readiness.remaining == 0
                ? AppColors.success
                : AppColors.warning,
          ),
        ),
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Icon(
                      row.$3 ? Icons.check_circle : Icons.cancel_outlined,
                      size: 19,
                      color: row.$3 ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(row.$1, style: AppTypography.label)),
                    Text(
                      row.$2,
                      style: AppTypography.meta.copyWith(
                        color: row.$3 ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _IncidentContextCard extends StatelessWidget {
  const _IncidentContextCard({required this.incident});
  final CapIncident incident;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.auto_awesome, color: AppColors.ink),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                incident.number,
                style: AppTypography.label.copyWith(color: AppColors.orange),
              ),
              Text(
                '${context.mockText(incident.siteName)} • ${_priority(context, incident.priority)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.meta.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            context.tr('Context ready', 'السياق جاهز'),
            style: AppTypography.meta.copyWith(color: AppColors.success),
          ),
        ),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onRetry,
    required this.onAction,
  });
  final AiChatMessage message;
  final VoidCallback onRetry;
  final ValueChanged<AiLocalAction> onAction;

  @override
  Widget build(BuildContext context) {
    final user = message.role == AiChatRole.user;
    final content =
        context.strings.isArabic &&
            message.content.startsWith('I am ready to help')
        ? 'أنا جاهز لمساعدتك في هذا البلاغ. اسألني عن الخطوة التالية أو الأدلة الناقصة أو اطلب إرشادات لحل المشكلة.'
        : message.content;
    return Align(
      alignment: user
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!user) ...[
              const CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.ink,
                child: Icon(
                  Icons.auto_awesome,
                  size: 17,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: user
                      ? AppColors.orange
                      : message.isError
                      ? AppColors.error.withValues(alpha: .07)
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadiusDirectional.only(
                    topStart: Radius.circular(user ? 16 : 4),
                    topEnd: Radius.circular(user ? 4 : 16),
                    bottomStart: const Radius.circular(16),
                    bottomEnd: const Radius.circular(16),
                  ),
                  border: user
                      ? null
                      : Border.all(
                          color: message.isError
                              ? AppColors.error.withValues(alpha: .25)
                              : AppColors.border,
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isTroubleshooting) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.health_and_safety_outlined,
                            size: 17,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              context.tr(
                                'Suggested Guidance',
                                'إرشادات مقترحة',
                              ),
                              style: AppTypography.label.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    SelectableText(content, style: AppTypography.body),
                    if (message.isTroubleshooting) ...[
                      const SizedBox(height: 9),
                      Text(
                        context.tr(
                          'AI-generated guidance — verify according to site procedures.',
                          'إرشادات مولدة بالذكاء الاصطناعي — تحقق منها وفق إجراءات الموقع.',
                        ),
                        style: AppTypography.meta.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                    if (message.isError) ...[
                      const SizedBox(height: 9),
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 17),
                        label: Text(context.tr('Retry', 'إعادة المحاولة')),
                      ),
                    ],
                    if (message.actions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: message.actions
                            .map(
                              (action) => OutlinedButton.icon(
                                onPressed: () => onAction(action),
                                icon: Icon(_actionIcon(action), size: 17),
                                label: Text(_actionLabel(context, action)),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingCard extends StatefulWidget {
  const _ThinkingCard();
  @override
  State<_ThinkingCard> createState() => _ThinkingCardState();
}

class _ThinkingCardState extends State<_ThinkingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();
  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const CircleAvatar(
        radius: 17,
        backgroundColor: AppColors.ink,
        child: Icon(Icons.auto_awesome, size: 17, color: AppColors.orange),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: animation,
              child: const Icon(
                Icons.auto_awesome,
                size: 18,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.tr('Analyzing incident…', 'جارٍ تحليل البلاغ…'),
              style: AppTypography.label,
            ),
          ],
        ),
      ),
    ],
  );
}

class _ListeningCard extends StatelessWidget {
  const _ListeningCard();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.info.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.mic, color: AppColors.info),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            context.tr('Listening… (simulated)', 'جارٍ الاستماع… (محاكاة)'),
            style: AppTypography.label,
          ),
        ),
      ],
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.listening,
    required this.onSend,
    required this.onMic,
  });
  final TextEditingController controller;
  final bool enabled, listening;
  final VoidCallback onSend, onMic;
  @override
  Widget build(BuildContext context) => Material(
    elevation: 12,
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton.filledTonal(
              tooltip: context.tr('Simulated voice input', 'إدخال صوتي محاكى'),
              onPressed: enabled ? onMic : null,
              icon: Icon(listening ? Icons.graphic_eq : Icons.mic_none),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: context.tr(
                    'Ask about this incident…',
                    'اسأل عن هذا البلاغ…',
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: context.tr('Send message', 'إرسال الرسالة'),
              onPressed: enabled ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: AppColors.ink,
              ),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});
  final AiCopilotMode mode;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.orange.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      mode == AiCopilotMode.groq ? 'GROQ' : 'MOCK',
      style: AppTypography.meta.copyWith(
        color: AppColors.orangeDark,
        fontWeight: FontWeight.w800,
        fontSize: 9,
      ),
    ),
  );
}

class _ToolScreen extends StatelessWidget {
  const _ToolScreen({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: child,
    ),
  );
}

String _promptLabel(BuildContext context, String prompt) => switch (prompt) {
  'What should I do next?' => context.tr(prompt, 'ما الخطوة التالية؟'),
  'Summarize this incident' => context.tr(prompt, 'لخص هذا البلاغ'),
  'What is missing before completion?' => context.tr(
    prompt,
    'ما الناقص قبل الإكمال؟',
  ),
  'Show required evidence' => context.tr(prompt, 'اعرض الأدلة المطلوبة'),
  'Help me troubleshoot' => context.tr(prompt, 'ساعدني في حل المشكلة'),
  'Explain site history' => context.tr(prompt, 'اشرح سجل الموقع'),
  _ => prompt,
};

String _actionLabel(BuildContext context, AiLocalAction action) =>
    switch (action) {
      AiLocalAction.continueQuestionnaire => context.tr(
        'Continue Questionnaire',
        'متابعة الاستبيان',
      ),
      AiLocalAction.captureSignature => context.tr(
        'Capture Signature',
        'التقاط التوقيع',
      ),
      AiLocalAction.addAttachment => context.tr('Add Attachment', 'إضافة مرفق'),
      AiLocalAction.viewSimilarIncidents => context.tr(
        'View Similar Incidents',
        'عرض البلاغات المشابهة',
      ),
    };

IconData _actionIcon(AiLocalAction action) => switch (action) {
  AiLocalAction.continueQuestionnaire => Icons.fact_check_outlined,
  AiLocalAction.captureSignature => Icons.draw_outlined,
  AiLocalAction.addAttachment => Icons.attach_file,
  AiLocalAction.viewSimilarIncidents => Icons.history,
};

String _priority(BuildContext context, Priority priority) => switch (priority) {
  Priority.critical => context.tr('Critical Priority', 'أولوية حرجة'),
  Priority.high => context.tr('High Priority', 'أولوية عالية'),
  Priority.medium => context.tr('Medium Priority', 'أولوية متوسطة'),
  Priority.low => context.tr('Low Priority', 'أولوية منخفضة'),
};
