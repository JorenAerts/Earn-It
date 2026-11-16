package be.gloop.app

import android.content.Context
import be.gloop.core.pricing.PricingCatalog

/** Reads the files from `Shared/Config`, packaged as assets (see app/build.gradle.kts). */
object SharedContent {
    fun text(context: Context, path: String): String =
        context.assets.open(path).bufferedReader().use { it.readText() }

    fun pricing(context: Context): PricingCatalog = PricingCatalog.decode(text(context, "Pricing.json"))
}
