package com.orange.accesslog.access_log_plus.location

import android.content.Context

/**
 * Native copy of the tracking policy pushed from Flutter via
 * `applyConfiguration`.
 *
 * Persisted in SharedPreferences so a system-restarted foreground service can
 * rebuild its location request without Flutter being alive.
 */
data class GpsTrackingConfig(
    val continuousGpsTracking: Boolean,
    val intervalMinutes: Int,
    val accuracyThreshold: Double?,
    val allowOfflineGpsCollection: Boolean,
) {
    /** Location-update interval in milliseconds, clamped to a sane minimum. */
    val intervalMillis: Long
        get() = maxOf(intervalMinutes, 1).toLong() * 60_000L

    fun persist(context: Context) {
        prefs(context).edit()
            .putBoolean(KEY_CONTINUOUS, continuousGpsTracking)
            .putInt(KEY_INTERVAL, intervalMinutes)
            .putBoolean(KEY_ALLOW_OFFLINE, allowOfflineGpsCollection)
            .apply {
                if (accuracyThreshold == null) {
                    remove(KEY_ACCURACY)
                } else {
                    putLong(KEY_ACCURACY, accuracyThreshold.toRawBits())
                }
            }
            .apply()
    }

    companion object {
        private const val PREFS = "cap_gps_tracking"
        private const val KEY_CONTINUOUS = "continuous"
        private const val KEY_INTERVAL = "interval"
        private const val KEY_ACCURACY = "accuracy"
        private const val KEY_ALLOW_OFFLINE = "allow_offline"

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        fun from(context: Context): GpsTrackingConfig? {
            val prefs = prefs(context)
            if (!prefs.contains(KEY_INTERVAL)) return null
            val accuracy = if (prefs.contains(KEY_ACCURACY)) {
                Double.fromBits(prefs.getLong(KEY_ACCURACY, 0L))
            } else {
                null
            }
            return GpsTrackingConfig(
                continuousGpsTracking = prefs.getBoolean(KEY_CONTINUOUS, false),
                intervalMinutes = prefs.getInt(KEY_INTERVAL, 1),
                accuracyThreshold = accuracy,
                allowOfflineGpsCollection = prefs.getBoolean(KEY_ALLOW_OFFLINE, false),
            )
        }

        fun fromChannel(arguments: Map<*, *>?): GpsTrackingConfig {
            val map = arguments ?: emptyMap<Any, Any>()
            val interval = (map[GpsTrackingConstants.ARG_INTERVAL_MINUTES] as? Number)?.toInt() ?: 1
            val accuracy = (map[GpsTrackingConstants.ARG_ACCURACY_THRESHOLD] as? Number)?.toDouble()
            return GpsTrackingConfig(
                continuousGpsTracking =
                    map[GpsTrackingConstants.ARG_CONTINUOUS] as? Boolean ?: false,
                intervalMinutes = if (interval < 1) 1 else interval,
                accuracyThreshold = accuracy,
                allowOfflineGpsCollection =
                    map[GpsTrackingConstants.ARG_ALLOW_OFFLINE] as? Boolean ?: false,
            )
        }
    }
}
