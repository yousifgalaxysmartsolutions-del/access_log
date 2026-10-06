import '../../../../core/error/exception_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../../forms/domain/repositories/cap_form_repository.dart';
import '../../domain/actions/incident_available_action.dart';
import '../../domain/actions/incident_execution_context.dart';
import '../../domain/repositories/incident_execution_repository.dart';
import '../api/incident_api_service.dart';

class IncidentExecutionRepositoryImpl implements IncidentExecutionRepository {
  IncidentExecutionRepositoryImpl(this.api, this.context, this.forms);
  final IncidentApiService api;
  final ApiRequestContextProvider context;
  final CapFormRepository forms;
  String get authMessage => CapLocaleHolder.instance.isArabic
      ? 'يرجى تسجيل الدخول مجددًا'
      : 'Please sign in again';
  @override
  Future<Result<List<IncidentTeamMember>>> getTeam() async {
    final envelope = await context.wrap<Null>(
      null,
      authenticationMessage: authMessage,
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard(
        () async => GeneralResponse.parseOrThrow(
          await api.getMyTeamUser(data),
          (raw) => (raw as List)
              .map(
                (e) => IncidentTeamMember.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(),
          isArabic: CapLocaleHolder.instance.isArabic,
          fallbackMessage: CapLocaleHolder.instance.isArabic
              ? 'تعذّر تحميل أعضاء الفريق'
              : 'Unable to load team',
          endpoint: 'CAP/CapAuth/GetMyTeamUser',
          model: 'IncidentTeamMember',
        ).data!,
      ),
    };
  }

  @override
  Future<Result<void>> execute(IncidentExecutionContext execution) async {
    if (execution.incidentId <= 0 ||
        execution.actionTypeId <= 0 ||
        execution.selectedAction.flow == IncidentActionFlow.request) {
      return const FailureResult(ValidationFailure());
    }
    if (execution.selectedAction.type != IncidentAction.assign) {
      if ((execution.newStatusId ?? 0) <= 0) {
        return const FailureResult(ValidationFailure());
      }
      return forms.submit(execution.toStatusChange());
    }
    if ((execution.assignedUserId ?? 0) <= 0) {
      return const FailureResult(ValidationFailure());
    }
    final envelope = await context.wrap(
      execution,
      authenticationMessage: authMessage,
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard<void>(() async {
        final result = GeneralResponse.parse<Object?>(
          await api.assignIncident(data),
          (raw) => raw,
        );
        if (!result.isSuccess) {
          throw ApiException(
            ServiceFailure(
              'cap_result_${result.resultCode}',
              result.messageFor(isArabic: CapLocaleHolder.instance.isArabic) ??
                  (CapLocaleHolder.instance.isArabic
                      ? 'تعذّر الإسناد'
                      : 'Unable to assign'),
            ),
          );
        }
      }),
    };
  }
}
