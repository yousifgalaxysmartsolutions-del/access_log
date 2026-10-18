import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'features/gps_tracking/domain/gps_tracking_manager.dart';
import 'features/gps_tracking/domain/gps_tracking_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  // Reconcile native tracking with the system configuration after session
  // restoration. Fire-and-forget: the tracking engine is native and must not
  // depend on any screen or Bloc staying alive.
  unawaited(services<GpsTrackingManager>().reconcile());
  // Centralized server-sync triggers: an immediate attempt plus a conservative
  // sweep that notices "internet restored" / "new point captured". It is
  // entirely independent of tracking and of any screen.
  if (services.isRegistered<GpsTrackingSyncService>()) {
    services<GpsTrackingSyncService>().startAutoSync();
  }
  runApp(const AccessLogApp());
}
