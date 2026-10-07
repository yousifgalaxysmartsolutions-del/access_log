import '../../../../core/error/exception_mapper.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../domain/repositories/system_gps_configuration_repository.dart';
import '../api/incident_api_service.dart';
import '../models/system_gps_configuration.dart';

class SystemGpsConfigurationRepositoryImpl
    implements SystemGpsConfigurationRepository {
  const SystemGpsConfigurationRepositoryImpl(this.api, this.context);
  final IncidentApiService api;
  final ApiRequestContextProvider context;
  @override
  Future<Result<SystemGpsConfiguration>> load() => apiGuard(() async {
    final arabic = CapLocaleHolder.instance.isArabic;
    // Ordinary envelope, explicitly data:null; NOT metadataOnly.
    final envelope = await context.wrap<Null>(
      null,
      authenticationMessage: arabic
          ? 'يرجى تسجيل الدخول مجددًا'
          : 'Please sign in again',
    );
    switch (envelope) {
      case FailureResult(:final failure):
        throw ApiException(failure);
      case Success(:final data):
        return GeneralResponse.parseOrThrow<SystemGpsConfiguration>(
          await api.getSystemConfiguration(data),
          (raw) => SystemGpsConfiguration.fromJson(
            Map<String, dynamic>.from(raw as Map),
          ),
          endpoint: 'CAP/CapConfiguration/GetSystemConfiguration',
          model: 'SystemGpsConfiguration',
          isArabic: arabic,
          fallbackMessage: arabic
              ? 'تعذّر تحميل إعدادات الموقع'
              : 'Unable to load location configuration',
        ).data!;
    }
  });
}
