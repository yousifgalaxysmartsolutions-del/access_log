import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:access_log_plus/core/di/injection.dart';
import 'package:access_log_plus/core/routes/app_routes.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/network/cap/api_request_context.dart';
import 'package:access_log_plus/core/network/cap/cap_device_app_info.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/incidents/data/incident_lookup_store.dart';
import 'package:access_log_plus/features/incidents/data/api/incident_api_service.dart';
import 'package:access_log_plus/features/incidents/data/repositories/incident_repository_impl.dart';
import 'package:access_log_plus/features/incidents/domain/usecases/get_incident_list_use_case.dart';
import 'package:access_log_plus/screens/dashboard/cap_dashboard_screen.dart';
import 'package:access_log_plus/models/models.dart';
import 'package:access_log_plus/features/dashboard/presentation/dashboard_incident_navigation.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_lookup_models.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_list_models.dart';
import 'package:access_log_plus/features/incidents/data/mappers/incident_mapper.dart';

class _Lookup implements IncidentLookupStore {
  @override
  IncidentLookupData get current => IncidentLookupData(
    status: const [
      IncidentLookupItem(id: 407, code: 'IN_PROCESS'),
      IncidentLookupItem(id: 509, code: 'COMPLETED'),
      IncidentLookupItem(id: 713, code: 'HOLD'),
      IncidentLookupItem(id: 207, code: 'NEED_APPROVAL'),
    ],
  );
  @override
  Future<Result<IncidentLookupData>> refresh() async => Success(current);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport implements HttpClientAdapter {
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
        'resultcode': 1,
        'data': {'items': [], 'totalCount': 0, 'page': 1, 'pageSize': 100},
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
  testWidgets(
    'Real dashboard card -> named route -> Retrofit sends selected Lookup ID',
    (tester) async {
      await services.reset();
      addTearDown(services.reset);
      final transport = _Transport();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/'))
        ..httpClientAdapter = transport;
      addTearDown(dio.close);
      services.registerSingleton<IncidentLookupStore>(_Lookup());
      services.registerSingleton<GetIncidentListUseCase>(
        GetIncidentListUseCase(
          IncidentRepositoryImpl(
            IncidentApiService(dio),
            ApiRequestContextProvider(
              users: null,
              currentUser: () =>
                  const SessionUser(id: '4098', name: 'Engineer'),
              deviceInfo: CapDeviceAppInfoProvider(
                appVersion: '1',
                osVersion: '15.1',
                deviceType: 'Android',
              ),
            ),
          ),
        ),
      );
      final navigator = GlobalKey<NavigatorState>();
      final filters = <IncidentListFilter>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const CapDashboardScreen(),
          onGenerateRoute: (settings) {
            if (settings.arguments is IncidentListFilter) {
              filters.add(settings.arguments as IncidentListFilter);
            }
            return AppRoutes.onGenerateRoute(settings);
          },
        ),
      );
      await tester.pumpAndSettle();
      for (final entry in [
        ('In Progress', 407),
        ('Completed', 509),
        ('On Hold', 713),
        ('Need Approval', 207),
      ]) {
        await tester.scrollUntilVisible(
          find.text(entry.$1).first,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(entry.$1).first);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
        expect(filters.last.statusId, entry.$2);
        expect(
          (transport.calls.last.data as Map)['data']['StatusId'],
          entry.$2,
        );
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
      }
      expect(transport.calls.length, 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'Dashboard uses arbitrary backend IDs rather than enum indexes/fixed IDs',
    () {
      final entries = [
        (CapIncidentStatus.needAssign, 'NEED_ASSIGN', 101),
        (CapIncidentStatus.needApproval, 'NEED_APPROVAL', 207),
        (CapIncidentStatus.pending, 'PENDING', 303),
        (CapIncidentStatus.inProcess, 'IN_PROCESS', 407),
        (CapIncidentStatus.completed, 'COMPLETED', 509),
        (CapIncidentStatus.hold, 'HOLD', 713),
        (CapIncidentStatus.cancelled, 'CANCELLED', 601),
      ];
      final lookup = IncidentLookupData(
        status: entries
            .map(
              (e) => IncidentLookupItem(
                id: e.$3,
                code: e.$2,
                name: 'Backend label',
              ),
            )
            .toList(),
      );
      for (final entry in entries) {
        final filter = DashboardIncidentNavigation.resolve(entry.$1, lookup)!;
        expect(filter.statusId, entry.$3);
        expect(filter.status, entry.$1);
        expect(filter.isActive, true);
        expect(filter.withoutStatus().statusId, isNull);
        expect(filter.withoutStatus().isActive, false);
      }
    },
  );
  test(
    'Name aliases supported, unavailable/ambiguous status never becomes all',
    () {
      expect(
        DashboardIncidentNavigation.resolve(
          CapIncidentStatus.inProcess,
          IncidentLookupData(
            status: [const IncidentLookupItem(id: 407, name: 'In Progress')],
          ),
        )!.statusId,
        407,
      );
      expect(
        DashboardIncidentNavigation.resolve(
          CapIncidentStatus.hold,
          IncidentLookupData(
            status: [const IncidentLookupItem(id: 713, name: 'On Hold')],
          ),
        )!.statusId,
        713,
      );
      expect(
        DashboardIncidentNavigation.resolve(
          CapIncidentStatus.needApproval,
          IncidentLookupData(),
        ),
        isNull,
      );
      expect(
        DashboardIncidentNavigation.resolve(
          CapIncidentStatus.completed,
          IncidentLookupData(
            status: [
              const IncidentLookupItem(id: 501, code: 'COMPLETED'),
              const IncidentLookupItem(id: 502, code: 'COMPLETED'),
            ],
          ),
        ),
        isNull,
      );
    },
  );
  test(
    'Incident mapper preserves original status ID for numeric filtering',
    () {
      final incident = IncidentMapper.toIncident(
        IncidentListItem.fromJson({
          'incidentId': 11,
          'status': {'id': 407, 'name': 'In Process'},
        }),
        requestedOn: DateTime(2026, 10, 7),
      );
      expect(incident.backendStatusId, 407);
      expect(incident.status, CapIncidentStatus.inProcess);
    },
  );
}
