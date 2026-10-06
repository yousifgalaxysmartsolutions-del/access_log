import '../../../../core/error/exception_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../domain/repositories/incident_action_configuration_repository.dart';
import '../api/incident_api_service.dart';
import '../models/incident_action_configuration_models.dart';

class IncidentActionConfigurationRepositoryImpl
    implements IncidentActionConfigurationRepository {
  IncidentActionConfigurationRepositoryImpl(this._api, this._context);
  final IncidentApiService _api;
  final ApiRequestContextProvider _context;
  @override
  Future<Result<IncidentActionConfiguration?>> getConfiguration(
    int actionTypeId,
  ) async {
    if (actionTypeId <= 0) return const FailureResult(ValidationFailure());
    final arabic = CapLocaleHolder.instance.isArabic;
    final fallback = arabic
        ? 'تعذّر تحميل متطلبات الإجراء'
        : 'Unable to load action requirements';
    final envelope = await _context.wrap(
      IncidentActionConfigurationRequest(actionTypeId),
      authenticationMessage: arabic
          ? 'يرجى تسجيل الدخول مجددًا'
          : 'Please sign in again',
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard<IncidentActionConfiguration?>(() async {
        final response = await _api.getIncidentActionConfiguration(data);
        // Intentionally NOT parseOrThrow/requireData: success + data:null is valid.
        final parsed = GeneralResponse.parse<IncidentActionConfiguration>(
          response,
          (raw) => IncidentActionConfiguration.fromJson(
            Map<String, dynamic>.from(raw as Map),
          ),
          endpoint: 'CAP/CapConfiguration/GetIncedientActionConfiguration',
          model: 'IncidentActionConfiguration',
          fallbackMessage: fallback,
        );
        if (!parsed.isSuccess) {
          throw ApiException(
            ServiceFailure(
              'cap_result_${parsed.resultCode}',
              parsed.messageFor(isArabic: arabic) ?? fallback,
            ),
          );
        }
        return parsed.data;
      }),
    };
  }
}
