package be.gloop.app.ui

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import be.gloop.app.R
import be.gloop.app.alarm.AlarmScheduler

/** What the alarm needs from the system (iOS: `PermissionKind`). Only missing ones are shown. */
enum class AlarmPermission(val titleRes: Int, val reasonRes: Int) {
    NOTIFICATIONS(R.string.perm_notifications_title, R.string.perm_notifications_reason),
    EXACT_ALARMS(R.string.perm_exact_title, R.string.perm_exact_reason),
    FULL_SCREEN(R.string.perm_fullscreen_title, R.string.perm_fullscreen_reason),
    BATTERY(R.string.perm_battery_title, R.string.perm_battery_reason);

    fun isGranted(context: Context): Boolean = when (this) {
        NOTIFICATIONS -> Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        EXACT_ALARMS -> AlarmScheduler(context).canScheduleExact
        FULL_SCREEN -> Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
            context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
        BATTERY -> context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(context.packageName)
    }

    /** Settings screen for everything that isn't a runtime dialog. */
    fun settingsIntent(context: Context): Intent {
        val pkg = Uri.parse("package:${context.packageName}")
        return when (this) {
            NOTIFICATIONS -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            EXACT_ALARMS -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg)
                else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg)
            FULL_SCREEN -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg)
                else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg)
            // The list screen, not the direct dialog: that needs REQUEST_IGNORE_BATTERY_OPTIMIZATIONS (Play policy).
            BATTERY -> Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    companion object {
        fun missing(context: Context): List<AlarmPermission> = entries.filterNot { it.isGranted(context) }
    }
}
