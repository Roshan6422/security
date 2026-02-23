package com.safeshell.safe_shell_mobile

import android.app.*
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
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
        if (!isRunning) {
            val notification = createNotification()
            startForeground(NOTIFICATION_ID, notification)
            startMonitoring()
            isRunning = true
        }
        return START_STICKY
    }

    private fun startMonitoring() {
        Thread {
            while (isRunning) {
                val foregroundApp = getForegroundApp()
                if (foregroundApp != null) {
                    // If focusing on a different app, we might want to relock others?
                    // For now, let's keep it simple: if foreground is NOT the locked package, nothing happens.
                    // If it IS a locked package and NOT temp-unlocked, intercept.
                    if (isAppLocked(foregroundApp)) {
                        interceptApp(foregroundApp)
                    }
                }
                Thread.sleep(400) // Polling interval (reduced for faster response)
            }
        }.start()
    }

    private fun getForegroundApp(): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        // Query window reduced from 10s to 5s for precision
        val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 1000 * 5, time)

        
        if (stats != null && stats.isNotEmpty()) {
            var latestStat = stats[0]
            for (stat in stats) {
                if (stat.lastTimeUsed > latestStat.lastTimeUsed) {
                    latestStat = stat
                }
            }
            return latestStat.packageName
        }
        return null
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
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        intent.putExtra("LOCK_TARGET", packageName)
        startActivity(intent)
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
