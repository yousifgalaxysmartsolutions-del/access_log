import '../../../../core/error/exception_mapper.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_json.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../domain/repositories/incident_details_repository.dart';
import '../api/incident_api_service.dart';
import '../models/incident_details_models.dart';

/// Repository for the incident details screen.
///
/// Shares [ApiRequestContextProvider] for the CAP envelope metadata and
/// [GeneralResponse] for result-code handling, exactly like the dashboard and
/// incident list repositories. DTOs are returned as parsed: no mapping to UI
/// models happens here.
class IncidentDetailsRepositoryImpl implements IncidentDetailsRepository {
  IncidentDetailsRepositoryImpl(this._api, this._context);

  final IncidentApiService _api;
  final ApiRequestContextProvider _context;

  @override
  Future<Result<IncidentDetailsData>> getIncidentDetails({
    required int incidentId,
    required String incidentNo,
  }) async {
    final envelope = await _context.wrap(
      IncidentDetailsRequestData(
        incidentId: incidentId,
        incidentNo: incidentNo,
      ),
      authenticationMessage: 'Sign in again to load incident details',
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard(() async {
        final response = await _api.getIncidentDetails(data);
        final parsed = GeneralResponse.parseOrThrow<IncidentDetailsData>(
          response,
          (raw) => IncidentDetailsData.fromJson(capMap(raw)),
          isArabic: CapLocaleHolder.instance.isArabic,
          fallbackMessage: 'Unable to load incident details',
          endpoint: 'CAP/CapIncident/GetIncidentDetails',
          model: 'IncidentDetailsData',
        );
        return parsed.data!;
      }),
    };
  }

  @override
  Future<Result<IncidentRequestsData>> getIncidentRequests({
    required int incidentId,
  }) async {
    final envelope = await _context.wrap(
      IncidentRequestsRequestData(incidentId: incidentId),
      authenticationMessage: 'Sign in again to load incident requests',
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard(() async {
        final response = await _api.getIncidentRequests(data);
        // An incident with `items: []` parses into a valid empty list, which is
        // a success rather than a failure.
        final parsed = GeneralResponse.parseOrThrow<IncidentRequestsData>(
          response,
          (raw) => IncidentRequestsData.fromJson(capMap(raw)),
          isArabic: CapLocaleHolder.instance.isArabic,
          fallbackMessage: 'Unable to load incident requests',
          endpoint: 'CAP/CapIncident/GetIncidentRequests',
          model: 'IncidentRequestsData',
        );
        return parsed.data!;
      }),
    };
  }

  /// Timeline history, decoded into [IncidentTimelineData].
  ///
  /// An incident with `events: []` parses into a valid empty list, which is a
  /// success rather than a failure: an incident that has not been acted on yet
  /// is not an error. Individual events are parsed by json_serializable; nothing
  /// in this layer walks the list.
  @override
  Future<Result<IncidentTimelineData>> getIncidentTimeline({
    required int incidentId,
  }) async {
    final envelope = await _context.wrap(
      IncidentTimelineRequestData(incidentId: incidentId),
      authenticationMessage: 'Sign in again to load the incident timeline',
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard(() async {
        final response = await _api.getIncidentTimeline(data);
        final parsed = GeneralResponse.parseOrThrow<IncidentTimelineData>(
          response,
          (raw) => IncidentTimelineData.fromJson(capMap(raw)),
          isArabic: CapLocaleHolder.instance.isArabic,
          fallbackMessage: 'Unable to load the incident timeline',
          endpoint: 'CAP/CapIncident/GetIncidentTimeline',
          model: 'IncidentTimelineData',
        );
        return parsed.data!;
      }),
    };
  }
}
