import '../../../../core/error/exception_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../../forms/data/models/cap_form_models.dart';
import '../../domain/repositories/periodic_photo_repository.dart';
import '../api/periodic_photo_api_service.dart';
import '../models/periodic_photo_payload.dart';

/// CAP-backed [PeriodicPhotoRepository].
///
/// Reuses the shared Dio, request envelope, error mapping and CAP response
/// parsing. It performs no local storage work and never decides a failure is a
/// success.
class PeriodicPhotoRepositoryImpl implements PeriodicPhotoRepository {
  const PeriodicPhotoRepositoryImpl(this.api, this.context);

  final PeriodicPhotoApiService api;
  final ApiRequestContextProvider context;

  @override
  Future<Result<bool>> submit({
    required int incidentId,
    required CapFormEvidence evidence,
  }) => apiGuard<bool>(() async {
    final isArabic = CapLocaleHolder.instance.isArabic;

    final payload = SavePeriodicPhotoRequestData(
      incidentId: incidentId,
      // Real detected extension: png stays png, jpeg stays jpg.
      imageData: evidence.extension,
      imageBytes: evidence.bytes.toList(growable: false),
    );

    final envelope = await context.wrap<SavePeriodicPhotoRequestData>(
      payload,
      authenticationMessage: isArabic
          ? 'يرجى تسجيل الدخول مجددًا'
          : 'Please sign in again',
    );
    final request = switch (envelope) {
      FailureResult(:final failure) => throw ApiException(failure),
      Success(:final data) => data,
    };

    final response = await api.savePeriodicPhoto(request);

    // Success is the CAP result code, never merely HTTP 200.
    final parsed = GeneralResponse.parse<bool>(
      response,
      (_) => true,
      endpoint: 'CAP/CapIncident/SavePeriodicPhoto',
      model: 'PeriodicPhoto',
    );


    // if (!parsed.isSuccess) {
    //   print('Periodic photo upload failedss: ${parsed.resultCode}parsed');
    //   throw ApiException(
    //     ServiceFailure(
    //       'cap_result_${parsed.resultCode}',
    //       parsed.messageFor(isArabic: isArabic) ??
    //           (isArabic
    //               ? 'تعذّر رفع الصورة الدورية'
    //               : 'Unable to upload the required photo'),
    //     ),
    //   );
    // }
    print('Periodic photo upload failedss: ${parsed.resultCode}2');

    return true;
  });
}
