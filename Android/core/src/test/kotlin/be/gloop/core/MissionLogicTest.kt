package be.gloop.core

import be.gloop.core.missions.MathProblemGenerator
import be.gloop.core.missions.MathSession
import be.gloop.core.missions.MemoryGame
import be.gloop.core.missions.MissionRun
import be.gloop.core.missions.QuizBank
import be.gloop.core.missions.QuizQuestion
import be.gloop.core.missions.QuizSession
import be.gloop.core.missions.ShakeDetector
import be.gloop.core.missions.TongueTwisters
import be.gloop.core.missions.TypingCheck
import be.gloop.core.model.MissionConfig
import be.gloop.core.model.MissionDifficulty
import be.gloop.core.model.MissionKind
import be.gloop.core.model.QuizTopic
import be.gloop.core.random.SplitMix64
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MissionLogicTest {
    @Test fun mathProblemMatchesIOSForTheSameSeed() {
        val p = MathProblemGenerator.make(MissionDifficulty.HARD, SplitMix64(7))
        assertEquals("19 × 6 − 92", p.text)
        assertEquals(19 * 6 - 92, p.answer)
    }

    @Test fun mathNeedsTargetInARowAndAWrongAnswerResets() {
        val s = MathSession(3, MissionDifficulty.EASY, SplitMix64(1))
        assertTrue(s.submit(s.problem.answer)); assertTrue(s.submit(s.problem.answer))
        assertFalse(s.submit(s.problem.answer + 1))
        assertEquals(0, s.correctInRow)
        repeat(3) { s.submit(s.problem.answer) }
        assertTrue(s.isComplete)
    }

    @Test fun mathRangesPerDifficulty() {
        val rng = SplitMix64(99)
        repeat(200) {
            val easy = MathProblemGenerator.make(MissionDifficulty.EASY, rng)
            assertTrue(easy.answer in 4..40)
            val hard = MathProblemGenerator.make(MissionDifficulty.HARD, rng)
            assertTrue(hard.answer in (12 * 6 - 99)..(29 * 19 - 20))
        }
    }

    @Test fun memoryPairsMatchAndMismatchesClose() {
        val game = MemoryGame(6, SplitMix64(3))
        assertEquals(12, game.cards.size)
        val first = game.cards[0]
        val partner = game.cards.indexOfFirst { it.id != first.id && it.face == first.face }
        val other = game.cards.indexOfFirst { it.face != first.face }
        assertEquals(MemoryGame.FlipResult.FIRST, game.flip(0))
        assertEquals(MemoryGame.FlipResult.MISMATCH, game.flip(other))
        assertTrue(game.needsClose)
        assertEquals(MemoryGame.FlipResult.IGNORED, game.flip(partner))
        game.closeMismatch()
        game.flip(0)
        assertEquals(MemoryGame.FlipResult.MATCH, game.flip(partner))
        assertTrue(game.cards[0].isMatched)
        assertEquals(2, game.moves)
    }

    @Test fun memoryCanBeCompleted() {
        val game = MemoryGame(8, SplitMix64(5))
        val byFace = game.cards.groupBy { it.face }.values
        for (pair in byFace) { game.flip(pair[0].id); game.flip(pair[1].id) }
        assertTrue(game.isComplete)
    }

    @Test fun quizAsksEachQuestionOnceAndCountsCorrect() {
        val questions = (1..5).map { QuizQuestion("Q$it", "A$it", listOf("x", "y", "z")) }
        val quiz = QuizSession(questions, 3, SplitMix64(11))
        val seen = mutableListOf<String>()
        quiz.answer(-1) // wrong just moves on
        while (!quiz.isComplete) {
            val round = quiz.round!!
            seen += round.question.question
            assertEquals(4, round.options.size)
            quiz.answer(round.correctIndex)
        }
        assertEquals(3, quiz.correct)
        assertEquals(seen.size, seen.toSet().size)
    }

    @Test fun quizBankMergesTranslations() {
        val en = QuizBank.load(sharedSource, "en")
        assertEquals(QuizTopic.entries.toSet(), en.keys)
        assertTrue(en.values.all { it.size == 20 })
        val nl = QuizBank.load(sharedSource, "nl")
        assertNotEquals(en[QuizTopic.GENERAL]!![0].question, nl[QuizTopic.GENERAL]!![0].question)
        assertEquals(en.keys, QuizBank.load(sharedSource, "pt-BR").keys) // pt-BR → Quiz.pt.json
    }

    @Test fun typingForgivesCaseAndPunctuationButNotLetters() {
        assertTrue(TypingCheck.matches("she sells  sea shells!", "She sells sea-shells"))
        assertTrue(TypingCheck.matches("“Café”", "café"))
        assertFalse(TypingCheck.matches("cafe", "café"))
        assertEquals(5, TypingCheck.correctPrefix("she sx", "She sells"))
    }

    @Test fun tongueTwistersPerLanguage() {
        val en = TongueTwisters.load(sharedSource, "en")
        assertEquals(MissionDifficulty.entries.toSet(), en.keys)
        val nl = TongueTwisters.load(sharedSource, "nl")
        assertNotEquals(en[MissionDifficulty.EASY], nl[MissionDifficulty.EASY])
        assertEquals(en, TongueTwisters.load(sharedSource, "xx")) // unknown → English
    }

    @Test fun shakeNeedsThresholdAndSpacing() {
        val d = ShakeDetector()
        assertFalse(d.process(0.0, 0.0, 1.0, 0.0))  // gravity only
        assertTrue(d.process(2.5, 0.0, 0.0, 0.1))
        assertFalse(d.process(2.5, 0.0, 0.0, 0.2))  // too soon
        assertTrue(d.process(0.0, 2.1, 0.0, 0.4))
        assertEquals(2, d.count)
        assertEquals(listOf(1.7, 2.0, 2.5), MissionDifficulty.entries.map { ShakeDetector.threshold(it) })
    }

    @Test fun missionRunStepsAndBackupOnce() {
        val run = MissionRun(listOf(MissionConfig(kind = MissionKind.OBJECT), MissionConfig(kind = MissionKind.SHAKE)))
        assertEquals(120, run.backupDelaySeconds)
        assertEquals(MissionRun.Outcome.BACKUP_STARTED, run.apply(MissionRun.Result.NEEDS_BACKUP))
        assertEquals(MissionKind.MATH, run.current!!.kind)
        assertEquals(MissionDifficulty.HARD, run.current!!.difficulty)
        assertEquals(null, run.backupDelaySeconds)
        run.swapToBackup() // no second swap
        assertEquals(setOf(0), run.backedUp)
        assertEquals(MissionRun.Outcome.NEXT_STEP, run.apply(MissionRun.Result.SUCCESS))
        assertEquals(MissionRun.Outcome.FINISHED, run.apply(MissionRun.Result.SUCCESS))
        assertTrue(run.isFinished)
    }
}
