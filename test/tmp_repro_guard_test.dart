import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:access_log_plus/core/context/active_incident_context.dart';
import 'package:access_log_plus/core/session/session_manager.dart';
import 'package:access_log_plus/features/app_requirements/presentation/app_requirement_guard.dart';
import 'package:access_log_plus/features/gps_tracking/domain/background_location_service.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_requirement_gate.dart';
import 'package:access_log_plus/features/gps_tracking/domain/gps_tracking_manager.dart';
import 'package:access_log_plus/features/periodic_photo/domain/periodic_photo_coordinator.dart';
import 'package:access_log_plus/features/periodic_photo/domain/periodic_photo_gate.dart';

import 'support/periodic_photo_fakes.dart';

void main() {
  testWidgets('repro: guard + gps dispose', (tester) async {
    final now = DateTime(2026, 1, 1, 10, 0, 0);
    final session = SessionManager(MemoryTokenStorage())..startDemo();
    print('R1: session');

    final service = FakeLocationService()
      ..permission = LocationPermissionStatus.denied;
    final configuration = FakeSystemConfigurationRepository(
      initial: photoConfiguration(continuousTracking: true),
    );
    final manager = GpsTrackingManager(service, configuration);
    final gpsGate = GpsRequirementGate(manager);
    await gpsGate.reconcile();
    print('R2: gps reconciled → ${gpsGate.state}');

    final coordinator = PeriodicPhotoCoordinator(
      configuration: FakeSystemConfigurationRepository(
        initial: photoConfiguration(photoEnabled: true, photoInterval: 1),
      ),
      store: MemoryScheduleStore(),
      now: () => now,
    );
    final photoGate = PeriodicPhotoGate(
      coordinator: coordinator,
      repository: FakePeriodicPhotoRepository(),
      retainStore: MemoryRetainStore(),
      activeIncident: ActiveIncidentContext(),
      session: session,
      capturePhoto: () async => null,
      now: () => now,
    );
    await photoGate.reconcile();
    print('R3: photo reconciled → ${photoGate.state}');

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
    print('R4: pumped, gps visible=${find.byType(Text).evaluate().length}');
    expect(find.text('GpsBlockingScreen'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    print('R5: unmounted');

    await gpsGate.dispose();
    print('R6: gpsGate disposed');
    await photoGate.dispose();
    print('R7: photoGate disposed');
    await coordinator.dispose();
    print('R8: coordinator disposed');
    await manager.dispose();
    print('R9: manager disposed');
    await service.dispose();
    print('R10: service disposed');
    await session.dispose();
    print('R11: done');
  }, timeout: const Timeout(Duration(seconds: 20)));
}
