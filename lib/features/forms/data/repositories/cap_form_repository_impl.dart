import '../../../../core/error/exception_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../domain/repositories/cap_form_repository.dart';
import '../api/cap_form_api_service.dart';
import '../models/cap_form_models.dart';

class CapFormRepositoryImpl implements CapFormRepository {
  CapFormRepositoryImpl(this._api, this._context);
  final CapFormApiService _api;
  final ApiRequestContextProvider _context;
  String _message(String en, String ar) =>
      CapLocaleHolder.instance.isArabic ? ar : en;
  @override
  Future<Result<CapQuestionForm>> load(int formId) async {
    if (formId <= 0) return const FailureResult(ValidationFailure());
    final envelope = await _context.wrap(
      GetCapFormPayload(formId),
      authenticationMessage: _message(
        'Sign in again to load the form',
        'سجّل الدخول مجددًا لتحميل النموذج',
      ),
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard(() async {
        final response = await _api.getForm(data);
        final form = GeneralResponse.parseOrThrow(
          response,
          (raw) =>
              CapQuestionForm.fromJson(Map<String, dynamic>.from(raw as Map)),
          isArabic: CapLocaleHolder.instance.isArabic,
          fallbackMessage: _message(
            'Unable to load form',
            'تعذّر تحميل النموذج',
          ),
          endpoint: 'CAP/CapLookup/GetFormQuestion',
          model: 'CapQuestionForm',
        ).data!;
        if (form.id != formId) {
          throw ApiException(
            ValidationFailure(
              _message('Unexpected form returned', 'تم استلام نموذج غير مطابق'),
            ),
          );
        }
        return form;
      }),
    };
  }

  @override
  Future<Result<void>> submit(IncidentFormSubmission submission) async {
    if (submission.answers.any((a) => a.evidence != null)) {
      return FailureResult(
        ServiceFailure(
          'form_evidence_contract',
          _message(
            'Evidence encoding requires API confirmation',
            'صيغة إرسال الإثبات تحتاج تأكيد الـAPI',
          ),
        ),
      );
    }
    if ([
      submission.formId,
      submission.incidentId,
      submission.actionTypeId,
      submission.newStatusId,
    ].any((id) => id <= 0)) {
      return const FailureResult(ValidationFailure());
    }
    final envelope = await _context.wrap(
      submission,
      authenticationMessage: _message(
        'Sign in again to submit the form',
        'سجّل الدخول مجددًا لإرسال النموذج',
      ),
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard<void>(() async {
        final response = GeneralResponse.parse<Object?>(
          await _api.submit(data),
          (raw) => raw,
        );
        // Mutation responses may legitimately contain data:null.
        if (!response.isSuccess) {
          throw ApiException(
            ServiceFailure(
              'cap_result_${response.resultCode}',
              response.messageFor(
                    isArabic: CapLocaleHolder.instance.isArabic,
                  ) ??
                  _message('Unable to submit form', 'تعذّر إرسال النموذج'),
            ),
          );
        }
      }),
    };
  }
}
