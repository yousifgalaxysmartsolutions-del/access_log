import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'features/gps_tracking/domain/gps_capture_sync_bridge.dart';
import 'features/gps_tracking/domain/gps_requirement_gate.dart';
import 'features/gps_tracking/domain/gps_tracking_sync_service.dart';
import 'features/periodic_photo/domain/periodic_photo_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  // Reconcile the app-level requirements with the system configuration after
  // session restoration. Fire-and-forget: the tracking engine is native and
  // the gates are plain services, so neither depends on a screen or Bloc
  // staying alive. The periodic-photo gate restores its persisted deadline too
  // (a restart never restarts the interval).
  unawaited(services<GpsRequirementGate>().reconcile());
  if (services.isRegistered<PeriodicPhotoGate>()) {
    unawaited(services<PeriodicPhotoGate>().reconcile());
  }
  // Centralized server-sync: bridge the native "point captured" signal to an
  // immediate sync attempt, keep a conservative sweep as a safety net, and try
  // once now. Entirely independent of tracking and of any screen.
  if (services.isRegistered<GpsCaptureSyncBridge>()) {
    services<GpsCaptureSyncBridge>().start();
  }
  if (services.isRegistered<GpsTrackingSyncService>()) {
    services<GpsTrackingSyncService>().startAutoSync();
  }
  runApp(const AccessLogApp());
}
