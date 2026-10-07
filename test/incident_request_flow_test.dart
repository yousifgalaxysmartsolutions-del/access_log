import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/requests/data/api/request_api_service.dart';
import 'package:access_log_plus/features/requests/data/repositories/request_creation_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:access_log_plus/features/incidents/presentation/incident_action_configuration_screen.dart';
import 'package:access_log_plus/widgets/app_button.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/requests/data/models/request_creation_models.dart';
import 'package:access_log_plus/features/requests/domain/repositories/request_creation_repository.dart';
import 'package:access_log_plus/features/requests/domain/usecases/incident_request_use_case.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_action_configuration_models.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/incident_action_configuration_repository.dart';
import 'package:access_log_plus/features/incidents/domain/actions/incident_available_action.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_action_configuration_use_case.dart';
import 'package:access_log_plus/features/incidents/presentation/bloc/incident_action_configuration_cubit.dart';
import 'package:access_log_plus/features/forms/data/models/cap_form_models.dart';
import 'package:access_log_plus/features/forms/domain/repositories/cap_form_repository.dart';
import 'package:access_log_plus/features/forms/domain/usecases/cap_form_use_cases.dart';
import 'package:access_log_plus/features/forms/presentation/bloc/cap_form_cubit.dart';

class _Actions implements IncidentActionConfigurationRepository {
  @override
  Future<Result<IncidentActionConfiguration?>> getConfiguration(int id) =>
      throw StateError('Action configuration forbidden');
}

class _Transport implements HttpClientAdapter {
  Object? data;
  int code = 1;
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    return ResponseBody.fromString(
      jsonEncode({'resultcode': code, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void repositoryTests() {
  test(
    'Retrofit uses exact endpoints/envelopes; repository blocks missing status before HTTP',
    () async {
      final adapter = _Transport();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repository = RequestCreationRepositoryImpl(
        RequestApiService(dio),
        ApiRequestContextProvider(
          users: null,
          currentUser: () => const SessionUser(id: '4098', name: 'Test'),
          deviceInfo: CapDeviceAppInfoProvider(
            appVersion: '1',
            deviceType: 'iOS',
            osVersion: '15.1',
          ),
        ),
      );
      var result = await repository.getConfiguration(2, 17);
      expect(result, isA<Success<RequestConfiguration?>>());
      expect((result as Success<RequestConfiguration?>).data, isNull);
      expect(
        adapter.calls.single.path,
        'CAP/CapConfiguration/GetRequestConfiguration',
      );
      expect((adapter.calls.single.data as Map)['data'], {
        'RequestTypeId': 2,
        'IncidentId': 17,
      });
      adapter.data = {
        'id': 1,
        'requestType': {'id': 2, 'name': 'Renewal'},
        'gpsRequired': false,
        'photoRequiredLevel': 0,
        'questionFormId': '',
        'approvalRequired': false,
        'autoApproval': false,
        'confirmationCodeRequired': false,
        'isActive': true,
      };
      result = await repository.getConfiguration(2, 17);
      expect(
        (result as Success<RequestConfiguration?>).data!.photoRequiredLevel,
        0,
      );
      await repository.create(
        RequestExecutionContext(
          incidentId: 17,
          requestTypeId: 2,
          newStatusId: null,
        ),
      );
      expect(adapter.calls.length, 2);
      adapter.data = null;
      final created = await repository.create(
        RequestExecutionContext(
          incidentId: 17,
          requestTypeId: 2,
          newStatusId: 99,
        ),
      );
      expect(created, isA<Success<void>>());
      expect(adapter.calls.last.path, 'CAP/CapRequest/CreateRequest');
      final body = adapter.calls.last.data as Map;
      expect(body['userid'], 4098);
      expect(body['data'], {
        'IncidentId': 17,
        'RequestTypeId': 2,
        'Remark': '',
        'QuestionFormId': null,
        'NewStatusId': 99,
        'lat': '',
        'long': '',
        'photo': '',
        'NoOfMinute': 0,
        'Answers': [],
      });
      adapter.code = 0;
      expect(
        await repository.create(
          RequestExecutionContext(
            incidentId: 17,
            requestTypeId: 2,
            newStatusId: 99,
          ),
        ),
        isA<FailureResult<void>>(),
      );
    },
  );
}

class _Requests implements RequestCreationRepository {
  RequestConfiguration? configuration;
  final calls = <RequestExecutionContext>[];
  final configurations = <List<int>>[];
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<Result<RequestConfiguration?>> getConfiguration(
    int type,
    int incident,
  ) async {
    configurations.add([type, incident]);
    return Success(configuration);
  }

  @override
  Future<Result<void>> create(RequestExecutionContext input) async {
    calls.add(input);
    if (gate != null) await gate!.future;
    return fail ? const FailureResult(ServerFailure()) : const Success(null);
  }
}

class _Forms implements CapFormRepository {
  final ids = <int>[];
  @override
  Future<Result<CapQuestionForm>> load(int id) async {
    ids.add(id);
    return Success(
      CapQuestionForm(
        id: id,
        title: 'Form',
        questions: [
          CapFormQuestion(id: 702, title: 'Serial', typeId: 1, required: true),
          CapFormQuestion(
            id: 703,
            title: 'Options',
            typeId: 14,
            options: [
              const CapFormOption(10, 'A'),
              const CapFormOption(20, 'B'),
            ],
          ),
          CapFormQuestion(id: 704, title: 'Photo', typeId: 4),
        ],
      ),
    );
  }

  @override
  Future<Result<void>> submit(IncidentFormSubmission input) =>
      throw StateError('Status execution forbidden');
}

void main() {
  repositoryTests();
  late _Requests requests;
  late _Forms forms;
  late IncidentActionConfigurationCubit flow;
  var gpsCalls = 0, photoCalls = 0;
  var elapsed = Duration.zero;
  IncidentActionConfigurationCubit build({
    int? status,
    IncidentAction type = IncidentAction.interventionRequest,
    int id = 1,
  }) {
    final cubit = IncidentActionConfigurationCubit(
      action: IncidentAvailableAction(
        type: type,
        actionTypeId: id,
        newStatusId: null,
        flow: IncidentActionFlow.request,
      ),
      incidentId: 17,
      getConfiguration: GetIncidentActionConfigurationUseCase(_Actions()),
      requestExecutor: IncidentRequestUseCase(requests),
      requestNewStatusId: status,
      formElapsed: () => elapsed,
      form: CapFormCubit(GetCapFormUseCase(forms)),
      getLocation: () async {
        gpsCalls++;
        return '27.2112,43.3565';
      },
      handlePhoto: (_) async {
        photoCalls++;
        return ActionPhotoResult(
          ActionPhotoOutcome.completed,
          evidence: CapFormEvidence(
            name: 'photo.jpg',
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        );
      },
    );
    addTearDown(cubit.close);
    return cubit;
  }

  setUp(() {
    requests = _Requests();
    forms = _Forms();
    gpsCalls = photoCalls = 0;
    elapsed = Duration.zero;
  });

  for (final formId in [null, '', '   ']) {
    test(
      'No form ($formId), GPS false, photo zero skips all collections',
      () async {
        requests.configuration = RequestConfiguration(
          gpsRequired: false,
          photoRequiredLevel: 0,
          questionFormId: formId,
        );
        flow = build(status: 99);
        await flow.start();
        expect(flow.state.hasRequirements, false);
        expect(flow.state.requirementsValid, true);
        await flow.continueExecution();
        expect(forms.ids, isEmpty);
        expect(gpsCalls, 0);
        expect(photoCalls, 0);
        final input = requests.calls.single;
        expect(input.questionFormId, isNull);
        expect(input.answers, isEmpty);
        expect(input.noOfMinute, 0);
        expect(input.toJson()['NewStatusId'], 99);
      },
    );
  }
  for (final locale in ['en', 'ar']) {
    testWidgets(
      'Submit validates and focuses first unanswered field in $locale',
      (tester) async {
        requests.configuration = const RequestConfiguration(
          gpsRequired: false,
          photoRequiredLevel: 0,
          questionFormId: '1085',
        );
        flow = build(status: 1);
        await tester.runAsync(flow.start);
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: IncidentActionConfigurationScreen(
              action: flow.action,
              incidentId: 17,
              coordinator: flow,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byKey(const ValueKey('requirements-continue'));
        expect(tester.widget<AppButton>(button).onPressed, isNotNull);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(requests.calls, isEmpty);
        expect(flow.form.state.errors[702], CapFormError.required);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'question-702');
        final field = find.byType(TextFormField).first;
        expect(tester.getRect(field).top, greaterThanOrEqualTo(0));
        await tester.enterText(field, 'filled serial');
        await tester.pumpAndSettle();
        requests.fail = true;
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(requests.calls.length, 1);
        expect(requests.calls.single.answers.first.text, 'filled serial');
        expect(tester.takeException(), isNull);
        await tester.runAsync(flow.close);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  test(
    'Confirmed execution input sends NewStatusId 1 for every request type',
    () async {
      expect(IncidentRequestUseCase.confirmedNewStatusId, 1);
      for (final entry in [
        (IncidentAction.interventionRequest, 1),
        (IncidentAction.renewalRequest, 2),
        (IncidentAction.departureRequest, 3),
      ]) {
        flow = build(
          status: IncidentRequestUseCase.confirmedNewStatusId,
          type: entry.$1,
          id: entry.$2,
        );
        await flow.start();
        expect(flow.submissionBlocked, false);
        await flow.continueExecution();
        expect(requests.calls.last.toJson()['NewStatusId'], 1);
        expect(requests.calls.last.requestTypeId, entry.$2);
        await flow.close();
      }
    },
  );
  test(
    'Unknown NewStatusId blocks usecase, coordinator and serialization',
    () async {
      flow = build();
      await flow.start();
      expect(flow.submissionBlocked, true);
      expect(flow.state.requirementsValid, true);
      await flow.continueExecution();
      await IncidentRequestUseCase(requests).create(flow.requestExecution!);
      expect(requests.calls, isEmpty);
      expect(() => flow.requestExecution!.toJson(), throwsStateError);
    },
  );
  for (final entry in [
    (IncidentAction.interventionRequest, 1),
    (IncidentAction.renewalRequest, 2),
    (IncidentAction.departureRequest, 3),
  ]) {
    test('${entry.$1} uses request executor and selected request ID', () async {
      flow = build(status: 99, type: entry.$1, id: entry.$2);
      await flow.start();
      await flow.continueExecution();
      expect(requests.configurations, [
        [entry.$2, 17],
      ]);
      expect(requests.calls.single.requestTypeId, entry.$2);
      expect(flow.state.stage, ActionConfigurationStage.succeeded);
    });
  }
  test(
    'Full requirements preserve bytes, separate choices, duration and retry',
    () async {
      requests.configuration = const RequestConfiguration(
        gpsRequired: true,
        photoRequiredLevel: 1,
        questionFormId: '1085',
      );
      flow = build(status: 99);
      await flow.start();
      expect(forms.ids, [1085]);
      expect(gpsCalls, 0);
      expect(photoCalls, 0);
      expect(flow.state.requirementsValid, false);
      await flow.refreshLocation();
      await flow.capturePhoto();
      flow.setRemark('field note');
      flow.form.answer(702, [
        CapFormAnswer(questionId: 702, questionTypeId: 1, text: 'serial'),
      ]);
      flow.form.answer(703, [
        CapFormAnswer(questionId: 703, questionTypeId: 14, optionId: 10),
        CapFormAnswer(questionId: 703, questionTypeId: 14, optionId: 20),
      ]);
      flow.form.answer(704, [
        CapFormAnswer(
          questionId: 704,
          questionTypeId: 4,
          evidence: CapFormEvidence(
            name: 'answer.jpg',
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList([4, 5]),
          ),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      elapsed = const Duration(minutes: 7, seconds: 25);
      requests.fail = true;
      requests.gate = Completer<void>();
      final first = flow.continueExecution();
      await flow.continueExecution();
      expect(requests.calls.length, 1);
      requests.gate!.complete();
      await first;
      expect(flow.state.executionFailure, isNotNull);
      elapsed = const Duration(minutes: 12);
      requests.fail = false;
      requests.gate = null;
      await flow.continueExecution();
      expect(requests.calls.length, 2);
      final json = requests.calls.last.toJson();
      expect(json['lat'], '27.2112');
      expect(json['long'], '43.3565');
      expect(json['photo'], base64Encode([1, 2, 3]));
      expect(json['Remark'], 'field note');
      expect(json['QuestionFormId'], 1085);
      expect(json['NoOfMinute'], 7);
      final answers = json['Answers'] as List;
      expect(
        answers
            .where((a) => a['QuestionId'] == 703)
            .map((a) => a['OptionAnswer']),
        [10, 20],
      );
      expect(
        answers.singleWhere((a) => a['QuestionId'] == 704)['AnswerBytes'],
        [4, 5],
      );
    },
  );
}
