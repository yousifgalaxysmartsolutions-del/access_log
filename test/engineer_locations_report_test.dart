import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/di/injection.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/incidents/domain/actions/incident_execution_context.dart';
import 'package:access_log_plus/features/reports/data/api/report_api_service.dart';
import 'package:access_log_plus/features/reports/data/models/engineer_locations_report_models.dart';
import 'package:access_log_plus/features/reports/data/repositories/engineer_locations_report_repository_impl.dart';
import 'package:access_log_plus/features/reports/domain/repositories/engineer_locations_report_repository.dart';
import 'package:access_log_plus/features/reports/domain/usecases/get_engineer_locations_report_use_case.dart';
import 'package:access_log_plus/features/reports/presentation/bloc/engineer_locations_report_cubit.dart';
import 'package:access_log_plus/screens/reporting/engineer_sites_report_screen.dart';

const engineerReportFixture = <String, dynamic>{
  'engineer': {'id': 4099, 'name': 'engineer 1'},
  'team': null,
  'jobTitle': null,
  'requestsCount': 1,
  'incidentsCount': 4,
  'locationsCount': 3,
  'locations': [
    {
      'location': {'id': 'D10738', 'name': 'site b1', 'code': null},
      'region': {'id': 111, 'name': 'Giza'},
      'area': {'id': 121, 'name': 'Giza'},
      'requestsCount': 1,
      'incidentsCount': 2,
      'lastActivityDate': '2026-10-07T10:32:53.94',
    },
    {
      'location': {'id': 'D10736', 'name': 'site 3', 'code': null},
      'region': {'id': 79, 'name': 'Cairo'},
      'area': {'id': 103, 'name': 'Monshat Naser'},
      'requestsCount': 0,
      'incidentsCount': 1,
      'lastActivityDate': '2026-10-06T18:00:09.353',
    },
    {
      'location': {'id': 'D10739', 'name': 'site b2', 'code': null},
      'region': {'id': 81, 'name': 'Giza'},
      'area': {'id': 90, 'name': 'El Ayat'},
      'requestsCount': 0,
      'incidentsCount': 1,
      'lastActivityDate': '2026-10-06T15:53:26.133',
    },
  ],
};
const reportTeam = [
  IncidentTeamMember(
    id: 4099,
    name: 'engineer 1',
    userName: 'engA',
    mobile: '59003322',
  ),
  IncidentTeamMember(
    id: 4100,
    name: 'engineer 2',
    userName: 'engB',
    mobile: '50885566',
  ),
  IncidentTeamMember(
    id: 4101,
    name: 'engineer 3',
    userName: 'engC',
    mobile: '50112244',
  ),
];

class EngineerReportTestRepository
    implements EngineerLocationsReportRepository {
  final calls = <EngineerLocationsReportFilter>[];
  Result<EngineerLocationsReportData> result = Success(
    EngineerLocationsReportData.fromJson(engineerReportFixture),
  );
  Future<Result<EngineerLocationsReportData>> Function(
    EngineerLocationsReportFilter,
  )?
  handler;
  @override
  Future<Result<EngineerLocationsReportData>> getReport(
    EngineerLocationsReportFilter filter,
  ) async {
    calls.add(filter);
    return handler == null ? result : handler!(filter);
  }
}

EngineerLocationsReportCubit engineerReportTestCubit(
  EngineerReportTestRepository repo, {
  Result<List<IncidentTeamMember>> team = const Success(reportTeam),
  int userId = 4099,
  Future<Result<List<IncidentTeamMember>>> Function()? teamLoader,
}) => EngineerLocationsReportCubit(
  getReport: GetEngineerLocationsReportUseCase(repo),
  loadTeam: teamLoader ?? () async => team,
  currentUser: () =>
      SessionUser(id: userId.toString(), name: 'Signed-in engineer'),
  now: () => DateTime(2026, 10, 13),
);

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object? response = engineerReportFixture;
  int resultCode = 1;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'resultcode': resultCode, 'data': response}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'typed API response preserves actual counts, locations and nullable values',
    () {
      final data = EngineerLocationsReportData.fromJson(engineerReportFixture);
      expect(data.engineer!.id, 4099);
      expect(data.engineer!.name, 'engineer 1');
      expect(data.team, isNull);
      expect(data.jobTitle, isNull);
      expect(data.locationsCount, 3);
      expect(data.incidentsCount, 4);
      expect(data.requestsCount, 1);
      expect(data.locations, hasLength(3));
      expect(data.locations.first.location!.code, isNull);
      expect(data.locations.first.location!.id, 'D10738');
      expect(data.locations[1].area!.name, 'Monshat Naser');
      expect(data.locations.last.lastActivityDate, '2026-10-06T15:53:26.133');
      final empty = EngineerLocationsReportData.fromJson({
        'locations': [<String, dynamic>{}],
      });
      expect(empty.locationsCount, isNull);
      expect(empty.locations.single.location, isNull);
    },
  );
  test(
    'default engineer is session user, initial dates are current month',
    () async {
      final repo = EngineerReportTestRepository();
      var teamCalls = 0;
      final cubit = engineerReportTestCubit(
        repo,
        userId: 7777,
        teamLoader: () async {
          teamCalls++;
          return const Success(reportTeam);
        },
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();
      await cubit.loadInitial();
      expect(repo.calls.single.toJson(), {
        'FromDate': '2026-10-01',
        'ToDate': '2026-10-31',
        'EngineerUserId': 7777,
      });
      expect(cubit.engineers.keys, [7777, 4099, 4100, 4101]);
      expect(teamCalls, 1);
      expect(cubit.hasOtherEngineers, isTrue);
    },
  );
  test(
    'team IDs and dates are draft-only until Apply; reset restores signed-in user and month',
    () async {
      final repo = EngineerReportTestRepository();
      final cubit = engineerReportTestCubit(repo);
      addTearDown(cubit.close);
      await cubit.loadInitial();
      cubit.beginFilters();
      cubit.updateDraft(
        engineerUserId: 4101,
        fromDate: DateTime(2026, 9, 1),
        toDate: DateTime(2026, 9, 30),
      );
      expect(repo.calls, hasLength(1));
      expect(cubit.state.active.engineerUserId, 4099);
      cubit.cancelFilters();
      expect(repo.calls, hasLength(1));
      cubit.beginFilters();
      cubit.updateDraft(
        engineerUserId: 4100,
        fromDate: DateTime(2026, 9, 1),
        toDate: DateTime(2026, 9, 30),
      );
      expect(await cubit.applyFilters(), isTrue);
      expect(repo.calls.last.toJson(), {
        'FromDate': '2026-09-01',
        'ToDate': '2026-09-30',
        'EngineerUserId': 4100,
      });
      await cubit.refresh();
      expect(repo.calls.last.engineerUserId, 4100);
      cubit.beginFilters();
      cubit.resetDraft();
      expect(cubit.state.active.engineerUserId, 4100);
      await cubit.applyFilters();
      expect(repo.calls.last.toJson(), {
        'FromDate': '2026-10-01',
        'ToDate': '2026-10-31',
        'EngineerUserId': 4099,
      });
    },
  );
  test(
    'team deduplication, no subordinate users and invalid drafts are safe',
    () async {
      final repo = EngineerReportTestRepository();
      final cubit = engineerReportTestCubit(
        repo,
        team: Success([reportTeam.first, reportTeam.first]),
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();
      expect(cubit.hasOtherEngineers, isFalse);
      expect(cubit.state.team, hasLength(1));
      cubit.beginFilters();
      cubit.updateDraft(engineerUserId: 9999);
      expect(cubit.state.draft!.engineerUserId, 4099);
      cubit.updateDraft(fromDate: DateTime(2027));
      expect(await cubit.applyFilters(), isFalse);
      expect(cubit.state.filterError, isTrue);
      expect(repo.calls, hasLength(1));
    },
  );
  test(
    'team lookup failure does not block own report; stale report response cannot replace current data',
    () async {
      final repo = EngineerReportTestRepository();
      final cubit = engineerReportTestCubit(
        repo,
        team: const FailureResult(NetworkFailure()),
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();
      expect(cubit.state.data!.engineer!.id, 4099);
      expect(cubit.state.teamFailure, isA<NetworkFailure>());
      expect(cubit.state.failure, isNull);
      final old = Completer<Result<EngineerLocationsReportData>>();
      var calls = 0;
      repo.handler = (_) => ++calls == 1
          ? old.future
          : Future.value(
              Success(EngineerLocationsReportData(locationsCount: 88)),
            );
      final first = cubit.refresh();
      await cubit.refresh();
      old.complete(Success(EngineerLocationsReportData(locationsCount: 1)));
      await first;
      expect(cubit.state.data!.locationsCount, 88);
    },
  );
  test('invalid signed-in user never sends report or team requests', () async {
    final repo = EngineerReportTestRepository();
    var teamCalls = 0;
    final cubit = engineerReportTestCubit(
      repo,
      userId: 0,
      teamLoader: () async {
        teamCalls++;
        return const Success([]);
      },
    );
    addTearDown(cubit.close);
    await cubit.loadInitial();
    expect(repo.calls, isEmpty);
    expect(teamCalls, 0);
    expect(cubit.state.failure, isA<UnauthorizedFailure>());
  });
  test(
    'Retrofit sends exact selected engineer payload inside authenticated CAP metadata',
    () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://cap.test/api/'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final context = ApiRequestContextProvider(
        users: null,
        currentUser: () => const SessionUser(id: '4086', name: 'manager'),
        deviceInfo: CapDeviceAppInfoProvider(
          osVersion: '15.1',
          deviceType: 'iOS',
          appVersion: '1',
        ),
      );
      final repo = EngineerLocationsReportRepositoryImpl(
        ReportApiService(dio),
        context,
      );
      final filter = EngineerLocationsReportFilter(
        fromDate: DateTime(2026, 9, 1),
        toDate: DateTime(2026, 9, 30),
        engineerUserId: 4099,
      );
      final response = await repo.getReport(filter);
      expect(response, isA<Success<EngineerLocationsReportData>>());
      final request = adapter.requests.single;
      expect(request.uri.path, '/api/CAP/CapReport/GetEngineerLocationsReport');
      final body = jsonDecode(jsonEncode(request.data)) as Map;
      expect(body['userid'], 4086);
      expect(body['data'], filter.toJson());
      expect(body['lang'], anyOf('ar', 'en'));
      adapter.response = null;
      expect(
        await repo.getReport(filter),
        isA<FailureResult<EngineerLocationsReportData>>(),
      );
      adapter.response = engineerReportFixture;
      adapter.resultCode = 0;
      expect(
        await repo.getReport(filter),
        isA<FailureResult<EngineerLocationsReportData>>(),
      );
    },
  );
  for (final lang in ['en', 'ar']) {
    testWidgets(
      'original report UI and engineer/date filters fit narrow large text $lang',
      (tester) async {
        await services.reset();
        addTearDown(services.reset);
        final repo = EngineerReportTestRepository();
        services.registerFactory<EngineerLocationsReportCubit>(
          () => engineerReportTestCubit(repo),
        );
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: const EngineerSitesReportScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('engineer 1'), findsOneWidget);
        expect(find.text('2026-10-01 — 2026-10-31'), findsOneWidget);
        expect(find.text('Ahmed Mohamed'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('site b2'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('D10739'), findsOneWidget);
        await tester.tap(find.byTooltip(lang == 'ar' ? 'الفلاتر' : 'Filters'));
        await tester.pumpAndSettle();
        expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
        await tester.tap(find.text('engineer 1').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('engineer 2').last);
        await tester.pumpAndSettle();
        expect(repo.calls, hasLength(1));
        await tester.ensureVisible(
          find.text(lang == 'ar' ? 'تطبيق الفلاتر' : 'Apply Filters'),
        );
        await tester.tap(
          find.text(lang == 'ar' ? 'تطبيق الفلاتر' : 'Apply Filters'),
        );
        await tester.pumpAndSettle();
        expect(repo.calls.last.engineerUserId, 4100);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'own-only engineer list hides selector; empty and failure states do not show mock sites',
    (tester) async {
      await services.reset();
      addTearDown(services.reset);
      final repo = EngineerReportTestRepository()
        ..result = Success(
          EngineerLocationsReportData(
            engineer: EngineerLocationsReportData.fromJson(
              engineerReportFixture,
            ).engineer,
            locationsCount: 0,
            requestsCount: 0,
            incidentsCount: 0,
          ),
        );
      services.registerFactory<EngineerLocationsReportCubit>(
        () => engineerReportTestCubit(repo, team: const Success([])),
      );
      await tester.pumpWidget(
        const MaterialApp(home: EngineerSitesReportScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('No Site Activity'), findsOneWidget);
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      repo.result = const FailureResult(NetworkFailure('Report unavailable'));
      // Reopen the route to verify a first-load error rather than stale mock data.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(home: EngineerSitesReportScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Report unavailable'), findsOneWidget);
      expect(find.text('site b1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
