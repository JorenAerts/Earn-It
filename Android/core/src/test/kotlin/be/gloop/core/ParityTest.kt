package be.gloop.core

import be.gloop.core.coach.MorningTips
import be.gloop.core.random.SplitMix64
import org.junit.Assert.assertEquals
import org.junit.Test

/** Expected values printed by the same algorithms in Swift (iOS), so both apps behave the same. */
class ParityTest {
    @Test fun rawSequenceMatchesSwift() {
        val r = SplitMix64(1)
        assertEquals(listOf(-7995527694508729151L, -4689498862643123097L, -534904783426661026L), List(3) { r.next() })
    }

    @Test fun boundedIntsMatchSwift() {
        val r = SplitMix64(42)
        assertEquals(listOf(16, 5, 7, 8, 2, 18, 6, 17), List(8) { r.nextInt(2..20) })
    }

    @Test fun hardMathDrawsMatchSwift() {
        val r = SplitMix64(7)
        assertEquals(listOf(19, 6, 92), listOf(r.nextInt(12..29), r.nextInt(6..19), r.nextInt(20..99)))
    }

    @Test fun tipOrderMatchesSwift() {
        assertEquals(
            listOf(13, 45, 36, 3, 26, 8, 51, 50, 46, 27, 14, 19, 7, 9, 11, 29, 20, 31, 25, 37, 48, 53, 28, 42, 41, 52, 10,
                24, 21, 22, 16, 1, 44, 30, 23, 0, 17, 2, 32, 38, 39, 15, 18, 6, 35, 34, 4, 49, 47, 43, 40, 5, 12, 33),
            MorningTips.shuffledOrder(54),
        )
    }
}
