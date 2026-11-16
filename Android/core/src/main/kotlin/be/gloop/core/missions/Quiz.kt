package be.gloop.core.missions

import be.gloop.core.content.ContentSource
import be.gloop.core.content.translated
import be.gloop.core.model.QuizTopic
import be.gloop.core.random.SplitMix64
import be.gloop.core.random.shuffledSwift
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json

@Serializable
data class QuizQuestion(val question: String, val answer: String, val wrong: List<String>)

/** `Quiz.json` + `Translations/Quiz.<code>.json` (a topic missing there stays English). */
object QuizBank {
    private val json = Json { ignoreUnknownKeys = true }
    private val table = MapSerializer(String.serializer(), ListSerializer(QuizQuestion.serializer()))

    fun load(source: ContentSource, language: String): Map<QuizTopic, List<QuizQuestion>> {
        fun decode(text: String?) = text?.let { runCatching { json.decodeFromString(table, it) }.getOrNull() }.orEmpty()
        val merged = decode(source.read("Quiz.json")).toMutableMap()
        decode(source.translated("Quiz", "json", language)).forEach { (topic, questions) ->
            if (questions.isNotEmpty()) merged[topic] = questions
        }
        return merged.mapNotNull { (key, questions) -> QuizTopic.fromRaw(key)?.let { it to questions } }.toMap()
    }
}

/**
 * Port of iOS `QuizSession`: questions in random order (each once until all were asked),
 * shuffled options, done after `target` correct answers. A wrong answer just moves on.
 */
class QuizSession(private val all: List<QuizQuestion>, target: Int, private val rng: SplitMix64) {
    data class Round(val question: QuizQuestion, val options: List<String>) {
        val correctIndex: Int get() = options.indexOf(question.answer).coerceAtLeast(0)
    }

    val target = target.coerceIn(1, all.size.coerceAtLeast(1))
    var correct = 0; private set
    var round: Round? = null; private set
    private var deck = mutableListOf<QuizQuestion>()

    init { next() }

    val isComplete: Boolean get() = correct >= target

    /** Returns whether the picked option was right, and advances. */
    fun answer(index: Int): Boolean {
        val current = round ?: return false
        val right = index == current.correctIndex
        if (right) correct += 1
        if (!isComplete) next()
        return right
    }

    private fun next() {
        if (all.isEmpty()) { round = null; return }
        if (deck.isEmpty()) {
            deck = all.shuffledSwift(rng).toMutableList()
            val current = round?.question
            if (deck.size > 1 && current != null && deck.last() == current) {
                val tmp = deck[0]; deck[0] = deck[deck.size - 1]; deck[deck.size - 1] = tmp
            }
        }
        val question = deck.removeAt(deck.size - 1)
        val options = (listOf(question.answer) + question.wrong.take(3)).shuffledSwift(rng)
        round = Round(question, options)
    }
}
