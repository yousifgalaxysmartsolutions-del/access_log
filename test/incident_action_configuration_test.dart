import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/forms/data/models/cap_form_models.dart';
import 'package:access_log_plus/features/forms/domain/repositories/cap_form_repository.dart';
import 'package:access_log_plus/features/forms/domain/usecases/cap_form_use_cases.dart';
import 'package:access_log_plus/features/forms/presentation/bloc/cap_form_cubit.dart';
import 'package:access_log_plus/features/incidents/data/api/incident_api_service.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_action_configuration_models.dart';
import 'package:access_log_plus/features/incidents/data/repositories/incident_action_configuration_repository_impl.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/incident_action_configuration_repository.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_action_configuration_use_case.dart';
import 'package:access_log_plus/features/incidents/domain/actions/incident_available_action.dart';
import 'package:access_log_plus/features/incidents/presentation/bloc/incident_action_configuration_cubit.dart';
import 'package:access_log_plus/features/incidents/presentation/incident_action_configuration_screen.dart';

class _Config implements IncidentActionConfigurationRepository {
  _Config(this.trace);
  final List<String> trace;
  Result<IncidentActionConfiguration?> result = const Success(null);
  Completer<Result<IncidentActionConfiguration?>>? gate;
  final ids = <int>[];
  @override
  Future<Result<IncidentActionConfiguration?>> getConfiguration(int id) {
    trace.add('config');
    ids.add(id);
    return gate?.future ?? Future.value(result);
  }
}

class _Forms implements CapFormRepository {
  _Forms(this.trace);
  final List<String> trace;
  final ids = <int>[];
  Failure? failure;
  @override
  Future<Result<CapQuestionForm>> load(int id) async {
    trace.add('form');
    ids.add(id);
    return failure != null
        ? FailureResult(failure!)
        : Success(
            CapQuestionForm(
              id: id,
              title: 'Form',
              questions: [
                CapFormQuestion(
                  id: 702,
                  title: 'Serial',
                  typeId: 1,
                  required: true,
                ),
              ],
            ),
          );
  }

  @override
  Future<Result<void>> submit(IncidentFormSubmission submission) =>
      throw StateError('Final execution is forbidden');
}

const _assign = IncidentAvailableAction(
  type: IncidentAction.assign,
  actionTypeId: 1,
  flow: IncidentActionFlow.assign, newStatusId: null,
);

class _Adapter implements HttpClientAdapter {
  Object? data;
  int resultCode = 1;
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'resultcode': resultCode,
        'resultmessageen': 'test',
        'data': data,
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
  late List<String> trace;
  late _Config config;
  late _Forms forms;
  setUp(() {
    trace = [];
    config = _Config(trace);
    forms = _Forms(trace);
  });
  IncidentActionConfigurationCubit coordinator({
    IncidentAvailableAction action = _assign,
    Future<String?> Function()? location,
    ActionPhotoHandler? photo,
  }) {
    final result = IncidentActionConfigurationCubit(
      action: action,
      getConfiguration: GetIncidentActionConfigurationUseCase(config),
      form: CapFormCubit(GetCapFormUseCase(forms)),
      getLocation:
          location ??
          () async {
            trace.add('gps');
            return '30,31';
          },
      // Test-only policy deliberately defines no production meaning for levels.
      handlePhoto:
          photo ??
          (level) async {
            trace.add('photo:$level');
            return const ActionPhotoResult(ActionPhotoOutcome.completed);
          },
    );
    addTearDown(() async {
      if (!result.isClosed) await result.close();
    });
    return result;
  }

  test('level 0 skips camera and loads configured form', () async {
    config.result = const Success(
      IncidentActionConfiguration(
        gpsRequired: false,
        photoRequiredLevel: 0,
        questionFormId: '1087',
      ),
    );
    final flow = coordinator(
      photo: (level) => resolveActionPhoto(
        level,
        capturePhoto: () => throw StateError('Camera must not open'),
      ),
    );
    await flow.start();
    expect(trace, ['config', 'form']);
    expect(forms.ids, [1087]);
    expect(flow.state.stage, ActionConfigurationStage.formReady);
  });

  test('level 1 waits for captured photo before loading form 1087', () async {
    config.result = const Success(
      IncidentActionConfiguration(
        gpsRequired: true,
        photoRequiredLevel: 1,
        questionFormId: '1087',
      ),
    );
    final camera = Completer<CapFormEvidence?>();
    final flow = coordinator(
      photo: (level) => resolveActionPhoto(
        level,
        capturePhoto: () {
          trace.add('camera');
          return camera.future;
        },
      ),
    );
    final pending = flow.start();
    await Future<void>.delayed(Duration.zero);
    expect(trace, ['config', 'gps', 'camera']);
    expect(forms.ids, isEmpty);
    final evidence = CapFormEvidence(
      name: 'photo.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    camera.complete(evidence);
    await pending;
    expect(trace, ['config', 'gps', 'camera', 'form']);
    expect(forms.ids, [1087]);
    expect(flow.state.photo, same(evidence));
    expect(flow.state.stage, ActionConfigurationStage.formReady);
  });

  test('required photo cancellation prevents form loading', () async {
    config.result = const Success(
      IncidentActionConfiguration(
        gpsRequired: false,
        photoRequiredLevel: 1,
        questionFormId: '1087',
      ),
    );
    final flow = coordinator(
      photo: (level) =>
          resolveActionPhoto(level, capturePhoto: () async => null),
    );
    await flow.start();
    expect(flow.state.failure, isA<CancelledFailure>());
    expect(forms.ids, isEmpty);
  });

  test(
    'undefined photo levels do not open camera or bypass requirements',
    () async {
      for (final level in <int?>[null, -1, 2]) {
        final result = await resolveActionPhoto(
          level,
          capturePhoto: () => throw StateError('Undefined photo rule'),
        );
        expect(result.outcome, ActionPhotoOutcome.awaitingPolicy);
      }
    },
  );

  test(
    'null config short circuits every requirement and property access',
    () async {
      final flow = coordinator(
        location: () => throw StateError('GPS must never run'),
        photo: (_) => throw StateError('Photo level must never be read'),
      );
      await flow.start();
      expect(flow.state.stage, ActionConfigurationStage.readyToContinue);
      expect(flow.state.configuration, isNull);
      expect(trace, ['config']);
      expect(forms.ids, isEmpty);
      expect(flow.form.state.form, isNull);
    },
  );
  test(
    'non-null skips GPS and empty form, with resolved injected photo policy',
    () async {
      for (final id in [null, '', '   ']) {
        trace.clear();
        config.result = Success(
          IncidentActionConfiguration(
            gpsRequired: false,
            questionFormId: id,
            photoRequiredLevel: 0,
          ),
        );
        final flow = coordinator();
        await flow.start();
        expect(trace, ['config', 'photo:0']);
        expect(flow.state.stage, ActionConfigurationStage.readyToContinue);
        expect(forms.ids, isEmpty);
      }
    },
  );
  test('GPS precedes photo, no form requested without FormId', () async {
    config.result = const Success(
      IncidentActionConfiguration(gpsRequired: true, photoRequiredLevel: 1),
    );
    final flow = coordinator();
    await flow.start();
    expect(trace, ['config', 'gps', 'photo:1']);
    expect(flow.state.location, '30,31');
    expect(flow.state.stage, ActionConfigurationStage.readyToContinue);
  });
  test(
    'form uses existing usecase only after GPS/photo, requires valid confirmation',
    () async {
      config.result = const Success(
        IncidentActionConfiguration(
          gpsRequired: true,
          photoRequiredLevel: 9,
          questionFormId: '1085',
        ),
      );
      final flow = coordinator();
      await flow.start();
      expect(trace, ['config', 'gps', 'photo:9', 'form']);
      expect(forms.ids, [1085]);
      expect(flow.state.stage, ActionConfigurationStage.formReady);
      flow.completeForm();
      expect(flow.state.stage, ActionConfigurationStage.formReady);
      flow.form.text(flow.form.state.form!.questions.single, 'test serial');
      flow.completeForm();
      expect(flow.state.stage, ActionConfigurationStage.readyToContinue);
      expect(flow.state.answers.single.text, 'test serial');
      expect(trace, ['config', 'gps', 'photo:9', 'form']);
    },
  );
  test(
    'default photo handler invents no meaning even for null/zero/one',
    () async {
      for (final level in [null, 0, 1, 9]) {
        trace.clear();
        config.result = Success(
          IncidentActionConfiguration(
            gpsRequired: false,
            photoRequiredLevel: level,
            questionFormId: '1085',
          ),
        );
        final flow = coordinator(photo: unresolvedActionPhotoPolicy);
        await flow.start();
        expect(flow.state.stage, ActionConfigurationStage.waitingForPhoto);
        expect(trace, ['config']);
        expect(forms.ids, isEmpty);
      }
    },
  );
  test(
    'all six action types including Assign use selected ID, not name or fixed 8',
    () async {
      for (final type in [
        IncidentAction.assign,
        IncidentAction.cancel,
        IncidentAction.approve,
        IncidentAction.reject,
        IncidentAction.hold,
        IncidentAction.complete,
      ]) {
        final flow = coordinator(
          action: IncidentAvailableAction(
            type: type,
            actionTypeId: 37,
            flow: type == IncidentAction.assign
                ? IncidentActionFlow.assign
                : IncidentActionFlow.actionType, newStatusId: null,
          ),
        );
        await flow.start();
        expect(config.ids.last, 37);
        expect(flow.state.stage, ActionConfigurationStage.readyToContinue);
      }
    },
  );
  test(
    'Request type cannot accidentally use its ID as an ActionTypeId',
    () async {
      final flow = coordinator(
        action: const IncidentAvailableAction(
          type: IncidentAction.interventionRequest,
          flow: IncidentActionFlow.request,
          actionTypeId: 1, newStatusId: null,
        ),
      );
      await flow.start();
      expect(trace, isEmpty);
      expect(flow.state.stage, ActionConfigurationStage.failure);
    },
  );
  test('config failure prevents all downstream work', () async {
    config.result = const FailureResult(NetworkFailure());
    final flow = coordinator();
    await flow.start();
    expect(trace, ['config']);
    expect(flow.state.failure, isA<NetworkFailure>());
  });
  test('GPS exception and cancellation prevent photo and form', () async {
    config.result = const Success(
      IncidentActionConfiguration(gpsRequired: true, questionFormId: '1085'),
    );
    for (final fails in [true, false]) {
      trace.clear();
      final flow = coordinator(
        location: () async {
          if (fails) throw Exception('permission');
          return null;
        },
      );
      await flow.start();
      expect(flow.state.stage, ActionConfigurationStage.failure);
      expect(trace, ['config']);
    }
  });
  test(
    'photo error/cancel stops form; form error preserves typed failure',
    () async {
      config.result = const Success(
        IncidentActionConfiguration(gpsRequired: false, questionFormId: '1085'),
      );
      for (final fails in [true, false]) {
        final flow = coordinator(
          photo: (_) async {
            if (fails) throw Exception('camera');
            return const ActionPhotoResult(ActionPhotoOutcome.cancelled);
          },
        );
        await flow.start();
        expect(flow.state.stage, ActionConfigurationStage.failure);
        expect(forms.ids, isEmpty);
      }
      forms.failure = const NetworkFailure();
      final flow = coordinator();
      await flow.start();
      expect(flow.state.failure, isA<NetworkFailure>());
    },
  );
  test('invalid form ID is not guessed and cannot reach ready', () async {
    config.result = const Success(
      IncidentActionConfiguration(gpsRequired: false, questionFormId: 'wrong'),
    );
    final flow = coordinator();
    await flow.start();
    expect(forms.ids, isEmpty);
    expect(flow.state.failure, isA<ValidationFailure>());
  });
  test(
    'duplicate starts make one call; completion after close is ignored',
    () async {
      config.gate = Completer<Result<IncidentActionConfiguration?>>();
      final flow = coordinator();
      final pending = flow.start();
      await flow.start();
      expect(config.ids.length, 1);
      await flow.close();
      config.gate!.complete(const Success(null));
      await pending;
      expect(trace, ['config']);
    },
  );
  test(
    'repository preserves exact endpoint/envelope; success-null vs failure-null',
    () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repository = IncidentActionConfigurationRepositoryImpl(
        IncidentApiService(dio),
        ApiRequestContextProvider(
          users: null,
          currentUser: () => const SessionUser(id: '4099', name: 'Engineer'),
          deviceInfo: CapDeviceAppInfoProvider(
            appVersion: '1',
            deviceType: 'iOS',
            osVersion: '15',
          ),
        ),
      );
      final result = await repository.getConfiguration(37);
      expect(result, isA<Success<IncidentActionConfiguration?>>());
      expect((result as Success).data, isNull);
      expect(
        adapter.calls.single.path,
        'CAP/CapConfiguration/GetIncedientActionConfiguration',
      );
      final sent = jsonDecode(jsonEncode(adapter.calls.single.data)) as Map;
      expect(sent['data'], {'ActionTypeId': 37});
      expect(sent['userid'], 4099);
      adapter.resultCode = 0;
      expect(await repository.getConfiguration(37), isA<FailureResult>());
      adapter.resultCode = 1;
      adapter.data = {
        'id': 1,
        'actionType': {'id': 8, 'name': ' Hold'},
        'userType': -1,
        'questionFormId': '1085',
        'gpsRequired': true,
        'photoRequiredLevel': 1,
        'isActive': true,
      };
      final parsed =
          (await repository.getConfiguration(8)
                  as Success<IncidentActionConfiguration?>)
              .data!;
      expect(parsed.actionType!.name, ' Hold');
      expect(parsed.questionFormId, '1085');
      expect(parsed.gpsRequired, true);
      expect(parsed.photoRequiredLevel, 1);
      adapter.data = 'malformed';
      expect(await repository.getConfiguration(8), isA<FailureResult>());
    },
  );
  for (final lang in ['en', 'ar']) {
    testWidgets(
      'null config ready screen uses existing direction and large text in $lang',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final flow = coordinator();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: IncidentActionConfigurationScreen(
              action: _assign,
              coordinator: flow,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(lang == 'ar' ? 'جاهز للمتابعة' : 'Ready to continue'),
          findsOneWidget,
        );
        expect(trace, ['config']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
