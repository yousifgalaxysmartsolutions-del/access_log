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
import 'package:access_log_plus/features/reports/data/api/report_api_service.dart';
import 'package:access_log_plus/features/reports/data/models/engineers_activity_report_models.dart';
import 'package:access_log_plus/features/reports/data/models/incident_report_models.dart';
import 'package:access_log_plus/features/reports/data/repositories/engineers_activity_report_repository_impl.dart';
import 'package:access_log_plus/features/reports/domain/repositories/engineers_activity_report_repository.dart';
import 'package:access_log_plus/features/reports/domain/usecases/get_engineers_activity_report_use_case.dart';
import 'package:access_log_plus/features/reports/domain/usecases/incident_report_use_cases.dart';
import 'package:access_log_plus/features/reports/presentation/bloc/engineers_activity_report_cubit.dart';
import 'package:access_log_plus/features/reports/presentation/bloc/engineer_locations_report_cubit.dart';
import 'package:access_log_plus/screens/reporting/engineer_activity_report_screen.dart';
import 'package:access_log_plus/screens/reporting/engineer_sites_report_screen.dart';
import 'incident_report_test.dart' show ReportTestRepository;
import 'engineer_locations_report_test.dart'
    show reportTeam, EngineerReportTestRepository, engineerReportTestCubit;

const activityEngineerFixture = <String, dynamic>{
  'groupBy': 'Engineer',
  'items': [
    {
      'engineerId': 4099,
      'engineerName': 'engineer 1',
      'team': null,
      'jobTitle': null,
      'locations': [
        {'id': 'D10738', 'name': 'site b1', 'code': null},
        {'id': 'D10739', 'name': 'site b2', 'code': null},
        {'id': 'D10736', 'name': 'site 3', 'code': null},
      ],
      'city': null,
      'engineers': null,
      'onHoldCount': 2,
      'completedCount': 0,
      'inProgressCount': 0,
      'assignedCount': 4,
    },
    {
      'engineerId': 4100,
      'engineerName': 'engineer 2',
      'team': null,
      'jobTitle': null,
      'locations': [
        {'id': 'D10734', 'name': 'site 1', 'code': null},
      ],
      'city': null,
      'engineers': null,
      'onHoldCount': 1,
      'completedCount': 0,
      'inProgressCount': 0,
      'assignedCount': 1,
    },
  ],
  'totalCount': 2,
  'page': 1,
  'pageSize': 100,
};
const activityCityFixture = <String, dynamic>{
  'groupBy': 'City',
  'items': [
    {
      'engineerId': null,
      'engineerName': null,
      'team': null,
      'jobTitle': null,
      'locations': null,
      'city': {'id': 79, 'name': 'Cairo'},
      'engineers': [
        {'id': 4099, 'name': 'engineer 1'},
        {'id': 4100, 'name': 'engineer 2'},
      ],
      'onHoldCount': 2,
      'completedCount': 0,
      'inProgressCount': 0,
      'assignedCount': 2,
    },
    {
      'engineerId': null,
      'engineerName': null,
      'team': null,
      'jobTitle': null,
      'locations': null,
      'city': {'id': 81, 'name': 'Giza'},
      'engineers': [
        {'id': 4099, 'name': 'engineer 1'},
      ],
      'onHoldCount': 1,
      'completedCount': 0,
      'inProgressCount': 0,
      'assignedCount': 1,
    },
    {
      'engineerId': null,
      'engineerName': null,
      'team': null,
      'jobTitle': null,
      'locations': null,
      'city': {'id': 111, 'name': 'Giza'},
      'engineers': [
        {'id': 4099, 'name': 'engineer 1'},
      ],
      'onHoldCount': 0,
      'completedCount': 0,
      'inProgressCount': 0,
      'assignedCount': 2,
    },
  ],
  'totalCount': 3,
  'page': 1,
  'pageSize': 100,
};

class ActivityReportTestRepository
    implements EngineersActivityReportRepository {
  final calls = <EngineersActivityReportFilter>[];
  Future<Result<EngineersActivityReportData>> Function(
    EngineersActivityReportFilter,
  )?
  handler;
  @override
  Future<Result<EngineersActivityReportData>> getReport(
    EngineersActivityReportFilter filter,
  ) async {
    calls.add(filter);
    return handler != null
        ? handler!(filter)
        : Success(
            EngineersActivityReportData.fromJson(
              filter.groupBy == EngineersActivityGroup.engineer
                  ? activityEngineerFixture
                  : activityCityFixture,
            ),
          );
  }
}

EngineersActivityReportCubit activityReportTestCubit(
  ActivityReportTestRepository repo, {
  ReportTestRepository? locations,
}) => EngineersActivityReportCubit(
  getReport: GetEngineersActivityReportUseCase(repo),
  getLocations: GetReportLocationsUseCase(locations ?? ReportTestRepository()),
  loadTeam: () async => const Success(reportTeam),
  currentUser: () => const SessionUser(id: '4086', name: 'manager'),
  now: () => DateTime(2026, 10, 14),
);
void registerActivityReportTestCubit() =>
    services.registerFactory<EngineersActivityReportCubit>(
      () => activityReportTestCubit(ActivityReportTestRepository()),
    );

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object? response;
  int code = 1;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = jsonDecode(jsonEncode(options.data)) as Map;
    return ResponseBody.fromString(
      jsonEncode({
        'resultcode': code,
        'data':
            response ??
            ((body['data'] as Map)['GroupBy'] == 'City'
                ? activityCityFixture
                : activityEngineerFixture),
      }),
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
    'expanded region loads real Engineer rows with RegionId and caches them',
    () async {
      final repo = ActivityReportTestRepository();
      final cubit = activityReportTestCubit(repo);
      addTearDown(cubit.close);
      await cubit.loadInitial();
      await cubit.changeGroup(EngineersActivityGroup.region);
      await cubit.loadRegion(81);
      expect(repo.calls.last.groupBy, EngineersActivityGroup.engineer);
      expect(repo.calls.last.regionId, 81);
      expect(repo.calls.last.toJson()['FromDate'], '2026-10-01');
      expect(cubit.state.regionDetails[81]!.items.first.assignedCount, 4);
      final calls = repo.calls.length;
      await cubit.loadRegion(81);
      expect(repo.calls, hasLength(calls));
      await cubit.changeGroup(EngineersActivityGroup.engineer);
      expect(cubit.state.regionDetails, isEmpty);
    },
  );
  test(
    'per-engineer site filters request server counters without mutating siblings or global filters',
    () async {
      final repo = ActivityReportTestRepository();
      final cubit = activityReportTestCubit(repo);
      addTearDown(cubit.close);
      await cubit.loadInitial();
      repo.handler = (filter) async => Success(
        EngineersActivityReportData(
          groupBy: filter.groupBy,
          totalCount: 1,
          items: [
            EngineersActivityReportItem(
              engineerId: 4099,
              engineerName: 'engineer 1',
              assignedCount: 17,
              onHoldCount: 6,
            ),
          ],
        ),
      );
      await cubit.selectEngineerSite(4099, 'D10739');
      expect(repo.calls.last.locationCode, 'D10739');
      expect(repo.calls.last.engineerUserId, 4099);
      expect(repo.calls.last.page, 1);
      expect(cubit.siteSelection(4099).data!.assignedCount, 17);
      expect(cubit.state.active.locationCode, '');
      expect(cubit.state.active.engineerUserId, -1);
      expect(cubit.state.data!.items.first.assignedCount, 4);
      expect(cubit.state.data!.items.last.assignedCount, 1);
      final calls = repo.calls.length;
      await cubit.selectEngineerSite(4099, '');
      expect(repo.calls, hasLength(calls));
      expect(cubit.siteSelection(4099).code, '');
      final older = Completer<Result<EngineersActivityReportData>>();
      repo.handler = (_) => older.future;
      final pending = cubit.selectEngineerSite(4099, 'D10738');
      await cubit.selectEngineerSite(4099, '');
      older.complete(
        Success(
          EngineersActivityReportData(groupBy: EngineersActivityGroup.engineer),
        ),
      );
      await pending;
      expect(cubit.siteSelection(4099).code, '');
      expect(cubit.siteSelection(4099).data, isNull);
    },
  );
  testWidgets(
    'original orange avatar, horizontal ChoiceChips and API site counters are restored',
    (tester) async {
      await services.reset();
      addTearDown(services.reset);
      final repo = ActivityReportTestRepository();
      final cubit = activityReportTestCubit(repo);
      services.registerFactory<EngineersActivityReportCubit>(() => cubit);
      await tester.pumpWidget(
        const MaterialApp(home: EngineerActivityReportScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Filter sites'), findsNWidgets(2));
      expect(find.byType(ChoiceChip), findsWidgets);
      repo.handler = (filter) async => Success(
        EngineersActivityReportData(
          groupBy: filter.groupBy,
          totalCount: 1,
          items: [
            EngineersActivityReportItem(
              engineerId: 4099,
              assignedCount: 17,
              onHoldCount: 6,
            ),
          ],
        ),
      );
      await tester.tap(find.text('site b2'));
      await tester.pumpAndSettle();
      expect(find.text('17'), findsOneWidget);
      expect(repo.calls.last.locationCode, 'D10739');
      await tester.tap(find.text('All Sites').first);
      await tester.pumpAndSettle();
      expect(find.text('17'), findsNothing);
      expect(cubit.siteSelection(4099).code, '');
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'both typed shapes preserve nullable fields, server counters and duplicate region names by ID',
    () {
      final engineer = EngineersActivityReportData.fromJson(
        activityEngineerFixture,
      );
      expect(engineer.items.first.assignedCount, 4);
      expect(engineer.items.first.locations, hasLength(3));
      expect(engineer.items.first.team, isNull);
      expect(engineer.items.first.city, isNull);
      expect(engineer.items.first.engineers, isEmpty);
      final city = EngineersActivityReportData.fromJson(activityCityFixture);
      expect(city.groupBy, EngineersActivityGroup.region);
      expect(city.items, hasLength(3));
      expect(city.items.map((e) => e.city!.id), [79, 81, 111]);
      expect(city.items.where((e) => e.city!.name == 'Giza'), hasLength(2));
      expect(city.items.first.assignedCount, 2);
      expect(city.items.first.engineers, hasLength(2));
      expect(city.items.first.locations, isEmpty);
      expect(
        () => EngineersActivityReportData.fromJson({'groupBy': 'Area'}),
        throwsFormatException,
      );
    },
  );
  test(
    'initial current-month all-engineer payload, group switching calls API and preserves filters',
    () async {
      final repo = ActivityReportTestRepository();
      final cubit = activityReportTestCubit(repo);
      addTearDown(cubit.close);
      await cubit.loadInitial();
      await cubit.loadInitial();
      expect(repo.calls.single.toJson(), {
        'FromDate': '2026-10-01',
        'ToDate': '2026-10-31',
        'RegionId': -1,
        'AreaId': -1,
        'GroupBy': 'Engineer',
        'EngineerUserId': -1,
        'LocationCode': '',
        'Page': 1,
        'PageSize': 100,
      });
      cubit.beginFilters();
      cubit.updateDraft(
        cubit.state.draft!.copyWith(
          engineerUserId: 4100,
          regionId: 81,
          areaId: 90,
          locationCode: 'D10739',
        ),
      );
      expect(repo.calls, hasLength(1));
      cubit.cancelFilters();
      expect(cubit.state.active.engineerUserId, -1);
      cubit.beginFilters();
      cubit.updateDraft(
        cubit.state.draft!.copyWith(
          engineerUserId: 4100,
          regionId: 81,
          areaId: 90,
          locationCode: 'D10739',
        ),
      );
      await cubit.applyFilters();
      await cubit.changeGroup(EngineersActivityGroup.region);
      expect(repo.calls.last.toJson(), {
        'FromDate': '2026-10-01',
        'ToDate': '2026-10-31',
        'RegionId': 81,
        'AreaId': 90,
        'GroupBy': 'City',
        'EngineerUserId': 4100,
        'LocationCode': 'D10739',
        'Page': 1,
        'PageSize': 100,
      });
      expect(cubit.state.data!.items, hasLength(3));
      await cubit.refresh();
      expect(repo.calls.last.groupBy, EngineersActivityGroup.region);
      cubit.beginFilters();
      cubit.resetDraft();
      await cubit.applyFilters();
      expect(repo.calls.last.groupBy, EngineersActivityGroup.region);
      expect(repo.calls.last.engineerUserId, -1);
      expect(repo.calls.last.regionId, -1);
    },
  );
  test(
    'location dependency, current-team IDs and invalid-date validation live in Cubit',
    () async {
      final repo = ActivityReportTestRepository();
      final locations = ReportTestRepository();
      final cubit = activityReportTestCubit(repo, locations: locations);
      addTearDown(cubit.close);
      await cubit.loadInitial();
      expect(cubit.engineers.keys, [4086, 4099, 4100, 4101]);
      expect(cubit.regions.map((e) => e.id), [81, 79]);
      cubit.beginFilters();
      cubit.updateDraft(
        cubit.state.draft!.copyWith(
          regionId: 81,
          areaId: 90,
          locationCode: 'D10739',
        ),
      );
      cubit.updateDraft(cubit.state.draft!.copyWith(regionId: 79));
      expect(cubit.state.draft!.areaId, -1);
      expect(cubit.state.draft!.locationCode, '');
      cubit.updateDraft(cubit.state.draft!.copyWith(fromDate: DateTime(2027)));
      expect(await cubit.applyFilters(), isFalse);
      expect(repo.calls, hasLength(1));
      cubit.resetDraft();
      cubit.cancelFilters();
      cubit.beginFilters();
      expect(locations.locationCalls, 1);
      cubit.setDraftRange(IncidentReportDateRange.today);
      expect(cubit.state.draft!.toJson()['FromDate'], '2026-10-14');
    },
  );
  test(
    'pagination stays server-side and late grouping response cannot overwrite current group',
    () async {
      final repo = ActivityReportTestRepository()
        ..handler = (filter) async => Success(
          EngineersActivityReportData(
            groupBy: filter.groupBy,
            totalCount: 201,
            page: filter.page,
            pageSize: filter.pageSize,
          ),
        );
      final cubit = activityReportTestCubit(repo);
      addTearDown(cubit.close);
      await cubit.loadInitial();
      await cubit.loadPage(2);
      expect(repo.calls.last.page, 2);
      final older = Completer<Result<EngineersActivityReportData>>();
      var calls = 0;
      repo.handler = (filter) => ++calls == 1
          ? older.future
          : Future.value(
              Success(
                EngineersActivityReportData.fromJson(activityCityFixture),
              ),
            );
      final first = cubit.refresh();
      await cubit.changeGroup(EngineersActivityGroup.region);
      older.complete(
        Success(EngineersActivityReportData.fromJson(activityEngineerFixture)),
      );
      await first;
      expect(cubit.state.data!.groupBy, EngineersActivityGroup.region);
      expect(repo.calls.last.page, 1);
    },
  );
  test(
    'unexpected response group is rejected without local conversion',
    () async {
      final repo = ActivityReportTestRepository()
        ..handler = (_) async =>
            Success(EngineersActivityReportData.fromJson(activityCityFixture));
      final result = await GetEngineersActivityReportUseCase(repo)(
        EngineersActivityReportFilter.currentMonth(DateTime(2026, 10, 14)),
      );
      expect(result, isA<FailureResult<EngineersActivityReportData>>());
    },
  );
  test(
    'Retrofit posts exact envelope and Engineer/City wire values with selected IDs',
    () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://cap.test/api/'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final context = ApiRequestContextProvider(
        users: null,
        currentUser: () => const SessionUser(id: '4086'),
        deviceInfo: CapDeviceAppInfoProvider(
          osVersion: '15.1',
          deviceType: 'iOS',
          appVersion: '1',
        ),
      );
      final repo = EngineersActivityReportRepositoryImpl(
        ReportApiService(dio),
        context,
      );
      for (final group in EngineersActivityGroup.values) {
        final filter = EngineersActivityReportFilter.currentMonth(
          DateTime(2026, 10, 14),
        ).copyWith(groupBy: group, engineerUserId: 4100, regionId: 79);
        expect(
          await repo.getReport(filter),
          isA<Success<EngineersActivityReportData>>(),
        );
        expect(
          adapter.requests.last.uri.path,
          '/api/CAP/CapReport/GetEngineersActivityReport',
        );
        final body = jsonDecode(jsonEncode(adapter.requests.last.data)) as Map;
        expect(body['userid'], 4086);
        expect(body['lang'], anyOf('ar', 'en'));
        expect(body['data'], filter.toJson());
      }
      adapter.code = 0;
      expect(
        await repo.getReport(
          EngineersActivityReportFilter.currentMonth(DateTime(2026, 10, 14)),
        ),
        isA<FailureResult<EngineersActivityReportData>>(),
      );
    },
  );
  for (final lang in ['en', 'ar']) {
    testWidgets(
      'UI only offers Engineer/Region and renders real City groups with large text $lang',
      (tester) async {
        await services.reset();
        addTearDown(services.reset);
        final repo = ActivityReportTestRepository();
        services.registerFactory<EngineersActivityReportCubit>(
          () => activityReportTestCubit(repo),
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
            home: const EngineerActivityReportScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('engineer 1'), findsOneWidget);
        expect(find.text('Ahmed Mohamed'), findsNothing);
        final dropdown = tester.widget<DropdownButton<EngineersActivityGroup>>(
          find.byType(DropdownButton<EngineersActivityGroup>),
        );
        expect(dropdown.items, hasLength(2));
        await tester.tap(
          find.byType(DropdownButtonFormField<EngineersActivityGroup>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(lang == 'ar' ? 'الإقليم' : 'Region').last);
        await tester.pumpAndSettle();
        expect(
          repo.calls
              .where((e) => e.groupBy == EngineersActivityGroup.region)
              .last
              .toJson()['GroupBy'],
          'City',
        );
        expect(find.text('Cairo'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('region-111-2')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Giza'), findsWidgets);
        final callsBeforeFilter = repo.calls.length;
        await tester.tap(
          find.byTooltip(lang == 'ar' ? 'فلاتر التقرير' : 'Report Filters'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(lang == 'ar' ? 'المهندس' : 'Engineer'),
          findsOneWidget,
        );
        await tester.tap(find.byType(DropdownButtonFormField<int>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('engineer 2').last);
        await tester.pumpAndSettle();
        expect(repo.calls, hasLength(callsBeforeFilter));
        await tester.tap(
          find.text(lang == 'ar' ? 'تطبيق الفلاتر' : 'Apply Filters'),
        );
        await tester.pumpAndSettle();
        final mainRequest = repo.calls
            .where((e) => e.groupBy == EngineersActivityGroup.region)
            .last;
        expect(mainRequest.engineerUserId, 4100);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'engineer drill-down uses real engineer ID and active dates, not prototype details',
    (tester) async {
      await services.reset();
      addTearDown(services.reset);
      final sites = EngineerReportTestRepository();
      registerActivityReportTestCubit();
      services.registerFactory<EngineerLocationsReportCubit>(
        () => engineerReportTestCubit(sites),
      );
      await tester.pumpWidget(
        const MaterialApp(home: EngineerActivityReportScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('engineer 1'));
      await tester.pumpAndSettle();
      expect(find.byType(EngineerSitesReportScreen), findsOneWidget);
      expect(sites.calls.single.engineerUserId, 4099);
      expect(sites.calls.single.toJson()['FromDate'], '2026-10-01');
    },
  );
  testWidgets('loading, empty and retry contain no fake engineer rows', (
    tester,
  ) async {
    await services.reset();
    addTearDown(services.reset);
    final repo = ActivityReportTestRepository();
    final gate = Completer<Result<EngineersActivityReportData>>();
    repo.handler = (_) => gate.future;
    services.registerFactory<EngineersActivityReportCubit>(
      () => activityReportTestCubit(repo),
    );
    await tester.pumpWidget(
      const MaterialApp(home: EngineerActivityReportScreen()),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete(
      const FailureResult(NetworkFailure('Activity report unavailable')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Activity report unavailable'), findsOneWidget);
    repo.handler = (filter) async =>
        Success(EngineersActivityReportData(groupBy: filter.groupBy));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No groups found'), findsOneWidget);
    expect(find.text('engineer 1'), findsNothing);
  });
}
