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
import 'package:access_log_plus/features/requests/data/models/request_models.dart';
import 'package:access_log_plus/features/requests/domain/repositories/request_repository.dart';
import 'package:access_log_plus/features/requests/domain/usecases/get_request_lookup_use_case.dart';
import 'package:access_log_plus/features/requests/presentation/bloc/request_details_cubit.dart';
import 'package:access_log_plus/features/reports/data/api/report_api_service.dart';
import 'package:access_log_plus/features/reports/data/models/incident_report_models.dart';
import 'package:access_log_plus/features/reports/data/models/requests_path_report_models.dart';
import 'package:access_log_plus/features/reports/data/repositories/requests_path_report_repository_impl.dart';
import 'package:access_log_plus/features/reports/domain/repositories/requests_path_report_repository.dart';
import 'package:access_log_plus/features/reports/domain/usecases/get_requests_path_report_use_case.dart';
import 'package:access_log_plus/features/reports/domain/usecases/incident_report_use_cases.dart';
import 'package:access_log_plus/features/reports/presentation/bloc/requests_path_report_cubit.dart';
import 'package:access_log_plus/screens/reporting/request_flow_report_screen.dart';
import 'package:access_log_plus/screens/requests/api_request_details_screen.dart';
import 'incident_report_test.dart' show ReportTestRepository;
import 'request_details_test.dart' show RequestDetailsTestCubit;

const pathReportFixture = <String, dynamic>{
  'summary': {
    'approvedCount': 1,
    'pendingDecisionCount': 1,
    'completedCount': 0,
    'rejectedCount': 1,
  },
  'items': [
    {
      'id': 3,
      'requestCode': 'INT-2026-0003',
      'incidentNo': 'INC-0003',
      'locationName': 'site 3',
      'requestType': {'id': 1, 'name': 'Intervention Request'},
      'requestStatus': {'id': 1, 'name': 'Pending'},
      'steps': [
        {
          'key': 'Created',
          'titleEn': 'Created',
          'titleAr': 'تم الإنشاء',
          'state': 'done',
          'dateTime': '2026-09-10T00:57:15.38',
        },
        {
          'key': 'Sent',
          'titleEn': 'Sent',
          'titleAr': 'تم الإرسال',
          'state': 'done',
          'dateTime': '2026-09-10T00:57:15.38',
        },
        {
          'key': 'UnderReview',
          'titleEn': 'Under Review',
          'titleAr': 'قيد المراجعة',
          'state': 'current',
          'dateTime': null,
        },
        {
          'key': 'Final',
          'titleEn': 'Pending Decision',
          'titleAr': 'القرار قيد الانتظار',
          'state': 'current',
          'dateTime': null,
        },
      ],
    },
    {
      'id': 1,
      'requestCode': 'INT-2026-0001',
      'incidentNo': 'INC-0001',
      'locationName': 'site 1',
      'requestType': {'id': 1, 'name': 'Intervention Request'},
      'requestStatus': {'id': 2, 'name': 'Approved'},
      'steps': [
        {
          'key': 'Created',
          'titleEn': 'Created',
          'titleAr': 'تم الإنشاء',
          'state': 'done',
          'dateTime': '2026-09-05T00:00:00',
        },
        {
          'key': 'Sent',
          'titleEn': 'Sent',
          'titleAr': 'تم الإرسال',
          'state': 'done',
          'dateTime': '2026-09-05T00:00:00',
        },
        {
          'key': 'UnderReview',
          'titleEn': 'Under Review',
          'titleAr': 'قيد المراجعة',
          'state': 'done',
          'dateTime': '2026-09-06T23:37:17.22',
        },
        {
          'key': 'Final',
          'titleEn': 'Approved',
          'titleAr': 'تمت الموافقة',
          'state': 'done',
          'dateTime': '2026-09-06T23:37:17.22',
        },
      ],
    },
    {
      'id': 2,
      'requestCode': 'REN-2026-0002',
      'incidentNo': 'INC-0001',
      'locationName': 'site 1',
      'requestType': {'id': 2, 'name': 'Renewal Request'},
      'requestStatus': {'id': 3, 'name': 'Rejected'},
      'steps': [
        {
          'key': 'Created',
          'titleEn': 'Created',
          'titleAr': 'تم الإنشاء',
          'state': 'done',
          'dateTime': '2026-09-05T00:00:00',
        },
        {
          'key': 'Sent',
          'titleEn': 'Sent',
          'titleAr': 'تم الإرسال',
          'state': 'done',
          'dateTime': '2026-09-05T00:00:00',
        },
        {
          'key': 'UnderReview',
          'titleEn': 'Under Review',
          'titleAr': 'قيد المراجعة',
          'state': 'done',
          'dateTime': '2026-09-07T01:33:42.047',
        },
        {
          'key': 'Final',
          'titleEn': 'Rejected',
          'titleAr': 'تم الرفض',
          'state': 'done',
          'dateTime': '2026-09-07T01:33:42.047',
        },
      ],
    },
  ],
  'totalCount': 3,
  'page': 1,
  'pageSize': 100,
};

class PathReportTestRepository implements RequestsPathReportRepository {
  final calls = <RequestsPathReportFilter>[];
  Result<RequestsPathReportData> result = Success(
    RequestsPathReportData.fromJson(pathReportFixture),
  );
  Future<Result<RequestsPathReportData>> Function(RequestsPathReportFilter)?
  handler;
  @override
  Future<Result<RequestsPathReportData>> getReport(
    RequestsPathReportFilter filter,
  ) async {
    calls.add(filter);
    return handler == null ? result : handler!(filter);
  }
}

class PathReportTestLookup implements RequestRepository {
  int calls = 0;
  Result<RequestLookupData> result = const Success(
    RequestLookupData(
      requestType: [
        RequestLookupItemDto(
          id: 11,
          name: 'Live request type',
          code: 'Intervention',
        ),
      ],
      requestStatus: [
        RequestLookupItemDto(
          id: 22,
          name: 'Live request status',
          code: 'PENDING',
        ),
      ],
    ),
  );
  @override
  Future<Result<RequestLookupData>> getRequestLookup() async {
    calls++;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RequestsPathReportCubit pathReportTestCubit(
  PathReportTestRepository repo, {
  PathReportTestLookup? lookup,
  ReportTestRepository? locations,
}) => RequestsPathReportCubit(
  getReport: GetRequestsPathReportUseCase(repo),
  getLookup: GetRequestLookupUseCase(lookup ?? PathReportTestLookup()),
  getLocations: GetReportLocationsUseCase(locations ?? ReportTestRepository()),
  now: () => DateTime(2026, 10, 13),
);

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object? response = pathReportFixture;
  int code = 1;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'resultcode': code, 'data': response}),
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
    'real response preserves summary and exact ordered bilingual steps/states',
    () {
      final data = RequestsPathReportData.fromJson(pathReportFixture);
      expect(data.summary!.approvedCount, 1);
      expect(data.summary!.pendingDecisionCount, 1);
      expect(data.summary!.completedCount, 0);
      expect(data.summary!.rejectedCount, 1);
      expect(data.items, hasLength(3));
      expect(data.items.first.id, 3);
      expect(data.items.first.steps.map((e) => e.key), [
        'Created',
        'Sent',
        'UnderReview',
        'Final',
      ]);
      expect(data.items.first.steps.map((e) => e.state), [
        'done',
        'done',
        'current',
        'current',
      ]);
      expect(data.items.first.steps.last.dateTime, isNull);
      expect(data.items.first.steps.last.titleAr, 'القرار قيد الانتظار');
      expect(data.items.last.steps.last.titleAr, 'تم الرفض');
      final sparse = RequestsPathReportData.fromJson({
        'items': [<String, dynamic>{}],
      });
      expect(sparse.summary, isNull);
      expect(sparse.items.single.steps, isEmpty);
    },
  );
  test(
    'month defaults, draft cancellation and confirmed request lookup wire IDs',
    () async {
      final repo = PathReportTestRepository();
      final lookup = PathReportTestLookup();
      final locations = ReportTestRepository();
      final cubit = pathReportTestCubit(
        repo,
        lookup: lookup,
        locations: locations,
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();
      await cubit.loadInitial();
      expect(repo.calls.single.toJson(), {
        'FromDate': '2026-10-01',
        'ToDate': '2026-10-31',
        'RegionId': -1,
        'AreaId': -1,
        'LocationCode': '',
        'IncidentTypeId': -1,
        'StatusId': -1,
        'Page': 1,
        'PageSize': 100,
      });
      cubit.beginFilters();
      cubit.updateDraft(
        cubit.state.draft!.copyWith(requestTypeId: 11, requestStatusId: 22),
      );
      expect(repo.calls, hasLength(1));
      expect(cubit.state.active.requestTypeId, -1);
      cubit.cancelFilters();
      expect(repo.calls, hasLength(1));
      cubit.beginFilters();
      cubit.updateDraft(
        cubit.state.draft!.copyWith(
          requestTypeId: cubit.state.lookup!.requestType.single.id,
          requestStatusId: cubit.state.lookup!.requestStatus.single.id,
          fromDate: DateTime(2026, 9, 1),
          toDate: DateTime(2026, 9, 30),
          range: IncidentReportDateRange.custom,
          regionId: 81,
          areaId: 90,
          locationCode: 'D10739',
          page: 4,
        ),
      );
      await cubit.applyFilters();
      expect(repo.calls.last.toJson(), {
        'FromDate': '2026-09-01',
        'ToDate': '2026-09-30',
        'RegionId': 81,
        'AreaId': 90,
        'LocationCode': 'D10739',
        'IncidentTypeId': 11,
        'StatusId': 22,
        'Page': 1,
        'PageSize': 100,
      });
      await cubit.refresh();
      expect(repo.calls.last.requestTypeId, 11);
      cubit.beginFilters();
      cubit.resetDraft();
      expect(cubit.state.active.requestTypeId, 11);
      await cubit.applyFilters();
      expect(
        repo.calls.last.toJson(),
        RequestsPathReportFilter.currentMonth(DateTime(2026, 10, 13)).toJson(),
      );
      expect(lookup.calls, 1);
      expect(locations.locationCalls, 1);
    },
  );
  test(
    'region/area/site options use GetLocations and incompatible draft choices are cleared',
    () async {
      final cubit = pathReportTestCubit(PathReportTestRepository());
      addTearDown(cubit.close);
      await cubit.loadInitial();
      expect(cubit.regions.map((e) => e.id), [81, 79]);
      cubit.beginFilters();
      cubit.updateDraft(
        cubit.state.draft!.copyWith(
          regionId: 81,
          areaId: 90,
          locationCode: 'D10739',
        ),
      );
      expect(cubit.areas.map((e) => e.id), [90]);
      cubit.updateDraft(cubit.state.draft!.copyWith(regionId: 79));
      expect(cubit.state.draft!.areaId, -1);
      expect(cubit.state.draft!.locationCode, '');
      expect(cubit.sites.single.id, 'D10736');
    },
  );
  test(
    'invalid dates do not request; pagination and refresh keep active filters',
    () async {
      final repo = PathReportTestRepository()
        ..handler = (filter) async => Success(
          RequestsPathReportData(
            totalCount: 201,
            page: filter.page,
            pageSize: filter.pageSize,
            items: RequestsPathReportData.fromJson(pathReportFixture).items,
          ),
        );
      final cubit = pathReportTestCubit(repo);
      addTearDown(cubit.close);
      await cubit.loadInitial();
      cubit.beginFilters();
      cubit.updateDraft(cubit.state.draft!.copyWith(fromDate: DateTime(2027)));
      expect(await cubit.applyFilters(), isFalse);
      expect(repo.calls, hasLength(1));
      cubit.cancelFilters();
      await cubit.loadPage(2);
      expect(repo.calls.last.page, 2);
      await cubit.refresh();
      expect(repo.calls.last.page, 2);
      await cubit.resetFilters();
      expect(repo.calls.last.page, 1);
    },
  );
  test(
    'late responses are ignored and filter options failure does not replace report data',
    () async {
      final repo = PathReportTestRepository();
      final lookup = PathReportTestLookup()
        ..result = const FailureResult(NetworkFailure());
      final cubit = pathReportTestCubit(repo, lookup: lookup);
      addTearDown(cubit.close);
      await cubit.loadInitial();
      expect(cubit.state.optionsFailure, isA<NetworkFailure>());
      expect(cubit.state.data!.items, hasLength(3));
      final older = Completer<Result<RequestsPathReportData>>();
      var count = 0;
      repo.handler = (_) => ++count == 1
          ? older.future
          : Future.value(Success(RequestsPathReportData(totalCount: 99)));
      final first = cubit.refresh();
      await cubit.refresh();
      older.complete(Success(RequestsPathReportData(totalCount: 1)));
      await first;
      expect(cubit.state.data!.totalCount, 99);
    },
  );
  test(
    'API endpoint and envelope use exact confirmed names and current session',
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
      final repo = RequestsPathReportRepositoryImpl(
        ReportApiService(dio),
        context,
      );
      final filter = RequestsPathReportFilter.currentMonth(
        DateTime(2026, 10, 13),
      ).copyWith(requestTypeId: 11, requestStatusId: 22);
      expect(
        await repo.getReport(filter),
        isA<Success<RequestsPathReportData>>(),
      );
      final request = adapter.requests.single;
      expect(request.uri.path, '/api/CAP/CapReport/GetRequestsPathReport');
      final body = jsonDecode(jsonEncode(request.data)) as Map;
      expect(body['userid'], 4086);
      expect(body['lang'], anyOf('ar', 'en'));
      expect(body['data'], filter.toJson());
      expect((body['data'] as Map).containsKey('RequestTypeId'), isFalse);
      adapter.response = null;
      expect(
        await repo.getReport(filter),
        isA<FailureResult<RequestsPathReportData>>(),
      );
      adapter.response = pathReportFixture;
      adapter.code = 0;
      expect(
        await repo.getReport(filter),
        isA<FailureResult<RequestsPathReportData>>(),
      );
    },
  );
  for (final lang in ['en', 'ar']) {
    testWidgets(
      'original flow UI renders server steps and request/location filters at narrow large text $lang',
      (tester) async {
        await services.reset();
        addTearDown(services.reset);
        final repo = PathReportTestRepository();
        services.registerFactory<RequestsPathReportCubit>(
          () => pathReportTestCubit(repo),
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
            home: const RequestFlowReportScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('INT-2026-0003'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(lang == 'ar' ? 'تم الإنشاء' : 'Created'),
          findsWidgets,
        );
        expect(
          find.text(lang == 'ar' ? 'الخطوة الحالية' : 'Current step'),
          findsNWidgets(2),
        );
        expect(find.textContaining('REQ-2026-'), findsNothing);
        await tester.tap(
          find.byTooltip(lang == 'ar' ? 'فلاتر الطلبات' : 'Request Filters'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(lang == 'ar' ? 'نوع الطلب' : 'Request Type'),
          findsOneWidget,
        );
        await tester.tap(find.byType(DropdownButtonFormField<int>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Live request type').last);
        await tester.pumpAndSettle();
        expect(repo.calls, hasLength(1));
        await tester.tap(
          find.text(lang == 'ar' ? 'تطبيق الفلاتر' : 'Apply Filters'),
        );
        await tester.pumpAndSettle();
        expect(repo.calls.last.toJson()['IncidentTypeId'], 11);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('flow card opens actual API request details using request ID', (
    tester,
  ) async {
    await services.reset();
    addTearDown(services.reset);
    services.registerFactory<RequestsPathReportCubit>(
      () => pathReportTestCubit(PathReportTestRepository()),
    );
    services.registerFactory<RequestDetailsCubit>(
      () => RequestDetailsTestCubit(),
    );
    await tester.pumpWidget(const MaterialApp(home: RequestFlowReportScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('INT-2026-0003'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('INT-2026-0003'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ApiRequestDetailsScreen>(find.byType(ApiRequestDetailsScreen))
          .requestId,
      3,
    );
    expect(find.text('Request #3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('loading, empty and failure states contain no fake requests', (
    tester,
  ) async {
    await services.reset();
    addTearDown(services.reset);
    final repo = PathReportTestRepository();
    final gate = Completer<Result<RequestsPathReportData>>();
    repo.handler = (_) => gate.future;
    services.registerFactory<RequestsPathReportCubit>(
      () => pathReportTestCubit(repo),
    );
    await tester.pumpWidget(const MaterialApp(home: RequestFlowReportScreen()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete(
      Success(
        RequestsPathReportData(
          summary: const RequestsPathReportSummary(
            approvedCount: 0,
            pendingDecisionCount: 0,
            completedCount: 0,
            rejectedCount: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No Requests Available'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.handler = null;
    repo.result = const FailureResult(ServerFailure('Path report unavailable'));
    await tester.pumpWidget(const MaterialApp(home: RequestFlowReportScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Path report unavailable'), findsOneWidget);
    expect(find.text('INT-2026-0003'), findsNothing);
    repo.result = Success(RequestsPathReportData());
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No Requests Available'), findsOneWidget);
  });
}
