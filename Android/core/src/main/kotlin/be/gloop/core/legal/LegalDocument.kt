package be.gloop.core.legal

import be.gloop.core.content.ContentLanguage
import be.gloop.core.content.ContentSource
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/** The in-app legal documents (`Shared/Config/Legal/<file>.md`), port of iOS `LegalDocumentKind`. */
enum class LegalDocumentKind(val file: String) { PRIVACY("privacy"), TERMS("terms"), HEALTH_SAFETY("health-safety"), COMMUNITY("community") }

/** A parsed document (port of iOS `LegalDocument`): title + blocks; inline Markdown kept for the view. */
data class LegalDocument(val title: String, val blocks: List<Block>, val isTranslation: Boolean = false) {
    sealed interface Block {
        data class Heading(val text: String) : Block
        data class Paragraph(val text: String) : Block
        data class Bullets(val items: List<String>) : Block
    }

    companion object {
        /** Shown wherever a `Legal.json` value is still empty. */
        const val MISSING = "[to be completed]"

        /** Replaces `{{key}}` with values; unknown or empty keys become [MISSING]. */
        fun fill(text: String, values: Map<String, String>): String {
            val out = StringBuilder(); var rest = text
            while (true) {
                val open = rest.indexOf("{{"); if (open < 0) break
                out.append(rest, 0, open)
                val close = rest.indexOf("}}", open + 2)
                if (close < 0) { out.append(rest.substring(open)); return out.toString() }
                val key = rest.substring(open + 2, close).trim()
                out.append(values[key]?.trim()?.takeIf { it.isNotEmpty() } ?: MISSING)
                rest = rest.substring(close + 2)
            }
            return out.append(rest).toString()
        }

        /** Minimal Markdown: `# Title`, `## Heading`, `- bullet`, blank-line separated paragraphs. */
        fun parse(markdown: String): LegalDocument {
            var title = ""
            val blocks = mutableListOf<Block>()
            val paragraph = mutableListOf<String>(); val bullets = mutableListOf<String>()
            fun flush() {
                if (paragraph.isNotEmpty()) { blocks += Block.Paragraph(paragraph.joinToString("\n")); paragraph.clear() }
                if (bullets.isNotEmpty()) { blocks += Block.Bullets(bullets.toList()); bullets.clear() }
            }
            for (raw in markdown.lines()) {
                val line = raw.trim()
                when {
                    line.isEmpty() -> flush()
                    line.startsWith("## ") -> { flush(); blocks += Block.Heading(line.drop(3)) }
                    line.startsWith("# ") -> { flush(); title = line.drop(2) }
                    line.startsWith("- ") -> { if (paragraph.isNotEmpty()) flush(); bullets += line.drop(2) }
                    else -> { if (bullets.isNotEmpty()) flush(); paragraph += line }
                }
            }
            flush()
            return LegalDocument(title, blocks)
        }

        /** `Legal.json` string values (keys starting with "_" are comments). */
        fun values(json: String?): Map<String, String> {
            val obj = json?.let { runCatching { Json.parseToJsonElement(it) as? JsonObject }.getOrNull() } ?: return emptyMap()
            return obj.filterKeys { !it.startsWith("_") }.mapNotNull { (k, v) -> (v as? JsonPrimitive)?.takeIf { it.isString }?.let { k to it.content } }.toMap()
        }

        /** `"country.nl"` overrides `"country"` in Dutch documents (most specific code wins). */
        fun localizedValues(values: Map<String, String>, language: String): Map<String, String> {
            val result = values.filterKeys { '.' !in it }.toMutableMap()
            for (code in ContentLanguage.codes(language).reversed()) {
                for ((key, value) in values) if (key.endsWith(".$code") && value.isNotEmpty()) result[key.dropLast(code.length + 1)] = value
            }
            return result
        }

        /** The document in `language` when `Legal/<kind>.<code>.md` exists, else English. */
        fun load(kind: LegalDocumentKind, source: ContentSource, language: String, english: Boolean = false): LegalDocument? {
            var values = values(source.read("Legal.json"))
            val translated = if (english) null else ContentLanguage.codes(language).firstNotNullOfOrNull { source.read("Legal/${kind.file}.$it.md") }
            if (translated != null) values = localizedValues(values, language)
            val text = translated ?: source.read("Legal/${kind.file}.md") ?: return null
            return parse(fill(text, values)).copy(isTranslation = translated != null)
        }
    }
}
