package com.safeshell.safe_shell_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build

class UsbDetector(private val ctx: Context, private val listener: UsbListener) {

    interface UsbListener {
        fun onUsbConnected(device: UsbDevice)
        fun onUsbDisconnected(device: UsbDevice)
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val dev = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    } ?: return
                    listener.onUsbConnected(dev)
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val dev = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    } ?: return
                    listener.onUsbDisconnected(dev)
                }
            }
        }
    }

    fun register() {
        val filter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            ctx.registerReceiver(receiver, filter)
        }
    }

    fun unregister() {
        try {
            ctx.unregisterReceiver(receiver)
        } catch (e: Exception) {
            // Receiver not registered
        }
    }
}
