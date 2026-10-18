package com.orange.accesslog.access_log_plus.location

import android.location.Location
import java.util.Locale

/**
 * Validates native location results before they are persisted.
 *
 * Deliberately isolated so the acceptance rules can be adjusted in one place.
 *
 * `gpsAccuracyThreshold` is intentionally not applied as a hard filter here.
 * Its unit/business meaning is not established anywhere in the project, and the
 * observed sample value (1.0) would reject almost every real fix. The threshold
 * is carried in [GpsTrackingConfig] for the sync policy instead. The only
 * accuracy rule enforced is rejecting clearly invalid (negative/NaN) accuracy.
 */
object GpsPointValidator {
    fun isValidCoordinate(latitude: Double, longitude: Double): Boolean =
        latitude.isFinite() &&
            longitude.isFinite() &&
            latitude in -90.0..90.0 &&
            longitude in -180.0..180.0

    fun isUsable(location: Location?): Boolean {
        if (location == null) return false
        if (!isValidCoordinate(location.latitude, location.longitude)) return false
        // A non-null, reasonable capture timestamp is required.
        if (location.time <= 0L) return false
        if (location.hasAccuracy()) {
            val accuracy = location.accuracy.toDouble()
            if (!accuracy.isFinite() || accuracy < 0.0) return false
        }
        return true
    }

    /** Fixed 7-decimal representation matching the CAP sample payload. */
    fun formatCoordinate(value: Double): String =
        String.format(Locale.US, "%.7f", value)
}
