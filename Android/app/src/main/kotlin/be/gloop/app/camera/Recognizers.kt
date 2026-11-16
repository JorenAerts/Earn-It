package be.gloop.app.camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.util.Log
import be.gloop.core.camera.ColorMatch
import com.google.android.gms.tasks.Tasks
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.imageembedder.ImageEmbedder
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.google.mlkit.vision.objects.ObjectDetection
import com.google.mlkit.vision.objects.defaults.ObjectDetectorOptions

/**
 * On-device recognition for the camera missions (Android's counterparts of Apple Vision). Called on
 * the camera's analysis thread, so the ML Kit tasks are awaited synchronously.
 */
object Recognizers {
    private val barcodeClient by lazy { BarcodeScanning.getClient() }
    private val labeler by lazy { ImageLabeling.getClient(ImageLabelerOptions.Builder().setConfidenceThreshold(0.2f).build()) }
    @Volatile private var embedder: ImageEmbedder? = null

    /** Every readable code in the frame (QR and the common barcodes). */
    fun codes(bitmap: Bitmap): List<String> = runCatching {
        Tasks.await(barcodeClient.process(InputImage.fromBitmap(bitmap, 0))).mapNotNull { it.rawValue }
    }.getOrDefault(emptyList())

    /** Image labels with confidences ("Sky" 0.84, "Cloud" 0.6, …). */
    fun labels(bitmap: Bitmap): List<Pair<String, Float>> = runCatching {
        Tasks.await(labeler.process(InputImage.fromBitmap(bitmap, 0))).map { it.text to it.confidence }
    }.getOrDefault(emptyList())

    /** L2-normalised embedding of the whole frame (compare with `Embeddings.cosineDistance`). */
    fun embed(context: Context, bitmap: Bitmap): FloatArray? = runCatching {
        val e = embedder ?: synchronized(this) {
            embedder ?: ImageEmbedder.createFromOptions(context, ImageEmbedder.ImageEmbedderOptions.builder()
                .setBaseOptions(BaseOptions.builder().setModelAssetPath("models/mobilenet_v3_large.tflite").build())
                .setRunningMode(RunningMode.IMAGE)
                .setL2Normalize(true)
                .build()).also { embedder = it }
        }
        e.embed(BitmapImageBuilder(bitmap).build()).embeddingResult().embeddings().first().floatEmbedding()
    }.onFailure { Log.w("GloopCamera", "embed failed", it) }.getOrNull()

    /**
     * The item cut out of the frame (iOS: foreground instance mask + crop): the most prominent
     * object's box plus a small margin. null = nothing usable in view (too small / no object).
     */
    fun itemCrop(bitmap: Bitmap): Bitmap? = runCatching {
        val objects = Tasks.await(objectDetector.process(InputImage.fromBitmap(bitmap, 0)))
        val box = objects.maxByOrNull { it.boundingBox.width() * it.boundingBox.height() }?.boundingBox ?: return null
        val coverage = box.width().toDouble() * box.height() / (bitmap.width.toDouble() * bitmap.height)
        if (coverage < MINIMUM_COVERAGE) return null
        val mx = (box.width() * 0.1).toInt(); val my = (box.height() * 0.1).toInt()
        val left = (box.left - mx).coerceAtLeast(0); val top = (box.top - my).coerceAtLeast(0)
        val right = (box.right + mx).coerceAtMost(bitmap.width); val bottom = (box.bottom + my).coerceAtMost(bitmap.height)
        if (right - left < 16 || bottom - top < 16) return null
        Bitmap.createBitmap(bitmap, left, top, right - left, bottom - top)
    }.getOrNull()

    /** Ignore "objects" smaller than this share of the frame (too far / noise), as on iOS. */
    private const val MINIMUM_COVERAGE = 0.02

    private val objectDetector by lazy {
        ObjectDetection.getClient(ObjectDetectorOptions.Builder().setDetectorMode(ObjectDetectorOptions.SINGLE_IMAGE_MODE).build())
    }

    /** Hue/saturation/brightness of the average colour in the middle 20 % of the frame. */
    fun centerColor(bitmap: Bitmap): Triple<Double, Double, Double> {
        val w = bitmap.width; val h = bitmap.height
        val x0 = (w * 0.4).toInt(); val y0 = (h * 0.4).toInt(); val cw = (w * 0.2).toInt().coerceAtLeast(1); val ch = (h * 0.2).toInt().coerceAtLeast(1)
        val pixels = IntArray(cw * ch)
        bitmap.getPixels(pixels, 0, cw, x0, y0, cw, ch)
        var r = 0L; var g = 0L; var b = 0L
        for (p in pixels) { r += Color.red(p); g += Color.green(p); b += Color.blue(p) }
        val n = pixels.size * 255.0
        return ColorMatch.hsb(r / n, g / n, b / n)
    }

    /** Mean luma 0…1 (sampled), for the auto flashlight. */
    fun meanLuma(bitmap: Bitmap): Double {
        val step = 16; var sum = 0.0; var count = 0
        var y = 0
        while (y < bitmap.height) {
            var x = 0
            while (x < bitmap.width) {
                val p = bitmap.getPixel(x, y)
                sum += (0.299 * Color.red(p) + 0.587 * Color.green(p) + 0.114 * Color.blue(p)) / 255.0
                count++; x += step
            }
            y += step
        }
        return if (count == 0) 0.0 else sum / count
    }
}
