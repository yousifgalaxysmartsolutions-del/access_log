import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/error/failure.dart';
import '../../../../widgets/app_button.dart';
import '../../data/models/cap_form_models.dart';
import '../bloc/cap_form_cubit.dart';

/// Inject foreground capture without coupling form state to native plugins.
typedef CapFormCapture =
    Future<CapFormAnswer?> Function(CapFormQuestion question);

/// API-backed form. The caller owns/loads/closes the cubit and chooses FormId.
/// Confirm only returns answers; it never changes an incident or submits data.
class CapDynamicForm extends StatefulWidget {
  const CapDynamicForm({
    super.key,
    required this.cubit,
    required this.onConfirmed,
    required this.onRetry,
    this.capture,
    this.forSubmission = true,
    this.embedded = false,
  });
  final CapFormCubit cubit;
  final ValueChanged<List<CapFormAnswer>> onConfirmed;
  final VoidCallback onRetry;
  final CapFormCapture? capture;
  final bool forSubmission;

  /// Render the existing questions in a parent scroll view with one outer CTA.
  final bool embedded;
  @override
  State<CapDynamicForm> createState() => CapDynamicFormState();
}

class CapDynamicFormState extends State<CapDynamicForm> {
  CapFormCubit get cubit => widget.cubit;
  bool get embedded => widget.embedded;
  bool get forSubmission => widget.forSubmission;
  CapFormCapture? get capture => widget.capture;
  VoidCallback get onRetry => widget.onRetry;
  ValueChanged<List<CapFormAnswer>> get onConfirmed => widget.onConfirmed;
  final _anchors = <int, GlobalKey>{};
  final _focusNodes = <int, FocusNode>{};

  /// Uses the existing validator, then reveals the first visible invalid field.
  Future<bool> validateAndFocus() async {
    final answers = cubit.confirmedAnswers(forSubmission: forSubmission);
    if (answers != null) return true;
    final first = cubit.state.visibleQuestions
        .where((q) => cubit.state.errors.containsKey(q.id))
        .firstOrNull;
    if (first == null) return false;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return false;
    final target = _anchors[first.id]?.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.1,
        duration: const Duration(milliseconds: 250),
      );
      if (mounted) _focusNodes[first.id]?.requestFocus();
    }
    return false;
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<CapFormCubit, CapFormState>(
    bloc: cubit,
    builder: (context, state) {
      if (state.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (state.failure != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline),
                Text(state.failure!.message),
                AppButton(
                  label: context.tr('Retry', 'إعادة المحاولة'),
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        );
      }
      final form = state.form;
      if (form == null) {
        return Center(
          child: Text(context.tr('No form loaded', 'لم يتم تحميل نموذج')),
        );
      }
      final children = <Widget>[
        if (state.submitting) const LinearProgressIndicator(),
        if (state.submissionFailure case final failure?)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              failure is ServiceFailure &&
                      failure.code == 'form_evidence_contract'
                  ? context.tr(
                      'Evidence is saved in this form. Sending it awaits confirmation of the API encoding.',
                      'الإثبات محفوظ داخل النموذج. إرساله ينتظر تأكيد صيغة الـAPI.',
                    )
                  : failure.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Text(form.title, style: Theme.of(context).textTheme.headlineSmall),
        if (form.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              form.description.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
            ),
          ),
        if (form.questions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.tr(
                'This form has no questions',
                'هذا النموذج لا يحتوي على أسئلة',
              ),
            ),
          ),
        for (final question in state.visibleQuestions)
          Card(
            key: ValueKey('question-${form.id}-${question.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${question.title}${question.required ? ' *' : ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    question.required
                        ? context.tr('Required', 'مطلوب')
                        : context.tr('Optional', 'اختياري'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  AbsorbPointer(
                    key: _anchors.putIfAbsent(question.id, GlobalKey.new),
                    absorbing: state.submitting || state.submitted,
                    child: _QuestionInput(
                      key: ValueKey('${form.id}-${question.id}'),
                      question: question,
                      values: state.answers[question.id] ?? const [],
                      cubit: cubit,
                      capture: capture,
                      focusNode: _focusNodes.putIfAbsent(
                        question.id,
                        () => FocusNode(debugLabel: 'question-${question.id}'),
                      ),
                    ),
                  ),
                  if (state.errors[question.id] case final error?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error(context, error),
                        semanticsLabel: _error(context, error),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (!embedded) const SizedBox(height: 16),
        if (!embedded)
          AppButton(
            label: context.tr('Confirm', 'تأكيد'),
            loading: state.submitting,
            onPressed: state.submitted
                ? null
                : () async {
                    if (await validateAndFocus() && mounted) {
                      onConfirmed(
                        cubit.confirmedAnswers(forSubmission: forSubmission)!,
                      );
                    }
                  },
          ),
      ];
      return Material(
        color: Colors.transparent,
        child: embedded
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              )
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: children,
                ),
              ),
      );
    },
  );
  String _error(BuildContext context, CapFormError error) => switch (error) {
    CapFormError.required => context.tr(
      'Please complete this required field',
      'يرجى استكمال هذا الحقل المطلوب',
    ),
    CapFormError.invalid => context.tr(
      'Please enter a valid answer',
      'يرجى إدخال إجابة صحيحة',
    ),
    CapFormError.unsupported => context.tr(
      'This question type is not supported',
      'نوع السؤال غير مدعوم',
    ),
    CapFormError.multipleOptionsContract => context.tr(
      'Sending multiple choices awaits API contract confirmation',
      'إرسال اختيارات متعددة ينتظر تأكيد صيغة الـAPI',
    ),
  };
}

class _QuestionInput extends StatefulWidget {
  const _QuestionInput({
    super.key,
    required this.question,
    required this.values,
    required this.cubit,
    this.capture,
    required this.focusNode,
  });
  final CapFormQuestion question;
  final List<CapFormAnswer> values;
  final CapFormCubit cubit;
  final CapFormCapture? capture;
  final FocusNode focusNode;
  @override
  State<_QuestionInput> createState() => _QuestionInputState();
}

class _QuestionInputState extends State<_QuestionInput> {
  bool capturing = false;
  String? captureError;
  late final TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.values.firstOrNull?.text ?? '',
    );
  }

  @override
  void didUpdateWidget(_QuestionInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.values.firstOrNull?.text ?? '';
    if (value != controller.text) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> capture() async {
    if (capturing || widget.capture == null) return;
    setState(() {
      capturing = true;
      captureError = null;
    });
    try {
      final answer = await widget.capture!(widget.question);
      if (mounted && !widget.cubit.isClosed && answer != null) {
        widget.cubit.answer(widget.question.id, [answer]);
      }
    } catch (_) {
      if (mounted) {
        captureError = context.tr(
          'Capture failed. Check permissions and device services, or retry. Maximum evidence size: 16 MB.',
          'تعذّر الالتقاط. راجع الصلاحيات وخدمات الجهاز أو حاول مجددًا. أقصى حجم للإثبات: ١٦ ميجابايت.',
        );
      }
    } finally {
      if (mounted) setState(() => capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = buildInput(context);
    return switch (widget.question.type) {
      CapQuestionType.text ||
      CapQuestionType.number ||
      CapQuestionType.location ||
      CapQuestionType.qr ||
      CapQuestionType.barcode => input,
      _ => Focus(focusNode: widget.focusNode, child: input),
    };
  }

  Widget buildInput(BuildContext context) {
    final q = widget.question;
    final text = widget.values.firstOrNull?.text ?? '';
    switch (q.type) {
      case CapQuestionType.text:
      case CapQuestionType.number:
      case CapQuestionType.location:
      case CapQuestionType.qr:
      case CapQuestionType.barcode:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              focusNode: widget.focusNode,
              controller: controller,
              maxLines: q.type == CapQuestionType.text ? 3 : 1,
              textDirection: q.type == CapQuestionType.text
                  ? null
                  : TextDirection.ltr,
              keyboardType: q.type == CapQuestionType.number
                  ? const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    )
                  : TextInputType.text,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                helperText: q.type == CapQuestionType.location
                    ? context.tr(
                        'Manual coordinates: latitude, longitude (no GPS capture)',
                        'إحداثيات يدوية: خط العرض، خط الطول (بدون التقاط الموقع)',
                      )
                    : (q.type == CapQuestionType.qr ||
                          q.type == CapQuestionType.barcode)
                    ? context.tr('Enter code manually', 'أدخل الكود يدويًا')
                    : null,
                helperMaxLines: 4,
              ),
              onChanged: (value) => widget.cubit.text(q, value),
            ),
            if (captureError != null) Text(captureError!),
            if (widget.capture != null &&
                [
                  CapQuestionType.location,
                  CapQuestionType.qr,
                  CapQuestionType.barcode,
                ].contains(q.type))
              OutlinedButton.icon(
                onPressed: capturing ? null : capture,
                icon: Icon(
                  q.type == CapQuestionType.location
                      ? Icons.my_location
                      : Icons.qr_code_scanner,
                ),
                label: Text(
                  capturing
                      ? context.tr('Please wait', 'يرجى الانتظار')
                      : q.type == CapQuestionType.location
                      ? context.tr(
                          'Use current location',
                          'استخدام الموقع الحالي',
                        )
                      : context.tr('Scan code', 'مسح الكود'),
                ),
              ),
          ],
        );
      case CapQuestionType.singleChoice:
      case CapQuestionType.multiChoice:
        final selected = widget.values.map((a) => a.optionId).toSet();
        return Column(
          children: [
            if (q.options.isEmpty)
              Text(
                context.tr('No options available', 'لا توجد اختيارات متاحة'),
              ),
            for (final option in q.options)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option.label),
                value: selected.contains(option.id),
                checkboxShape: q.type == CapQuestionType.singleChoice
                    ? const CircleBorder()
                    : null,
                onChanged: (checked) {
                  final ids = q.type == CapQuestionType.singleChoice
                      ? <int>{}
                      : {...selected};
                  checked == true ? ids.add(option.id) : ids.remove(option.id);
                  widget.cubit.options(q, ids);
                },
              ),
          ],
        );
      case CapQuestionType.rating:
        return Wrap(
          spacing: 8,
          children: [
            for (var i = 0.5; i <= 5; i += 0.5)
              ChoiceChip(
                label: Text('$i'),
                selected: text == '$i',
                onSelected: (_) => widget.cubit.text(q, '$i'),
              ),
          ],
        );
      case CapQuestionType.dateTime:
        return OutlinedButton.icon(
          icon: const Icon(Icons.calendar_month),
          label: Text(
            text.isEmpty
                ? context.tr('Choose date and time', 'اختر التاريخ والوقت')
                : text,
          ),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(text) ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (time == null || !mounted || widget.cubit.isClosed) return;
            widget.cubit.text(
              q,
              DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              ).toIso8601String(),
            );
          },
        );
      case CapQuestionType.image:
      case CapQuestionType.video:
      case CapQuestionType.signature:
      case CapQuestionType.audio:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.values.firstOrNull?.evidence case final evidence?) ...[
              Text(
                '${evidence.name} • ${(evidence.bytes.length / 1024).ceil()} KB',
              ),
              if (evidence.mimeType.startsWith('image/'))
                GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: InteractiveViewer(
                              child: Image.memory(
                                evidence.bytes,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(context.tr('Close', 'إغلاق')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: Image.memory(
                    evidence.bytes,
                    height: 140,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
            ],
            if (widget.values.isNotEmpty)
              Text(context.tr('Evidence attached', 'تم إرفاق الإثبات')),
            if (widget.capture == null)
              Text(
                context.tr(
                  'Capture integration is not connected yet',
                  'لم يتم ربط التقاط الإثبات بعد',
                ),
              ),
            if (captureError != null) Text(captureError!),
            OutlinedButton.icon(
              icon: Icon(switch (q.type) {
                CapQuestionType.image => Icons.camera_alt_outlined,
                CapQuestionType.video => Icons.videocam_outlined,
                CapQuestionType.audio => Icons.mic_none,
                _ => Icons.draw_outlined,
              }),
              label: Text(
                capturing
                    ? context.tr('Please wait', 'يرجى الانتظار')
                    : context.tr('Add evidence', 'إضافة إثبات'),
              ),
              onPressed: widget.capture == null || capturing ? null : capture,
            ),
            if (widget.values.isNotEmpty)
              TextButton(
                onPressed: () => widget.cubit.answer(q.id, []),
                child: Text(context.tr('Remove', 'إزالة')),
              ),
          ],
        );
      case CapQuestionType.unsupported:
        return Text(
          context.tr(
            'Unsupported question type: ${q.typeId}',
            'نوع سؤال غير مدعوم: ${q.typeId}',
          ),
        );
    }
  }
}
