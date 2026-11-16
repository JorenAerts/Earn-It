package be.gloop.core.content

/**
 * Which translated content files to try for a language (port of iOS `L10n.contentCodes`):
 * "pt-BR" → ["pt-BR", "pt"], "nl" → ["nl"], English → none (the base files are English).
 */
object ContentLanguage {
    fun codes(code: String): List<String> {
        if (code == "en" || code.startsWith("en-")) return emptyList()
        val base = code.substringBefore('-')
        return if (base == code) listOf(code) else listOf(code, base)
    }
}

/** Reads a content file by path (assets on Android, `Shared/Config` in tests); null when missing. */
fun interface ContentSource {
    fun read(path: String): String?
}

/** `Translations/<name>.<code>.json` for the first code that has one. */
fun ContentSource.translated(name: String, ext: String, language: String): String? =
    ContentLanguage.codes(language).firstNotNullOfOrNull { read("Translations/$name.$it.$ext") }
