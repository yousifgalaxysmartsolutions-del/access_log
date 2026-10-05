import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/network/cap/cap_locale_holder.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/requests/data/api/request_api_service.dart';
import 'package:access_log_plus/features/requests/data/models/request_models.dart';
import 'package:access_log_plus/features/requests/data/repositories/request_repository_impl.dart';
import 'package:access_log_plus/features/requests/domain/repositories/request_repository.dart';
import 'request_models_test.dart' show lookupJson, listJson, listBodyJson;

class _Users implements SessionUserStorage {
  SessionUser? user = const SessionUser(id: '4089', name: 'Test engineer');
  bool fail = false;
  @override
  Future<SessionUser?> readUser() async {
    if (fail) throw const FormatException('Storage unavailable');
    return user;
  }

  @override
  Future<void> clearUser() async {}
  @override
  Future<void> writeUser(SessionUser value) async {}
}

class _Adapter implements HttpClientAdapter {
  Map<String, dynamic> body = {};
  bool fail = false;
  final requests = <RequestOptions>[];
  Map<String, dynamic> get sent =>
      jsonDecode(jsonEncode(requests.last.data)) as Map<String, dynamic>;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (fail) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
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

Future<Result<RequestListData>> _list(RequestRepository repo) =>
    repo.getRequestList(
      fromDate: DateTime(2026, 9, 1, 14),
      toDate: DateTime(2026, 9, 10, 23),
      requestTypeId: -1,
      requestStatusId: -1,
      locationCode: '',
      incidentNo: '',
      page: 1,
      pageSize: 2,
    );

void main() {
  late _Adapter adapter;
  late _Users users;
  late Dio dio;
  late RequestRepository repo;
  late ApiRequestContextProvider context;
  late Locale previousLocale;
  void respond(Object? data) => adapter.body = {'resultcode': 1, 'data': data};
  setUp(() {
    previousLocale = CapLocaleHolder.instance.locale;
    CapLocaleHolder.instance.update(const Locale('en'));
    adapter = _Adapter();
    users = _Users();
    dio = Dio(BaseOptions(baseUrl: 'https://cap.test/api/'))
      ..httpClientAdapter = adapter;
    context = ApiRequestContextProvider(
      users: users,
      deviceInfo: CapDeviceAppInfoProvider(
        osVersion: '15.1',
        deviceType: 'iOS',
        appVersion: '1',
      ),
    );
    repo = RequestRepositoryImpl(RequestApiService(dio), context);
  });
  tearDown(() {
    dio.close();
    CapLocaleHolder.instance.update(previousLocale);
  });

  test(
    'lookup success uses session metadata and omits data entirely',
    () async {
      respond(lookupJson);
      final result = await repo.getRequestLookup();
      expect(result, isA<Success<RequestLookupData>>());
      final data = (result as Success<RequestLookupData>).data;
      expect(data.requestType.length, 3);
      expect(data.requestStatus.length, 3);
      expect(data.requestActionType.length, 3);
      final normal = await context.wrap({
        'probe': 1,
      }, authenticationMessage: 'Sign in');
      final normalJson =
          (normal as Success).data.toJson() as Map<String, dynamic>;
      expect(normalJson['data'], {'probe': 1});
      expect(
        adapter.sent,
        Map<String, dynamic>.from(normalJson)..remove('data'),
      );
      expect(adapter.sent.containsKey('data'), false);
      expect(adapter.sent['userid'], 4089);
      expect(adapter.requests.single.path, 'CAP/CapLookup/GetAllRequestLookup');
    },
  );
  test('empty lookup arrays are success', () async {
    respond({'requestType': [], 'requestStatus': [], 'requestActionType': []});
    expect(await repo.getRequestLookup(), isA<Success<RequestLookupData>>());
  });
  test('list exact payload, typed results and pagination metadata', () async {
    respond(listJson);
    final result = await _list(repo);
    final data = (result as Success<RequestListData>).data;
    expect(adapter.sent['data'], listBodyJson);
    expect(data.items.length, 2);
    expect(data.totalCount, 3);
    expect(data.page, 1);
    expect(data.pageSize, 2);
    expect(data.items.first.id, 3);
    expect(data.items.first.incidentId, 3);
    expect(data.items.first.incidentNo, 'INC-0003');
    expect(data.items.first.requestStatus?.name, 'Pending');
    expect(
      adapter.requests.length,
      1,
      reason: 'repository does not auto-paginate',
    );
  });
  test(
    'non-default filters, page and arbitrary dates pass through unchanged',
    () async {
      respond({'items': [], 'totalCount': 71, 'page': 4, 'pageSize': 20});
      final result = await repo.getRequestList(
        fromDate: DateTime(2031, 2, 3),
        toDate: DateTime(2031, 3, 4),
        requestTypeId: 3,
        requestStatusId: 1,
        locationCode: 'D10736',
        incidentNo: 'INC-0003',
        page: 4,
        pageSize: 20,
      );
      expect(adapter.sent['data'], {
        'FromDate': '2031-02-03',
        'ToDate': '2031-03-04',
        'RequestTypeId': 3,
        'RequestStatusId': 1,
        'LocationCode': 'D10736',
        'IncidentNo': 'INC-0003',
        'Page': 4,
        'PageSize': 20,
      });
      expect((result as Success<RequestListData>).data.totalCount, 71);
    },
  );
  test('empty list success retains backend metadata', () async {
    respond({'items': [], 'totalCount': 0, 'page': 1, 'pageSize': 20});
    final data = ((await _list(repo)) as Success<RequestListData>).data;
    expect(data.items, isEmpty);
    expect(data.totalCount, 0);
    expect(data.pageSize, 20);
  });
  test('approve uses Remark and returns actual backend decision', () async {
    respond({
      'id': 1,
      'requestStatus': {'id': 2, 'name': 'Approved'},
    });
    final data =
        ((await repo.approveRequest(requestId: 1, remark: 'test approve'))
                as Success<RequestDecisionData>)
            .data;
    expect(adapter.sent['data'], {'RequestId': 1, 'Remark': 'test approve'});
    expect(data.id, 1);
    expect(data.requestStatus?.id, 2);
    expect(data.requestStatus?.name, 'Approved');
  });
  test('reject uses Reason and returns actual backend decision', () async {
    respond({
      'id': 2,
      'requestStatus': {'id': 3, 'name': 'Rejected'},
    });
    final data =
        ((await repo.rejectRequest(requestId: 2, reason: 'tst rej'))
                as Success<RequestDecisionData>)
            .data;
    expect(adapter.sent['data'], {'RequestId': 2, 'Reason': 'tst rej'});
    expect(data.id, 2);
    expect(data.requestStatus?.id, 3);
    expect(data.requestStatus?.name, 'Rejected');
  });
  test('decisions never infer status or overwrite caller text', () async {
    respond({
      'id': 77,
      'requestStatus': {'id': 90, 'name': 'Queued'},
    });
    final approved =
        ((await repo.approveRequest(requestId: 19, remark: ' ملاحظة '))
                as Success<RequestDecisionData>)
            .data;
    expect(adapter.sent['data'], {'RequestId': 19, 'Remark': ' ملاحظة '});
    expect(approved.requestStatus?.name, 'Queued');
    final rejected =
        ((await repo.rejectRequest(requestId: 20, reason: 'custom reason'))
                as Success<RequestDecisionData>)
            .data;
    expect(adapter.sent['data'], {'RequestId': 20, 'Reason': 'custom reason'});
    expect(rejected.id, 77);
    expect(rejected.requestStatus?.id, 90);
  });

  final operations =
      <String, Future<Result<Object?>> Function(RequestRepository)>{
        'lookup': (r) => r.getRequestLookup(),
        'list': _list,
        'approve': (r) => r.approveRequest(requestId: 1, remark: 'reviewed'),
        'reject': (r) => r.rejectRequest(requestId: 2, reason: 'incorrect'),
      };
  for (final operation in operations.entries) {
    test(
      '${operation.key}: a malformed nested field fails as a parse error',
      () async {
        // Regression for the reported crash. `totalCount` is declared `int`, so
        // the generated `(json['totalCount'] as num)` cast raises a `TypeError`.
        // That is an `Error`, not an `Exception`, so it used to escape the
        // `on Exception` repository boundary as an unhandled exception.
        adapter.body = {
          'resultcode': 1,
          'resultmessages': {'resultmessageen': 'OK'},
          'data': {...listJson, 'totalCount': 'many'},
        };
        final result = await _list(repo);
        expect(result, isA<FailureResult>());
        final failure = (result as FailureResult).failure;
        expect(failure, isA<ServiceFailure>());
        expect((failure as ServiceFailure).code, 'cap_parse_error');
        // The request still reached the endpoint; only decoding failed.
        expect(adapter.requests, hasLength(1));
      },
    );
    test(
      '${operation.key}: CAP failure uses current backend message language',
      () async {
        adapter.body = {
          'resultcode': 0,
          'resultmessages': {
            'resultmessageen': 'Denied',
            'resultmessagear': 'غير مسموح',
          },
          'data': null,
        };
        for (final lang in ['en', 'ar']) {
          CapLocaleHolder.instance.update(Locale(lang));
          final result = await operation.value(repo);
          expect(result, isA<FailureResult>());
          expect((result as FailureResult).failure, isA<ServiceFailure>());
          expect(result.failure.message, lang == 'ar' ? 'غير مسموح' : 'Denied');
        }
      },
    );
    test('${operation.key}: success with null required data fails', () async {
      respond(null);
      final result = await operation.value(repo);
      expect(result, isA<FailureResult>());
      expect((result as FailureResult).failure, isA<ServiceFailure>());
    });
    test('${operation.key}: Dio failure maps through apiGuard', () async {
      adapter.fail = true;
      final result = await operation.value(repo);
      expect(result, isA<FailureResult>());
      expect((result as FailureResult).failure, isA<NetworkFailure>());
    });
    test('${operation.key}: invalid session prevents network access', () async {
      for (final user in [
        null,
        const SessionUser(id: '0'),
        const SessionUser(id: 'invalid'),
      ]) {
        users.user = user;
        final result = await operation.value(repo);
        expect(result, isA<FailureResult>());
        expect((result as FailureResult).failure, isA<UnauthorizedFailure>());
      }
      expect(adapter.requests, isEmpty);
    });
    test(
      '${operation.key}: context storage exception does not escape',
      () async {
        users.fail = true;
        expect(await operation.value(repo), isA<FailureResult>());
        expect(adapter.requests, isEmpty);
      },
    );
  }
}
