package be.gloop.core.coach

import be.gloop.core.content.ContentSource
import be.gloop.core.content.translated
import be.gloop.core.random.SplitMix64
import be.gloop.core.random.shuffledSwift
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.temporal.ChronoUnit

@Serializable
data class MorningTip(val id: String, val kind: Kind, val text: String, val author: String? = null) {
    @Serializable
    enum class Kind { @SerialName("tip") TIP, @SerialName("quote") QUOTE }
}

/** Port of iOS `MorningTips`: same list, same seeded order, so both apps show the same tip each day. */
object MorningTips {
    @Serializable private data class Translation(val text: String, val author: String? = null)

    private val json = Json { ignoreUnknownKeys = true }
    private const val SEED = 0x6C009A11L
    private val EPOCH: LocalDate = LocalDate.of(2026, 1, 1)

    fun load(source: ContentSource, language: String): List<MorningTip> {
        val tips = source.read("MorningTips.json")
            ?.let { runCatching { json.decodeFromString(ListSerializer(MorningTip.serializer()), it) }.getOrNull() }
            ?: return emptyList()
        val local = source.translated("MorningTips", "json", language)?.let {
            runCatching { json.decodeFromString(MapSerializer(String.serializer(), Translation.serializer()), it) }.getOrNull()
        } ?: return tips
        return tips.map { tip ->
            val t = local[tip.id]
            if (t == null || t.text.isEmpty()) tip else tip.copy(text = t.text, author = t.author ?: tip.author)
        }
    }

    /** Same tip all day, a different one tomorrow, no repeats until the whole list was shown. */
    fun pick(tips: List<MorningTip>, day: LocalDate): MorningTip? {
        if (tips.isEmpty()) return null
        val order = shuffledOrder(tips.size)
        val n = (ChronoUnit.DAYS.between(EPOCH, day) % tips.size).toInt()
        return tips[order[if (n < 0) n + tips.size else n]]
    }

    fun shuffledOrder(count: Int): List<Int> = (0 until count).toList().shuffledSwift(SplitMix64(SEED))
}
