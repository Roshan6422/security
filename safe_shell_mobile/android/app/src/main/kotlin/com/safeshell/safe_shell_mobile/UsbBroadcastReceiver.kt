package com.safeshell.safe_shell_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbManager
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class UsbBroadcastReceiver(private val channel: MethodChannel) : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (UsbManager.ACTION_USB_DEVICE_ATTACHED == action) {
            Log.d("SafeShellUSB", "USB Device Attached")
            channel.invokeMethod("onUsbStatusChanged", mapOf("connected" to true))
        } else if (UsbManager.ACTION_USB_DEVICE_DETACHED == action) {
            Log.d("SafeShellUSB", "USB Device Detached")
            channel.invokeMethod("onUsbStatusChanged", mapOf("connected" to false))
        } else if ("android.hardware.usb.action.USB_STATE" == action) {
            val connected = intent.extras?.getBoolean("connected") ?: false
            Log.d("SafeShellUSB", "USB State Changed: Connected=$connected")
            channel.invokeMethod("onUsbStatusChanged", mapOf("connected" to connected))
        }
    }
}
