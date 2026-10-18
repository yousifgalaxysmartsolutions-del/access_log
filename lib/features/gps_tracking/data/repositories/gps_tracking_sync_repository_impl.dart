import '../../../../core/error/exception_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../domain/gps_location_record.dart';
import '../../domain/repositories/gps_tracking_sync_repository.dart';
import '../api/gps_tracking_api_service.dart';
import '../models/gps_tracking_sync_payload.dart';

/// CAP-backed [GpsTrackingSyncRepository].
///
/// Reuses the shared Dio, request envelope, error mapping and CAP response
/// parsing. It performs no local storage work and never deletes anything.
class GpsTrackingSyncRepositoryImpl implements GpsTrackingSyncRepository {
  const GpsTrackingSyncRepositoryImpl(this.api, this.context);

  final GpsTrackingApiService api;
  final ApiRequestContextProvider context;

  @override
  Future<Result<bool>> upload({
    required int incidentId,
    required List<GpsLocationRecord> records,
  }) => apiGuard<bool>(() async {
    if (records.isEmpty) return true;

    final isArabic = CapLocaleHolder.instance.isArabic;
    final payload = GpsTrackingSyncRequestData(
      incidentId: incidentId,
      points: records
          .map(GpsTrackingPointPayload.fromRecord)
          .toList(growable: false),
    );

    final envelope = await context.wrap<GpsTrackingSyncRequestData>(
      payload,
      authenticationMessage: isArabic
          ? 'يرجى تسجيل الدخول مجددًا'
          : 'Please sign in again',
    );
    final request = switch (envelope) {
      FailureResult(:final failure) => throw ApiException(failure),
      Success(:final data) => data,
    };

    final response = await api.uploadGpsTracking(request);

    // Success is the CAP result code, never merely HTTP 200.
    final parsed = GeneralResponse.parse<bool>(
      response,
      (_) => true,
      endpoint: 'CAP/CapAuth/GpsTracking',
      model: 'GpsTracking',
    );
    if (!parsed.isSuccess) {
      throw ApiException(
        ServiceFailure(
          'cap_result_${parsed.resultCode}',
          parsed.messageFor(isArabic: isArabic) ??
              (isArabic
                  ? 'تعذّر إرسال نقاط الموقع'
                  : 'Unable to upload location points'),
        ),
      );
    }
    return true;
  });
}
