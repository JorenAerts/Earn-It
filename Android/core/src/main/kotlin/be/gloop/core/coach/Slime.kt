package be.gloop.core.coach

/** Port of the pure part of iOS `SlimeDrawing` / `SlimeLook`: what Gloop looks like. */
enum class SlimeEyes { SPARKLY, OPEN, SLEEPY, SQUINT, TEARY }
enum class SlimeMouth { GRIN, SMILE, FLAT, FROWN, OPEN }

/** Body colours (top light, bottom deep; RGB 0…1). Each matches an app icon. */
enum class SlimeColor(val top: DoubleArray, val bottom: DoubleArray) {
    ORANGE(doubleArrayOf(1.00, 0.72, 0.30), doubleArrayOf(0.96, 0.42, 0.10)),
    MINT(doubleArrayOf(0.55, 0.95, 0.78), doubleArrayOf(0.12, 0.70, 0.55)),
    GRAPE(doubleArrayOf(0.80, 0.62, 1.00), doubleArrayOf(0.50, 0.28, 0.86)),
    MIDNIGHT(doubleArrayOf(0.45, 0.62, 1.00), doubleArrayOf(0.18, 0.26, 0.72)),
    GOLD(doubleArrayOf(1.00, 0.90, 0.45), doubleArrayOf(0.88, 0.62, 0.10)),
}

data class SlimePose(
    val droop: Double,
    val eyes: SlimeEyes = SlimeEyes.OPEN,
    val mouth: SlimeMouth = SlimeMouth.SMILE,
    val drips: Int = 0,
    val blush: Boolean = false,
    val sparkle: Boolean = false,
    val steam: Boolean = false,
    val sweat: Boolean = false,
    val saturation: Double = 1.0,
    val redness: Double = 0.0,
)

/** Pose + breathing (`bounce` 0…1) + trembling (anger 0…1). */
data class SlimeLook(val pose: SlimePose, val bounce: Double, val tremble: Double) {
    companion object {
        /** iOS `SlimeLook.make`: droop from vitality, expression from the mood. */
        fun make(vitality: Double, mood: CoachMood, anger: Double = 0.0): SlimeLook {
            val v = vitality.coerceIn(0.0, 1.0)
            var droop = 1 - v
            var pose = SlimePose(
                droop = droop,
                eyes = when { v >= 0.8 -> SlimeEyes.SPARKLY; v >= 0.5 -> SlimeEyes.OPEN; v >= 0.25 -> SlimeEyes.SLEEPY; else -> SlimeEyes.TEARY },
                mouth = when { v >= 0.8 -> SlimeMouth.GRIN; v >= 0.5 -> SlimeMouth.SMILE; v >= 0.25 -> SlimeMouth.FLAT; else -> SlimeMouth.FROWN },
                blush = v >= 0.7, sparkle = v >= 0.8, saturation = 0.55 + 0.45 * v,
            )
            var bounce = 0.3 + 0.7 * v
            var tremble = 0.0
            val a = anger.coerceIn(0.0, 1.0)
            when (mood) {
                CoachMood.PROUD -> {
                    droop = maxOf(0.0, droop - 0.35)
                    pose = pose.copy(eyes = SlimeEyes.SPARKLY, mouth = SlimeMouth.GRIN, blush = true, sparkle = true,
                        saturation = maxOf(pose.saturation, 0.9))
                    bounce = maxOf(bounce, 0.9)
                }
                CoachMood.CALM -> {}
                CoachMood.SUSPICIOUS -> pose = pose.copy(eyes = SlimeEyes.SQUINT, mouth = SlimeMouth.FLAT, sweat = true, sparkle = false)
                CoachMood.ANGRY -> {
                    droop = minOf(1.0, droop + 0.25 * a)
                    pose = pose.copy(redness = 0.25 + 0.55 * a, eyes = SlimeEyes.SQUINT,
                        mouth = if (a > 0.5) SlimeMouth.OPEN else SlimeMouth.FROWN, steam = a >= 0.6, blush = false, sparkle = false)
                    tremble = a
                }
                CoachMood.DISAPPOINTED -> {
                    droop = minOf(1.0, droop + 0.2)
                    pose = pose.copy(eyes = SlimeEyes.TEARY, mouth = SlimeMouth.FROWN, blush = false, sparkle = false,
                        saturation = minOf(pose.saturation, 0.7))
                }
            }
            val drips = when { droop >= 0.75 -> 3; droop >= 0.5 -> 2; droop >= 0.3 -> 1; else -> 0 }
            return SlimeLook(pose.copy(droop = droop, drips = drips), bounce, tremble)
        }
    }
}
