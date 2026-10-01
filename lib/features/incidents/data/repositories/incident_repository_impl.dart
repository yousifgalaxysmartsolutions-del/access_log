import '../../../../core/error/exception_mapper.dart';
import '../../../../core/network/cap/api_request_context.dart';
import '../../../../core/network/cap/cap_json.dart';
import '../../../../core/network/cap/cap_locale_holder.dart';
import '../../../../core/network/cap/general_response.dart';
import '../../../../core/network/result.dart';
import '../../../../models/models.dart';
import '../../domain/repositories/incident_repository.dart';
import '../api/incident_api_service.dart';
import '../mappers/incident_mapper.dart';
import '../models/incident_list_models.dart';

class IncidentRepositoryImpl implements IncidentRepository {
  IncidentRepositoryImpl(this._api, this._context);

  final IncidentApiService _api;
  final ApiRequestContextProvider _context;

  @override
  Future<Result<List<CapIncident>>> getIncidentsForDay({
    required DateTime day,
  }) async {
    // CAP expects both bounds as `yyyy-MM-dd`, so "today" means a single day
    // rather than a range that starts at midnight.
    final date = formatCapDate(day);
    final envelope = await _context.wrap(
      IncidentListRequestData(fromDate: date, toDate: date),
      authenticationMessage: 'Sign in again to load incidents',
    );
    return switch (envelope) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(:final data) => apiGuard(() async {
        final response = await _api.getIncidentList(data);
        final parsed = GeneralResponse.parseOrThrow<IncidentListData>(
          response,
          IncidentListData.parse,
          isArabic: CapLocaleHolder.instance.isArabic,
          fallbackMessage: 'Unable to load incidents',
        );
        return IncidentMapper.toIncidents(
          parsed.data!.incidents,
          requestedOn: day,
        );
      }),
    };
  }
}
