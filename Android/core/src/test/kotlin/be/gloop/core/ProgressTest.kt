package be.gloop.core

import be.gloop.core.coach.MorningTips
import be.gloop.core.progress.StreakCalculator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class ProgressTest {
    private fun d(day: Int) = LocalDate.of(2026, 11, day)

    @Test fun streaks() {
        val days = listOf(d(10), d(11), d(12), d(14), d(15))
        assertEquals(3, StreakCalculator.bestStreak(days))
        assertEquals(2, StreakCalculator.currentStreak(days, d(15)))
        assertEquals(2, StreakCalculator.currentStreak(days, d(16)))  // today not done yet
        assertEquals(0, StreakCalculator.currentStreak(days, d(17)))
        assertEquals(0, StreakCalculator.bestStreak(emptyList()))
    }

    @Test fun tipIsStableForADayAndCyclesWithoutRepeats() {
        val tips = MorningTips.load(sharedSource, "en")
        assertEquals(54, tips.size)
        assertEquals(MorningTips.pick(tips, d(16)), MorningTips.pick(tips, d(16)))
        assertNotEquals(MorningTips.pick(tips, d(16)), MorningTips.pick(tips, d(17)))
        val cycle = (0 until 54).map { MorningTips.pick(tips, d(1).plusDays(it.toLong()))!!.id }
        assertEquals(54, cycle.toSet().size)
    }

    @Test fun tipsAreTranslated() {
        val en = MorningTips.load(sharedSource, "en")
        val nl = MorningTips.load(sharedSource, "nl")
        assertEquals(en.map { it.id }, nl.map { it.id })
        assertTrue(en.zip(nl).count { (a, b) -> a.text != b.text } > 40)
    }
}
