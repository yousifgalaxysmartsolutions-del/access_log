import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/context/active_incident_context.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/features/app_requirements/presentation/app_requirement_guard.dart';
import 'package:access_log_plus/features/forms/data/models/cap_form_models.dart';
import 'package:access_log_plus/features/gps_tracking/domain/background_location_service.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_requirement_gate.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_tracking_manager.dart';
import 'package:access_log_plus/features/gps_tracking/presentation/gps_blocking_screen.dart';
import 'package:access_log_plus/features/periodic_photo/domain/periodic_photo_coordinator.dart';
import 'package:access_log_plus/features/periodic_photo/domain/periodic_photo_gate.dart';
import 'package:access_log_plus/features/periodic_photo/presentation/periodic_photo_blocking_screen.dart';

import 'support/periodic_photo_fakes.dart';

/// The app's single blocking overlay: GPS first, then the periodic photo.
///
/// The priority rule is tested directly (pure function) and through the real
/// widget with both requirement graphs wired in, proving that two outstanding
/// requirements never produce two competing screens.
/// Local harness for the photo requirement graph used by the guard tests.
class _PhotoRig {
  _PhotoRig(this.gate, this.coordinator, this.repository, this.captures);

  final PeriodicPhotoGate gate;
  final PeriodicPhotoCoordinator coordinator;
  final FakePeriodicPhotoRepository repository;
  final List<Object?> captures;

  Future<void> dispose() async {
    await gate.dispose();
    await coordinator.dispose();
  }
}

class _ControlledGpsGate implements GpsRequirementGate {
  @override
  GpsGateState state = GpsGateState.checking;
  final _changes = StreamController<GpsGateState>.broadcast();
  @override
  Stream<GpsGateState> get changes => _changes.stream;
  int permissionRequests = 0;
  void update(GpsGateState value) {
    state = value;
    _changes.add(value);
  }

  @override
  Future<void> reconcile() async {}
  @override
  Future<LocationPermissionStatus> requestPermissions() async {
    permissionRequests++;
    update(GpsGateState.ready);
    return LocationPermissionStatus.always;
  }

  @override
  Future<void> openLocationSettings() async {}
  @override
  Future<void> dispose() async {
    unawaited(_changes.close());
  }
}

void main() {
  group('pickBlockingRequirement', () {
    test('GPS first when both requirements are outstanding', () {
      expect(
        pickBlockingRequirement(
          authenticated: true,
          gpsBlocking: true,
          photoBlocking: true,
        ),
        AppRequirement.gps,
      );
    });

    test('photo blocks once GPS is satisfied', () {
      expect(
        pickBlockingRequirement(
          authenticated: true,
          gpsBlocking: false,
          photoBlocking: true,
        ),
        AppRequirement.photo,
      );
    });

    test('nothing outstanding → nothing blocks', () {
      expect(
        pickBlockingRequirement(
          authenticated: true,
          gpsBlocking: false,
          photoBlocking: false,
        ),
        AppRequirement.none,
      );
    });

    test('signed-out sessions are never blocked, even when overdue', () {
      expect(
        pickBlockingRequirement(
          authenticated: false,
          gpsBlocking: true,
          photoBlocking: true,
        ),
        AppRequirement.none,
      );
    });
  });

  group('AppRequirementGuard', () {
    final disposers = <Future<void> Function()>[];

    Future<void> disposeAll() async {
      for (final dispose in disposers.reversed) {
        await dispose();
      }
      disposers.clear();
    }

    late DateTime now;

    setUp(() {
      now = DateTime(2026, 1, 1, 10, 0, 0);
    });

    tearDown(() async {
      await disposeAll();
    });

    Future<GpsRequirementGate> makeGpsGate({required bool blocking}) async {
      final service = FakeLocationService()
        ..permission = blocking
            ? LocationPermissionStatus.denied
            : LocationPermissionStatus.always;
      final configuration = FakeSystemConfigurationRepository(
        initial: photoConfiguration(continuousTracking: blocking),
      );
      final manager = GpsTrackingManager(service, configuration);
      final gate = GpsRequirementGate(manager);
      await gate.reconcile();
      disposers.add(() async {
        await gate.dispose();
        await manager.dispose();
        await service.dispose();
      });
      return gate;
    }

    Future<_PhotoRig> makePhotoGate({
      required SessionManager session,
      bool enabled = true,
      List<Object?>? captures,
    }) async {
      final queue = captures ?? <Object?>[];
      final configuration = FakeSystemConfigurationRepository(
        initial: photoConfiguration(photoEnabled: enabled, photoInterval: 1),
      );
      final coordinator = PeriodicPhotoCoordinator(
        configuration: configuration,
        store: MemoryScheduleStore(),
        now: () => now,
      );
      final repository = FakePeriodicPhotoRepository();
      final incident = ActiveIncidentContext();
      final gate = PeriodicPhotoGate(
        coordinator: coordinator,
        repository: repository,
        retainStore: MemoryRetainStore(),
        activeIncident: incident,
        session: session,
        capturePhoto: () async {
          if (queue.isEmpty) return null;
          return queue.removeAt(0) as CapFormEvidence?;
        },
        now: () => now,
      );
      await gate.reconcile();
      now = DateTime(2026, 1, 1, 10, 1, 0);
      await gate.reconcile();
      final rig = _PhotoRig(gate, coordinator, repository, queue);
      disposers.add(() async {
        await rig.dispose();
        await incident.dispose();
      });
      return rig;
    }

    SessionManager authenticatedSession() {
      final session = SessionManager(MemoryTokenStorage())..startDemo();
      disposers.add(session.dispose);
      return session;
    }

    testWidgets(
      'GPS checks and startup are silent; only confirmed issues cover the app',
      (tester) async {
        final session = authenticatedSession();
        final gps = _ControlledGpsGate();
        disposers.add(gps.dispose);
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: AppRequirementGuard(
              session: session,
              gpsGate: gps,
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('Use app'),
              ),
            ),
          ),
        );
        for (final state in [
          GpsGateState.checking,
          GpsGateState.startingTracker,
          GpsGateState.ready,
          GpsGateState.disabledByConfiguration,
        ]) {
          gps.update(state);
          await tester.pump();
          expect(find.byType(GpsBlockingScreen), findsNothing);
          await tester.tap(find.text('Use app'));
        }
        expect(taps, 4);
        for (final state in [
          GpsGateState.permissionRequired,
          GpsGateState.backgroundPermissionRequired,
          GpsGateState.locationServicesDisabled,
          GpsGateState.error,
        ]) {
          gps.update(state);
          await tester.pump();
          expect(find.byType(GpsBlockingScreen), findsOneWidget);
        }
        gps.update(GpsGateState.ready);
        await tester.pump();
        expect(find.byType(GpsBlockingScreen), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );

    for (final lang in ['en', 'ar']) {
      testWidgets(
        'Always permission instructions fit large text in $lang and action uses existing gate',
        (tester) async {
          final session = authenticatedSession();
          final gps = _ControlledGpsGate()
            ..state = GpsGateState.backgroundPermissionRequired;
          disposers.add(gps.dispose);
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(lang),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: AppRequirementGuard(
                session: session,
                gpsGate: gps,
                child: const Text('Use app'),
              ),
            ),
          );
          await tester.pump();
          expect(find.textContaining('Always'), findsWidgets);
          final button = find.byType(FilledButton);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(gps.permissionRequests, 1);
          expect(find.byType(GpsBlockingScreen), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    SessionManager signedOutSession() {
      final session = SessionManager(MemoryTokenStorage());
      disposers.add(session.dispose);
      return session;
    }

    Future<void> pumpGuard(
      WidgetTester tester, {
      required GpsRequirementGate gpsGate,
      required PeriodicPhotoGate photoGate,
      required SessionManager session,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppRequirementGuard(
            gpsGate: gpsGate,
            photoGate: photoGate,
            session: session,
            child: const Text('app-content'),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'both outstanding → GPS blocks and the photo gate never stacks',
      (tester) async {
        final session = authenticatedSession();
        final gps = await makeGpsGate(blocking: true);
        final photo = await makePhotoGate(session: session);
        expect(gps.state, GpsGateState.permissionRequired);
        expect(photo.gate.state, PeriodicPhotoGateState.due);

        await pumpGuard(
          tester,
          gpsGate: gps,
          photoGate: photo.gate,
          session: session,
        );

        expect(find.byType(GpsBlockingScreen), findsOneWidget);
        expect(
          find.byType(PeriodicPhotoBlockingScreen),
          findsNothing,
          reason: 'requirements never stack two competing overlays',
        );
        // The navigator stays mounted underneath, only covered.
        expect(find.text('app-content'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await disposeAll();
      },
    );

    testWidgets('GPS satisfied + photo due → the photo gate blocks', (
      tester,
    ) async {
      final session = authenticatedSession();
      final gps = await makeGpsGate(blocking: false);
      final photo = await makePhotoGate(session: session);
      expect(gps.state, GpsGateState.disabledByConfiguration);
      expect(photo.gate.state, PeriodicPhotoGateState.due);

      await pumpGuard(
        tester,
        gpsGate: gps,
        photoGate: photo.gate,
        session: session,
      );

      expect(find.byType(PeriodicPhotoBlockingScreen), findsOneWidget);
      expect(find.byType(GpsBlockingScreen), findsNothing);
      expect(find.text('Take Photo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await disposeAll();
    });

    testWidgets('signed-out session → neither requirement blocks', (
      tester,
    ) async {
      final session = signedOutSession();
      final gps = await makeGpsGate(blocking: true);
      final photo = await makePhotoGate(session: session);

      await pumpGuard(
        tester,
        gpsGate: gps,
        photoGate: photo.gate,
        session: session,
      );

      expect(find.byType(GpsBlockingScreen), findsNothing);
      expect(find.byType(PeriodicPhotoBlockingScreen), findsNothing);
      expect(find.text('app-content'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await disposeAll();
    });

    testWidgets('tapping Take Photo captures, uploads and releases the app', (
      tester,
    ) async {
      final session = authenticatedSession();
      final captures = <Object?>[jpegEvidence()];
      final photo = await makePhotoGate(session: session, captures: captures);
      final gps = await makeGpsGate(blocking: false);

      await pumpGuard(
        tester,
        gpsGate: gps,
        photoGate: photo.gate,
        session: session,
      );
      expect(find.byType(PeriodicPhotoBlockingScreen), findsOneWidget);

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      expect(photo.gate.state, PeriodicPhotoGateState.waiting);
      expect(find.byType(PeriodicPhotoBlockingScreen), findsNothing);
      expect(find.text('app-content'), findsOneWidget);
      expect(photo.repository.submissions, 1);
      expect(captures, isEmpty, reason: 'the queued photo was consumed');

      await tester.pumpWidget(const SizedBox());
      await disposeAll();
    });
  });
}
