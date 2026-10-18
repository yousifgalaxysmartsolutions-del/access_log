package com.orange.accesslog.access_log_plus.location

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridges native tracking events to Flutter *when an engine is alive*.
 *
 * The service emits regardless of whether a sink is attached; capture and
 * persistence never depend on Flutter listening.
 */
object GpsEventBus {
    @Volatile
    private var sink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    fun attach(eventSink: EventChannel.EventSink?) {
        sink = eventSink
    }

    fun emit(event: String, permission: String? = null, message: String? = null) {
        val current = sink ?: return
        mainHandler.post {
            current.success(
                mapOf(
                    GpsTrackingConstants.EVENT_KEY to event,
                    GpsTrackingConstants.EVENT_PERMISSION to permission,
                    GpsTrackingConstants.EVENT_MESSAGE to message,
                ),
            )
        }
    }
}
