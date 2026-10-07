import '../../../../core/error/exception_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../domain/repositories/request_creation_repository.dart';
import '../api/request_api_service.dart';
import '../models/request_creation_models.dart';

class RequestCreationRepositoryImpl implements RequestCreationRepository {
  const RequestCreationRepositoryImpl(this.api, this.context);
  final RequestApiService api;
  final ApiRequestContextProvider context;
  Future<Result<T>> _perform<T, P>(
    P input,
    Future<ApiResponse> Function(CapRequest<P>) send,
    T Function(ApiResponse) decode,
  ) => apiGuard(() async {
    final envelope = await context.wrap(
      input,
      authenticationMessage: CapLocaleHolder.instance.isArabic
          ? 'يرجى تسجيل الدخول مجددًا'
          : 'Please sign in again',
    );
    switch (envelope) {
      case FailureResult(:final failure):
        throw ApiException(failure);
      case Success(:final data):
        return decode(await send(data));
    }
  });
  GeneralResponse<T> _parse<T>(
    ApiResponse response,
    T Function(dynamic) decode,
    String endpoint,
  ) {
    final arabic = CapLocaleHolder.instance.isArabic;
    final fallback = arabic ? 'تعذّر تنفيذ الطلب' : 'Unable to process request';
    final parsed = GeneralResponse.parse<T>(
      response,
      decode,
      endpoint: endpoint,
      model: '$T',
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
    return parsed;
  }

  @override
  Future<Result<RequestConfiguration?>> getConfiguration(
    int requestTypeId,
    int incidentId,
  ) {
    if (requestTypeId <= 0 || incidentId <= 0) {
      return Future.value(const FailureResult(ValidationFailure()));
    }
    return _perform(
      RequestConfigurationInput(requestTypeId, incidentId),
      api.getRequestConfiguration,
      (response) => _parse<RequestConfiguration>(
        response,
        (raw) => RequestConfiguration.fromJson(
          Map<String, dynamic>.from(raw as Map),
        ),
        'CAP/CapConfiguration/GetRequestConfiguration',
      ).data,
    );
  }

  @override
  Future<Result<void>> create(RequestExecutionContext input) {
    if (!input.canSubmit ||
        input.incidentId <= 0 ||
        input.requestTypeId <= 0 ||
        input.noOfMinute < 0) {
      return Future.value(const FailureResult(ValidationFailure()));
    }
    return _perform(input, api.createRequest, (response) {
      _parse<Object>(
        response,
        (raw) => raw as Object,
        'CAP/CapRequest/CreateRequest',
      );
    });
  }
}
