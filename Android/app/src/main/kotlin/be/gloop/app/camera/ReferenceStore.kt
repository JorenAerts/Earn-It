package be.gloop.app.camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.util.UUID

/**
 * Registered items / beds on the phone (iOS `ObjectReferenceStore`): `files/MissionAssets/<id>/`
 * with `reference.json` (embeddings + threshold) and `thumb.jpg`. `MissionConfig.payload` = id.
 * Only numbers describing the photos are kept, plus a small thumbnail; nothing leaves the phone.
 */
class ReferenceStore(context: Context) {
    @Serializable data class Reference(val embeddings: List<List<Float>>, val threshold: Float)

    private val root = File(context.filesDir, "MissionAssets")

    fun save(embeddings: List<FloatArray>, threshold: Float, thumbnail: Bitmap?): String {
        val id = UUID.randomUUID().toString().uppercase()
        val dir = File(root, id).apply { mkdirs() }
        File(dir, "reference.json").writeText(Json.encodeToString(Reference.serializer(), Reference(embeddings.map { it.toList() }, threshold)))
        thumbnail?.let { bmp -> File(dir, "thumb.jpg").outputStream().use { bmp.forAnalysis(400).compress(Bitmap.CompressFormat.JPEG, 80, it) } }
        return id
    }

    fun load(id: String?): Pair<List<FloatArray>, Float>? {
        val file = id?.let { File(File(root, it), "reference.json") }?.takeIf { it.isFile } ?: return null
        val ref = runCatching { Json.decodeFromString(Reference.serializer(), file.readText()) }.getOrNull() ?: return null
        return ref.embeddings.map { it.toFloatArray() } to ref.threshold
    }

    fun thumbnail(id: String?): Bitmap? = id?.let { File(File(root, it), "thumb.jpg") }?.takeIf { it.isFile }?.let { BitmapFactory.decodeFile(it.path) }

    /** Remove references no alarm uses any more (older than an hour, so a setup in progress survives). */
    fun prune(inUse: Set<String>) {
        val cutoff = System.currentTimeMillis() - 3_600_000
        root.listFiles()?.filter { it.isDirectory && it.name !in inUse && it.lastModified() < cutoff }?.forEach { it.deleteRecursively() }
    }
}
