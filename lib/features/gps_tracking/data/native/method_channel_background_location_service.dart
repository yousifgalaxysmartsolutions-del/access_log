import 'package:flutter/services.dart';

import '../../gps_tracking_channels.dart';
import '../../domain/background_location_service.dart';

/// [BackgroundLocationService] backed by the `cap/background_location` /
/// `cap/background_location_events` platform channels.
///
/// All failures from the native side are converted to safe defaults so a
/// missing/unsupported plugin never crashes the app: capture itself is native
/// and independent of this bridge.
class MethodChannelBackgroundLocationService
    implements BackgroundLocationService {
  MethodChannelBackgroundLocationService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _method = methodChannel ?? const MethodChannel(GpsTrackingChannels.method),
       _eventChannel =
           eventChannel ?? const EventChannel(GpsTrackingChannels.events);

  final MethodChannel _method;
  final EventChannel _eventChannel;

  Stream<GpsTrackingEvent>? _events;

  @override
  Future<void> applyConfiguration(GpsTrackingConfiguration configuration) =>
      _invokeVoid(
        GpsTrackingChannels.applyConfiguration,
        configuration.toChannelArguments(),
      );

  @override
  Future<void> startTracking() =>
      _invokeVoid(GpsTrackingChannels.startTracking);

  @override
  Future<void> stopTracking() => _invokeVoid(GpsTrackingChannels.stopTracking);

  @override
  Future<bool> isTracking() async {
    try {
      return await _method.invokeMethod<bool>(
            GpsTrackingChannels.isTracking,
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<LocationPermissionStatus> getPermissionStatus() async {
    try {
      final value = await _method.invokeMethod<Object?>(
        GpsTrackingChannels.getPermissionStatus,
      );
      return LocationPermissionStatus.fromWire(value);
    } on PlatformException {
      return LocationPermissionStatus.unknown;
    } on MissingPluginException {
      return LocationPermissionStatus.unknown;
    }
  }

  @override
  Future<LocationPermissionStatus> requestPermissions() async {
    try {
      final value = await _method.invokeMethod<Object?>(
        GpsTrackingChannels.requestPermissions,
      );
      return LocationPermissionStatus.fromWire(value);
    } on PlatformException {
      return LocationPermissionStatus.unknown;
    } on MissingPluginException {
      return LocationPermissionStatus.unknown;
    }
  }

  @override
  Stream<GpsTrackingEvent> get events =>
      _events ??= _eventChannel
          .receiveBroadcastStream()
          .map(GpsTrackingEvent.fromWire)
          .handleError((Object _) {});

  Future<void> _invokeVoid(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      await _method.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // Native side reports errors through the event channel and status
      // queries. Swallow here so the manager can keep its invariants.
    } on MissingPluginException {
      // Unsupported platform (tests/tooling): tracking is simply unavailable.
    }
  }
}
