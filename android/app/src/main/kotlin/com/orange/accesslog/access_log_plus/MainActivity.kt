package com.orange.accesslog.access_log_plus

import com.orange.accesslog.access_log_plus.location.LocationBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var locationBridge: LocationBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        locationBridge = LocationBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        locationBridge?.onRequestPermissionsResult(requestCode)
    }

    override fun onDestroy() {
        locationBridge?.detach()
        locationBridge = null
        super.onDestroy()
    }
}
