import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:access_log_plus/core/di/injection.dart';
import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/features/requests/data/models/request_models.dart';
import 'package:access_log_plus/features/requests/domain/repositories/request_repository.dart';
import 'package:access_log_plus/features/requests/domain/usecases/get_request_lookup_use_case.dart';
import 'package:access_log_plus/features/requests/domain/usecases/get_request_list_use_case.dart';
import 'package:access_log_plus/features/requests/domain/usecases/approve_request_use_case.dart';
import 'package:access_log_plus/features/requests/domain/usecases/reject_request_use_case.dart';
import 'package:access_log_plus/features/incidents/data/models/incident_details_models.dart'
    show IdNameDto;
import 'package:access_log_plus/features/requests/presentation/bloc/request_list_bloc.dart';
import 'package:access_log_plus/screens/requests/my_requests_screen.dart';
import 'request_models_test.dart' show listJson, lookupJson;

class _UnusedRepository implements RequestRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Widget test must only dispatch events');
}

class _Bloc extends RequestListBloc {
  _Bloc()
    : super(
        getRequestLookup: GetRequestLookupUseCase(_UnusedRepository()),
        getRequestList: GetRequestListUseCase(_UnusedRepository()),
        approveRequest: ApproveRequestUseCase(_UnusedRepository()),
        rejectRequest: RejectRequestUseCase(_UnusedRepository()),
      );
  final events = <RequestListEvent>[];
  @override
  void add(RequestListEvent event) => events.add(event);
  void show(RequestListState value) => emit(value);
}

void main() {
  late _Bloc bloc;
  setUp(() {
    bloc = _Bloc();
    bloc.show(
      bloc.state.copyWith(
        items: RequestListData.fromJson(listJson).items,
        lookupData: RequestLookupData.fromJson(lookupJson),
        totalCount: 2,
      ),
    );
    services.registerFactory<RequestListBloc>(() => bloc);
  });
  tearDown(() async {
    if (!bloc.isClosed) await bloc.close();
    await services.reset();
  });
  Future<void> open(WidgetTester tester, {String lang = 'en'}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(lang),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(body: MyRequestsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  for (final approve in [true, false]) {
    testWidgets(
      '${approve ? 'approve' : 'reject'} dialog forwards trimmed text to correct event',
      (tester) async {
        await open(tester);
        final label = approve ? 'Approve' : 'Reject';
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(find.text(approve ? 'Remark' : 'Reason'), findsOneWidget);
        await tester.enterText(
          find.descendant(of: dialog, matching: find.byType(TextField)),
          '  hello  ',
        );
        await tester.tap(
          find.descendant(of: dialog, matching: find.text(label)),
        );
        await tester.pumpAndSettle();
        if (approve) {
          final event = bloc.events.last as ApproveRequest;
          expect(event.requestId, 3);
          expect(event.remark, 'hello');
        } else {
          final event = bloc.events.last as RejectRequest;
          expect(event.requestId, 3);
          expect(event.reason, 'hello');
        }
      },
    );
  }
  testWidgets('cancel and optional empty input do not invent validation', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.text('Reject'));
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(bloc.events.length, 2);
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Reject'),
      ),
    );
    await tester.pumpAndSettle();
    expect((bloc.events.last as RejectRequest).reason, '');
  });
  testWidgets('final unknown and null-ID rows hide actions', (tester) async {
    bloc.show(
      bloc.state.copyWith(
        items: [
          const RequestListItemDto(
            id: 1,
            requestStatus: IdNameDto(id: 2, name: 'Approved'),
          ),
          const RequestListItemDto(
            id: 2,
            requestStatus: IdNameDto(id: 3, name: 'Rejected'),
          ),
          const RequestListItemDto(
            id: 4,
            requestStatus: IdNameDto(id: 99, name: 'Unknown'),
          ),
          const RequestListItemDto(
            requestStatus: IdNameDto(id: 1, name: 'Pending'),
          ),
        ],
      ),
    );
    await open(tester);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
  testWidgets(
    'row loading only on selected row; failure stays pending and feedback occurs once',
    (tester) async {
      await open(tester);
      await tester.ensureVisible(find.text('Approve'));
      bloc.show(
        bloc.state.copyWith(
          actingRequestId: 3,
          actingAction: RequestActionKind.approve,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('decision-3')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Approve'))
            .onPressed,
        isNull,
      );
      expect(find.byType(RequestLoadingSkeleton), findsNothing);
      bloc.show(
        bloc.state.copyWith(
          actingRequestId: null,
          actingAction: null,
          actionFailure: const NetworkFailure(),
          actionRevision: 1,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Unable to complete the request decision. Please try again.'),
        findsOneWidget,
      );
      expect(bloc.state.items.first.requestStatus?.name, 'Pending');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Approve'))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets('authoritative success updates card and retains search', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'D10736');
    await tester.pump();
    bloc.show(
      bloc.state.copyWith(
        items: [
          bloc.state.items.first.withRequestStatus(
            const IdNameDto(id: 2, name: 'Approved'),
          ),
        ],
        lastDecision: const RequestDecisionData(
          id: 3,
          requestStatus: IdNameDto(id: 2, name: 'Approved'),
        ),
        completedAction: RequestActionKind.approve,
        actionRevision: 1,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Request approved successfully'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'D10736',
    );
  });
  testWidgets(
    'initial events once, true API card, no automatic writes or fake navigation',
    (tester) async {
      await open(tester);
      await tester.pump();
      await tester.pump();
      expect(bloc.events.whereType<LoadRequests>().length, 1);
      expect(bloc.events.whereType<LoadRequestLookup>().length, 1);
      expect(find.text('Request #3'), findsOneWidget);
      expect(find.text('INC-0003'), findsOneWidget);
      expect(find.text('site 3 • D10736'), findsOneWidget);
      expect(find.text('gsm manager'), findsOneWidget);
      expect(find.textContaining('10/09/2026'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.byIcon(Icons.science_outlined), findsNothing);
      await tester.tap(find.text('Request #3'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(RequestDetailsScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(bloc.isClosed, true);
    },
  );
  testWidgets('type and status use lookup IDs without enum assumptions', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(
      find.widgetWithText(ChoiceChip, 'Renewal Request'),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Renewal Request'));
    await tester.pump();
    await tester.pump();
    expect((bloc.events.last as ApplyRequestFilters).requestTypeId, 2);
    final status = tester.widget<DropdownButtonFormField<int>>(
      find.byType(DropdownButtonFormField<int>),
    );
    status.onChanged!(2);
    expect((bloc.events.last as ApplyRequestFilters).requestStatusId, 2);
  });
  testWidgets('search is local on loaded rows and clear search restores list', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'D10736');
    await tester.pump();
    await tester.pump();
    expect(find.text('1 requests'), findsOneWidget);
    expect(find.text('Request #1'), findsNothing);
    await tester.enterText(find.byType(TextField), 'no-match');
    await tester.pump();
    await tester.pump();
    expect(find.text('No search results'), findsOneWidget);
    expect(find.text('No requests yet'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Clear search'));
    await tester.pump();
    await tester.pump();
    expect(find.text('2 requests'), findsOneWidget);
    expect(bloc.events.length, 2);
  });
  testWidgets('full sheet preserves values and applies one exact event', (
    tester,
  ) async {
    bloc.show(
      bloc.state.copyWith(
        fromDate: DateTime(2026, 9, 1),
        toDate: DateTime(2026, 9, 10),
        requestTypeId: 3,
        requestStatusId: 1,
        locationCode: 'D10736',
        incidentNo: 'INC-0003',
      ),
    );
    await open(tester);
    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    expect(find.text('D10736'), findsOneWidget);
    expect(find.text('INC-0003'), findsWidgets);
    await tester.ensureVisible(find.text('Apply Filters'));
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();
    final event = bloc.events.last as ApplyRequestFilters;
    expect(event.fromDate, DateTime(2026, 9, 1));
    expect(event.toDate, DateTime(2026, 9, 10));
    expect(event.requestTypeId, 3);
    expect(event.requestStatusId, 1);
    expect(event.locationCode, 'D10736');
    expect(event.incidentNo, 'INC-0003');
    expect(bloc.events.whereType<ApplyRequestFilters>().length, 1);
  });
  testWidgets(
    'invalid date shows validation and keeps sheet open; reset restores defaults',
    (tester) async {
      bloc.show(
        bloc.state.copyWith(
          fromDate: DateTime(2026, 10, 1),
          toDate: DateTime(2026, 9, 1),
          locationCode: 'X',
        ),
      );
      await open(tester);
      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply Filters'));
      await tester.tap(find.text('Apply Filters'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Start date must be on or before end date.'),
        findsOneWidget,
      );
      expect(bloc.events.whereType<ApplyRequestFilters>(), isEmpty);
      await tester.ensureVisible(find.text('Reset'));
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      final event = bloc.events.last as ApplyRequestFilters;
      final now = DateTime.now();
      expect(event.fromDate, DateTime(now.year, now.month, now.day));
      expect(event.toDate, event.fromDate);
      expect(event.locationCode, '');
      expect(event.incidentNo, '');
      expect(event.requestTypeId, -1);
      expect(event.requestStatusId, -1);
    },
  );
  testWidgets(
    'skeleton keeps header search filters; lookup loading does not hide list',
    (tester) async {
      bloc.show(bloc.state.copyWith(items: [], loading: true));
      await open(tester);
      expect(find.byType(RequestLoadingSkeleton), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Filter'), findsOneWidget);
      bloc.show(
        bloc.state.copyWith(
          items: RequestListData.fromJson(listJson).items,
          loading: false,
          lookupLoading: true,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Request #3'), findsOneWidget);
      expect(find.byType(RequestLoadingSkeleton), findsNothing);
    },
  );
  testWidgets(
    'initial and retained-data errors retry without resetting filters',
    (tester) async {
      bloc.show(
        bloc.state.copyWith(items: [], failure: const NetworkFailure()),
      );
      await open(tester);
      await tester.tap(find.text('Retry'));
      expect(bloc.events.last, isA<LoadRequests>());
      bloc.show(
        bloc.state.copyWith(items: RequestListData.fromJson(listJson).items),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Request #3'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    },
  );
  testWidgets('lookup failure retry only loads lookup', (tester) async {
    bloc.show(bloc.state.copyWith(lookupFailure: const NetworkFailure()));
    await open(tester);
    expect(find.text('Request #3'), findsOneWidget);
    await tester.tap(find.text('Retry filters'));
    expect(bloc.events.whereType<LoadRequests>().length, 1);
    expect(bloc.events.whereType<LoadRequestLookup>().length, 2);
  });
  testWidgets(
    'empty results distinguish default and backend filtered queries',
    (tester) async {
      bloc.show(bloc.state.copyWith(items: [], totalCount: 0));
      await open(tester);
      expect(find.text('No requests yet'), findsOneWidget);
      bloc.show(bloc.state.copyWith(locationCode: 'X'));
      await tester.pump();
      await tester.pump();
      expect(find.text('No matching requests'), findsOneWidget);
    },
  );
  testWidgets('refresh waits for state and keeps cards and search', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'D10736');
    await tester.pump();
    await tester.pump();
    final done = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    expect(bloc.events.last, isA<RefreshRequests>());
    bloc.show(bloc.state.copyWith(refreshing: true));
    await tester.pump();
    await tester.pump();
    expect(find.text('Request #3'), findsOneWidget);
    expect(find.byType(RequestLoadingSkeleton), findsNothing);
    bloc.show(bloc.state.copyWith(refreshing: false));
    await tester.pump();
    await tester.pump();
    await done;
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'D10736',
    );
  });
  testWidgets(
    'scroll dispatches load more; bottom error and loading preserve cards',
    (tester) async {
      bloc.show(bloc.state.copyWith(totalCount: 3));
      await open(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(bloc.events.whereType<LoadMoreRequests>(), isNotEmpty);
      bloc.show(bloc.state.copyWith(loadingMore: true));
      await tester.pump();
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('load-more-loading')),
      );
      expect(find.byType(RequestLoadingSkeleton), findsNothing);
      bloc.show(
        bloc.state.copyWith(
          loadingMore: false,
          loadMoreFailure: const NetworkFailure(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.ensureVisible(find.text('Retry more'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
      await tester.pumpAndSettle();
      final beforeRetry = bloc.events.length;
      await tester.tap(find.text('Retry more'));
      expect(bloc.events.length, beforeRetry + 1);
      expect(bloc.events.last, isA<LoadMoreRequests>());
      expect(bloc.state.items.length, 2);
    },
  );
  testWidgets('Arabic and unknown/null data render safely', (tester) async {
    bloc.show(
      bloc.state.copyWith(
        items: [
          const RequestListItemDto(id: 77, createdDate: 'bad-date'),
          const RequestListItemDto(),
        ],
      ),
    );
    await open(tester, lang: 'ar');
    expect(find.text('طلب #77'), findsOneWidget);
    expect(find.text('bad-date'), findsOneWidget);
    expect(find.text('null'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
