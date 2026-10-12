import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/incidents/data/incident_lookup_store.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_lookup_models.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_lookup_use_case.dart';
import 'package:access_log_plus/core/di/injection.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_list_use_case.dart';
import 'package:access_log_plus/features/incidents/presentation/bloc/incident_list_bloc.dart';
import 'package:access_log_plus/models/models.dart';
import 'package:access_log_plus/screens/incidents/incident_list_screen.dart';
import 'package:access_log_plus/widgets/cap_incident_card.dart';
import 'package:access_log_plus/widgets/skeleton_shimmer.dart';
import 'incident_list_bloc_test.dart' show ListRepositoryFake, apiIncident;

void main() {
  late ListRepositoryFake repo;
  setUp(() {
    repo = ListRepositoryFake()
      ..result = Success([
        apiIncident(81),
        apiIncident(82, status: 'In Process', priority: 'Low'),
      ]);
    services.registerSingleton<GetIncidentListUseCase>(
      GetIncidentListUseCase(repo),
    );
  });
  tearDown(() async => services.reset());
  Future<void> open(
    WidgetTester tester, {
    IncidentListFilter? filter,
    String lang = 'en',
    void Function(Object?)? onNavigate,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(lang),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        onGenerateRoute: (settings) {
          onNavigate?.call(settings.arguments);
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Details')),
          );
        },
        home: IncidentListScreen(initialFilter: filter),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> registerLookup() async {
    FlutterSecureStorage.setMockInitialValues({});
    final session = SessionManager(SecureStorageService())..startDemo();
    services.registerSingleton<SessionManager>(
      session,
      dispose: (value) => value.dispose(),
    );
    repo.lookupResult = Success(
      IncidentLookupData(
        status: const [
          IncidentLookupItem(
            id: 82,
            name: 'Backend Status',
            code: 'FULLY_REJECTED',
          ),
        ],
        priority: const [IncidentLookupItem(id: 31, name: 'Backend Priority')],
        incidentType: const [IncidentLookupItem(id: 72, name: 'Backend Type')],
      ),
    );
    services.registerSingleton<IncidentLookupStore>(
      IncidentLookupStore(GetIncidentLookupUseCase(repo), session),
      dispose: (value) => value.dispose(),
    );
  }

  testWidgets(
    'lookup dropdown IDs and manual fields reach API filters; refresh and reset work',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await registerLookup();
      await open(tester);
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      final dropdowns = find.byType(DropdownButtonFormField<int>);
      expect(dropdowns, findsNWidgets(3));
      expect(
        tester
            .widget<DropdownButton<int>>(find.byType(DropdownButton<int>).at(0))
            .items!
            .map((item) => item.value),
        [-1, 72],
      );
      tester.widget<DropdownButtonFormField<int>>(dropdowns.at(0)).onChanged!(
        72,
      );
      await tester.pump();
      tester.widget<DropdownButtonFormField<int>>(dropdowns.at(1)).onChanged!(
        82,
      );
      await tester.pump();
      tester.widget<DropdownButtonFormField<int>>(dropdowns.at(2)).onChanged!(
        31,
      );
      await tester.pump();
      Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.enterText(field('Location code'), 'D10739');
      await tester.enterText(field('Incident number'), 'INC-001');
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(repo.calls, hasLength(2));
      expect(repo.statusIds.last, 82);
      expect(repo.filters.last?.priorityId, 31);
      expect(repo.filters.last?.incidentTypeId, 72);
      expect(repo.filters.last?.locationCode, 'D10739');
      expect(repo.filters.last?.incidentNumber, 'INC-001');
      // The server response is authoritative, not filtered again by guessed enums.
      expect(find.byType(CapIncidentCard), findsNWidgets(2));
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(repo.filters.last?.incidentTypeId, 72);
      tester.widget<InputChip>(find.byType(InputChip)).onDeleted!();
      await tester.pumpAndSettle();
      expect(repo.statusIds.last, -1);
      expect(repo.filters.last?.priorityId, 31);
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(repo.statusIds.last, -1);
      expect(repo.filters.last?.priorityId, isNull);
      expect(repo.filters.last?.incidentTypeId, isNull);
      expect(repo.filters.last?.locationCode, isNull);
      expect(repo.filters.last?.incidentNumber, isNull);
    },
  );

  testWidgets(
    'tab return clears filters and search and displays fresh default-day results',
    (tester) async {
      final filter = IncidentListFilter(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 3),
        status: CapIncidentStatus.inProcess,
        priority: Priority.low,
      );
      Widget page(bool active) => MaterialApp(
        home: Scaffold(
          body: IncidentListScreen(isActive: active, initialFilter: filter),
        ),
      );
      await tester.pumpWidget(page(true));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'Power');
      await tester.pumpWidget(page(false));
      await tester.pump();
      expect(repo.calls, hasLength(1));
      repo.result = Success([
        apiIncident(99, status: 'Pending', priority: 'High'),
      ]);
      await tester.pumpWidget(page(true));
      await tester.pump();
      expect(repo.calls, hasLength(2));
      final today = IncidentListBloc.dayOnly(DateTime.now());
      expect(repo.calls.last, (today, today));
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '',
      );
      expect(
        tester
            .widget<CapIncidentCard>(find.byType(CapIncidentCard))
            .incident
            .incidentId,
        99,
      );
      await tester.pumpWidget(page(true));
      await tester.pump();
      expect(repo.calls, hasLength(2));
    },
  );

  testWidgets(
    'applying non-date filters stays local; date changes refetch; priority and date sorts',
    (tester) async {
      await open(tester);
      Future<void> apply(IncidentListFilter value) async {
        await tester.tap(find.text('Filters'));
        await tester.pumpAndSettle();
        Navigator.of(
          tester.element(find.byType(IncidentFilterSheet)),
        ).pop(value);
        await tester.pumpAndSettle();
      }

      await apply(
        const IncidentListFilter(
          status: CapIncidentStatus.inProcess,
          priority: Priority.low,
        ),
      );
      expect(repo.calls.length, 1);
      expect(
        tester
            .widget<CapIncidentCard>(find.byType(CapIncidentCard))
            .incident
            .incidentId,
        82,
      );
      await apply(
        IncidentListFilter(
          from: DateTime(2026, 9, 1),
          to: DateTime(2026, 9, 30),
        ),
      );
      expect(repo.calls.length, 2);
      final menu = tester.widget<PopupMenuButton<IncidentSort>>(
        find.byType(PopupMenuButton<IncidentSort>),
      );
      menu.onSelected!(IncidentSort.priority);
      await tester.pump();
      expect(
        tester
            .widget<CapIncidentCard>(find.byType(CapIncidentCard).first)
            .incident
            .incidentId,
        81,
      );
      menu.onSelected!(IncidentSort.oldest);
      await tester.pump();
      expect(
        tester
            .widget<CapIncidentCard>(find.byType(CapIncidentCard).first)
            .incident
            .incidentId,
        81,
      );
      repo.result = Success([
        apiIncident(81, date: '2026-09-25'),
        apiIncident(82, date: '2026-09-01'),
      ]);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CapIncidentCard>(find.byType(CapIncidentCard).first)
            .incident
            .incidentId,
        82,
      );
      expect(repo.calls.length, 3);
    },
  );

  testWidgets('today loads once; search locally; real ID navigates', (
    tester,
  ) async {
    Object? argument;
    await open(tester, onNavigate: (value) => argument = value);
    expect(
      repo.calls.single,
      IncidentListBloc.range(const IncidentListFilter()),
    );
    await tester.enterText(find.byType(TextField), 'inc-81');
    await tester.pump();
    expect(find.byType(CapIncidentCard), findsOneWidget);
    expect(repo.calls.length, 1);
    await tester.tap(find.byType(CapIncidentCard));
    await tester.pumpAndSettle();
    expect((argument as CapIncident).incidentId, 81);
  });
  testWidgets(
    'initial date + every local text filter; chip clears only status',
    (tester) async {
      await open(
        tester,
        filter: IncidentListFilter(
          from: DateTime(2026, 9, 1),
          to: DateTime(2026, 9, 30),
          status: CapIncidentStatus.pending,
          priority: Priority.high,
          region: 'cAi',
          area: 'CENT',
          site: '81',
          incidentNumber: '81',
          type: 'pow',
          location: 'tower',
        ),
      );
      expect(repo.calls.single, (DateTime(2026, 9, 1), DateTime(2026, 9, 30)));
      expect(find.byType(CapIncidentCard), findsOneWidget);
      tester.widget<InputChip>(find.byType(InputChip)).onDeleted!();
      await tester.pump();
      expect(find.byType(CapIncidentCard), findsOneWidget);
      expect(repo.calls.length, 2);
      await tester.enterText(find.byType(TextField), 'nonexistent');
      await tester.pump();
      expect(find.text('No incidents found'), findsOneWidget);
    },
  );
  testWidgets(
    'skeleton, initial error retry, refresh keeps data, reset returns today',
    (tester) async {
      final gate = Completer<Result<List<CapIncident>>>();
      repo.gate = gate;
      await open(
        tester,
        filter: IncidentListFilter(from: DateTime(2026, 9, 1)),
      );
      expect(find.byType(SkeletonBox), findsWidgets);
      gate.complete(const FailureResult(NetworkFailure()));
      repo.gate = null;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(CapIncidentCard), findsWidgets);
      repo.result = const FailureResult(NetworkFailure());
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.byType(CapIncidentCard), findsWidgets);
      expect(repo.calls.last, (DateTime(2026, 9, 1), DateTime(2026, 9, 1)));
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(
        repo.calls.last,
        IncidentListBloc.range(const IncidentListFilter()),
      );
    },
  );
  testWidgets('empty API result is not error and Arabic layout renders', (
    tester,
  ) async {
    repo.result = const Success([]);
    await open(tester, lang: 'ar');
    expect(find.text('لا توجد بلاغات'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
