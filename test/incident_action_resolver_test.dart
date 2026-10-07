import 'dart:async';
import 'package:access_log_plus/features/incidents/domain/repositories/incident_execution_repository.dart';
import 'package:access_log_plus/features/incidents/domain/actions/incident_execution_context.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/incident_execution_use_case.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_action_configuration_models.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/incident_action_configuration_repository.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_action_configuration_use_case.dart';
import 'package:access_log_plus/features/forms/data/models/cap_form_models.dart';
import 'package:access_log_plus/features/forms/domain/repositories/cap_form_repository.dart';
import 'package:access_log_plus/features/forms/domain/usecases/cap_form_use_cases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/di/injection.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/incidents/data/incident_lookup_store.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_lookup_models.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_details_models.dart';
import 'package:access_log_plus/features/incidents/data/repositories/demo_incident_repository.dart';
import 'package:access_log_plus/features/incidents/data/repositories/demo_incident_details_repository.dart';
import 'package:access_log_plus/features/incidents/domain/actions/incident_available_action.dart';
import 'package:access_log_plus/features/incidents/domain/actions/incident_action_resolver_service.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_lookup_use_case.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_details_use_case.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_timeline_use_case.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_requests_use_case.dart';
import 'package:access_log_plus/features/incidents/presentation/bloc/incident_details_bloc.dart';
import 'package:access_log_plus/features/incidents/presentation/widgets/incident_action_area.dart';
import 'package:access_log_plus/screens/incidents/incident_details_screen.dart';
import 'package:access_log_plus/widgets/app_button.dart';
import 'incident_lookup_test.dart' show fixture, MemoryStorage;
import 'incident_details_general_tab_test.dart' show buildIncident;

class _NoRequirements implements IncidentActionConfigurationRepository {
  final ids = <int>[];
  @override
  Future<Result<IncidentActionConfiguration?>> getConfiguration(
    int actionTypeId,
  ) async {
    ids.add(actionTypeId);
    return const Success(null);
  }
}

class _UnusedForms implements CapFormRepository {
  @override
  Future<Result<CapQuestionForm>> load(int formId) =>
      throw StateError('No form for null config');
  @override
  Future<Result<void>> submit(IncidentFormSubmission submission) =>
      throw StateError('No final execution');
}

class _UnusedExecution implements IncidentExecutionRepository {
  final executed = <IncidentExecutionContext>[];
  @override
  Future<Result<List<IncidentTeamMember>>> getTeam() =>
      throw StateError('No team load before continue');
  @override
  Future<Result<void>> execute(IncidentExecutionContext context) async {
    executed.add(context);
    return const Success(null);
  }
}

class _Lookup extends DemoIncidentRepository {
  IncidentLookupData value = IncidentLookupData.fromJson(
    fixture['data']! as Map<String, dynamic>,
  );
  @override
  Future<Result<IncidentLookupData>> getIncidentLookup() async =>
      Success(value);
}

class _Details extends DemoIncidentDetailsRepository {
  int calls = 0;
  Completer<Result<IncidentDetailsData>>? gate;
  IncidentDetailsData value = const IncidentDetailsData(
    status: IdNameDto(id: 2, name: 'Need Approval'),
  );
  @override
  Future<Result<IncidentDetailsData>> getIncidentDetails({
    required int incidentId,
    required String incidentNo,
  }) {
    calls++;
    return gate?.future ?? Future.value(Success(value));
  }
}

void main() {
  late SessionManager session;
  late _Lookup repository;
  late IncidentLookupStore store;
  late IncidentActionResolverService resolver;
  setUp(() async {
    session = SessionManager(MemoryStorage());
    await session.signIn(const SessionTokens('test', 'test'));
    repository = _Lookup();
    store = IncidentLookupStore(GetIncidentLookupUseCase(repository), session);
    resolver = IncidentActionResolverService(store);
    await store.refresh();
  });
  tearDown(() async {
    await services.reset();
    await store.dispose();
    await session.dispose();
  });

  final expected = <int?, List<IncidentAction>>{
    1: [IncidentAction.assign, IncidentAction.cancel],
    2: [IncidentAction.approve, IncidentAction.reject],
    3: [IncidentAction.hold, IncidentAction.interventionRequest],
    4: [
      IncidentAction.hold,
      IncidentAction.renewalRequest,
      IncidentAction.complete,
    ],
    5: [IncidentAction.departureRequest],
    6: [],
    7: [],
    8: [],
    999: [],
    null: [],
  };
  for (final entry in expected.entries) {
    test('status ${entry.key} resolves exact approved actions', () {
      final actions = resolver.resolve(incidentStatusId: entry.key);
      expect(actions.map((a) => a.type), entry.value);
      for (final action in actions) {
        expect(
          action.flow,
          action.type == IncidentAction.assign
              ? IncidentActionFlow.assign
              : [
                  IncidentAction.interventionRequest,
                  IncidentAction.renewalRequest,
                  IncidentAction.departureRequest,
                ].contains(action.type)
              ? IncidentActionFlow.request
              : IncidentActionFlow.actionType,
        );
      }
    });
  }

  test(
    'changed status and action IDs use latest codes, not names or fixed IDs',
    () async {
      expect(resolver.resolve(incidentStatusId: 2).first.actionTypeId, 3);
      repository.value = IncidentLookupData(
        status: const [
          IncidentLookupItem(id: 12, name: 'Pending', code: ' NEED_APPROVAL '),
        ],
        actionType: const [
          IncidentLookupItem(
            id: 30,
            name: 'Different translation',
            code: 'APPROVE',
          ),
          IncidentLookupItem(id: 40, code: 'reject'),
        ],
      );
      await store.refresh();
      final actions = resolver.resolve(incidentStatusId: 12);
      expect(actions.map((a) => a.type), [
        IncidentAction.approve,
        IncidentAction.reject,
      ]);
      expect(actions.map((a) => a.actionTypeId), [30, 40]);
      expect(resolver.resolve(incidentStatusId: 2), isEmpty);
    },
  );

  test('Hold raw spaces preserved; request metadata is ActionTypeId', () {
    final actions = resolver.resolve(incidentStatusId: 4);
    expect(actions.first.actionTypeId, 8);
    expect(store.current!.actionType[7].code, ' Hold');
    expect(actions[1].actionTypeId, 6);
    expect(actions[1].flow, IncidentActionFlow.request);
  });

  test('missing lookup status codes or action IDs fail closed', () async {
    store.clear();
    expect(resolver.resolve(incidentStatusId: 2), isEmpty);
    for (final code in [null, '', 'UNKNOWN']) {
      repository.value = IncidentLookupData(
        status: [IncidentLookupItem(id: 2, name: 'Need Approval', code: code)],
      );
      await store.refresh();
      expect(resolver.resolve(incidentStatusId: 2), isEmpty);
    }
    repository.value = IncidentLookupData(
      status: const [IncidentLookupItem(id: 2, code: 'NEED_APPROVAL')],
      actionType: const [IncidentLookupItem(id: 4, code: 'Reject')],
    );
    await store.refresh();
    expect(resolver.resolve(incidentStatusId: 2).map((a) => a.type), [
      IncidentAction.reject,
    ]);
    repository.value = IncidentLookupData(
      status: repository.value.status,
      actionType: const [
        IncidentLookupItem(code: 'Approve'),
        IncidentLookupItem(id: 0, code: 'Reject'),
      ],
    );
    await store.refresh();
    expect(resolver.resolve(incidentStatusId: 2), isEmpty);
  });

  test('ambiguous lookup matches are omitted rather than guessed', () async {
    repository.value = IncidentLookupData(
      status: repository.value.status,
      actionType: const [
        IncidentLookupItem(id: 3, code: 'Approve'),
        IncidentLookupItem(id: 30, code: 'approve'),
      ],
    );
    await store.refresh();
    expect(resolver.resolve(incidentStatusId: 2), isEmpty);
  });

  Widget app(Widget child, {String lang = 'en', double scale = 1}) =>
      MaterialApp(
        locale: Locale(lang),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      );

  for (final entry in expected.entries) {
    testWidgets('area renders ${entry.value.length} buttons for ${entry.key}', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            bottomNavigationBar: IncidentActionArea(
              actions: resolver.resolve(incidentStatusId: entry.key),
              onActionSelected: (_) {},
            ),
          ),
        ),
      );
      expect(find.byType(AppButton), findsNWidgets(entry.value.length));
      if (entry.value.isEmpty) {
        expect(find.text('No available actions'), findsOneWidget);
      }
      expect(find.text('Resume Activity'), findsNothing);
    });
  }

  testWidgets(
    'callback receives complete resolved metadata, loading hides actions',
    (tester) async {
      IncidentAvailableAction? selected;
      final actions = resolver.resolve(incidentStatusId: 2);
      await tester.pumpWidget(
        app(
          Scaffold(
            bottomNavigationBar: IncidentActionArea(
              actions: actions,
              onActionSelected: (action) => selected = action,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Approve'));
      expect(selected, same(actions.first));
      expect(selected!.type, IncidentAction.approve);
      expect(selected!.flow, IncidentActionFlow.actionType);
      expect(selected!.actionTypeId, 3);
      await tester.pumpWidget(
        app(
          Scaffold(
            bottomNavigationBar: IncidentActionArea(
              actions: actions,
              loading: true,
              onActionSelected: (_) {},
            ),
          ),
        ),
      );
      expect(find.byType(AppButton), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('Arabic RTL and English large text fit narrow action area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final lang in ['ar', 'en']) {
      await tester.pumpWidget(
        app(
          Scaffold(
            bottomNavigationBar: IncidentActionArea(
              actions: resolver.resolve(incidentStatusId: 4),
              onActionSelected: (_) {},
            ),
          ),
          lang: lang,
          scale: 2,
        ),
      );
      expect(
        Directionality.of(tester.element(find.byType(IncidentActionArea))),
        lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(find.byType(AppButton), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'real details drives action; null configuration skips requirements and refreshes after execution',
    (tester) async {
      final details = _Details()
        ..gate = Completer<Result<IncidentDetailsData>>();
      final bloc = IncidentDetailsBloc(
        getIncidentDetails: GetIncidentDetailsUseCase(details),
        getIncidentTimeline: GetIncidentTimelineUseCase(details),
        getIncidentRequests: GetIncidentRequestsUseCase(details),
      );
      services.registerFactory<IncidentDetailsBloc>(() => bloc);
      services.registerSingleton<IncidentActionResolverService>(resolver);
      final configuration = _NoRequirements();
      services.registerSingleton<IncidentExecutionRepository>(
        _UnusedExecution(),
      );
      services.registerSingleton<IncidentExecutionUseCase>(
        IncidentExecutionUseCase(services<IncidentExecutionRepository>()),
      );
      services.registerSingleton<GetIncidentActionConfigurationUseCase>(
        GetIncidentActionConfigurationUseCase(configuration),
      );
      services.registerSingleton<GetCapFormUseCase>(
        GetCapFormUseCase(_UnusedForms()),
      );
      await tester.pumpWidget(
        app(IncidentDetailsScreen(incident: buildIncident())),
      );
      await tester.pump();
      expect(find.byType(AppButton), findsNothing);
      expect(details.calls, 1);
      details.gate!.complete(Success(details.value));
      await tester.pumpAndSettle();
      final area = find.byType(IncidentActionArea);
      expect(
        find.descendant(of: area, matching: find.text('Approve')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: area, matching: find.text('Reject')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: area, matching: find.text('Hold')),
        findsNothing,
      );
      expect(
        find.descendant(of: area, matching: find.text('New Request')),
        findsNothing,
      );
      await tester.tap(
        find.descendant(of: area, matching: find.text('Approve')),
      );
      await tester.pumpAndSettle();
      expect(configuration.ids, [3]);
      expect(find.text('Ready to continue'), findsNothing);
      final executor =
          services<IncidentExecutionRepository>() as _UnusedExecution;
      expect(executor.executed, hasLength(1));
      expect(executor.executed.single.incidentId, buildIncident().incidentId);
      expect(executor.executed.single.actionTypeId, 3);
      expect(executor.executed.single.newStatusId, 3);
      expect(details.calls, 2);
      expect(find.text('Action completed successfully'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
