import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/cap/cap_parse_diagnostics.dart';
import 'package:access_log_plus/features/forms/presentation/cap_incident_form_screen.dart';
import 'package:access_log_plus/features/forms/presentation/widgets/cap_form_capture.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/forms/data/api/cap_form_api_service.dart';
import 'package:access_log_plus/features/forms/data/models/cap_form_models.dart';
import 'package:access_log_plus/features/forms/data/repositories/cap_form_repository_impl.dart';
import 'package:access_log_plus/features/forms/domain/repositories/cap_form_repository.dart';
import 'package:access_log_plus/features/forms/domain/usecases/cap_form_use_cases.dart';
import 'package:access_log_plus/features/forms/presentation/bloc/cap_form_cubit.dart';
import 'package:access_log_plus/features/forms/presentation/widgets/cap_dynamic_form.dart';

Map<String, dynamic> fixture() => {
  'FormId': 1085,
  'Title': 'Intervention Request',
  'Description': '<p>Details</p>',
  'taskquestion': [
    {
      'QuestionID': 702,
      'QuestionName': 'Serial',
      'QuestionTypeID': 1,
      'QuestionMendatory': true,
      'QuestionAnswer': null,
    },
    {
      'QuestionID': 708,
      'QuestionName': 'GPS',
      'QuestionTypeID': 13,
      'QuestionMendatory': true,
      'QuestionAnswer': null,
    },
  ],
};

class _Repository implements CapFormRepository {
  int submissions = 0;
  IncidentFormSubmission? lastSubmission;
  Completer<Result<void>>? submitGate;
  Result<void> submitResult = const Success(null);
  CapQuestionForm form = CapQuestionForm.fromJson(fixture());
  final gates = <Completer<Result<CapQuestionForm>>>[];
  bool delayed = false;
  @override
  Future<Result<CapQuestionForm>> load(int formId) {
    if (!delayed) return Future.value(Success(form));
    final gate = Completer<Result<CapQuestionForm>>();
    gates.add(gate);
    return gate.future;
  }

  @override
  Future<Result<void>> submit(IncidentFormSubmission submission) {
    submissions++;
    lastSubmission = submission;
    return submitGate?.future ?? Future.value(submitResult);
  }
}

class _Adapter implements HttpClientAdapter {
  Object? body = {'resultcode': 1, 'data': fixture()};
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
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
  testWidgets('captured GPS updates the visible editable field', (
    tester,
  ) async {
    final repository = _Repository();
    final cubit = CapFormCubit(GetCapFormUseCase(repository));
    addTearDown(cubit.close);
    await cubit.load(1085);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CapDynamicForm(
            cubit: cubit,
            onConfirmed: (_) {},
            onRetry: () {},
            capture: (q) async => CapFormAnswer(
              questionId: q.id,
              questionTypeId: q.typeId,
              text: '30.1,31.2',
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Use current location'));
    await tester.tap(find.text('Use current location'));
    await tester.pumpAndSettle();
    expect(find.text('30.1,31.2'), findsOneWidget);
    expect(cubit.state.answers[708]!.single.text, '30.1,31.2');
  });
  testWidgets('back navigation can keep or discard unsent answers', (
    tester,
  ) async {
    final repository = _Repository();
    final cubit = CapFormCubit(
      GetCapFormUseCase(repository),
      submit: SubmitIncidentFormUseCase(repository),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => CapIncidentFormScreen(
                    formId: 1085,
                    incidentId: 26,
                    newStatusId: 3,
                    actionTypeId: 3,
                    cubit: cubit,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    cubit.text(repository.form.questions.first, 'unsent');
    await tester.pumpAndSettle();
    expect(cubit.state.answers.isNotEmpty, true);
    expect(
      tester
          .widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope))
          .canPop,
      false,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard form?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(CapIncidentFormScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(CapIncidentFormScreen), findsNothing);
    expect(repository.submissions, 0);
  });
  test(
    'submit is single flight, preserves inputs on failure and retries explicitly',
    () async {
      final repository = _Repository()..submitGate = Completer<Result<void>>();
      final cubit = CapFormCubit(
        GetCapFormUseCase(repository),
        submit: SubmitIncidentFormUseCase(repository),
      );
      addTearDown(cubit.close);
      await cubit.load(1085);
      cubit.text(repository.form.questions.first, 'S-123');
      cubit.text(repository.form.questions.last, '30,31');
      final pending = cubit.submit(
        incidentId: 26,
        newStatusId: 3,
        actionTypeId: 3,
        remark: 'Approved',
      );
      await cubit.submit(
        incidentId: 26,
        newStatusId: 3,
        actionTypeId: 3,
        remark: 'Duplicate',
      );
      expect(repository.submissions, 1);
      expect(cubit.state.submitting, true);
      cubit.text(repository.form.questions.first, 'Do not modify');
      expect(cubit.state.answers[702]!.single.text, 'S-123');
      repository.submitGate!.complete(
        const FailureResult(ServerFailure('Unavailable')),
      );
      await pending;
      expect(cubit.state.submissionFailure, isA<ServerFailure>());
      expect(cubit.state.answers[702]!.single.text, 'S-123');
      repository.submitGate = null;
      await cubit.submit(
        incidentId: 26,
        newStatusId: 3,
        actionTypeId: 3,
        remark: 'Approved',
      );
      expect(repository.submissions, 2);
      expect(cubit.state.submitted, true);
      expect(repository.lastSubmission!.formId, 1085);
      await cubit.submit(
        incidentId: 26,
        newStatusId: 3,
        actionTypeId: 3,
        remark: 'Duplicate',
      );
      expect(repository.submissions, 2);
    },
  );
  test(
    'local evidence is immutable, serialized as raw bytes and never logged',
    () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final evidence = CapFormEvidence(
        name: 'signature.png',
        mimeType: 'image/png',
        bytes: bytes,
      );
      bytes[0] = 9;
      expect(evidence.bytes[0], 1);
      expect(() => evidence.bytes[0] = 4, throwsUnsupportedError);
      final answer = CapFormAnswer(
        questionId: 1,
        questionTypeId: 7,
        evidence: evidence,
      );
      expect(answer.toJson()['AnswerBytes'], [1, 2, 3]);
      expect(redactCapPayload({'AnswerBytes': 'private-content'}), {
        'AnswerBytes': '[REDACTED]',
      });
    },
  );
  test(
    'confirmed evidence wire encoding submits raw bytes without losing evidence',
    () async {
      final repository = _Repository()
        ..form = CapQuestionForm(
          id: 1,
          title: 'Evidence',
          questions: [
            CapFormQuestion(id: 1, title: 'Photo', typeId: 4, required: true),
          ],
        );
      final cubit = CapFormCubit(
        GetCapFormUseCase(repository),
        submit: SubmitIncidentFormUseCase(repository),
      );
      addTearDown(cubit.close);
      await cubit.load(1);
      cubit.answer(1, [
        CapFormAnswer(
          questionId: 1,
          questionTypeId: 4,
          evidence: CapFormEvidence(
            name: 'photo.jpg',
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList([1]),
          ),
        ),
      ]);
      await cubit.submit(
        incidentId: 26,
        newStatusId: 3,
        actionTypeId: 3,
        remark: '',
      );
      expect(repository.submissions, 1);
      expect(cubit.state.submissionFailure, isNull);
      expect(repository.lastSubmission!.toJson()['Answers'], [
        {
          'QuestionId': 1,
          'QuestionTypeId': 4,
          'TextAnswer': '',
          'AnswerBytes': [1],
          'OptionAnswer': 0,
        },
      ]);
      expect(cubit.state.answers[1]!.single.evidence, isNotNull);
    },
  );
  testWidgets('signature supports draw, clear, PNG confirmation', (
    tester,
  ) async {
    CapFormEvidence? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.push<CapFormEvidence>(
                  context,
                  MaterialPageRoute(builder: (_) => const CapSignatureScreen()),
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
    final canvas = find.bySemanticsLabel('Signature canvas');
    await tester.drag(canvas, const Offset(80, 30));
    await tester.pump();
    await tester.tap(find.text('Clear'));
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(canvas));
    await gesture.moveBy(const Offset(30, 5));
    await gesture.moveBy(const Offset(30, 10));
    await gesture.moveBy(const Offset(30, -5));
    await gesture.up();
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Use signature'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(result?.mimeType, 'image/png');
    expect(result?.bytes.isNotEmpty, true);
  });
  testWidgets(
    'route shows real submission success and returns true for refresh',
    (tester) async {
      final repository = _Repository()
        ..form = CapQuestionForm(id: 1085, title: 'Form', questions: []);
      final cubit = CapFormCubit(
        GetCapFormUseCase(repository),
        submit: SubmitIncidentFormUseCase(repository),
      );
      addTearDown(cubit.close);
      bool? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CapIncidentFormScreen(
                        formId: 1085,
                        incidentId: 26,
                        newStatusId: 3,
                        actionTypeId: 3,
                        cubit: cubit,
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
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Submitted successfully'), findsOneWidget);
      await tester.tap(find.text('Back to incident'));
      await tester.pumpAndSettle();
      expect(saved, true);
      expect(repository.submissions, 1);
    },
  );
  test('all STC type IDs resolve and unknown types fail safely', () async {
    expect(
      [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        13,
        14,
      ].map(CapQuestionType.fromId).contains(CapQuestionType.unsupported),
      false,
    );
    final repository = _Repository()
      ..form = CapQuestionForm(
        id: 1,
        title: 'Unknown',
        questions: [CapFormQuestion(id: 1, title: 'Unknown', typeId: 999)],
      );
    final cubit = CapFormCubit(GetCapFormUseCase(repository));
    addTearDown(cubit.close);
    await cubit.load(1);
    expect(cubit.confirmedAnswers(), isNull);
    expect(cubit.state.errors[1], CapFormError.unsupported);
  });
  test(
    'multi choice emits separate answers with the selected option IDs',
    () async {
      final question = CapFormQuestion(
        id: 1,
        title: 'Choices',
        typeId: 14,
        options: const [CapFormOption(1, 'One'), CapFormOption(2, 'Two')],
      );
      final repository = _Repository()
        ..form = CapQuestionForm(
          id: 1,
          title: 'Choices',
          questions: [question],
        );
      final cubit = CapFormCubit(GetCapFormUseCase(repository));
      addTearDown(cubit.close);
      await cubit.load(1);
      cubit.options(question, {1, 2});
      expect(cubit.state.answers[1]!.length, 2);
      final answers = cubit.confirmedAnswers()!;
      expect(answers.map((a) => a.questionId), [1, 1]);
      expect(answers.map((a) => a.optionId), [1, 2]);
      expect(cubit.state.errors, isEmpty);
    },
  );
  test(
    'required evidence cannot silently pass without a capture provider',
    () async {
      final repository = _Repository()
        ..form = CapQuestionForm(
          id: 1,
          title: 'Evidence',
          questions: [
            for (final id in [4, 6, 7, 11])
              CapFormQuestion(
                id: id,
                title: 'Evidence',
                typeId: id,
                required: true,
              ),
          ],
        );
      final cubit = CapFormCubit(GetCapFormUseCase(repository));
      addTearDown(cubit.close);
      await cubit.load(1);
      expect(cubit.confirmedAnswers(), isNull);
      expect(cubit.state.errors.length, 4);
    },
  );
  test('preserves STC types and supplied CAP field casing', () {
    final form = CapQuestionForm.fromJson(fixture());
    expect(form.id, 1085);
    expect(form.questions.last.type, CapQuestionType.location);
    expect(const GetCapFormPayload(1085).toJson(), {'FormId': 1085});
    final payload = IncidentFormSubmission(
      incidentId: 26,
      newStatusId: 3,
      actionTypeId: 3,
      formId: 1085,
      remark: 'approve',
      answers: const [
        CapFormAnswer(
          questionId: 708,
          questionTypeId: 13,
          text: '27.2112,43.3565',
        ),
      ],
    );
    expect(payload.toJson(), {
      'IncidentId': 26,
      'NewStatusId': 3,
      'ActionTypeId': 3,
      'QuestionFormId': 1085,
      'Remark': 'approve',
      'lat': '',
      'long': '',
      'photo': '',
      'Answers': [
        {
          'QuestionId': 708,
          'QuestionTypeId': 13,
          'TextAnswer': '27.2112,43.3565',
          'AnswerBytes': null,
          'OptionAnswer': 0,
        },
      ],
    });
  });
  test(
    'validation requires real values, checks GPS, and returns answers only',
    () async {
      final cubit = CapFormCubit(GetCapFormUseCase(_Repository()));
      addTearDown(cubit.close);
      await cubit.load(1085);
      expect(cubit.confirmedAnswers(), isNull);
      expect(cubit.state.errors.length, 2);
      cubit.text(cubit.state.form!.questions.first, 'serial-100');
      cubit.text(cubit.state.form!.questions.last, '999,20');
      expect(cubit.confirmedAnswers(), isNull);
      cubit.text(cubit.state.form!.questions.last, '30.04,31.23');
      expect(cubit.confirmedAnswers()!.length, 2);
    },
  );
  test('conditional descendants clear and do not leak answers', () async {
    final repository = _Repository()
      ..form = CapQuestionForm(
        id: 7,
        title: 'Conditions',
        questions: [
          CapFormQuestion(
            id: 1,
            title: 'Damaged?',
            typeId: 3,
            options: const [CapFormOption(10, 'Yes'), CapFormOption(11, 'No')],
          ),
          CapFormQuestion(
            id: 2,
            title: 'Damage',
            typeId: 1,
            required: true,
            relatedQuestionId: 1,
            relatedAnswerId: 10,
          ),
        ],
      );
    final cubit = CapFormCubit(GetCapFormUseCase(repository));
    addTearDown(cubit.close);
    await cubit.load(7);
    cubit.options(repository.form.questions.first, {10});
    expect(cubit.state.visibleQuestions.length, 2);
    expect(cubit.confirmedAnswers(), isNull);
    cubit.text(repository.form.questions.last, 'Broken');
    cubit.options(repository.form.questions.first, {11});
    expect(cubit.state.answers.containsKey(2), false);
    expect(cubit.confirmedAnswers()!.map((a) => a.questionId), [1]);
  });
  test(
    'invalid reference/cycle fails parsing rather than silently hiding fields',
    () {
      final json = fixture();
      (json['taskquestion'] as List).first['RelatedQuestionId'] = 702;
      expect(() => CapQuestionForm.fromJson(json), throwsFormatException);
    },
  );
  test('late load never overwrites new form or emits after close', () async {
    final repository = _Repository()..delayed = true;
    final cubit = CapFormCubit(GetCapFormUseCase(repository));
    final first = cubit.load(1);
    final second = cubit.load(2);
    repository.gates[1].complete(
      Success(CapQuestionForm(id: 2, title: 'new', questions: [])),
    );
    await second;
    repository.gates[0].complete(Success(repository.form));
    await first;
    expect(cubit.state.form!.id, 2);
    final third = cubit.load(3);
    await cubit.close();
    repository.gates[2].complete(Success(repository.form));
    await third;
  });
  test(
    'API uses shared metadata and handles null mutation data and malformed form',
    () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final context = ApiRequestContextProvider(
        users: null,
        currentUser: () => const SessionUser(id: '4099', name: 'Engineer'),
        deviceInfo: CapDeviceAppInfoProvider(
          osVersion: '15',
          deviceType: 'iOS',
          appVersion: '1',
        ),
      );
      final repository = CapFormRepositoryImpl(CapFormApiService(dio), context);
      expect(await repository.load(1085), isA<Success<CapQuestionForm>>());
      expect(adapter.calls.single.path, 'CAP/CapLookup/GetFormQuestion');
      final sent = jsonDecode(jsonEncode(adapter.calls.single.data)) as Map;
      expect(sent['userid'], 4099);
      expect(sent['data'], {'FormId': 1085});
      adapter.body = {'resultcode': 1, 'data': null};
      expect(
        await repository.submit(
          IncidentFormSubmission(
            incidentId: 26,
            newStatusId: 3,
            actionTypeId: 3,
            formId: 1085,
            remark: '',
            answers: [],
          ),
        ),
        isA<Success<void>>(),
      );
      expect(adapter.calls.last.path, 'CAP/CapIncident/IncidentStatusChange');
      adapter.body = {
        'resultcode': 1,
        'data': {'FormId': 1085},
      };
      expect(
        await repository.load(1085),
        isA<FailureResult<CapQuestionForm>>(),
      );
      adapter.body = {
        'resultcode': 0,
        'resultmessageen': 'Rejected',
        'data': null,
      };
      expect(
        await repository.load(1085),
        isA<FailureResult<CapQuestionForm>>(),
      );
    },
  );
  for (final language in ['ar', 'en']) {
    testWidgets('form fits narrow viewport with large text in $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      final cubit = CapFormCubit(GetCapFormUseCase(repository));
      addTearDown(cubit.close);
      await cubit.load(1085);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: CapDynamicForm(
              cubit: cubit,
              onConfirmed: (_) {},
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byType(CapDynamicForm))),
        language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
    });
  }
}
