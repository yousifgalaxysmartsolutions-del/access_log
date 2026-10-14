import 'dart:async';
import 'package:access_log_plus/core/di/injection.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/incidents/data/mappers/incident_mapper.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_list_models.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_lookup_models.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_details_models.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/incident_repository.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/incident_details_repository.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_list_use_case.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_requests_use_case.dart';
import 'package:access_log_plus/features/incidents/presentation/bloc/incident_map_cubit.dart';
import 'package:access_log_plus/features/requests/presentation/bloc/request_details_cubit.dart';
import 'package:access_log_plus/models/models.dart';
import 'package:access_log_plus/screens/map/tower_map_screen.dart';
import 'package:access_log_plus/screens/requests/api_request_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'request_details_test.dart' show RequestDetailsTestCubit;

Map<String, dynamic> incidentJson({
  int id = 26,
  String? code = 'D10736',
  num? lat = 31.34573068640783,
  num? long = 30.056509692385522,
}) => {
  'incidentId': id,
  'incidentNo': 'INC-$id',
  'incidentTitle': 'API incident $id',
  'locationName': 'site 3',
  'locationCode': code,
  'region': {'id': 79, 'name': 'Cairo'},
  'area': {'id': 103, 'name': 'Monshat Naser'},
  'status': {'id': 3, 'name': 'Pending'},
  'priority': {'id': 1, 'name': 'High'},
  'latitude': lat,
  'longitude': long,
  'createdDate': '2026-10-14T10:00:00',
};
CapIncident incident({
  int id = 26,
  String? code = 'D10736',
  num? lat = 31.34573068640783,
  num? long = 30.056509692385522,
}) => IncidentMapper.toIncident(
  IncidentListItem.fromJson(
    incidentJson(id: id, code: code, lat: lat, long: long),
  ),
  requestedOn: DateTime(2026, 10, 14),
);

class _Incidents implements IncidentRepository {
  final days = <DateTime>[], ends = <DateTime?>[];
  Result<List<CapIncident>> result = Success([incident(), incident(id: 27)]);
  Completer<void>? gate;
  @override
  Future<Result<List<CapIncident>>> getIncidentsForDay({
    required DateTime day,
    DateTime? toDate,
    int statusId = -1,
    IncidentListFilter? filter,
  }) async {
    days.add(day);
    ends.add(toDate);
    await gate?.future;
    return result;
  }

  @override
  Future<Result<IncidentLookupData>> getIncidentLookup() async =>
      Success(IncidentLookupData());
}

class _Details implements IncidentDetailsRepository {
  final ids = <int>[];
  bool fail = false;
  @override
  Future<Result<IncidentRequestsData>> getIncidentRequests({
    required int incidentId,
  }) async {
    ids.add(incidentId);
    return fail
        ? const FailureResult(NetworkFailure())
        : const Success(
            IncidentRequestsData(
              items: [
                IncidentRequestItemDto(
                  id: 3,
                  requestType: IdNameDto(id: 1, name: 'Intervention Request'),
                  requestStatus: IdNameDto(id: 1, name: 'Pending'),
                ),
              ],
            ),
          );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

IncidentMapCubit _mapCubit(_Incidents repo, _Details details) =>
    IncidentMapCubit(
      getIncidents: GetIncidentListUseCase(repo),
      getRequests: GetIncidentRequestsUseCase(details),
      now: () => DateTime(2026, 10, 14, 17, 25),
    );

void main() {
  Widget app(Widget home, {String lang = 'en'}) => MaterialApp(
    locale: Locale(lang),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: home,
  );
  test(
    'list DTO and mapper retain coordinates exactly, including integer and null values',
    () {
      final dto = IncidentListItem.fromJson(incidentJson());
      expect(dto.latitude, 31.34573068640783);
      expect(dto.longitude, 30.056509692385522);
      final mapped = IncidentMapper.toIncident(
        dto,
        requestedOn: DateTime(2026, 10, 14),
      );
      expect(mapped.latitude, dto.latitude);
      expect(mapped.longitude, dto.longitude);
      expect(incident(lat: 31, long: 30).latitude, 31.0);
      expect(incident(lat: null, long: null).latitude, isNull);
    },
  );
  test(
    'map requests today only, groups incidents at same site and preserves real coordinates',
    () async {
      final repo = _Incidents();
      final details = _Details();
      final cubit = _mapCubit(repo, details);
      addTearDown(cubit.close);
      await cubit.refresh();
      expect(repo.days.single, DateTime(2026, 10, 14));
      expect(repo.ends.single, DateTime(2026, 10, 14));
      expect(cubit.state.sites, hasLength(1));
      final site = cubit.state.sites.single;
      expect(site.incidents, hasLength(2));
      expect(site.tower.latitude, 31.34573068640783);
      expect(site.tower.longitude, 30.056509692385522);
      cubit.search('INC-27');
      expect(cubit.visibleSites, hasLength(1));
      cubit.search('not-a-real-site');
      expect(cubit.visibleSites, isEmpty);
      await cubit.loadRequests(site);
      expect(details.ids, [26, 27]);
      expect(cubit.state.requests, hasLength(1));
    },
  );
  test(
    'missing/out-of-range coordinates never create fake markers and unnamed sites are not merged',
    () async {
      final repo = _Incidents()
        ..result = Success([
          incident(id: 1, code: 'bad', lat: 100),
          incident(id: 2, code: 'missing', lat: null, long: null),
          incident(id: 3, code: null, lat: 31, long: 30),
          incident(id: 4, code: null, lat: 32, long: 30),
        ]);
      final cubit = _mapCubit(repo, _Details());
      addTearDown(cubit.close);
      await cubit.refresh();
      expect(cubit.state.missingCoordinates, 2);
      expect(cubit.state.sites, hasLength(2));
    },
  );
  for (final lang in ['en', 'ar']) {
    testWidgets(
      'API tower marker opens actual incidents/requests and list search fits $lang',
      (tester) async {
        await services.reset();
        addTearDown(services.reset);
        final repo = _Incidents();
        final details = _Details();
        services.registerFactory<IncidentMapCubit>(
          () => _mapCubit(repo, details),
        );
        services.registerFactory<RequestDetailsCubit>(
          () => RequestDetailsTestCubit(),
        );
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(const TowerMapScreen(enableTiles: false), lang: lang),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(lang == 'ar' ? '1 أبراج ظاهرة' : '1 towers visible'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('tower-D10736')));
        await tester.pumpAndSettle();
        expect(find.text('site 3'), findsOneWidget);
        expect(find.text('INC-26'), findsOneWidget);
        await tester.tap(
          find.text(
            lang == 'ar' ? 'فتح كل طلبات البرج' : 'Open All Tower Requests',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TowerRequestsScreen), findsOneWidget);
        expect(details.ids, [26, 27]);
        await tester.tap(
          find.text(lang == 'ar' ? 'الطلبات (1)' : 'Requests (1)'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(lang == 'ar' ? 'طلب #3' : 'Request #3'));
        await tester.pumpAndSettle();
        expect(find.byType(ApiRequestDetailsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'search with no matches and refresh work without fabricated sites',
    (tester) async {
      await services.reset();
      addTearDown(services.reset);
      final repo = _Incidents();
      services.registerFactory<IncidentMapCubit>(
        () => _mapCubit(repo, _Details()),
      );
      await tester.pumpWidget(app(const TowerMapScreen(enableTiles: false)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'nothing-matches');
      await tester.pumpAndSettle();
      expect(find.text('0 towers visible'), findsOneWidget);
      await tester.tap(find.byTooltip('List view'));
      await tester.pumpAndSettle();
      expect(find.text('No towers found'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('site 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(repo.days, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'loading, error and no-coordinate empty states do not show mock markers',
    (tester) async {
      await services.reset();
      addTearDown(services.reset);
      final repo = _Incidents()..gate = Completer<void>();
      services.registerFactory<IncidentMapCubit>(
        () => _mapCubit(repo, _Details()),
      );
      await tester.pumpWidget(app(const TowerMapScreen(enableTiles: false)));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.result = const FailureResult(NetworkFailure('Map unavailable'));
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Map unavailable'), findsOneWidget);
      repo.gate = null;
      repo.result = Success([incident(lat: null, long: null)]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No mapped incidents today'), findsOneWidget);
      expect(
        find.textContaining('1 incidents have no valid coordinates'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('tower-D10736')), findsNothing);
    },
  );
}
