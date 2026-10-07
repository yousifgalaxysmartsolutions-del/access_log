import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:crop_your_image/crop_your_image.dart';
import 'package:access_log_plus/features/forms/presentation/widgets/cap_photo_editor.dart';
import 'package:access_log_plus/widgets/app_button.dart';
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
  Completer<Result<CapQuestionForm>>? gate;
  @override
  Future<Result<CapQuestionForm>> load(int id) async {
    trace.add('form');
    if (gate != null) return gate!.future;
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
  flow: IncidentActionFlow.assign,
  newStatusId: null,
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
      incidentId: 26,
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
            return ActionPhotoResult(
              ActionPhotoOutcome.completed,
              evidence: CapFormEvidence(
                name: 'photo.png',
                mimeType: 'image/png',
                bytes: img.encodePng(img.Image(width: 24, height: 16)),
              ),
            );
          },
    );
    addTearDown(() async {
      if (!result.isClosed) await result.close();
    });
    return result;
  }

  test(
    'null configuration reaches ready without GPS, photo, or form calls',
    () async {
      final flow = coordinator(
        location: () => throw StateError('GPS must be skipped'),
        photo: (_) => throw StateError('Photo must be skipped'),
      );
      await flow.start();
      expect(trace, ['config']);
      expect(flow.state.stage, ActionConfigurationStage.readyToContinue);
      expect(flow.state.requirementsValid, isTrue);
      expect(flow.state.hasRequirements, isFalse);
      expect(flow.state.execution!.questionFormId, isNull);
    },
  );
  test(
    'configuration with no requirements skips collection and form',
    () async {
      config.result = const Success(
        IncidentActionConfiguration(gpsRequired: false, photoRequiredLevel: 0),
      );
      final flow = coordinator();
      await flow.start();
      expect(trace, ['config']);
      expect(flow.state.hasRequirements, isFalse);
      expect(flow.state.requirementsValid, isTrue);
    },
  );
  test('form loads before any location or photo capture', () async {
    config.result = const Success(
      IncidentActionConfiguration(
        gpsRequired: true,
        photoRequiredLevel: 1,
        questionFormId: '1087',
      ),
    );
    final flow = coordinator();
    await flow.start();
    expect(trace, ['config', 'form']);
    expect(forms.ids, [1087]);
    expect(flow.state.requirementsValid, isFalse);
    // Collect in a different order; no sequential dependency.
    flow.form.text(flow.form.state.form!.questions.single, 'serial');
    flow.completeForm();
    await flow.capturePhoto();
    await flow.refreshLocation();
    expect(flow.state.requirementsValid, isTrue);
    expect(flow.state.execution!.lat, '30');
    expect(flow.state.execution!.long, '31');
    expect(flow.state.execution!.questionFormId, 1087);
    expect(flow.state.execution!.answers.single.text, 'serial');
  });
  test(
    'required photo deletion disables execution and preserves form, GPS, and remark',
    () async {
      config.result = const Success(
        IncidentActionConfiguration(
          gpsRequired: true,
          photoRequiredLevel: 1,
          questionFormId: '1087',
        ),
      );
      final flow = coordinator();
      await flow.start();
      flow.setRemark('keep remark');
      flow.form.text(flow.form.state.form!.questions.single, 'serial');
      flow.completeForm();
      await flow.capturePhoto();
      await flow.refreshLocation();
      expect(flow.state.requirementsValid, isTrue);
      flow.removePhoto();
      expect(flow.state.requirementsValid, isFalse);
      expect(flow.state.execution, isNull);
      expect(flow.state.remark, 'keep remark');
      expect(flow.state.location, '30,31');
      expect(flow.form.state.answers[702]!.single.text, 'serial');
      await flow.capturePhoto();
      expect(flow.state.execution!.remark, 'keep remark');
      expect(flow.state.execution!.answers.single.text, 'serial');
    },
  );
  test(
    'refresh preserves photo and answers; invalid GPS fails closed without deleting prior valid location',
    () async {
      config.result = const Success(
        IncidentActionConfiguration(gpsRequired: true, photoRequiredLevel: 0),
      );
      var location = 'invalid';
      final flow = coordinator(location: () async => location);
      await flow.start();
      await flow.refreshLocation();
      expect(flow.state.requirementsValid, isFalse);
      expect(flow.state.locationFailure, isNotNull);
      location = '30,31';
      await flow.refreshLocation();
      expect(flow.state.requirementsValid, isTrue);
      location = '500,31';
      await flow.refreshLocation();
      expect(flow.state.location, '30,31');
      expect(flow.state.locationFailure, isNotNull);
    },
  );
  test('capture and edit cancellation preserve the original photo', () async {
    config.result = const Success(
      IncidentActionConfiguration(gpsRequired: false, photoRequiredLevel: 1),
    );
    var cancel = false;
    final evidence = CapFormEvidence(
      name: 'photo.png',
      mimeType: 'image/png',
      bytes: img.encodePng(img.Image(width: 24, height: 16)),
    );
    final flow = coordinator(
      photo: (_) async => ActionPhotoResult(
        cancel ? ActionPhotoOutcome.cancelled : ActionPhotoOutcome.completed,
        evidence: cancel ? null : evidence,
      ),
    );
    await flow.start();
    await flow.capturePhoto();
    cancel = true;
    await flow.capturePhoto();
    expect(flow.state.photo, same(evidence));
    await flow.editPhoto((_) async => null);
    expect(flow.state.photo, same(evidence));
    final edited = CapFormEvidence(
      name: 'edited.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList([4, 5, 6]),
    );
    await flow.editPhoto((_) async => edited);
    expect(flow.state.photo, same(edited));
    expect(flow.state.execution!.photo, 'BAUG');
  });
  test(
    'loading a form does not block location or camera; late form preserves busy capture',
    () async {
      config.result = const Success(
        IncidentActionConfiguration(
          gpsRequired: true,
          photoRequiredLevel: 1,
          questionFormId: '1087',
        ),
      );
      forms.gate = Completer<Result<CapQuestionForm>>();
      final camera = Completer<ActionPhotoResult>();
      final flow = coordinator(photo: (_) => camera.future);
      final start = flow.start();
      await Future<void>.delayed(Duration.zero);
      expect(flow.state.stage, ActionConfigurationStage.loadingForm);
      await flow.refreshLocation();
      final capture = flow.capturePhoto();
      expect(flow.state.photoBusy, isTrue);
      forms.gate!.complete(
        Success(CapQuestionForm(id: 1087, title: 'Form', questions: const [])),
      );
      await start;
      expect(flow.state.photoBusy, isTrue);
      expect(flow.state.requirementsValid, isFalse);
      camera.complete(
        ActionPhotoResult(
          ActionPhotoOutcome.completed,
          evidence: CapFormEvidence(
            name: 'p.jpg',
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList([1]),
          ),
        ),
      );
      await capture;
      expect(flow.state.execution!.lat, '30');
      expect(flow.state.requirementsValid, isTrue);
    },
  );
  test(
    'duplicate location taps are single flight and disable final action while pending',
    () async {
      config.result = const Success(
        IncidentActionConfiguration(gpsRequired: true, photoRequiredLevel: 0),
      );
      final location = Completer<String?>();
      var calls = 0;
      final flow = coordinator(
        location: () {
          calls++;
          return location.future;
        },
      );
      await flow.start();
      final pending = flow.refreshLocation();
      await flow.refreshLocation();
      expect(calls, 1);
      expect(flow.state.locationBusy, isTrue);
      expect(flow.state.execution, isNull);
      location.complete('30,31');
      await pending;
      expect(flow.state.requirementsValid, isTrue);
    },
  );
  test(
    'form validity uses existing conditional and required validation without emitting errors on reads',
    () async {
      config.result = const Success(
        IncidentActionConfiguration(
          gpsRequired: false,
          photoRequiredLevel: 0,
          questionFormId: '1087',
        ),
      );
      final flow = coordinator();
      await flow.start();
      expect(flow.state.requirementsValid, isFalse);
      expect(flow.form.state.errors, isEmpty);
      flow.completeForm();
      expect(flow.form.state.errors[702], CapFormError.required);
      flow.form.text(flow.form.state.form!.questions.single, 'valid');
      await Future<void>.delayed(Duration.zero);
      expect(flow.state.requirementsValid, isTrue);
      flow.form.text(flow.form.state.form!.questions.single, '');
      await Future<void>.delayed(Duration.zero);
      expect(flow.state.requirementsValid, isFalse);
      expect(flow.state.execution, isNull);
    },
  );
  test(
    'form retry does not refetch configuration or lose collected inputs',
    () async {
      config.result = const Success(
        IncidentActionConfiguration(
          gpsRequired: true,
          photoRequiredLevel: 1,
          questionFormId: '1087',
        ),
      );
      forms.failure = const UnknownFailure();
      final flow = coordinator();
      await flow.start();
      await flow.refreshLocation();
      await flow.capturePhoto();
      flow.setRemark('saved');
      forms.failure = null;
      await flow.retryForm();
      expect(trace.where((s) => s == 'config'), hasLength(1));
      expect(flow.state.photo, isNotNull);
      expect(flow.state.location, '30,31');
      expect(flow.state.remark, 'saved');
      expect(flow.form.state.form!.id, 1087);
    },
  );
  test('unknown photo levels are not guessed', () async {
    for (final level in <int?>[null, 9]) {
      config.result = Success(
        IncidentActionConfiguration(
          gpsRequired: false,
          photoRequiredLevel: level,
        ),
      );
      final flow = coordinator();
      await flow.start();
      expect(flow.state.unknownPhotoPolicy, isTrue);
      expect(flow.state.requirementsValid, isFalse);
    }
  });
  test('invalid FormId stops loading without guessing', () async {
    config.result = const Success(
      IncidentActionConfiguration(
        gpsRequired: false,
        photoRequiredLevel: 0,
        questionFormId: 'wrong',
      ),
    );
    final flow = coordinator();
    await flow.start();
    expect(forms.ids, isEmpty);
    expect(flow.state.failure, isA<ValidationFailure>());
  });
  test(
    'all action types still use selected IDs and request flow is excluded',
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
            newStatusId: 3,
            flow: type == IncidentAction.assign
                ? IncidentActionFlow.assign
                : IncidentActionFlow.actionType,
          ),
        );
        await flow.start();
        expect(config.ids.last, 37);
      }
      final request = coordinator(
        action: const IncidentAvailableAction(
          type: IncidentAction.interventionRequest,
          actionTypeId: 1,
          newStatusId: null,
          flow: IncidentActionFlow.request,
        ),
      );
      final calls = config.ids.length;
      await request.start();
      expect(config.ids.length, calls);
      expect(request.state.failure, isA<ValidationFailure>());
    },
  );
  test(
    'GPS and photo errors remain local and do not discard other fields',
    () async {
      config.result = const Success(
        IncidentActionConfiguration(gpsRequired: true, photoRequiredLevel: 1),
      );
      final flow = coordinator(
        location: () async => throw const FormatException('GPS disabled'),
        photo: (_) async => throw const FormatException('Camera unavailable'),
      );
      await flow.start();
      flow.setRemark('saved');
      await flow.refreshLocation();
      await flow.capturePhoto();
      expect(flow.state.locationFailure, isNotNull);
      expect(flow.state.photoFailure, isNotNull);
      expect(flow.state.remark, 'saved');
      expect(flow.state.requirementsValid, isFalse);
    },
  );
  test('late configuration and captures after closing do not emit', () async {
    config.gate = Completer<Result<IncidentActionConfiguration?>>();
    final flow = coordinator();
    final pending = flow.start();
    await flow.start();
    expect(config.ids, hasLength(1));
    await flow.close();
    config.gate!.complete(const Success(null));
    await pending;
    config.gate = null;
    config.result = const Success(
      IncidentActionConfiguration(gpsRequired: true, photoRequiredLevel: 0),
    );
    final gps = Completer<String?>();
    final second = coordinator(location: () => gps.future);
    await second.start();
    final capture = second.refreshLocation();
    await second.close();
    gps.complete('30,31');
    await capture;
  });
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
    for (final sections in ['gps', 'photo', 'all']) {
      testWidgets(
        'unified $sections sections and sticky CTA fit narrow large text $lang',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          config.result = Success(
            IncidentActionConfiguration(
              gpsRequired: sections != 'photo',
              photoRequiredLevel: sections == 'gps' ? 0 : 1,
              questionFormId: sections == 'all' ? '1087' : null,
            ),
          );
          final flow = coordinator();
          await flow.start();
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
              home: IncidentActionConfigurationScreen(
                action: _assign,
                coordinator: flow,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(trace.where((s) => s == 'config'), hasLength(1));
          expect(
            find.byKey(const ValueKey('location-section')),
            sections == 'photo' ? findsNothing : findsOneWidget,
          );
          if (sections != 'all') {
            expect(
              find.byKey(const ValueKey('photo-section')),
              sections == 'gps' ? findsNothing : findsOneWidget,
            );
          }
          expect(find.text('Confirm'), findsNothing);
          final button = tester.widget<AppButton>(
            find.byKey(const ValueKey('requirements-continue')),
          );
          expect(button.onPressed, isNull);
          // Confirm all sections are present together, regardless of list laziness.
          if (sections == 'all') {
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('photo-section')),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            expect(find.byKey(const ValueKey('photo-section')), findsOneWidget);
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('form-section')),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            expect(find.byKey(const ValueKey('form-section')), findsOneWidget);
            flow.form.text(flow.form.state.form!.questions.single, 'serial');
            flow.completeForm();
          }
          if (sections != 'gps') await flow.capturePhoto();
          if (sections != 'photo') await flow.refreshLocation();
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<AppButton>(
                  find.byKey(const ValueKey('requirements-continue')),
                )
                .onPressed,
            isNotNull,
          );
          if (sections != 'gps') {
            flow.removePhoto();
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<AppButton>(
                    find.byKey(const ValueKey('requirements-continue')),
                  )
                  .onPressed,
              isNull,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  test('rotate uses the image library and changes actual pixel dimensions', () {
    final original = img.encodePng(img.Image(width: 80, height: 40));
    final rotated = img.decodeImage(rotatePhotoBytes(original))!;
    expect(rotated.width, 40);
    expect(rotated.height, 80);
  });
  testWidgets(
    'library editor crops and returns the edited image to its caller',
    (tester) async {
      final photo = CapFormEvidence(
        name: 'p.png',
        mimeType: 'image/png',
        bytes: img.encodePng(img.Image(width: 80, height: 40)),
      );
      CapFormEvidence? edited;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  edited = await Navigator.push<CapFormEvidence>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CapPhotoEditor(photo: photo),
                    ),
                  );
                },
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pump();
      Future<void> waitFor(bool Function() done) async {
        await tester.runAsync(() async {
          final elapsed = Stopwatch()..start();
          while (!done() && elapsed.elapsed < const Duration(seconds: 5)) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump();
          }
        });
        expect(done(), isTrue);
      }

      await waitFor(
        () =>
            find.byType(AppButton).evaluate().isNotEmpty &&
            tester.widget<AppButton>(find.byType(AppButton)).onPressed != null,
      );
      final crop = tester.widget<Crop>(find.byType(Crop));
      crop.controller!.area = ImageBasedRect.fromLTWH(0, 0, 40, 20);
      await tester.pump();
      await tester.tap(find.text('Use photo'));
      await waitFor(() => edited != null);
      await tester.pumpAndSettle();
      final image = img.decodeImage(edited!.bytes)!;
      expect(image.width, 40);
      expect(image.height, 20);
      expect(find.text('Open editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
