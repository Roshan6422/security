package com.safeshell.safe_shell_mobile

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

class AdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        Toast.makeText(context, "SafeShell anti‑uninstall enabled", Toast.LENGTH_SHORT).show()
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        // Show a warning dialog; user can still disable, but you can log it.
        return "Disabling protection may expose your vault data!"
    }

    override fun onDisabled(context: Context, intent: Intent) {
        Toast.makeText(context, "Anti‑uninstall disabled", Toast.LENGTH_LONG).show()
    }
}
