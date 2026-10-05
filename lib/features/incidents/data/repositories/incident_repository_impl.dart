import '../../../../core/error/exception_mapper.dart';
import '../../../../core/network/api_exception.dart';
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
    DateTime? toDate,
  }) async {
    // CAP expects both bounds as `yyyy-MM-dd`, so "today" means a single day
    // rather than a range that starts at midnight.
    final date = formatCapDate(day);
    final end = formatCapDate(toDate ?? day);
    return apiGuard(() async {
      if (date.compareTo(end) > 0) {
        throw const FormatException('Invalid date range');
      }
      final items = <CapIncident>[];
      final seen = <int>{};
      var page = 1;
      while (true) {
        final envelope = await _context.wrap(
          IncidentListRequestData(fromDate: date, toDate: end, page: page),
          authenticationMessage: 'Sign in again to load incidents',
        );
        final result = await switch (envelope) {
          FailureResult(:final failure) => Future.value(
            FailureResult<IncidentListData>(failure),
          ),
          Success(:final data) => apiGuard(() async {
            final response = await _api.getIncidentList(data);
            final parsed = GeneralResponse.parseOrThrow<IncidentListData>(
              response,
              IncidentListData.parse,
              isArabic: CapLocaleHolder.instance.isArabic,
              fallbackMessage: 'Unable to load incidents',
              endpoint: 'CAP/CapIncident/GetIncidentList',
              model: 'IncidentListData',
            );
            return parsed.data!;
          }),
        };
        switch (result) {
          case FailureResult(:final failure):
            throw ApiException(failure);
          case Success<IncidentListData>(:final data):
            final fresh = data.incidents
                .where((item) => seen.add(item.incidentId))
                .toList();
            items.addAll(IncidentMapper.toIncidents(fresh, requestedOn: day));
            if (items.length >= data.totalCount) return items;
            if (fresh.isEmpty || (data.page > 0 && data.page != page)) {
              throw const FormatException(
                'Incident pagination did not advance',
              );
            }
            page++;
        }
      }
    });
  }
}
