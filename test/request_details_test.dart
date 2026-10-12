import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/di/injection.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/features/requests/data/models/request_models.dart';
import 'package:access_log_plus/features/requests/domain/repositories/request_repository.dart';
import 'package:access_log_plus/features/requests/domain/usecases/get_request_details_use_case.dart';
import 'package:access_log_plus/features/requests/presentation/bloc/request_details_cubit.dart';
import 'package:access_log_plus/models/models.dart';
import 'package:access_log_plus/screens/requests/my_requests_screen.dart';
import 'package:access_log_plus/screens/requests/api_request_details_screen.dart';

final requestDetailsFixture = <String, dynamic>{
  'id': 3,
  'incident': {
    'id': 3,
    'incidentNo': 'INC-0003',
    'title': 'TEST-INC0001',
    'description': 'TEST Descriptiom',
    'alarmId': '1',
    'alarmName': 'TEST3',
    'productName': 'Pro3',
    'nativeMoName': null,
    'raisedTime': '2026-10-02T00:00:00',
    'clearedTime': null,
    'createdDate': '2026-10-01T00:00:00',
    'startDate': null,
    'closedDate': null,
    'lastModifiedDate': null,
    'alarmType': {'id': 3, 'name': 'GSM Cell out of Service'},
    'incidentType': {'id': 1, 'name': 'X2 Interface Fault'},
    'priority': {'id': 1, 'name': 'High'},
    'status': {'id': 1, 'name': 'Need Assign'},
    'notificationType': {'id': 1, 'name': 'manual'},
    'assignedEngineer': null,
    'lastModifiedBy': null,
    'location': {
      'id': 'D10736',
      'name': 'site 3',
      'region': {'id': 79, 'name': 'Cairo'},
      'area': {'id': 103, 'name': 'Monshat Naser'},
      'latitude': 31.34573068640783,
      'longitude': 30.056509692385522,
    },
  },
  'requestType': {'id': 1, 'name': 'Intervention Request'},
  'requestStatus': {'id': 1, 'name': 'Pending'},
  'remark': 'test approve',
  'NoOfMinute': null,
  'questionFormId': '1',
  'formName': 'Test Form1',
  'formDescription': 'Test Form1',
  'createdDate': '2026-09-10T00:57:15.38',
  'createdBy': {'id': 4098, 'name': 'gsm manager'},
  'lastModifiedBy': {'id': 4098, 'name': 'gsm manager'},
  'lastModifiedDate': '2026-09-10T00:57:15.38',
  'formAnswers': [
    for (final id in [12, 13])
      {
        'id': id,
        'questionId': 702,
        'questionText': 'Incident Serial?',
        'questionType': '1',
        'questionTypeInfo': {'id': 1, 'name': 'Text'},
        'mandatory': true,
        'orderNo': null,
        'textAnswer': 'test q1',
        'optionAnswer': null,
        'createdBy': {'id': 4098, 'name': 'gsm manager'},
        'createdDate': '2026-09-10T00:57:15.38',
        'updatedDate': '2026-09-10T00:57:15.38',
      },
    {
      'id': 14,
      'questionId': 704,
      'questionText': 'Remark ?',
      'questionType': '1',
      'questionTypeInfo': {'id': 1, 'name': 'Text'},
      'mandatory': false,
      'orderNo': null,
      'textAnswer': 'test q2',
      'optionAnswer': null,
    },
    {
      'id': 15,
      'questionId': 708,
      'questionText': 'GPS Location ?',
      'questionType': '13',
      'questionTypeInfo': {'id': 13, 'name': 'GPS Location'},
      'mandatory': true,
      'textAnswer': '27.2112,43.3565',
      'optionAnswer': null,
    },
  ],
  'timeline': [
    {
      'dateTime': '2026-09-10T00:57:23.043',
      'actionType': {'id': 1, 'name': 'Creation'},
      'eventType': 'StatusChange',
      'eventTitle': 'Request Created',
      'eventDescription': 'Request created',
      'remark': 'test approve',
      'oldValue': null,
      'newValue': {'id': 1, 'name': 'Pending'},
      'referenceId': null,
      'performedBy': {'id': 4098, 'name': 'gsm manager'},
    },
  ],
};

class _Repository implements RequestRepository {
  final calls = <int>[];
  Future<Result<RequestDetailsData>> Function(int)? respond;
  @override
  Future<Result<RequestDetailsData>> getRequestDetails({
    required int requestId,
  }) {
    calls.add(requestId);
    return respond?.call(requestId) ??
        Future.value(
          Success(RequestDetailsData.fromJson(requestDetailsFixture)),
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected operation');
}

class RequestDetailsTestCubit extends RequestDetailsCubit {
  RequestDetailsTestCubit()
    : super(
        GetRequestDetailsUseCase(
          _Repository()
            ..respond = (id) async => Success(RequestDetailsData(id: id)),
        ),
      );
}

void main() {
  tearDown(() async => services.reset());
  test(
    'details contract preserves nested incident, duplicate answers and timeline',
    () {
      final data = RequestDetailsData.fromJson(requestDetailsFixture);
      expect(data.incident!.location!.region!.name, 'Cairo');
      expect(data.incident!.alarmId, '1');
      expect(data.noOfMinute, isNull);
      expect(data.formAnswers, hasLength(4));
      expect(data.formAnswers.take(2).map((answer) => answer.questionId), [
        702,
        702,
      ]);
      expect(data.formAnswers.last.textAnswer, '27.2112,43.3565');
      expect(data.timeline.single.remark, 'test approve');
      expect(data.timeline.single.performedBy!.name, 'gsm manager');
      expect(
        RequestDetailsData.fromJson({
          'id': 3,
          'formAnswers': null,
          'timeline': null,
        }).formAnswers,
        isEmpty,
      );
    },
  );
  test(
    'details Cubit supports loading/error/retry and rejects mismatched ID',
    () async {
      final repo = _Repository();
      final cubit = RequestDetailsCubit(GetRequestDetailsUseCase(repo));
      addTearDown(cubit.close);
      final gate = Completer<Result<RequestDetailsData>>();
      repo.respond = (_) => gate.future;
      final loading = cubit.load(3);
      expect(cubit.state.loading, isTrue);
      gate.complete(const FailureResult(NetworkFailure()));
      await loading;
      expect(cubit.state.failure, isA<NetworkFailure>());
      repo.respond = null;
      await cubit.load(3);
      expect(cubit.state.data!.id, 3);
      await cubit.load(99);
      expect(cubit.state.data, isNull);
      expect(cubit.state.failure, isA<ValidationFailure>());
      final before = repo.calls.length;
      await cubit.load(0);
      expect(repo.calls.length, before);
    },
  );
  for (final language in ['en', 'ar']) {
    testWidgets(
      'request tap loads API details in $language and opens real incident',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Repository();
        services.registerFactory<RequestDetailsCubit>(
          () => RequestDetailsCubit(GetRequestDetailsUseCase(repo)),
        );
        CapIncident? selected;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            onGenerateRoute: (settings) {
              selected = settings.arguments as CapIncident;
              return MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Real incident')),
              );
            },
            home: const Scaffold(
              body: SingleChildScrollView(
                child: RequestCard(request: RequestListItemDto(id: 3)),
              ),
            ),
          ),
        );
        await tester.tap(find.text(language == 'ar' ? 'طلب #3' : 'Request #3'));
        await tester.pumpAndSettle();
        expect(find.byType(ApiRequestDetailsScreen), findsOneWidget);
        expect(repo.calls, [3]);
        expect(find.text('Intervention Request'), findsOneWidget);
        expect(find.text('Pending'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.text(
            language == 'ar' ? 'عرض البلاغ المرتبط' : 'View Related Incident',
          ),
        );
        await tester.pumpAndSettle();
        expect(selected!.incidentId, 3);
        expect(selected!.siteCode, 'D10736');
        expect(selected!.region, 'Cairo');
        expect(selected!.backendStatusId, 1);
      },
    );
  }
}
