package com.safeshell.safe_shell_mobile

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

object StealthLauncher {
    // Example: disguise as Calculator (package name of Android’s default calculator)
    private const val DISGUISE_PACKAGE = "com.android.calculator2"

    fun enable(context: Context) {
        val pm = context.packageManager
        val component = ComponentName(context, MainActivity::class.java)
        pm.setComponentEnabledSetting(
            component,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
        // Launch disguised app icon (doesn't affect our hidden activity)
        val launchIntent = pm.getLaunchIntentForPackage(DISGUISE_PACKAGE)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(launchIntent)
            } catch (e: Exception) {
                // Calculator not found or other error
            }
        }
    }

    fun disable(context: Context) {
        val pm = context.packageManager
        val component = ComponentName(context, MainActivity::class.java)
        pm.setComponentEnabledSetting(
            component,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
    }
}
