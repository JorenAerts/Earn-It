package be.gloop.core

import be.gloop.core.model.AlarmPlan
import be.gloop.core.model.AlarmSound
import be.gloop.core.model.MissionConfig
import be.gloop.core.model.MissionKind
import be.gloop.core.model.QuizTopic
import be.gloop.core.model.calendarWeekday
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

class ModelTest {
    private val brussels = ZoneId.of("Europe/Brussels")
    private fun at(y: Int, m: Int, d: Int, h: Int, min: Int) = ZonedDateTime.of(y, m, d, h, min, 0, 0, brussels)

    @Test fun weekdayNumbersFollowIOS() {
        assertEquals(1, LocalDate.of(2026, 11, 15).calendarWeekday()) // Sunday
        assertEquals(2, LocalDate.of(2026, 11, 16).calendarWeekday()) // Monday
        assertEquals(7, LocalDate.of(2026, 11, 21).calendarWeekday()) // Saturday
    }

    @Test fun nextFireTimeLaterTodayOrNextAllowedDay() {
        val plan = AlarmPlan(hour = 7, minute = 30, weekdays = setOf(2, 3, 4, 5, 6)) // weekdays
        assertEquals(at(2026, 11, 17, 7, 30), plan.nextFireTime(at(2026, 11, 16, 8, 0)))   // Mon after → Tue
        assertEquals(at(2026, 11, 16, 7, 30), plan.nextFireTime(at(2026, 11, 16, 6, 0)))   // Mon before
        assertEquals(at(2026, 11, 23, 7, 30), plan.nextFireTime(at(2026, 11, 20, 9, 0)))   // Fri after → Mon
        assertEquals(at(2026, 11, 17, 7, 30), plan.nextFireTime(at(2026, 11, 16, 7, 30))) // strictly after
    }

    @Test fun onceRingsAtTheNextOccurrence() {
        val plan = AlarmPlan(hour = 6, minute = 0, weekdays = emptySet())
        assertTrue(plan.isOnce)
        assertEquals(at(2026, 11, 17, 6, 0), plan.nextFireTime(at(2026, 11, 16, 22, 0)))
    }

    @Test fun nextFireTimeAcrossDaylightSaving() {
        // 2027-03-28: Brussels jumps 02:00 → 03:00. A 07:00 alarm stays at 07:00 local.
        val plan = AlarmPlan(hour = 7, minute = 0)
        assertEquals(at(2027, 3, 28, 7, 0), plan.nextFireTime(at(2027, 3, 27, 23, 0)))
    }

    @Test fun planListRoundTripsWithIOSKeys() {
        val plan = AlarmPlan(label = "Gym", sound = be.gloop.core.model.SoundChoice.of(AlarmSound.GENTLE_RISE),
            missions = listOf(MissionConfig(kind = MissionKind.QUIZ).withQuizTopic(QuizTopic.MOVIES_MUSIC)))
        val text = AlarmPlan.encodeList(listOf(plan))
        assertTrue(text.contains("\"reArmMinutes\":2") && text.contains("\"kind\":\"quiz\"") && text.contains("\"sound\":\"gentleRise\""))
        val back = AlarmPlan.decodeList(text).single()
        assertEquals(plan, back)
        assertEquals(QuizTopic.MOVIES_MUSIC, back.missions.single().quizTopic)
    }

    @Test fun unknownMissionsAreDroppedButNeverLeaveZero() {
        val text = """[{"id":"A","hour":7,"minute":0,"weekdays":[2],"missions":[{"id":"x","kind":"steps"}],
            "reArmMinutes":2,"maxReArms":15,"isEnabled":true}, {"broken":true}]"""
        val plans = AlarmPlan.decodeList(text)
        assertEquals(1, plans.size)
        assertEquals(MissionKind.MATH, plans.single().missions.single().kind)
        assertEquals(AlarmSound.CLASSIC, plans.single().sound.builtIn) // missing sound → Classic
        assertTrue(AlarmPlan.decodeList("not json").isEmpty())
    }

    @Test fun readinessAndDefaults() {
        assertFalse(MissionConfig(kind = MissionKind.QR).isReady)
        assertTrue(MissionConfig(kind = MissionKind.QR, payload = "abc").isReady)
        assertEquals(3, MissionConfig(kind = MissionKind.MATH).target)
        assertEquals(8, MissionConfig(kind = MissionKind.MEMORY).memoryPairs)
        assertEquals("gloop_gentle_rise", AlarmSound.GENTLE_RISE.resourceName)
        assertEquals("gloop_rise_and_conquer", AlarmSound.RISE_AND_CONQUER.resourceName)
        assertEquals("colorHunt", MissionKind.COLOR_HUNT.rawValue)
        assertNull(MissionKind.fromRaw("steps"))
    }
}
