import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../data/models/cap_form_models.dart';
import '../../domain/usecases/cap_form_use_cases.dart';

enum CapFormError { required, invalid, unsupported, multipleOptionsContract }

class CapFormState {
  CapFormState({
    this.form,
    this.loading = false,
    this.failure,
    this.submitting = false,
    this.submitted = false,
    this.submissionFailure,
    Map<int, List<CapFormAnswer>> answers = const {},
    Map<int, CapFormError> errors = const {},
  }) : answers = Map.unmodifiable(
         answers.map(
           (id, values) =>
               MapEntry(id, List<CapFormAnswer>.unmodifiable(values)),
         ),
       ),
       errors = Map.unmodifiable(errors);
  final CapQuestionForm? form;
  final bool loading;
  final Failure? failure;
  final bool submitting, submitted;
  final Failure? submissionFailure;
  final Map<int, List<CapFormAnswer>> answers;
  final Map<int, CapFormError> errors;
  bool isVisible(CapFormQuestion question, [Set<int>? path]) {
    if (question.relatedQuestionId == 0) return true;
    final visited = {...?path};
    if (!visited.add(question.id)) return false;
    final parents = form?.questions.where(
      (q) => q.id == question.relatedQuestionId,
    );
    if (parents == null ||
        parents.length != 1 ||
        !isVisible(parents.single, visited)) {
      return false;
    }
    return answers[question.relatedQuestionId]?.any(
          (a) => a.optionId == question.relatedAnswerId,
        ) ??
        false;
  }

  List<CapFormQuestion> get visibleQuestions =>
      form?.questions.where(isVisible).toList() ?? const [];
}

/// Per-form state, with stale-load protection and no local incident mutations.
class CapFormCubit extends Cubit<CapFormState> {
  CapFormCubit(this._load, {SubmitIncidentFormUseCase? submit})
    : _submit = submit,
      super(CapFormState());
  final GetCapFormUseCase _load;
  final SubmitIncidentFormUseCase? _submit;
  int _revision = 0;
  Future<void> load(int formId) async {
    if (isClosed || state.submitting) return;
    final revision = ++_revision;
    emit(CapFormState(loading: true));
    final result = await _load(formId);
    if (isClosed || revision != _revision) return;
    switch (result) {
      case Success(:final data):
        emit(CapFormState(form: data));
      case FailureResult(:final failure):
        emit(CapFormState(failure: failure));
    }
  }

  void answer(int questionId, List<CapFormAnswer> values) {
    if (isClosed || state.submitting || state.submitted) return;
    final questions = state.form?.questions.where((q) => q.id == questionId);
    if (questions == null || questions.length != 1) return;
    final question = questions.single;
    if (!state.isVisible(question) ||
        values.any(
          (a) =>
              a.questionId != questionId || a.questionTypeId != question.typeId,
        )) {
      return;
    }
    final answers = {...state.answers, questionId: values};
    final candidate = CapFormState(form: state.form, answers: answers);
    // Hidden descendants lose their answers and cannot leak into submission.
    for (final q in state.form!.questions) {
      if (!candidate.isVisible(q)) answers.remove(q.id);
    }
    emit(CapFormState(form: state.form, answers: answers));
  }

  void text(CapFormQuestion question, String value) => answer(question.id, [
    CapFormAnswer(
      questionId: question.id,
      questionTypeId: question.typeId,
      text: value,
    ),
  ]);
  void options(CapFormQuestion question, Set<int> ids) => answer(question.id, [
    for (final id in ids)
      CapFormAnswer(
        questionId: question.id,
        questionTypeId: question.typeId,
        optionId: id,
      ),
  ]);

  /// No API is invoked. Returns only validated visible answers.
  /// Each selected option remains its own answer for the parent question.
  List<CapFormAnswer>? confirmedAnswers({bool forSubmission = true}) {
    if (isClosed ||
        state.form == null ||
        state.loading ||
        state.submitting ||
        state.submitted) {
      return null;
    }
    final errors = <int, CapFormError>{};
    final result = <CapFormAnswer>[];
    for (final q in state.visibleQuestions) {
      final values = state.answers[q.id] ?? const <CapFormAnswer>[];
      final filled = values
          .where(
            (a) =>
                a.text.trim().isNotEmpty ||
                (a.answerBytes?.isNotEmpty ?? false) ||
                a.optionId > 0 ||
                (a.evidence?.bytes.isNotEmpty ?? false),
          )
          .toList();
      if (q.type == CapQuestionType.unsupported) {
        errors[q.id] = CapFormError.unsupported;
      } else if (q.required && filled.isEmpty) {
        errors[q.id] = CapFormError.required;
      } else if (filled.any((a) => !_valid(q, a))) {
        errors[q.id] = CapFormError.invalid;
      } else {
        result.addAll(filled);
      }
    }
    emit(
      CapFormState(form: state.form, answers: state.answers, errors: errors),
    );
    return errors.isEmpty ? List.unmodifiable(result) : null;
  }

  bool _valid(CapFormQuestion q, CapFormAnswer a) {
    switch (q.type) {
      case CapQuestionType.number:
        return double.tryParse(a.text)?.isFinite ?? false;
      case CapQuestionType.singleChoice:
      case CapQuestionType.multiChoice:
        return q.options.any((o) => o.id == a.optionId);
      case CapQuestionType.location:
        final parts = a.text
            .split(',')
            .map((p) => double.tryParse(p.trim()))
            .toList();
        return parts.length == 2 &&
            parts[0] != null &&
            parts[1] != null &&
            parts[0]!.isFinite &&
            parts[1]!.isFinite &&
            parts[0]!.abs() <= 90 &&
            parts[1]!.abs() <= 180;
      case CapQuestionType.rating:
        final rating = double.tryParse(a.text);
        return rating != null &&
            rating.isFinite &&
            rating >= 0.5 &&
            rating <= 5 &&
            (rating * 2) % 1 == 0;
      case CapQuestionType.image:
      case CapQuestionType.signature:
      case CapQuestionType.video:
      case CapQuestionType.audio:
        return (a.evidence?.bytes.isNotEmpty ?? false) ||
            (a.answerBytes?.isNotEmpty ?? false);
      case CapQuestionType.dateTime:
        return DateTime.tryParse(a.text) != null;
      default:
        return true;
    }
  }

  /// Caller supplies the incident transition and, when needed, a confirmed
  /// evidence encoder. Never guesses a FormId or mutates an incident locally.
  Future<void> submit({
    required int incidentId,
    required int newStatusId,
    required int actionTypeId,
    required String remark,
    List<CapFormAnswer> Function(List<CapFormAnswer>)? encodeAnswers,
  }) async {
    if (isClosed || state.submitting || state.submitted) return;
    final answers = confirmedAnswers();
    if (answers == null) return;
    final revision = _revision;
    final form = state.form!;
    final retained = state.answers;
    void failed(Failure failure) {
      if (!isClosed && revision == _revision) {
        emit(
          CapFormState(
            form: form,
            answers: retained,
            submissionFailure: failure,
          ),
        );
      }
    }

    if (_submit == null) {
      failed(
        const ServiceFailure(
          'form_submit_unavailable',
          'Form submission is not configured',
        ),
      );
      return;
    }
    List<CapFormAnswer> encoded;
    try {
      encoded = encodeAnswers?.call(answers) ?? answers;
    } on Exception {
      failed(
        const ServiceFailure('form_encoding', 'Unable to encode form evidence'),
      );
      return;
    }
    emit(CapFormState(form: form, answers: retained, submitting: true));
    final result = await _submit(
      IncidentFormSubmission(
        incidentId: incidentId,
        newStatusId: newStatusId,
        actionTypeId: actionTypeId,
        formId: form.id,
        remark: remark,
        answers: encoded,
      ),
    );
    if (isClosed || revision != _revision) return;
    switch (result) {
      case Success():
        emit(CapFormState(form: form, answers: retained, submitted: true));
      case FailureResult(:final failure):
        failed(failure);
    }
  }
}
