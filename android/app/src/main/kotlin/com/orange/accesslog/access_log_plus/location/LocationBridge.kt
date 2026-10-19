package com.orange.accesslog.access_log_plus.location

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter bridge for continuous background tracking.
 *
 * This is only a command/status surface: it starts/stops the native engine,
 * applies configuration and answers permission queries. The engine itself
 * ([LocationForegroundService] + [LocalGpsStore]) runs independently of this
 * bridge and of Flutter.
 */
class LocationBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val methodChannel = MethodChannel(messenger, GpsTrackingConstants.METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, GpsTrackingConstants.EVENT_CHANNEL)
    private var pendingPermission: MethodChannel.Result? = null

    /**
     * Event-driven Location Services monitor. The OS broadcasts when the user
     * toggles GPS; we re-evaluate and push the change to Flutter instead of
     * polling from Dart.
     */
    private val servicesReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != LocationManager.PROVIDERS_CHANGED_ACTION) return
            val status = permissionStatus()
            if (status == GpsTrackingConstants.PERMISSION_SERVICE_DISABLED) {
                GpsEventBus.emit(GpsTrackingConstants.EVENT_SERVICES_DISABLED)
            } else {
                GpsEventBus.emit(
                    GpsTrackingConstants.EVENT_PERMISSION_CHANGED,
                    permission = status,
                )
            }
        }
    }

    init {
        methodChannel.setMethodCallHandler { call, result -> handle(call, result) }
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                GpsEventBus.attach(events)
            }

            override fun onCancel(arguments: Any?) {
                GpsEventBus.attach(null)
            }
        })
        registerServicesMonitor()
    }

    fun detach() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        GpsEventBus.attach(null)
        pendingPermission = null
        unregisterServicesMonitor()
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            GpsTrackingConstants.START_TRACKING -> startTracking(result)
            GpsTrackingConstants.STOP_TRACKING -> {
                LocationForegroundService.stop(activity)
                result.success(true)
            }
            GpsTrackingConstants.IS_TRACKING ->
                result.success(LocationForegroundService.isRunning)
            GpsTrackingConstants.APPLY_CONFIGURATION -> {
                val config = GpsTrackingConfig.fromChannel(call.arguments as? Map<*, *>)
                config.persist(activity)
                LocationForegroundService.update(activity)
                result.success(null)
            }
            GpsTrackingConstants.GET_PERMISSION_STATUS ->
                result.success(permissionStatus())
            GpsTrackingConstants.REQUEST_PERMISSIONS -> requestPermissions(result)
            GpsTrackingConstants.OPEN_LOCATION_SETTINGS -> {
                openLocationSettings()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun openLocationSettings() {
        try {
            activity.startActivity(
                Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
            )
        } catch (_: Exception) {
            // No settings activity available; the gate keeps offering the action.
        }
    }

    private fun registerServicesMonitor() {
        val filter = IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                activity.registerReceiver(
                    servicesReceiver,
                    filter,
                    Context.RECEIVER_NOT_EXPORTED,
                )
            } else {
                activity.registerReceiver(servicesReceiver, filter)
            }
        } catch (_: Exception) {
            // Monitoring is best-effort; the permission query still reports it.
        }
    }

    private fun unregisterServicesMonitor() {
        try {
            activity.unregisterReceiver(servicesReceiver)
        } catch (_: Exception) {
            // Never registered.
        }
    }

    private fun startTracking(result: MethodChannel.Result) {
        val status = permissionStatus()
        when {
            status == GpsTrackingConstants.PERMISSION_SERVICE_DISABLED -> {
                GpsEventBus.emit(GpsTrackingConstants.EVENT_SERVICES_DISABLED)
                result.success(false)
            }
            status != GpsTrackingConstants.PERMISSION_ALWAYS -> {
                GpsEventBus.emit(
                    GpsTrackingConstants.EVENT_PERMISSION_CHANGED,
                    permission = status,
                )
                result.success(false)
            }
            else -> {
                try {
                    LocationForegroundService.start(activity)
                    result.success(true)
                } catch (error: Exception) {
                    // e.g. background start restriction on Android 12+.
                    GpsEventBus.emit(
                        GpsTrackingConstants.EVENT_ERROR,
                        message = error.message,
                    )
                    result.success(false)
                }
            }
        }
    }

    // --- Permissions -------------------------------------------------------

    private fun requestPermissions(result: MethodChannel.Result) {
        if (pendingPermission != null) {
            // A prompt is already in flight; never stack dialogs.
            result.success(permissionStatus())
            return
        }
        pendingPermission = result
        markRequested()
        requestNextInChain()
    }

    private fun requestNextInChain() {
        if (!hasForeground()) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ),
                REQUEST_FOREGROUND,
            )
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !hasPermission(Manifest.permission.POST_NOTIFICATIONS)
        ) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_NOTIFICATIONS,
            )
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !hasBackground()) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                REQUEST_BACKGROUND,
            )
            return
        }
        completePermissions()
    }

    /** Called by the host activity's `onRequestPermissionsResult`. */
    fun onRequestPermissionsResult(requestCode: Int) {
        if (pendingPermission == null) return
        when (requestCode) {
            REQUEST_FOREGROUND ->
                if (!hasForeground()) completePermissions() else requestNextInChain()
            REQUEST_NOTIFICATIONS -> requestNextInChain()
            REQUEST_BACKGROUND -> completePermissions()
        }
    }

    private fun completePermissions() {
        val status = permissionStatus()
        GpsEventBus.emit(
            GpsTrackingConstants.EVENT_PERMISSION_CHANGED,
            permission = status,
        )
        pendingPermission?.success(status)
        pendingPermission = null
    }

    private fun permissionStatus(): String {
        if (!locationServicesEnabled()) {
            return GpsTrackingConstants.PERMISSION_SERVICE_DISABLED
        }
        return when {
            hasForeground() && hasBackground() -> GpsTrackingConstants.PERMISSION_ALWAYS
            hasForeground() -> GpsTrackingConstants.PERMISSION_WHEN_IN_USE
            hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ->
                GpsTrackingConstants.PERMISSION_WHEN_IN_USE
            wasRequested() -> GpsTrackingConstants.PERMISSION_DENIED
            else -> GpsTrackingConstants.PERMISSION_NOT_DETERMINED
        }
    }

    private fun hasForeground(): Boolean =
        hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
            hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)

    private fun hasBackground(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            hasPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(activity, permission) ==
            PackageManager.PERMISSION_GRANTED

    private fun locationServicesEnabled(): Boolean {
        val manager = activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.isLocationEnabled
        } else {
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
    }

    private fun prefs() =
        activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun markRequested() = prefs().edit().putBoolean(KEY_REQUESTED, true).apply()

    private fun wasRequested(): Boolean = prefs().getBoolean(KEY_REQUESTED, false)

    companion object {
        private const val REQUEST_FOREGROUND = 0x4701
        private const val REQUEST_NOTIFICATIONS = 0x4702
        private const val REQUEST_BACKGROUND = 0x4703
        private const val PREFS = "cap_gps_tracking"
        private const val KEY_REQUESTED = "permission_requested"
    }
}
