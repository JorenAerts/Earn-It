package be.gloop.core.progress

import java.time.LocalDate

/** Port of iOS `StreakCalculator`. */
object StreakCalculator {
    /** Longest run of consecutive completed days ever. */
    fun bestStreak(completedDays: Collection<LocalDate>): Int {
        var best = 0; var run = 0; var previous: LocalDate? = null
        for (day in completedDays.toSortedSet()) {
            run = if (previous != null && previous.plusDays(1) == day) run + 1 else 1
            best = maxOf(best, run)
            previous = day
        }
        return best
    }

    /** Consecutive completed days ending today (or yesterday, if today isn't done yet). */
    fun currentStreak(completedDays: Collection<LocalDate>, today: LocalDate): Int {
        val days = completedDays.toSet()
        var cursor = if (today in days) today else today.minusDays(1)
        var streak = 0
        while (cursor in days) { streak += 1; cursor = cursor.minusDays(1) }
        return streak
    }
}
