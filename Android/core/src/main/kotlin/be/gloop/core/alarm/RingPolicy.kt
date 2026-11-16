package be.gloop.core.alarm

import be.gloop.core.model.AlarmPlan
import be.gloop.core.model.SessionState
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Pure rules of the Android ring loop. Android rings with no Stop button until the mission is
 * done, so instead of iOS's X → countdown → re-ring, the same limits apply as time:
 * - fail-safe after `maxReArms × reArmMinutes` (iOS: that many follow-ups);
 * - re-rings = whole `reArmMinutes` intervals that passed before success (feeds XP like iOS).
 */
object RingPolicy {
    /** Port of iOS `ReArmPolicy.currentSession`: a cycle per day, or a new one after a finished cycle. */
    fun currentSession(stored: SessionState?, nowMillis: Long, newRing: Boolean = false,
                       zone: ZoneId = ZoneId.systemDefault()): SessionState {
        val today = dayKey(nowMillis, zone)
        if (stored != null && stored.day == today && !(newRing && stored.isFinished)) return stored
        return SessionState(day = today)
    }

    fun failSafeAt(rangAtMillis: Long, plan: AlarmPlan): Long =
        rangAtMillis + plan.maxReArms.coerceAtLeast(1) * intervalMillis(plan)

    fun reRings(rangAtMillis: Long, nowMillis: Long, plan: AlarmPlan): Int {
        val elapsed = (nowMillis - rangAtMillis).coerceAtLeast(0)
        return (elapsed / intervalMillis(plan)).toInt().coerceAtMost(plan.maxReArms)
    }

    fun isFailSafeDue(rangAtMillis: Long, nowMillis: Long, plan: AlarmPlan): Boolean =
        nowMillis >= failSafeAt(rangAtMillis, plan)

    /** What to do with the alarm's own schedule right after it rang. */
    sealed interface AfterRing {
        data class Next(val atMillis: Long) : AfterRing
        data object Disable : AfterRing
    }

    fun afterRing(plan: AlarmPlan, nowMillis: Long, zone: ZoneId = ZoneId.systemDefault()): AfterRing =
        if (plan.isOnce) AfterRing.Disable
        else plan.nextFireTime(nowMillis, zone)?.let { AfterRing.Next(it) } ?: AfterRing.Disable

    fun dayKey(millis: Long, zone: ZoneId = ZoneId.systemDefault()): String =
        Instant.ofEpochMilli(millis).atZone(zone).toLocalDate().toString()

    fun day(key: String): LocalDate = LocalDate.parse(key)

    private fun intervalMillis(plan: AlarmPlan): Long = plan.reArmMinutes.coerceAtLeast(1) * 60_000L
}
