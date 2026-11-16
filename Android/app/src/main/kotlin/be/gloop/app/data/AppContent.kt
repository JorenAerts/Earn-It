package be.gloop.app.data

import android.content.Context
import android.content.res.Configuration
import be.gloop.core.content.ContentSource

/** Shared/Config files packaged as assets (see app/build.gradle.kts), in the app's language. */
class AppContent(private val context: Context) : ContentSource {
    override fun read(path: String): String? =
        runCatching { context.assets.open(path).bufferedReader().use { it.readText() } }.getOrNull()

    /** "nl", "pt-BR", … from the current app/device locale. */
    val language: String
        get() {
            val locale = context.resources.configuration.let { (it as Configuration).locales[0] }
            return if (locale.country.isNullOrEmpty()) locale.language else "${locale.language}-${locale.country}"
        }
}
