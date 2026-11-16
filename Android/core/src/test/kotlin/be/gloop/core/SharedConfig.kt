package be.gloop.core

import java.io.File

/** `Shared/Config`, passed in by Gradle (see core/build.gradle.kts). */
object SharedConfig {
    val dir: File = File(requireNotNull(System.getProperty("gloop.sharedConfig")) { "run the tests through Gradle" })

    fun text(path: String): String = File(dir, path).readText()
}
