package com.safeshell.safe_shell_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbManager
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class UsbBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val prefs = context.getSharedPreferences("safe_shell_prefs", Context.MODE_PRIVATE)
        
        var isConnected = false
        var shouldReport = false

        if (UsbManager.ACTION_USB_DEVICE_ATTACHED == action) {
            Log.d("SafeShellUSB", "USB Device Attached")
            isConnected = true
            shouldReport = true
        } else if (UsbManager.ACTION_USB_DEVICE_DETACHED == action) {
            Log.d("SafeShellUSB", "USB Device Detached")
            isConnected = false
            shouldReport = true
        } else if ("android.hardware.usb.action.USB_STATE" == action) {
            isConnected = intent.extras?.getBoolean("connected") ?: false
            Log.d("SafeShellUSB", "USB State Changed: Connected=$isConnected")
            shouldReport = true
        }

        if (shouldReport) {
            // Persist state so Flutter can read it on boot
            prefs.edit().putBoolean("usb_connected", isConnected).apply()
            
            // Try to report to Flutter via static channel
            try {
                MainActivity.stealthChannel?.invokeMethod("onUsbStatusChanged", mapOf("connected" to isConnected))
                Log.d("SafeShellUSB", "Reported to Flutter: $isConnected")
            } catch (e: Exception) {
                Log.e("SafeShellUSB", "Failed to report to Flutter: ${e.message}")
            }
        }
    }
}
