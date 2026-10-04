import '../../../../core/error/exception_mapper.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_json.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/cap_request.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../domain/repositories/request_repository.dart';
import '../api/request_api_service.dart';
import '../models/request_models.dart';

/// Transport-only repository: returns backend DTOs without UI/business rules.
class RequestRepositoryImpl implements RequestRepository {
  RequestRepositoryImpl(this._api, this._context);
  final RequestApiService _api;
  final ApiRequestContextProvider _context;

  String get _signIn => CapLocaleHolder.instance.isArabic
      ? 'يرجى تسجيل الدخول مجددًا للوصول إلى الطلبات'
      : 'Sign in again to access requests';

  @override
  Future<Result<RequestLookupData>> getRequestLookup() => _perform(
    _context.wrapMetadataOnly(authenticationMessage: _signIn),
    _api.getAllRequestLookup,
    RequestLookupData.fromJson,
    'Unable to load request lookups',
    'تعذر تحميل قوائم الطلبات',
  );

  @override
  Future<Result<RequestListData>> getRequestList({
    required DateTime fromDate,
    required DateTime toDate,
    required int requestTypeId,
    required int requestStatusId,
    required String locationCode,
    required String incidentNo,
    required int page,
    required int pageSize,
  }) => _perform(
    _context.wrap(
      RequestListRequestData(
        fromDate: formatCapDate(fromDate),
        toDate: formatCapDate(toDate),
        requestTypeId: requestTypeId,
        requestStatusId: requestStatusId,
        locationCode: locationCode,
        incidentNo: incidentNo,
        page: page,
        pageSize: pageSize,
      ),
      authenticationMessage: _signIn,
    ),
    _api.getRequestList,
    RequestListData.fromJson,
    'Unable to load requests',
    'تعذر تحميل الطلبات',
  );

  @override
  Future<Result<RequestDecisionData>> approveRequest({
    required int requestId,
    required String remark,
  }) => _perform(
    _context.wrap(
      RequestApproveData(requestId: requestId, remark: remark),
      authenticationMessage: _signIn,
    ),
    _api.requestApprove,
    RequestDecisionData.fromJson,
    'Unable to approve request',
    'تعذر الموافقة على الطلب',
  );

  @override
  Future<Result<RequestDecisionData>> rejectRequest({
    required int requestId,
    required String reason,
  }) => _perform(
    _context.wrap(
      RequestRejectData(requestId: requestId, reason: reason),
      authenticationMessage: _signIn,
    ),
    _api.requestReject,
    RequestDecisionData.fromJson,
    'Unable to reject request',
    'تعذر رفض الطلب',
  );

  // Same CAP parsing and error boundary as the incident repositories. The
  // context await is also inside apiGuard so storage/device exceptions cannot
  // escape as raw exceptions. No separate error mapping is introduced.
  Future<Result<T>> _perform<T extends Object, P>(
    Future<Result<CapRequest<P>>> envelope,
    Future<ApiResponse> Function(CapRequest<P>) send,
    T Function(Map<String, dynamic>) decode,
    String englishFallback,
    String arabicFallback,
  ) => apiGuard(() async {
    final context = await envelope;
    switch (context) {
      case FailureResult(:final failure):
        throw ApiException(failure);
      case Success(:final data):
        final response = await send(data);
        final isArabic = CapLocaleHolder.instance.isArabic;
        return GeneralResponse.parseOrThrow<T>(
          response,
          (raw) => decode(capMap(raw)),
          isArabic: isArabic,
          fallbackMessage: isArabic ? arabicFallback : englishFallback,
        ).data!;
    }
  });
}
