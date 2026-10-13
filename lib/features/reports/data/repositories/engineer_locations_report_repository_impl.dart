import '../../../../core/error/exception_mapper.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../domain/repositories/engineer_locations_report_repository.dart';
import '../api/report_api_service.dart';
import '../models/engineer_locations_report_models.dart';

class EngineerLocationsReportRepositoryImpl
    implements EngineerLocationsReportRepository {
  EngineerLocationsReportRepositoryImpl(this.api, this.context);
  final ReportApiService api;
  final ApiRequestContextProvider context;
  @override
  Future<Result<EngineerLocationsReportData>> getReport(
    EngineerLocationsReportFilter filter,
  ) async {
    final envelope = await context.wrap(
      filter,
      authenticationMessage: CapLocaleHolder.instance.isArabic
          ? 'يرجى تسجيل الدخول مجددًا لتحميل التقرير'
          : 'Sign in again to load the report',
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard(
        () async => GeneralResponse.parseOrThrow<EngineerLocationsReportData>(
          await api.getEngineerLocationsReport(data),
          (raw) => EngineerLocationsReportData.fromJson(
            Map<String, dynamic>.from(raw as Map),
          ),
          isArabic: CapLocaleHolder.instance.isArabic,
          fallbackMessage: CapLocaleHolder.instance.isArabic
              ? 'تعذر تحميل تقرير مواقع المهندس'
              : 'Unable to load engineer locations report',
          endpoint: 'CAP/CapReport/GetEngineerLocationsReport',
          model: 'EngineerLocationsReportData',
        ).data!,
      ),
    };
  }
}
