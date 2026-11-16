package be.gloop.core.missions

import be.gloop.core.model.MissionDifficulty
import be.gloop.core.random.SplitMix64

data class MathProblem(val text: String, val answer: Int)

/** Port of iOS `MathProblemGenerator`: same ranges, same order of draws. */
object MathProblemGenerator {
    fun make(difficulty: MissionDifficulty, rng: SplitMix64): MathProblem = when (difficulty) {
        MissionDifficulty.EASY -> {
            val a = rng.nextInt(2..20); val b = rng.nextInt(2..20)
            MathProblem("$a + $b", a + b)
        }
        MissionDifficulty.MEDIUM -> {
            val a = rng.nextInt(3..12); val b = rng.nextInt(3..12); val c = rng.nextInt(5..40)
            MathProblem("$a × $b + $c", a * b + c)
        }
        MissionDifficulty.HARD -> {
            val a = rng.nextInt(12..29); val b = rng.nextInt(6..19); val c = rng.nextInt(20..99)
            MathProblem("$a × $b − $c", a * b - c)
        }
    }
}

/** N correct in a row. A wrong answer resets the run and gives a new problem. */
class MathSession(target: Int, val difficulty: MissionDifficulty, private val rng: SplitMix64) {
    val target = target.coerceAtLeast(1)
    var correctInRow = 0; private set
    var problem: MathProblem = MathProblemGenerator.make(difficulty, rng); private set

    val isComplete: Boolean get() = correctInRow >= target

    /** Returns whether the answer was correct. */
    fun submit(answer: Int): Boolean {
        if (isComplete) return true
        val correct = answer == problem.answer
        correctInRow = if (correct) correctInRow + 1 else 0
        if (!isComplete) problem = MathProblemGenerator.make(difficulty, rng)
        return correct
    }
}
