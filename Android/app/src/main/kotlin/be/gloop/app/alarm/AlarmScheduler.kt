package be.gloop.app.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import be.gloop.app.MainActivity

/** Exact alarms via `AlarmManager.setAlarmClock` (shown in the status bar, survives Doze). */
class AlarmScheduler(private val context: Context) {
    private val manager = context.getSystemService(AlarmManager::class.java)

    /** Exact alarms allowed (always on 33+ with USE_EXACT_ALARM; a user toggle on 31–32). */
    val canScheduleExact: Boolean
        get() = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()

    fun schedule(planId: String, atMillis: Long, kind: Kind = Kind.MAIN) {
        val operation = ringIntent(planId, kind, PendingIntent.FLAG_UPDATE_CURRENT)!!
        val show = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        try {
            manager.setAlarmClock(AlarmManager.AlarmClockInfo(atMillis, show), operation)
        } catch (e: SecurityException) {
            // Exact alarms not allowed (31–32, user turned it off): best effort, may be late.
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, operation)
        }
    }

    fun cancel(planId: String, kind: Kind = Kind.MAIN) {
        ringIntent(planId, kind, PendingIntent.FLAG_NO_CREATE)?.let { manager.cancel(it); it.cancel() }
    }

    fun scheduleFailSafe(atMillis: Long) {
        val pi = failSafeIntent(PendingIntent.FLAG_UPDATE_CURRENT)!!
        try {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
        } catch (e: SecurityException) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
        }
    }

    fun cancelFailSafe() {
        failSafeIntent(PendingIntent.FLAG_NO_CREATE)?.let { manager.cancel(it); it.cancel() }
    }

    /** MAIN = the alarm's own schedule; TEST = "ring in 10 s"; RESUME = restart ringing after a reboot. */
    enum class Kind { MAIN, TEST, RESUME }

    private fun ringIntent(planId: String, kind: Kind, flags: Int): PendingIntent? {
        val intent = Intent(context, AlarmReceiver::class.java)
            .setData(Uri.parse("gloop://alarm/${kind.name.lowercase()}/$planId"))
            .putExtra(AlarmReceiver.EXTRA_PLAN_ID, planId)
            .putExtra(AlarmReceiver.EXTRA_KIND, kind.name)
        return PendingIntent.getBroadcast(context, 0, intent, flags or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun failSafeIntent(flags: Int): PendingIntent? =
        PendingIntent.getBroadcast(context, 0, Intent(context, FailSafeReceiver::class.java), flags or PendingIntent.FLAG_IMMUTABLE)
}
