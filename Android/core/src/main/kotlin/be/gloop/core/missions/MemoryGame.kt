package be.gloop.core.missions

import be.gloop.core.random.SplitMix64
import be.gloop.core.random.shuffledSwift

/** Port of iOS `MemoryGame`: a pair stays open, otherwise both close again (`closeMismatch`). */
class MemoryGame(pairs: Int, rng: SplitMix64) {
    data class Card(val id: Int, val face: String, val isUp: Boolean = false, val isMatched: Boolean = false)

    enum class FlipResult { IGNORED, FIRST, MATCH, MISMATCH }

    var cards: List<Card>; private set
    var moves = 0; private set
    private val open = mutableListOf<Int>()

    init {
        val faces = FACES.shuffledSwift(rng).take(pairs.coerceIn(2, FACES.size))
        cards = (faces + faces).shuffledSwift(rng).mapIndexed { i, face -> Card(i, face) }
    }

    val isComplete: Boolean get() = cards.all { it.isMatched }
    /** Two non-matching cards are face up and must be closed before the next flip. */
    val needsClose: Boolean get() = open.size == 2

    fun flip(index: Int): FlipResult {
        val card = cards.getOrNull(index) ?: return FlipResult.IGNORED
        if (needsClose || card.isUp || card.isMatched) return FlipResult.IGNORED
        update(index) { it.copy(isUp = true) }
        open += index
        if (open.size < 2) return FlipResult.FIRST
        moves += 1
        val (a, b) = open[0] to open[1]
        if (cards[a].face == cards[b].face) {
            update(a) { it.copy(isMatched = true) }
            update(b) { it.copy(isMatched = true) }
            open.clear()
            return FlipResult.MATCH
        }
        return FlipResult.MISMATCH
    }

    fun closeMismatch() {
        open.forEach { i -> update(i) { it.copy(isUp = false) } }
        open.clear()
    }

    private fun update(index: Int, change: (Card) -> Card) {
        cards = cards.toMutableList().also { it[index] = change(it[index]) }
    }

    companion object {
        val FACES = listOf("☀️", "🌙", "⭐️", "☕️", "🍓", "🍋", "🐸", "🐙", "🦊", "🐝", "🌵", "🍩")
    }
}
