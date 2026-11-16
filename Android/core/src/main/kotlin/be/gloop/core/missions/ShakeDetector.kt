package be.gloop.core.missions

import be.gloop.core.model.MissionDifficulty
import kotlin.math.sqrt

/**
 * Port of iOS `ShakeDetector`: samples in g (gravity included). A shake = magnitude ≥ threshold,
 * at least `minInterval` seconds after the previous one. Android sensors give m/s²: divide by 9.81.
 */
class ShakeDetector(val threshold: Double = 2.0, val minIntervalSeconds: Double = 0.25) {
    var count = 0; private set
    private var lastShake: Double? = null

    /** Returns true when this sample registered a new shake. */
    fun process(x: Double, y: Double, z: Double, timestampSeconds: Double): Boolean {
        val magnitude = sqrt(x * x + y * y + z * z)
        if (magnitude < threshold) return false
        lastShake?.let { if (timestampSeconds - it < minIntervalSeconds) return false }
        lastShake = timestampSeconds
        count += 1
        return true
    }

    companion object {
        const val STANDARD_GRAVITY = 9.80665

        /** Same thresholds as iOS `ShakeMonitor`. */
        fun threshold(difficulty: MissionDifficulty): Double = when (difficulty) {
            MissionDifficulty.EASY -> 1.7
            MissionDifficulty.MEDIUM -> 2.0
            MissionDifficulty.HARD -> 2.5
        }
    }
}
