package com.orange.accesslog.access_log_plus.location

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities

/** Minimal network-state probe used to stamp each captured point. */
object ConnectivityState {
    /**
     * True when an active network reports validated internet access. Used only
     * to set `isoffline`; it never gates capture or persistence.
     */
    fun isOnline(context: Context): Boolean {
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }
}
