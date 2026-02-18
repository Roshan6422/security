package com.safeshell.safe_shell_mobile

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.safeshell.safe_shell_mobile/stealth"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "toggleStealthMode") {
                val enable = call.argument<Boolean>("enable") ?: false
                toggleStealthMode(enable)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun toggleStealthMode(enable: Boolean) {
        val pm = packageManager
        val defaultComponent = ComponentName(this, "com.safeshell.safe_shell_mobile.MainActivity")
        val calculatorComponent = ComponentName(this, "com.safeshell.safe_shell_mobile.CalculatorActivityAlias")

        if (enable) {
            pm.setComponentEnabledSetting(calculatorComponent, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
            pm.setComponentEnabledSetting(defaultComponent, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
        } else {
            pm.setComponentEnabledSetting(defaultComponent, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
            pm.setComponentEnabledSetting(calculatorComponent, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
        }
    }
}
