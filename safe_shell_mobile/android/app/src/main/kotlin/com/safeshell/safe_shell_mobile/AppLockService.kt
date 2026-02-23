package com.safeshell.safe_shell_mobile

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.util.Log
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.util.*

class AppLockService : Service() {
    private var isRunning = false
    private val NOTIFICATION_ID = 101
    private val CHANNEL_ID = "safe_shell_app_lock"

    companion object {
        private val tempUnlockedPackages = mutableSetOf<String>()
        var isServiceRunning = false
            private set

        fun unlockPackage(packageName: String) {
            tempUnlockedPackages.add(packageName)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AppLockService", "onStartCommand called")
        if (!isRunning) {
            val notification = createNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // For Android 14+, we must specify the type in startForeground
                if (Build.VERSION.SDK_INT >= 34) {
                    startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            startMonitoring()
            isRunning = true
            isServiceRunning = true
            Log.d("AppLockService", "Monitoring started")
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        isServiceRunning = false
        super.onDestroy()
    }

    private fun startMonitoring() {
        Thread {
            while (isRunning) {
                val foregroundApp = getForegroundApp()
                if (foregroundApp != null) {
                    // Log even non-locked apps for debugging
                    Log.d("AppLockService", "Checking foreground app: $foregroundApp")
                    
                    // Check if it's a locked app and NOT already temp unlocked
                    if (isAppLocked(foregroundApp)) {
                        Log.w("AppLockService", "TARGET LOCKED APP DETECTED: $foregroundApp")
                        // Tiny delay to allow system to settle before interception
                        Thread.sleep(100) 
                        interceptApp(foregroundApp)
                        // Sleep a bit more after interception to prevent flickering 
                        Thread.sleep(600)
                    }
                }
                Thread.sleep(400) // Polling interval
            }
        }.start()
    }

    private fun getForegroundApp(): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        val usageEvents = usageStatsManager.queryEvents(time - 1000 * 5, time)
        val event = UsageEvents.Event()
        var lastEventPackage: String? = null

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lastEventPackage = event.packageName
            }
        }
        return lastEventPackage
    }

    private fun isAppLocked(packageName: String): Boolean {
        // Don't lock SafeShell itself
        if (packageName == this.packageName) return false
        
        // If it's already temp unlocked for this session
        if (tempUnlockedPackages.contains(packageName)) return false

        val prefs = getSharedPreferences("safe_shell_prefs", Context.MODE_PRIVATE)
        val lockedApps = prefs.getStringSet("locked_packages", setOf()) ?: setOf()
        
        return lockedApps.contains(packageName)
    }



    private fun interceptApp(packageName: String) {
        try {
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            intent.putExtra("LOCK_TARGET", packageName)
            startActivity(intent)
            Log.d("AppLockService", "Successfully called startActivity for $packageName")
        } catch (e: Exception) {
            Log.e("AppLockService", "CRITICAL: Failed to intercept $packageName! Error: ${e.message}")
            e.printStackTrace()
            // This is common on MIUI if 'Display pop-up windows' is OFF
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "SafeShell App Protection",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SafeShell Protection Active")
            .setContentText("Your private apps are being protected.")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }
}
