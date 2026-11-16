package be.gloop.app.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import be.gloop.app.GloopApplication

/** An alarm went off: start the ring cycle (or resume one after a reboot). */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val planId = intent.getStringExtra(EXTRA_PLAN_ID) ?: return
        val kind = runCatching { AlarmScheduler.Kind.valueOf(intent.getStringExtra(EXTRA_KIND) ?: "") }
            .getOrDefault(AlarmScheduler.Kind.MAIN)
        GloopApplication.controller(context).alarmFired(planId, kind)
    }

    companion object {
        const val EXTRA_PLAN_ID = "planId"
        const val EXTRA_KIND = "kind"
    }
}

/** Ringing for `maxReArms × reArmMinutes` without a finished mission: stop for good. */
class FailSafeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        GloopApplication.controller(context).failSafe()
    }
}

/** Alarms are cleared on reboot and need re-scheduling after time/timezone changes and updates. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> GloopApplication.controller(context).restoreAfterRestart()
        }
    }
}
