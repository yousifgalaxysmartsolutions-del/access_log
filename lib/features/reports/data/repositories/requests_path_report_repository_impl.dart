import '../../../../core/error/exception_mapper.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../domain/repositories/requests_path_report_repository.dart';
import '../api/report_api_service.dart';
import '../models/requests_path_report_models.dart';

class RequestsPathReportRepositoryImpl implements RequestsPathReportRepository {
  RequestsPathReportRepositoryImpl(this.api, this.context);
  final ReportApiService api;
  final ApiRequestContextProvider context;
  @override
  Future<Result<RequestsPathReportData>> getReport(
    RequestsPathReportFilter filter,
  ) async {
    final arabic = CapLocaleHolder.instance.isArabic;
    final envelope = await context.wrap(
      filter,
      authenticationMessage: arabic
          ? 'يرجى تسجيل الدخول مجددًا'
          : 'Please sign in again',
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard(
        () async => GeneralResponse.parseOrThrow<RequestsPathReportData>(
          await api.getRequestsPathReport(data),
          (raw) => RequestsPathReportData.fromJson(
            Map<String, dynamic>.from(raw as Map),
          ),
          isArabic: arabic,
          fallbackMessage: arabic
              ? 'تعذر تحميل تقرير مسار الطلبات'
              : 'Unable to load request flow report',
          endpoint: 'CAP/CapReport/GetRequestsPathReport',
          model: 'RequestsPathReportData',
        ).data!,
      ),
    };
  }
}
