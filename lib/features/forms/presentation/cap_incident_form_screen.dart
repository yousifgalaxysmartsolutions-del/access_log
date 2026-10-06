import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/localization/app_strings.dart';
import '../../../widgets/app_button.dart';
import '../data/models/cap_form_models.dart';
import 'bloc/cap_form_cubit.dart';
import 'widgets/cap_dynamic_form.dart';
import 'widgets/cap_form_capture.dart';

/// Ready-to-use route; opening location/FormId is deliberately caller-owned.
/// Await `Navigator.push<bool>(...)` and reload incident details only on true.
class CapIncidentFormScreen extends StatefulWidget {
  const CapIncidentFormScreen({
    super.key,
    required this.formId,
    required this.incidentId,
    required this.newStatusId,
    required this.actionTypeId,
    this.requireRemark = false,
    this.encodeAnswers,
    this.cubit,
    this.capture,
  });
  final int formId, incidentId, newStatusId, actionTypeId;
  final bool requireRemark;
  final List<CapFormAnswer> Function(List<CapFormAnswer>)? encodeAnswers;

  /// Tests/hosts may inject their own instance; otherwise the route owns one.
  final CapFormCubit? cubit;
  final CapFormCapture? capture;
  @override
  State<CapIncidentFormScreen> createState() => _CapIncidentFormScreenState();
}

class _CapIncidentFormScreenState extends State<CapIncidentFormScreen> {
  late final CapFormCubit cubit;
  final remark = TextEditingController();
  final remarkForm = GlobalKey<FormState>();
  final native = CapNativeFormCapture();
  bool allowPop = false, leaving = false;
  Future<void> leave(bool? result) async {
    if (!mounted) return;
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, result);
  }

  @override
  void initState() {
    super.initState();
    cubit = widget.cubit ?? services<CapFormCubit>();
    cubit.load(widget.formId);
  }

  @override
  void dispose() {
    if (widget.cubit == null) cubit.close();
    remark.dispose();
    super.dispose();
  }

  Future<bool> discard() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('Discard form?', 'تجاهل النموذج؟')),
          content: Text(
            context.tr(
              'Your unsent answers will be lost.',
              'سيتم فقدان الإجابات التي لم تُرسل.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Keep editing', 'متابعة التعديل')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('Discard', 'تجاهل')),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) => BlocBuilder<CapFormCubit, CapFormState>(
    bloc: cubit,
    builder: (context, state) => PopScope(
      canPop:
          allowPop ||
          (!state.submitting &&
              !state.submitted &&
              state.answers.isEmpty &&
              remark.text.isEmpty),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || state.submitting || leaving) return;
        leaving = true;
        try {
          if (state.submitted) {
            await leave(true);
          } else if (await discard()) {
            await leave(false);
          }
        } finally {
          leaving = false;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Incident form', 'نموذج البلاغ')),
        ),
        body: state.submitted
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 64),
                      Text(
                        context.tr(
                          'Submitted successfully',
                          'تم الإرسال بنجاح',
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: context.tr(
                          'Back to incident',
                          'العودة إلى البلاغ',
                        ),
                        onPressed: () => leave(true),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  // Scrolls with the keyboard and remains compact at large text sizes.
                  if (!state.loading && state.form != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Form(
                        key: remarkForm,
                        child: TextFormField(
                          controller: remark,
                          enabled: !state.submitting,
                          minLines: 1,
                          maxLines: 2,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: widget.requireRemark
                                ? context.tr('Remark *', 'الملاحظة *')
                                : context.tr(
                                    'Remark (optional)',
                                    'الملاحظة (اختياري)',
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              widget.requireRemark &&
                                  (value?.trim().isEmpty ?? true)
                              ? context.tr(
                                  'Please enter a remark',
                                  'يرجى إدخال الملاحظة',
                                )
                              : null,
                        ),
                      ),
                    ),
                  Expanded(
                    child: CapDynamicForm(
                      cubit: cubit,
                      capture:
                          widget.capture ??
                          (question) => native.capture(context, question),
                      onRetry: () => cubit.load(widget.formId),
                      onConfirmed: (_) {
                        if (!(remarkForm.currentState?.validate() ?? true)) {
                          return;
                        }
                        cubit.submit(
                          incidentId: widget.incidentId,
                          newStatusId: widget.newStatusId,
                          actionTypeId: widget.actionTypeId,
                          remark: remark.text.trim(),
                          encodeAnswers: widget.encodeAnswers,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}
