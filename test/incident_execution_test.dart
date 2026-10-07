import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/incidents/data/api/incident_api_service.dart';
import 'package:access_log_plus/features/incidents/data/incident_lookup_store.dart';
import 'package:access_log_plus/features/incidents/data/repositories/incident_action_configuration_repository_impl.dart';
import 'package:access_log_plus/features/incidents/data/repositories/incident_execution_repository_impl.dart';
import 'package:access_log_plus/features/incidents/domain/actions/incident_action_resolver_service.dart';
import 'package:access_log_plus/features/incidents/domain/actions/incident_available_action.dart';
import 'package:access_log_plus/features/incidents/domain/actions/incident_execution_context.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_action_configuration_use_case.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/incident_execution_use_case.dart';
import 'package:access_log_plus/features/incidents/presentation/bloc/incident_action_configuration_cubit.dart';
import 'package:access_log_plus/features/incidents/presentation/incident_action_configuration_screen.dart';
import 'package:access_log_plus/features/forms/data/api/cap_form_api_service.dart';
import 'package:access_log_plus/features/forms/data/models/cap_form_models.dart';
import 'package:access_log_plus/features/forms/data/repositories/cap_form_repository_impl.dart';
import 'package:access_log_plus/features/forms/domain/usecases/cap_form_use_cases.dart';
import 'package:access_log_plus/features/forms/presentation/bloc/cap_form_cubit.dart';

class _UnusedLookup implements IncidentLookupStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('No lookup');
}

class _Transport implements HttpClientAdapter {
  Object? configuration;
  Object? team = [
    {
      'id': 4099,
      'name': 'engineer 1',
      'userName': 'engA',
      'mobile': '59003322',
    },
    {
      'id': 4100,
      'name': 'engineer 2',
      'userName': 'engB',
      'mobile': '50885566',
    },
  ];
  final calls = <RequestOptions>[];
  final trace = <String>[];
  bool failMutation = false, failTeam = false;
  Completer<void>? mutationGate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    final endpoint = options.path.split('/').last;
    trace.add(endpoint);
    Object? data;
    var code = 1;
    switch (endpoint) {
      case 'GetIncedientActionConfiguration':
        data = configuration;
      case 'GetMyTeamUser':
        data = team;
        code = failTeam ? 0 : 1;
      case 'GetFormQuestion':
        data = {
          'FormId': 1087,
          'Title': 'Test form',
          'taskquestion': [
            {
              'QuestionID': 702,
              'QuestionName': 'Serial',
              'QuestionTypeID': 1,
              'QuestionMendatory': true,
              'QuestionAnswer': null,
            },
          ],
        };
      case 'AssignIncident':
      case 'IncidentStatusChange':
        if (mutationGate != null) await mutationGate!.future;
        code = failMutation ? 0 : 1;
      default:
        throw StateError('Unexpected endpoint: $endpoint');
    }
    return ResponseBody.fromString(
      jsonEncode({
        'resultcode': code,
        'resultmessageen': code == 1 ? 'Success' : 'Rejected by server',
        'data': data,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> payload(String endpoint) => Map<String, dynamic>.from(
    (jsonDecode(
              jsonEncode(
                calls.lastWhere((c) => c.path.endsWith(endpoint)).data,
              ),
            )
            as Map)['data']
        as Map,
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  late _Transport transport;
  late IncidentExecutionRepositoryImpl executor;
  late IncidentActionConfigurationRepositoryImpl configurations;
  late CapFormRepositoryImpl forms;
  final resolver = IncidentActionResolverService(_UnusedLookup());
  IncidentAvailableAction action(int status, IncidentAction type) => resolver
      .resolve(incidentStatusId: status)
      .singleWhere((a) => a.type == type);
  setUp(() {
    transport = _Transport();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/'))
      ..httpClientAdapter = transport;
    addTearDown(dio.close);
    final context = ApiRequestContextProvider(
      users: null,
      currentUser: () => const SessionUser(id: '4086', name: 'Admin'),
      deviceInfo: CapDeviceAppInfoProvider(
        appVersion: '1',
        deviceType: 'iOS',
        osVersion: '15.1',
      ),
    );
    final api = IncidentApiService(dio);
    forms = CapFormRepositoryImpl(CapFormApiService(dio), context);
    configurations = IncidentActionConfigurationRepositoryImpl(api, context);
    executor = IncidentExecutionRepositoryImpl(api, context, forms);
  });
  IncidentActionConfigurationCubit flow(
    IncidentAvailableAction selected, {
    bool full = false,
  }) {
    final cubit = IncidentActionConfigurationCubit(
      action: selected,
      incidentId: 26,
      executor: IncidentExecutionUseCase(executor),
      getConfiguration: GetIncidentActionConfigurationUseCase(configurations),
      form: CapFormCubit(GetCapFormUseCase(forms)),
      getLocation: () async {
        if (!full) throw StateError('GPS must be skipped');
        transport.trace.add('gps');
        return '27.2112,43.3565';
      },
      handlePhoto: (level) => resolveActionPhoto(
        level,
        capturePhoto: () async {
          if (!full) throw StateError('Photo must be skipped');
          transport.trace.add('photo');
          return CapFormEvidence(
            name: 'photo.jpg',
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList([1, 2, 3]),
          );
        },
      ),
    );
    addTearDown(() async {
      if (!cubit.isClosed) await cubit.close();
    });
    return cubit;
  }

  void fullConfiguration() {
    transport.configuration = {
      'gpsRequired': true,
      'photoRequiredLevel': 1,
      'questionFormId': '1087',
    };
  }

  void confirmForm(IncidentActionConfigurationCubit cubit) {
    cubit.form.answer(702, [
      const CapFormAnswer(
        questionId: 702,
        questionTypeId: 1,
        text: 'serial-123',
      ),
    ]);
    cubit.completeForm();
  }

  test(
    'Assign null configuration skips all requirements, selects member, sends exact payload',
    () async {
      final cubit = flow(action(1, IncidentAction.assign));
      await cubit.start();
      expect(transport.trace, ['GetIncedientActionConfiguration']);
      expect(cubit.state.execution!.newStatusId, isNull);
      cubit.setRemark('Assign remark');
      await cubit.continueExecution();
      expect(cubit.state.execution!.assignedUserId, isNull);
      final teamEnvelope =
          jsonDecode(jsonEncode(transport.calls.last.data)) as Map;
      expect(teamEnvelope.containsKey('data'), isTrue);
      expect(teamEnvelope['data'], isNull);
      expect(teamEnvelope['userid'], 4086);
      await cubit.continueExecution(); // no selection, no mutation
      cubit.selectMember(999);
      expect(cubit.state.execution!.assignedUserId, isNull);
      cubit.selectMember(4100);
      await cubit.continueExecution();
      expect(cubit.state.stage, ActionConfigurationStage.succeeded);
      expect(transport.trace, [
        'GetIncedientActionConfiguration',
        'GetMyTeamUser',
        'AssignIncident',
      ]);
      expect(transport.payload('AssignIncident'), {
        'IncidentId': 26,
        'AssignedUserId': 4100,
        'lat': '',
        'long': '',
        'photo': '',
        'Remark': 'Assign remark',
        'QuestionFormId': null,
        'Answers': [],
      });
    },
  );

  for (final assign in [true, false]) {
    test(
      'full requirements preserve every field until ${assign ? 'Assign' : 'Approve'} execution',
      () async {
        fullConfiguration();
        final cubit = flow(
          action(
            assign ? 1 : 2,
            assign ? IncidentAction.assign : IncidentAction.approve,
          ),
          full: true,
        );
        await cubit.start();
        expect(transport.trace, [
          'GetIncedientActionConfiguration',
          'GetFormQuestion',
        ]);
        await cubit.capturePhoto();
        await cubit.refreshLocation();
        confirmForm(cubit);
        cubit.setRemark('current remark');
        if (assign) {
          await cubit.continueExecution();
          cubit.selectMember(4099);
        }
        await cubit.continueExecution();
        final sent = transport.payload(
          assign ? 'AssignIncident' : 'IncidentStatusChange',
        );
        expect(sent['IncidentId'], 26);
        expect(sent['lat'], '27.2112');
        expect(sent['long'], '43.3565');
        expect(sent['photo'], 'AQID');
        expect(sent['Remark'], 'current remark');
        expect(sent['QuestionFormId'], 1087);
        expect(sent['Answers'], [
          {
            'QuestionId': 702,
            'QuestionTypeId': 1,
            'TextAnswer': 'serial-123',
            'AnswerBytes': null,
            'OptionAnswer': 0,
          },
        ]);
        expect(cubit.state.stage, ActionConfigurationStage.succeeded);
      },
    );
  }
  for (final entry in [
    (1, IncidentAction.cancel, 2, 6),
    (2, IncidentAction.approve, 3, 3),
    (2, IncidentAction.reject, 4, 1),
    (3, IncidentAction.hold, 8, 7),
    (4, IncidentAction.hold, 8, 7),
    (4, IncidentAction.complete, 9, 5),
  ]) {
    test(
      '${entry.$2} null config uses resolver IDs ${entry.$3}/${entry.$4}',
      () async {
        final cubit = flow(action(entry.$1, entry.$2));
        await cubit.start();
        await cubit.continueExecution();
        expect(transport.trace, [
          'GetIncedientActionConfiguration',
          'IncidentStatusChange',
        ]);
        final sent = transport.payload('IncidentStatusChange');
        expect(sent['ActionTypeId'], entry.$3);
        expect(sent['NewStatusId'], entry.$4);
        expect(sent['QuestionFormId'], isNull);
        expect(sent['Answers'], isEmpty);
      },
    );
  }
  test(
    'Assign requirements with no form preserve GPS/photo and skip GetFormQuestion',
    () async {
      transport.configuration = {
        'gpsRequired': true,
        'photoRequiredLevel': 1,
        'questionFormId': null,
      };
      final cubit = flow(action(1, IncidentAction.assign), full: true);
      await cubit.start();
      await cubit.capturePhoto();
      await cubit.refreshLocation();
      await cubit.continueExecution();
      cubit.selectMember(4099);
      await cubit.continueExecution();
      expect(transport.trace, isNot(contains('GetFormQuestion')));
      expect(transport.payload('AssignIncident')['QuestionFormId'], isNull);
      expect(transport.payload('AssignIncident')['photo'], 'AQID');
    },
  );
  test(
    'submission failure retains context; retry is explicit and single flight',
    () async {
      fullConfiguration();
      transport.failMutation = true;
      final cubit = flow(action(2, IncidentAction.approve), full: true);
      await cubit.start();
      await cubit.refreshLocation();
      await cubit.capturePhoto();
      confirmForm(cubit);
      cubit.setRemark('keep me');
      final retained = cubit.state.execution;
      transport.mutationGate = Completer<void>();
      final pending = cubit.continueExecution();
      await Future<void>.delayed(Duration.zero);
      await cubit.continueExecution();
      transport.mutationGate!.complete();
      await pending;
      expect(cubit.state.executionFailure, isNotNull);
      expect(cubit.state.execution, same(retained));
      expect(
        transport.trace.where((p) => p == 'IncidentStatusChange').length,
        1,
      );
      transport.failMutation = false;
      await cubit.continueExecution();
      expect(cubit.state.stage, ActionConfigurationStage.succeeded);
      expect(
        transport.trace
            .where((p) => p == 'GetIncedientActionConfiguration')
            .length,
        1,
      );
    },
  );
  test(
    'team error and empty team never execute or auto-select; retry keeps remark',
    () async {
      final cubit = flow(action(1, IncidentAction.assign));
      await cubit.start();
      cubit.setRemark('retain');
      transport.failTeam = true;
      await cubit.continueExecution();
      expect(cubit.state.executionFailure, isNotNull);
      transport.failTeam = false;
      transport.team = [];
      await cubit.continueExecution();
      await cubit.continueExecution();
      expect(cubit.state.team, isEmpty);
      expect(cubit.state.execution!.remark, 'retain');
      expect(transport.trace, isNot(contains('AssignIncident')));
    },
  );
  test('late mutation after route closed is ignored', () async {
    final cubit = flow(action(2, IncidentAction.approve));
    await cubit.start();
    transport.mutationGate = Completer<void>();
    final pending = cubit.continueExecution();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    transport.mutationGate!.complete();
    await pending;
    expect(cubit.isClosed, isTrue);
  });
  test(
    'final serializer sends evidence as raw bytes and each option independently',
    () async {
      final context = IncidentExecutionContext(
        incidentId: 26,
        selectedAction: action(2, IncidentAction.approve),
        questionFormId: 1087,
        answers: [
          CapFormAnswer(
            questionId: 702,
            questionTypeId: 4,
            evidence: CapFormEvidence(
              name: 'p.jpg',
              mimeType: 'image/jpeg',
              bytes: Uint8List.fromList([12, 34]),
            ),
          ),
          const CapFormAnswer(
            questionId: 705,
            questionTypeId: 14,
            optionId: 41,
          ),
          const CapFormAnswer(
            questionId: 705,
            questionTypeId: 14,
            optionId: 43,
          ),
        ],
      );
      await executor.execute(context);
      final answers =
          transport.payload('IncidentStatusChange')['Answers'] as List;
      expect(answers[0]['AnswerBytes'], [12, 34]);
      expect(answers[1]['QuestionId'], 705);
      expect(answers[2]['QuestionId'], 705);
      expect(answers[1]['OptionAnswer'], 41);
      expect(answers[2]['OptionAnswer'], 43);
    },
  );
  for (final lang in ['en', 'ar']) {
    testWidgets(
      'team selection fits narrow large text $lang and returns success',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final selected = action(1, IncidentAction.assign);
        final cubit = flow(selected);
        transport.configuration = {
          'gpsRequired': false,
          'photoRequiredLevel': 0,
          'questionFormId': '1087',
        };
        await tester.runAsync(cubit.start);
        confirmForm(cubit);
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IncidentActionConfigurationScreen(
                          action: selected,
                          incidentId: 26,
                          coordinator: cubit,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.runAsync(cubit.continueExecution);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        cubit.selectMember(4100);
        await tester.runAsync(cubit.continueExecution);
        await tester.pumpAndSettle();
        expect(result, isTrue);
        expect(find.text('Open'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
