package be.gloop.core.camera

import be.gloop.core.random.SplitMix64
import be.gloop.core.random.shuffledSwift
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** Port of iOS `ConsecutiveHits`: N analysed frames in a row must pass; one miss starts over. */
class ConsecutiveHits(required: Int) {
    val required = required.coerceAtLeast(1)
    var streak = 0; private set
    val isComplete: Boolean get() = streak >= required
    val progress: Double get() = min(1.0, streak / required.toDouble())
    fun record(hit: Boolean) { streak = if (hit) streak + 1 else 0 }
    fun reset() { streak = 0 }
}

/** Port of iOS `CodeMatcher`: what counts as "the registered code". */
object CodeMatcher {
    const val GENERATED_PREFIX = "gloop:"
    fun newPayload(): String = GENERATED_PREFIX + UUID.randomUUID().toString().uppercase()
    fun matches(scanned: String?, expected: String?): Boolean {
        val s = scanned?.trim()?.takeIf { it.isNotEmpty() } ?: return false
        val e = expected?.trim()?.takeIf { it.isNotEmpty() } ?: return false
        return s == e
    }
}

/** Port of iOS `SkyPolicy` (labels from ML Kit's image labeler instead of Vision's classifier). */
object SkyPolicy {
    val skyWords = setOf("sky", "cloud", "clouds", "cloudy", "overcast", "sunset", "sunrise", "dusk", "dawn",
        "rain", "rainbow", "storm", "thunderstorm", "lightning", "moon", "starry", "fog")
    /** ML Kit confidences run higher than Vision's; tuned on device (iOS: 0.25). */
    const val THRESHOLD = 0.5f
    const val REQUIRED_FRAMES = 4

    fun isSkyLabel(label: String): Boolean = label.lowercase().split('_', ' ', '-').any { it in skyWords }
    fun score(labels: List<Pair<String, Float>>): Float = labels.filter { isSkyLabel(it.first) }.maxOfOrNull { it.second } ?: 0f
    fun isSky(score: Float) = score >= THRESHOLD
}

/** Port of iOS `ColorTarget`: a hue window plus minimum saturation/brightness (grey/black/white never count). */
enum class ColorTarget(val hueCenter: Double, val hueTolerance: Double) {
    RED(0.0, 14.0), ORANGE(28.0, 12.0), YELLOW(54.0, 12.0), GREEN(120.0, 40.0),
    BLUE(215.0, 30.0), PURPLE(275.0, 22.0), PINK(325.0, 18.0);

    val minimumSaturation: Double get() = if (this == PINK) 0.25 else 0.4
    val minimumBrightness: Double get() = if (this == YELLOW) 0.45 else 0.25
}

/** Port of iOS `ColorMatch`. */
object ColorMatch {
    const val REQUIRED_FRAMES = 4

    fun hueDistance(a: Double, b: Double): Double { val d = abs(a - b) % 360; return min(d, 360 - d) }

    fun matches(hue: Double, saturation: Double, brightness: Double, target: ColorTarget): Boolean =
        saturation >= target.minimumSaturation && brightness >= target.minimumBrightness &&
            hueDistance(hue, target.hueCenter) <= target.hueTolerance

    /** `count` different colours in random order. */
    fun targets(count: Int, rng: SplitMix64): List<ColorTarget> =
        ColorTarget.entries.toList().shuffledSwift(rng).take(count.coerceIn(1, ColorTarget.entries.size))

    /** RGB 0…1 → hue degrees, saturation, brightness (HSB, like UIColor). */
    fun hsb(r: Double, g: Double, b: Double): Triple<Double, Double, Double> {
        val mx = max(r, max(g, b)); val mn = min(r, min(g, b)); val delta = mx - mn
        val hue = when {
            delta == 0.0 -> 0.0
            mx == r -> 60 * (((g - b) / delta) % 6)
            mx == g -> 60 * (((b - r) / delta) + 2)
            else -> 60 * (((r - g) / delta) + 4)
        }.let { if (it < 0) it + 360 else it }
        return Triple(hue, if (mx == 0.0) 0.0 else delta / mx, mx)
    }
}

/**
 * Item / bed matching on image embeddings (MediaPipe embedder on Android, Vision feature prints on
 * iOS). Same rules as iOS `ObjectMatchPolicy` / `BedMatchPolicy`: a per-reference threshold from the
 * spread of its own setup shots, clamped to bounds; N matching frames in a row. Distances here are
 * cosine distances (0 identical … 1 unrelated), so the bounds are Android's own (tuned on device).
 */
data class MatchRules(
    val requiredShots: Int,
    val requiredFrames: Int,
    val minimumThreshold: Float,
    val maximumThreshold: Float,
    val thresholdMargin: Float,
    /** Each setup shot must differ this much from the previous one (user moved). */
    val minimumShotChange: Float,
) {
    fun threshold(pairwiseDistances: List<Float>): Float {
        val widest = pairwiseDistances.maxOrNull() ?: return minimumThreshold
        return min(maximumThreshold, max(minimumThreshold, widest * thresholdMargin))
    }

    fun isMatch(distance: Float, threshold: Float) = distance <= threshold
    fun isDistinctShot(distanceToPrevious: Float) = distanceToPrevious >= minimumShotChange

    /** 0…1 "how close" (iOS `closeness`): 1 at or under the threshold, 0 at twice the threshold. */
    fun closeness(distance: Float, threshold: Float): Double {
        if (distance <= threshold) return 1.0
        val far = threshold * 2
        return ((far - distance) / (far - threshold)).toDouble().coerceIn(0.0, 1.0)
    }

    companion object {
        val ITEM = MatchRules(requiredShots = 5, requiredFrames = 4, minimumThreshold = 0.18f, maximumThreshold = 0.40f,
            thresholdMargin = 1.15f, minimumShotChange = 0.02f)
        val BED = MatchRules(requiredShots = 3, requiredFrames = 4, minimumThreshold = 0.10f, maximumThreshold = 0.25f,
            thresholdMargin = 1.2f, minimumShotChange = 0.015f)
    }
}

object Embeddings {
    fun cosineDistance(a: FloatArray, b: FloatArray): Float {
        var dot = 0.0; var na = 0.0; var nb = 0.0
        for (i in a.indices) { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
        if (na == 0.0 || nb == 0.0) return 1f
        return (1 - dot / (sqrt(na) * sqrt(nb))).toFloat().coerceIn(0f, 2f)
    }

    fun nearest(frame: FloatArray, references: List<FloatArray>): Float? = references.minOfOrNull { cosineDistance(frame, it) }

    fun pairwise(references: List<FloatArray>): List<Float> =
        references.indices.flatMap { i -> (i + 1 until references.size).map { j -> cosineDistance(references[i], references[j]) } }
}

/**
 * Port of iOS `AutoTorch`: turn the flashlight on after a few dark readings in a row, then keep it
 * on (once lit the scene looks bright; switching off again would flicker). Android decides "dark"
 * from the camera's exposure (`CameraDarkness`) instead of EXIF brightness.
 */
class AutoTorch {
    var darkStreak = 0; private set
    var latched = false; private set

    fun record(isDark: Boolean): Boolean {
        if (latched) return true
        darkStreak = if (isDark) darkStreak + 1 else 0
        if (darkStreak >= REQUIRED_DARK_READINGS) latched = true
        return latched
    }

    companion object { const val REQUIRED_DARK_READINGS = 3 }
}

/** Dark = the sensor is pushing hard (high ISO × long exposure) or the picture is still dim. */
object CameraDarkness {
    /** ISO × exposure seconds above this ≈ a dim bedroom (a lit room is ~10–40). */
    const val DARK_EXPOSURE = 120.0
    /** Mean luma 0…1 below this counts as dark when exposure data is missing. */
    const val DARK_LUMA = 0.12

    fun isDark(iso: Int?, exposureSeconds: Double?, meanLuma: Double): Boolean =
        if (iso != null && exposureSeconds != null) iso * exposureSeconds >= DARK_EXPOSURE || meanLuma < DARK_LUMA / 2
        else meanLuma < DARK_LUMA
}

/** Flashlight mode, cycled Auto → On → Off like the iOS Camera app (`gloop.camera.torch`, default Auto). */
enum class TorchMode { AUTO, ON, OFF;
    val next: TorchMode get() = when (this) { AUTO -> ON; ON -> OFF; OFF -> AUTO }
}
