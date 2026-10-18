package com.orange.accesslog.access_log_plus.location

import android.content.Context
import android.location.Location
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/**
 * Durable, app-private storage for captured GPS points.
 *
 * Format: JSON Lines, one record per line, appended and `fsync`ed. A single
 * interrupted write can at worst truncate the last line, never earlier history.
 *
 * Path contract shared with Dart (`LocalGpsStore`) and iOS
 * (`LocalGpsStore.swift`):
 *
 * `<filesDir>/cap_gps/locations.jsonl`
 *
 * `filesDir` is what Dart's `getApplicationSupportDirectory()` resolves to on
 * Android, so both sides read/write the same file.
 */
class LocalGpsStore(context: Context) {
    private val file = File(context.filesDir, "$DIRECTORY/$FILE_NAME")

    /** Appends one raw JSON record. Returns false if the write failed. */
    fun append(record: JSONObject): Boolean {
        synchronized(LOCK) {
            return try {
                file.parentFile?.mkdirs()
                FileOutputStream(file, true).use { output ->
                    output.write((record.toString() + "\n").toByteArray(Charsets.UTF_8))
                    output.flush()
                    output.fd.sync()
                }
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    /**
     * Builds and appends a record for [location]. Returns true when the point
     * was accepted and persisted.
     */
    fun appendLocation(context: Context, location: Location): Boolean {
        if (!GpsPointValidator.isUsable(location)) return false
        val isOffline = !ConnectivityState.isOnline(context)
        val record = JSONObject().apply {
            put("localId", UUID.randomUUID().toString())
            put("IncidentId", 0)
            put("LocationDateTime", formatTimestamp(location.time))
            put("TaskLatitude", GpsPointValidator.formatCoordinate(location.latitude))
            put("TaskLongitude", GpsPointValidator.formatCoordinate(location.longitude))
            put("isoffline", isOffline)
            if (location.hasAccuracy()) {
                put("gpsAccuracyMeters", location.accuracy.toDouble())
            }
        }
        return append(record)
    }

    companion object {
        const val DIRECTORY = "cap_gps"
        const val FILE_NAME = "locations.jsonl"
        private val LOCK = Any()

        /** `yyyy-MM-ddTHH:mm:ss.SSSSSS` in local time, matching the CAP sample. */
        fun formatTimestamp(epochMillis: Long): String {
            val seconds = SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss",
                Locale.US,
            ).format(Date(epochMillis))
            val micros = (epochMillis % 1000 + 1000) % 1000 * 1000
            return String.format(Locale.US, "%s.%06d", seconds, micros)
        }
    }
}
