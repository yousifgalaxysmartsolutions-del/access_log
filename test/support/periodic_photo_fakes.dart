import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:access_log_plus/core/error/failure.dart';
import 'package:access_log_plus/core/network/result.dart';
import 'package:access_log_plus/core/storage/secure_storage_service.dart';
import 'package:access_log_plus/features/forms/data/models/cap_form_models.dart';
import 'package:access_log_plus/features/gps_tracking/domain/background_location_service.dart';
import 'package:access_log_plus/features/incidents/data/models/system_gps_configuration.dart';
import 'package:access_log_plus/features/incidents/domain/repositories/system_gps_configuration_repository.dart';
import 'package:access_log_plus/features/periodic_photo/data/periodic_photo_retain_store.dart';
import 'package:access_log_plus/features/periodic_photo/data/periodic_photo_schedule_store.dart';
import 'package:access_log_plus/features/periodic_photo/domain/periodic_photo_schedule.dart';
import 'package:access_log_plus/features/periodic_photo/domain/repositories/periodic_photo_repository.dart';

/// Builds a `GetSystemConfiguration` value with the GPS and photo sections
/// explicitly decided by the test — no payload defaults sneak in.
SystemGpsConfiguration photoConfiguration({
  bool photoEnabled = false,
  int? photoInterval,
  bool continuousTracking = false,
}) => SystemGpsConfiguration(
  radiusMeters: 100,
  enableGpsValidation: true,
  continuousGpsTracking: continuousTracking,
  enablePhotoCapture: photoEnabled,
  periodicPhotoCaptureIntervalMinutes: photoInterval,
);

/// Configuration double shared by the photo coordinator and the GPS manager.
class FakeSystemConfigurationRepository
    implements SystemGpsConfigurationRepository {
  FakeSystemConfigurationRepository({SystemGpsConfiguration? initial})
    : result = Success(initial ?? photoConfiguration());

  int loads = 0;
  Result<SystemGpsConfiguration> result;

  @override
  Future<Result<SystemGpsConfiguration>> load() async {
    loads++;
    return result;
  }
}

/// In-memory schedule store: no file I/O, so it is safe inside `testWidgets`
/// (which runs in a fake-async zone where real I/O never completes).
class MemoryScheduleStore extends PeriodicPhotoScheduleStore {
  MemoryScheduleStore()
    : super(directory: () async => Directory.systemTemp);

  PeriodicPhotoSchedule? value;
  int writes = 0;

  @override
  Future<PeriodicPhotoSchedule?> read() async => value;

  @override
  Future<void> write(PeriodicPhotoSchedule schedule) async {
    value = schedule;
    writes++;
  }
}

/// In-memory retention store (same `testWidgets` reasoning as above).
class MemoryRetainStore extends PeriodicPhotoRetainStore {
  MemoryRetainStore() : super(directory: () async => Directory.systemTemp);

  RetainedPeriodicPhoto? value;
  int clears = 0;

  @override
  Future<RetainedPeriodicPhoto?> read() async => value;

  @override
  Future<void> write(RetainedPeriodicPhoto photo) async => value = photo;

  @override
  Future<void> clear() async {
    value = null;
    clears++;
  }
}

class MemoryTokenStorage implements TokenStorage {
  @override
  Future<SessionTokens?> readTokens() async => null;
  @override
  Future<void> writeTokens(SessionTokens tokens) async {}
  @override
  Future<void> clear() async {}
}

class FixedUserStorage implements SessionUserStorage {
  FixedUserStorage([this.user]);
  SessionUser? user;
  @override
  Future<SessionUser?> readUser() async => user;
  @override
  Future<void> writeUser(SessionUser value) async => user = value;
  @override
  Future<void> clearUser() async => user = null;
}

/// JPEG magic bytes so `CapFormEvidence.extension` detects `jpg` from content,
/// not from picker metadata.
CapFormEvidence jpegEvidence({String name = 'photo.jpg'}) => CapFormEvidence(
  name: name,
  mimeType: 'image/jpeg',
  bytes: Uint8List.fromList([
    0xFF,
    0xD8,
    0xFF,
    0xE0,
    0x00,
    0x10,
    0x4A,
    0x46,
    0x49,
    0x46,
    0x00,
    0x01,
  ]),
);

/// PNG signature so the same evidence reports `png`, never a hardcoded `jpg`.
CapFormEvidence pngEvidence({String name = 'photo.png'}) => CapFormEvidence(
  name: name,
  mimeType: 'image/png',
  bytes: Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
  ]),
);

/// Records every submission and returns a scripted result.
class FakePeriodicPhotoRepository implements PeriodicPhotoRepository {
  int submissions = 0;
  Result<bool> result = const Success(true);
  final List<({int incidentId, String extension, String name, List<int> bytes})>
  submitted = [];

  @override
  Future<Result<bool>> submit({
    required int incidentId,
    required CapFormEvidence evidence,
  }) async {
    submissions++;
    submitted.add((
      incidentId: incidentId,
      extension: evidence.extension,
      name: evidence.name,
      bytes: List<int>.of(evidence.bytes),
    ));
    return result;
  }
}

/// Native tracking double shared with the guard tests: records calls and lets
/// a test drive permission, location-services and tracker state.
class FakeLocationService implements BackgroundLocationService {
  final List<GpsTrackingConfiguration> applied = [];
  int startCalls = 0;
  int stopCalls = 0;
  int permissionRequests = 0;
  int openSettingsCalls = 0;
  bool tracking = false;

  LocationPermissionStatus permission = LocationPermissionStatus.always;
  LocationPermissionStatus requestResult = LocationPermissionStatus.always;

  final _events = StreamController<GpsTrackingEvent>.broadcast();

  @override
  Future<void> applyConfiguration(GpsTrackingConfiguration configuration) async {
    applied.add(configuration);
  }

  @override
  Future<void> startTracking() async {
    startCalls++;
    tracking = true;
  }

  @override
  Future<void> stopTracking() async {
    stopCalls++;
    tracking = false;
  }

  @override
  Future<bool> isTracking() async => tracking;

  @override
  Future<LocationPermissionStatus> getPermissionStatus() async => permission;

  @override
  Future<LocationPermissionStatus> requestPermissions() async {
    permissionRequests++;
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<void> openLocationSettings() async {
    openSettingsCalls++;
  }

  @override
  Stream<GpsTrackingEvent> get events => _events.stream;

  void emit(GpsTrackingEvent event) => _events.add(event);

  Future<void> dispose() => _events.close();
}

/// Convenience for asserting a network-style failure result.
Result<bool> networkFailure() => const FailureResult(NetworkFailure());
