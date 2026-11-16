package be.gloop.core

import kotlinx.serialization.json.Json
import org.junit.Assert.assertTrue
import org.junit.Test

/** Every shared JSON file must stay valid, because both apps ship it. */
class SharedConfigTest {
    @Test fun everySharedJsonFileParses() {
        val files = SharedConfig.dir.walkTopDown().filter { it.isFile && it.extension == "json" }.toList()
        assertTrue("expected the shared content, found ${files.size} files", files.size > 30)
        for (file in files) {
            runCatching { Json.parseToJsonElement(file.readText()) }
                .onFailure { throw AssertionError("${file.relativeTo(SharedConfig.dir)} is not valid JSON", it) }
        }
    }

    @Test fun legalDocumentsExist() {
        for (doc in listOf("privacy", "terms", "health-safety", "community")) {
            assertTrue(doc, SharedConfig.text("Legal/$doc.md").isNotBlank())
        }
    }
}
