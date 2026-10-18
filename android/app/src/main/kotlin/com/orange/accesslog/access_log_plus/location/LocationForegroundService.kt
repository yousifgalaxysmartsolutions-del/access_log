package com.orange.accesslog.access_log_plus.location

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.content.ContextCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationListener
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.orange.accesslog.access_log_plus.R
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Foreground location service that owns continuous capture.
 *
 * Uses `FusedLocationProviderClient` with a native update request derived from
 * `periodicGpsCaptureIntervalMinutes`. Every accepted fix is written straight
 * to [LocalGpsStore] on a background executor, so capture keeps working with
 * the Flutter engine suspended or gone.
 *
 * Idempotent: a second `ACTION_START` while running only refreshes the request.
 */
class LocationForegroundService : Service(), LocationListener {

    private lateinit var client: FusedLocationProviderClient
    private lateinit var store: LocalGpsStore
    private lateinit var writes: ExecutorService
    private var currentConfig: GpsTrackingConfig? = null
    private var lastAccepted: Location? = null

    override fun onCreate() {
        super.onCreate()
        client = LocationServices.getFusedLocationProviderClient(this)
        store = LocalGpsStore(this)
        writes = Executors.newSingleThreadExecutor()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE, ACTION_START, null -> {
                val config = GpsTrackingConfig.from(this) ?: currentConfig
                if (config == null || !config.continuousGpsTracking) {
                    // Nothing valid to run (e.g. system restart after config was
                    // cleared); do not keep a foreground service alive.
                    stopSelf()
                    return START_NOT_STICKY
                }
                currentConfig = config
                if (!startInForeground()) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                if (!isRunning) {
                    isRunning = true
                    GpsEventBus.emit(GpsTrackingConstants.EVENT_TRACKING_STARTED)
                }
                requestUpdates(config)
                return START_STICKY
            }
            else -> return START_STICKY
        }
    }

    private fun startInForeground(): Boolean {
        return try {
            createChannel()
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            true
        } catch (error: Exception) {
            // Missing permission, background start restriction, etc.
            isRunning = false
            GpsEventBus.emit(
                GpsTrackingConstants.EVENT_ERROR,
                message = error.message,
            )
            false
        }
    }

    private fun requestUpdates(config: GpsTrackingConfig) {
        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            config.intervalMillis,
        )
            .setMinUpdateIntervalMillis(config.intervalMillis)
            .setMaxUpdateDelayMillis(config.intervalMillis)
            .setWaitForAccurateLocation(false)
            .build()
        try {
            client.removeLocationUpdates(this)
            client.requestLocationUpdates(request, this, Looper.getMainLooper())
        } catch (error: SecurityException) {
            // Permission revoked while running.
            isRunning = false
            GpsEventBus.emit(GpsTrackingConstants.EVENT_ERROR, message = error.message)
            stopSelf()
        }
    }

    override fun onLocationChanged(location: Location) {
        if (isDuplicate(location)) return
        if (!GpsPointValidator.isUsable(location)) return
        lastAccepted = location
        writes.execute { store.appendLocation(applicationContext, location) }
    }

    private fun isDuplicate(location: Location): Boolean {
        val previous = lastAccepted ?: return false
        if (location.time == previous.time) return true
        val sameSpot =
            location.latitude == previous.latitude &&
                location.longitude == previous.longitude
        return sameSpot && location.time - previous.time < DUPLICATE_WINDOW_MILLIS
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Location tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Continuous location capture for Access Log+"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pending = launch?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.gps_tracking_notification_title))
            .setContentText(getString(R.string.gps_tracking_notification_text))
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pending)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    override fun onDestroy() {
        try {
            client.removeLocationUpdates(this)
        } catch (_: Exception) {
        }
        writes.shutdown()
        if (isRunning) {
            isRunning = false
            GpsEventBus.emit(GpsTrackingConstants.EVENT_TRACKING_STOPPED)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_START = "com.orange.accesslog.location.START"
        const val ACTION_STOP = "com.orange.accesslog.location.STOP"
        const val ACTION_UPDATE = "com.orange.accesslog.location.UPDATE"
        const val CHANNEL_ID = "cap_gps_tracking"
        const val NOTIFICATION_ID = 4711
        private const val DUPLICATE_WINDOW_MILLIS = 5_000L

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context) {
            val intent = Intent(context, LocationForegroundService::class.java)
                .setAction(ACTION_START)
            ContextCompat.startForegroundService(context, intent)
        }

        fun update(context: Context) {
            if (!isRunning) return
            val intent = Intent(context, LocationForegroundService::class.java)
                .setAction(ACTION_UPDATE)
            try {
                context.startService(intent)
            } catch (_: Exception) {
                // Background start restriction while not visible; next reconcile
                // or restart will apply the configuration.
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, LocationForegroundService::class.java))
        }
    }
}
