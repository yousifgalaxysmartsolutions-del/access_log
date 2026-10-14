import '../../../../core/error/exception_mapper.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../domain/repositories/engineers_activity_report_repository.dart';
import '../api/report_api_service.dart';
import '../models/engineers_activity_report_models.dart';

class EngineersActivityReportRepositoryImpl
    implements EngineersActivityReportRepository {
  EngineersActivityReportRepositoryImpl(this.api, this.context);
  final ReportApiService api;
  final ApiRequestContextProvider context;
  @override
  Future<Result<EngineersActivityReportData>> getReport(
    EngineersActivityReportFilter filter,
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
        () async => GeneralResponse.parseOrThrow<EngineersActivityReportData>(
          await api.getEngineersActivityReport(data),
          (raw) => EngineersActivityReportData.fromJson(
            Map<String, dynamic>.from(raw as Map),
          ),
          isArabic: arabic,
          fallbackMessage: arabic
              ? 'تعذر تحميل تقرير أنشطة المهندسين'
              : 'Unable to load engineers activity report',
          endpoint: 'CAP/CapReport/GetEngineersActivityReport',
          model: 'EngineersActivityReportData',
        ).data!,
      ),
    };
  }
}
