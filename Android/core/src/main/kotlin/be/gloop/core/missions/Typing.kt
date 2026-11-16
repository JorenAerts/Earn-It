package be.gloop.core.missions

import be.gloop.core.content.ContentSource
import be.gloop.core.content.translated
import be.gloop.core.model.MissionDifficulty
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json

/** Tongue twisters per difficulty; each language has its own file (not translations). */
object TongueTwisters {
    private val table = MapSerializer(String.serializer(), ListSerializer(String.serializer()))

    fun load(source: ContentSource, language: String): Map<MissionDifficulty, List<String>> {
        fun decode(text: String?) = text?.let { runCatching { Json.decodeFromString(table, it) }.getOrNull() }
        val raw = decode(source.translated("TongueTwisters", "json", language))
            ?: decode(source.read("TongueTwisters.json")).orEmpty()
        return raw.mapNotNull { (key, list) ->
            MissionDifficulty.entries.firstOrNull { it.name.equals(key, ignoreCase = true) }?.let { it to list }
        }.toMap()
    }
}

/**
 * Port of iOS `TypingCheck`: forgives case, punctuation, extra spaces and quote styles;
 * letters (accents included) must match.
 */
object TypingCheck {
    fun normalize(text: String): String {
        val kept = buildString {
            var i = 0
            val lower = text.lowercase()
            while (i < lower.length) {
                val cp = lower.codePointAt(i)
                if (Character.isLetter(cp) || Character.isDigit(cp) || Character.getType(cp).let { it == Character.NON_SPACING_MARK.toInt() || it == Character.COMBINING_SPACING_MARK.toInt() || it == Character.ENCLOSING_MARK.toInt() }) appendCodePoint(cp) else append(' ')
                i += Character.charCount(cp)
            }
        }
        return kept.split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
    }

    fun matches(typed: String, target: String): Boolean = normalize(typed) == normalize(target)

    /** How many leading characters of the normalized target are typed correctly. */
    fun correctPrefix(typed: String, target: String): Int =
        normalize(typed).zip(normalize(target)).takeWhile { (a, b) -> a == b }.size
}
