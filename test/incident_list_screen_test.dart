import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets(
    'tab return reloads the selected date range and preserves search',
    (tester) async {
      final filter = IncidentListFilter(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 3),
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
      await tester.pumpWidget(page(true));
      await tester.pump();
      expect(repo.calls, hasLength(2));
      expect(repo.calls.last, repo.calls.first);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Power',
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
      expect(repo.calls.length, 1);
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
