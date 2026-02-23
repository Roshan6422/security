package com.safeshell.safe_shell_mobile

import android.app.AppOpsManager
import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.util.Base64
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import android.util.Log
import java.util.Properties
import java.io.FileInputStream
import java.io.File

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.safeshell.safe_shell_mobile/stealth"
    private var pendingLockTarget: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        // Queue intent for after Flutter engine is ready
        val target = intent?.getStringExtra("LOCK_TARGET")
        if (target != null) {
            pendingLockTarget = target
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val target = intent.getStringExtra("LOCK_TARGET")
        if (target != null) {
            val engine = flutterEngine
            if (engine != null) {
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                channel.invokeMethod("showAppLock", mapOf("packageName" to target))
            } else {
                pendingLockTarget = target
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "toggleStealthMode" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    toggleStealthMode(enable)
                    result.success(true)
                }

                // Send any pending lock target now that Flutter is ready
                "ready" -> {
                    result.success(true)
                    val target = pendingLockTarget
                    if (target != null) {
                        pendingLockTarget = null
                        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                        channel.invokeMethod("showAppLock", mapOf("packageName" to target))
                    }
                }
                "toggleScreenshot" -> {
                    val allow = call.argument<Boolean>("allow") ?: false
                    if (allow) {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(true)
                }
                "getInstalledApps" -> {
                    val apps = getInstalledApps()
                    result.success(apps)
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val success = launchApp(packageName)
                    result.success(success)
                }
                "checkUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsagePermission" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "setLockedApps" -> {
                    val pkgList = call.argument<List<String>>("packages") ?: listOf()
                    setLockedApps(pkgList)
                    result.success(true)
                }
                "unlockPackage" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    AppLockService.unlockPackage(packageName)
                    result.success(true)
                }
                "hideApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val success = hideApp(packageName)
                    result.success(success)
                }
                "unhideApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val success = unhideApp(packageName)
                    result.success(success)
                }
                "isAppHidden" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    result.success(isAppHidden(packageName))
                }
                "checkOverlayPermission" -> {
                    val canDraw = Settings.canDrawOverlays(this)
                    Log.d("SafeShell", "checkOverlayPermission: $canDraw")
                    result.success(canDraw)
                }
                "checkServiceStatus" -> {
                    result.success(AppLockService.isServiceRunning)
                }
                "isMiui" -> {
                    result.success(isMiui())
                }
                "requestOverlayPermission" -> {
                    val packageName = call.argument<String>("packageName") ?: this.packageName
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // Fallback if the package URI intent fails
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                        startActivity(intent)
                        result.success(true)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun toggleStealthMode(enable: Boolean) {
        val pm = packageManager
        val defaultComponent = ComponentName(this, "com.safeshell.safe_shell_mobile.MainActivity")
        val calculatorComponent = ComponentName(this, "com.safeshell.safe_shell_mobile.CalculatorActivityAlias")

        if (enable) {
            // Enable calculator alias, Disable default
            pm.setComponentEnabledSetting(calculatorComponent, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, 0)
            pm.setComponentEnabledSetting(defaultComponent, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, 0)
        } else {
            // Enable default, Disable calculator alias
            pm.setComponentEnabledSetting(defaultComponent, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, 0)
            pm.setComponentEnabledSetting(calculatorComponent, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, 0)
        }
        
        // Android Launcher often takes a few seconds or a restart to refresh icons.
        // Some devices require DONT_KILL_APP to be 0 (kill app) to refresh instantly.
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val apps = mutableListOf<Map<String, String>>()
        val pm = packageManager
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        for (appInfo in packages) {
            // Only non-system apps or apps with launch intent
            val launchIntent = pm.getLaunchIntentForPackage(appInfo.packageName)
            if (launchIntent != null) {
                val appMap = mutableMapOf<String, String>()
                appMap["name"] = pm.getApplicationLabel(appInfo).toString()
                appMap["packageName"] = appInfo.packageName
                
                // Get icon as base64 (simplified)
                try {
                    val icon = pm.getApplicationIcon(appInfo)
                    val bitmap = if (icon is BitmapDrawable) {
                        icon.bitmap
                    } else {
                        val b = Bitmap.createBitmap(icon.intrinsicWidth, icon.intrinsicHeight, Bitmap.Config.ARGB_8888)
                        val canvas = Canvas(b)
                        icon.setBounds(0, 0, canvas.width, canvas.height)
                        icon.draw(canvas)
                        b
                    }
                    val stream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                    val byteArray = stream.toByteArray()
                    appMap["icon"] = Base64.encodeToString(byteArray, Base64.NO_WRAP)
                } catch (e: Exception) {
                    appMap["icon"] = ""
                }
                
                apps.add(appMap)
            }
        }
        return apps
    }

    private fun launchApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }


    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun setLockedApps(packages: List<String>) {
        val prefs = getSharedPreferences("safe_shell_prefs", Context.MODE_PRIVATE)
        Log.d("SafeShell", "Syncing locked apps to Native: $packages")
        prefs.edit().putStringSet("locked_packages", packages.toSet()).apply()
        
        // Start/Update the monitoring service
        // Even if packages is empty, we start the service so it can clear its internal list
        val serviceIntent = Intent(this, AppLockService::class.java)
        serviceIntent.putExtra("LOCKED_PACKAGES", packages.toTypedArray())
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun hideApp(packageName: String): Boolean {
        Log.d("SafeShell", "hideApp called for $packageName")
        return try {
            val pm = packageManager
            val componentNames = mutableListOf<ComponentName>()

            // Method 1: Standard Launcher Query
            val intent = Intent(Intent.ACTION_MAIN)
            intent.addCategory(Intent.CATEGORY_LAUNCHER)
            intent.`package` = packageName
            val resolveInfos = pm.queryIntentActivities(intent, 0)
            for (info in resolveInfos) {
                componentNames.add(ComponentName(packageName, info.activityInfo.name))
            }

            // Method 2: Fallback - Scan all activities in package
            if (componentNames.isEmpty()) {
                Log.d("SafeShell", "Fallback: Scanning all activities for $packageName")
                val pkgInfo = pm.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES)
                pkgInfo.activities?.forEach { activity ->
                    // Typically you only want to hide the 'Main' activity, but we'll try all if launcher is empty
                    componentNames.add(ComponentName(packageName, activity.name))
                }
            }

            if (componentNames.isEmpty()) {
                Log.e("SafeShell", "CRITICAL: No components found to hide for $packageName")
                return false
            }

            for (componentName in componentNames) {
                Log.d("SafeShell", "Hiding component: $componentName")
                pm.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    0 // Force sync
                )
            }
            true
        } catch (e: SecurityException) {
            Log.e("SafeShell", "MIUI SECURITY BLOCK: Failed to hide $packageName. Error: ${e.message}")
            false
        } catch (e: Exception) {
            Log.e("SafeShell", "Failed to hide $packageName: ${e.message}")
            false
        }
    }

    private fun unhideApp(packageName: String): Boolean {
        Log.d("SafeShell", "unhideApp called for $packageName")
        return try {
            val pm = packageManager
            // We need to get the component from the package info since launch intent won't work when disabled
            val pkgInfo = pm.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES)
            val activities = pkgInfo.activities ?: return false
            for (activity in activities) {
                val compName = ComponentName(packageName, activity.name)
                val state = pm.getComponentEnabledSetting(compName)
                if (state == PackageManager.COMPONENT_ENABLED_STATE_DISABLED) {
                    Log.d("SafeShell", "Unhiding component: $compName")
                    pm.setComponentEnabledSetting(
                        compName,
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        0 // Force launcher refresh
                    )
                }
            }
            true
        } catch (e: Exception) {
            Log.e("SafeShell", "Failed to unhide $packageName: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    private fun isAppHidden(packageName: String): Boolean {
        return try {
            val pm = packageManager
            val launchIntent = pm.getLaunchIntentForPackage(packageName)
            // If no launch intent, the launcher activity is disabled = hidden
            launchIntent == null
        } catch (e: Exception) {
            false
        }
    }

    private fun isMiui(): Boolean {
        return try {
            val properties = java.util.Properties()
            properties.load(java.io.FileInputStream(java.io.File("/system/build.prop")))
            properties.getProperty("ro.miui.ui.version.name", null) != null
        } catch (e: Exception) {
            // Fallback: check if manufacturer is Xiaomi
            android.os.Build.MANUFACTURER.equals("Xiaomi", ignoreCase = true)
        }
    }
}

