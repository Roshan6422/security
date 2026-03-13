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
        private var lockedPackages = mutableSetOf<String>()
        var isServiceRunning = false
            private set
        
        private var lastUnlockTime: Long = 0

        fun unlockPackage(packageName: String) {
            tempUnlockedPackages.add(packageName)
            lastUnlockTime = System.currentTimeMillis()
        }
    }

    private var screenReceiver: android.content.BroadcastReceiver? = null

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        
        screenReceiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == Intent.ACTION_SCREEN_OFF) {
                    if (tempUnlockedPackages.isNotEmpty()) {
                        Log.d("AppLockService", "Screen turned off. Clearing temp unlocks.")
                        tempUnlockedPackages.clear()
                    }
                }
            }
        }
        val filter = android.content.IntentFilter(Intent.ACTION_SCREEN_OFF)
        registerReceiver(screenReceiver, filter)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AppLockService", "onStartCommand called")
        
        // Handle package list updates via Intent
        val packagesFromIntent = intent?.getStringArrayExtra("LOCKED_PACKAGES")
        if (packagesFromIntent != null) {
            lockedPackages = packagesFromIntent.toMutableSet()
            Log.d("AppLockService", "Received updated locked packages from Intent: $lockedPackages")
        } else {
            // Load from SharedPreferences as fallback (crucial for boot start)
            val prefs = getSharedPreferences("safe_shell_prefs", Context.MODE_PRIVATE)
            val savedPackages = prefs.getStringSet("locked_packages", null)
            if (savedPackages != null) {
                lockedPackages = savedPackages.toMutableSet()
                Log.d("AppLockService", "Loaded ${lockedPackages.size} packages from SharedPreferences")
            }
        }

        if (!isRunning) {
            val notification = createNotification()
            // ... (rest of the notification logic)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
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
        Log.d("AppLockService", "Service onDestroy called")
        isRunning = false
        isServiceRunning = false
        screenReceiver?.let { unregisterReceiver(it) }
        super.onDestroy()
    }

    private fun startMonitoring() {
        Thread {
            while (isRunning) {
                val foregroundApp = getForegroundApp()
                if (foregroundApp != null) {
                    // Check if it's a locked app and NOT already temp unlocked
                    if (isAppLocked(foregroundApp)) {
                        Log.w("AppLockService", "INTERCEPT TRIGGERED for: $foregroundApp")
                        // Tiny delay to allow system to settle before interception
                        Thread.sleep(100) 
                        interceptApp(foregroundApp)
                        // Sleep a bit more after interception to prevent flickering 
                        Thread.sleep(600)
                    } else if (foregroundApp != packageName && !tempUnlockedPackages.contains(foregroundApp)) {
                        // User switched to a different app (e.g. Home launcher or another app)
                        // Ignore systemui to prevent locking just by pulling down notifications
                        if (foregroundApp != "com.android.systemui") {
                            val timeSinceUnlock = System.currentTimeMillis() - lastUnlockTime
                            if (tempUnlockedPackages.isNotEmpty() && timeSinceUnlock > 2000) {
                                Log.d("AppLockService", "Foreground changed to $foregroundApp, clearing temp unlocks")
                                tempUnlockedPackages.clear()
                            }
                        }
                    }
                }
                Thread.sleep(100) // Reduced polling interval for faster interception
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
        if (tempUnlockedPackages.contains(packageName)) {
            Log.d("AppLockService", "$packageName is temp unlocked")
            return false
        }

        val isLocked = lockedPackages.contains(packageName)
        if (isLocked) {
            Log.w("AppLockService", "INTERCEPT TRIGGERED for: $packageName")
        } else {
            // Optional: periodically log the count to confirm it's not 0
            if (System.currentTimeMillis() % 10000 < 400 && packageName != "com.miui.home" && packageName != "com.safeshell.safe_shell_mobile") {
                Log.d("AppLockService", "Service is watching. Current locked count: ${lockedPackages.size}")
            }
        }
        
        return isLocked
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
}
