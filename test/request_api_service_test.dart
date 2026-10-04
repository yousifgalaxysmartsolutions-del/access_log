import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/network/cap/general_response.dart';
import 'package:access_log_plus/features/requests/data/api/request_api_service.dart';
import 'package:access_log_plus/features/requests/data/models/request_models.dart';
import 'request_models_test.dart'
    show
        envelope,
        metadataEnvelope,
        metadataJson,
        lookupJson,
        listJson,
        listBody,
        listBodyJson;

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, dynamic> responseData = {};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    jsonEncode(options.data);
    return ResponseBody.fromString(
      jsonEncode({
        'resultcode': 1,
        'resultmessageen': 'Suceess Get data',
        'resultmessagear': 'Suceess Get data',
        'data': responseData,
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
  test(
    'four endpoints use supplied Dio/interceptors, exact bodies and shared response convention',
    () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://cap.test/api/'))
        ..httpClientAdapter = adapter;
      var intercepted = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            intercepted++;
            options.headers['X-Test-Interceptor'] = 'retained';
            handler.next(options);
          },
        ),
      );
      final api = RequestApiService(dio);
      adapter.responseData = lookupJson;
      final lookup = await api.getAllRequestLookup(metadataEnvelope());
      expect(
        GeneralResponse.parse(
          lookup,
          (raw) => RequestLookupData.fromJson(raw as Map<String, dynamic>),
        ).data!.requestType.length,
        3,
      );
      adapter.responseData = listJson;
      final list = await api.getRequestList(envelope(listBody));
      expect(
        GeneralResponse.parse(
          list,
          (raw) => RequestListData.fromJson(raw as Map<String, dynamic>),
        ).data!.totalCount,
        3,
      );
      adapter.responseData = {
        'id': 1,
        'requestStatus': {'id': 2, 'name': 'Approved'},
      };
      final approved = await api.requestApprove(
        envelope(
          const RequestApproveData(requestId: 1, remark: 'test approve'),
        ),
      );
      expect(
        GeneralResponse.parse(
          approved,
          (raw) => RequestDecisionData.fromJson(raw as Map<String, dynamic>),
        ).data!.requestStatus!.id,
        2,
      );
      adapter.responseData = {
        'id': 2,
        'requestStatus': {'id': 3, 'name': 'Rejected'},
      };
      final rejected = await api.requestReject(
        envelope(const RequestRejectData(requestId: 2, reason: 'tst rej')),
      );
      expect(
        GeneralResponse.parse(
          rejected,
          (raw) => RequestDecisionData.fromJson(raw as Map<String, dynamic>),
        ).data!.requestStatus!.id,
        3,
      );
      expect(intercepted, 4);
      expect(adapter.requests.map((r) => r.path), [
        'CAP/CapLookup/GetAllRequestLookup',
        'CAP/CapRequest/GetRequestList',
        'CAP/CapRequest/RequestApprove',
        'CAP/CapRequest/RequestReject',
      ]);
      for (final request in adapter.requests) {
        expect(request.method, 'POST');
        expect(request.headers['X-Test-Interceptor'], 'retained');
        expect(request.uri.toString(), 'https://cap.test/api/${request.path}');
      }
      expect(
        adapter.requests.map((r) => jsonDecode(jsonEncode(r.data))).toList(),
        [
          metadataJson,
          {...metadataJson, 'data': listBodyJson},
          {
            ...metadataJson,
            'data': {'RequestId': 1, 'Remark': 'test approve'},
          },
          {
            ...metadataJson,
            'data': {'RequestId': 2, 'Reason': 'tst rej'},
          },
        ],
      );
      dio.close();
    },
  );
}
