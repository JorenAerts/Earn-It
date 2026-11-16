package be.gloop.core

import be.gloop.core.alarm.RingPolicy
import be.gloop.core.model.AlarmPlan
import be.gloop.core.model.SessionState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime

class RingPolicyTest {
    private val zone = ZoneId.of("Europe/Brussels")
    private fun ms(d: Int, h: Int, m: Int = 0) = ZonedDateTime.of(2026, 11, d, h, m, 0, 0, zone).toInstant().toEpochMilli()
    private val plan = AlarmPlan(reArmMinutes = 2, maxReArms = 15)

    @Test fun sameDaySessionContinues() {
        val s = SessionState(day = "2026-11-16", firstEndedAt = ms(16, 7))
        assertSame(s, RingPolicy.currentSession(s, ms(16, 7, 5), zone = zone))
    }

    @Test fun newDayOrRingAfterFinishedCycleStartsFresh() {
        val done = SessionState(day = "2026-11-16", firstEndedAt = ms(16, 7), missionCompletedAt = ms(16, 7, 3))
        assertEquals(SessionState(day = "2026-11-17"), RingPolicy.currentSession(done, ms(17, 7), zone = zone))
        assertEquals(SessionState(day = "2026-11-16"), RingPolicy.currentSession(done, ms(16, 9), newRing = true, zone = zone))
        // Not a new ring: the finished cycle stays (so the app doesn't reopen the mission).
        assertSame(done, RingPolicy.currentSession(done, ms(16, 9), zone = zone))
    }

    @Test fun failSafeAfterMaxReArmsTimesInterval() {
        assertEquals(ms(16, 7, 30), RingPolicy.failSafeAt(ms(16, 7), plan))
        assertFalse(RingPolicy.isFailSafeDue(ms(16, 7), ms(16, 7, 29), plan))
        assertTrue(RingPolicy.isFailSafeDue(ms(16, 7), ms(16, 7, 30), plan))
    }

    @Test fun reRingsCountWholeIntervalsCapped() {
        assertEquals(0, RingPolicy.reRings(ms(16, 7), ms(16, 7, 1), plan))
        assertEquals(2, RingPolicy.reRings(ms(16, 7), ms(16, 7, 5), plan))
        assertEquals(15, RingPolicy.reRings(ms(16, 7), ms(16, 9), plan))
    }

    @Test fun afterRingRepeatsOrDisables() {
        val weekly = AlarmPlan(hour = 7, minute = 0, weekdays = setOf(2, 3))
        assertEquals(RingPolicy.AfterRing.Next(ms(17, 7)), RingPolicy.afterRing(weekly, ms(16, 7), zone))
        assertEquals(RingPolicy.AfterRing.Disable, RingPolicy.afterRing(weekly.copy(weekdays = emptySet()), ms(16, 7), zone))
    }
}
