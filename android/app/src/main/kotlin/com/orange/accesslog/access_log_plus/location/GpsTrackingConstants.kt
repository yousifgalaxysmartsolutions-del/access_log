package com.orange.accesslog.access_log_plus.location

/**
 * Channel, method and payload keys shared with Flutter.
 *
 * Mirrors `lib/features/gps_tracking/gps_tracking_channels.dart`. Keeping the
 * strings here avoids drift between the two sides.
 */
object GpsTrackingConstants {
    const val METHOD_CHANNEL = "cap/background_location"
    const val EVENT_CHANNEL = "cap/background_location_events"

    const val START_TRACKING = "startTracking"
    const val STOP_TRACKING = "stopTracking"
    const val IS_TRACKING = "isTracking"
    const val APPLY_CONFIGURATION = "applyConfiguration"
    const val GET_PERMISSION_STATUS = "getPermissionStatus"
    const val REQUEST_PERMISSIONS = "requestPermissions"
    const val OPEN_LOCATION_SETTINGS = "openLocationSettings"

    const val ARG_CONTINUOUS = "continuousGpsTracking"
    const val ARG_INTERVAL_MINUTES = "periodicGpsCaptureIntervalMinutes"
    const val ARG_ACCURACY_THRESHOLD = "gpsAccuracyThreshold"
    const val ARG_ALLOW_OFFLINE = "allowOfflineGpsCollection"

    const val EVENT_KEY = "event"
    const val EVENT_PERMISSION = "permission"
    const val EVENT_MESSAGE = "message"

    const val EVENT_TRACKING_STARTED = "trackingStarted"
    const val EVENT_TRACKING_STOPPED = "trackingStopped"
    const val EVENT_PERMISSION_CHANGED = "permissionChanged"
    const val EVENT_SERVICES_DISABLED = "locationServicesDisabled"
    const val EVENT_LOCATION_CAPTURED = "locationCaptured"
    const val EVENT_ERROR = "trackingError"

    const val PERMISSION_NOT_DETERMINED = "notDetermined"
    const val PERMISSION_WHEN_IN_USE = "whenInUse"
    const val PERMISSION_ALWAYS = "always"
    const val PERMISSION_DENIED = "denied"
    const val PERMISSION_SERVICE_DISABLED = "serviceDisabled"
    const val PERMISSION_UNKNOWN = "unknown"
}
