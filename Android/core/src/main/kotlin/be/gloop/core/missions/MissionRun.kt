package be.gloop.core.missions

import be.gloop.core.model.MissionConfig
import be.gloop.core.model.MissionDifficulty
import be.gloop.core.model.MissionKind

/** Port of iOS `MissionRun`: which step is active, what a result does, the backup swap. */
class MissionRun(steps: List<MissionConfig>) {
    enum class Result { SUCCESS, NEEDS_BACKUP }
    enum class Outcome { NEXT_STEP, FINISHED, BACKUP_STARTED }

    var steps: List<MissionConfig> = steps; private set
    var index = 0; private set
    /** Steps that were swapped for the backup. */
    val backedUp = mutableSetOf<Int>()

    val current: MissionConfig? get() = steps.getOrNull(index)
    val isFinished: Boolean get() = index >= steps.size

    /** Seconds before "Can't find it?" may be offered for the current step; null = never. */
    val backupDelaySeconds: Int? get() = current?.takeIf { index !in backedUp }?.kind?.backupAfterSeconds

    fun apply(result: Result): Outcome = when (result) {
        Result.SUCCESS -> { index += 1; if (isFinished) Outcome.FINISHED else Outcome.NEXT_STEP }
        Result.NEEDS_BACKUP -> { swapToBackup(); Outcome.BACKUP_STARTED }
    }

    fun swapToBackup() {
        if (index !in steps.indices || index in backedUp) return
        steps = steps.toMutableList().also { it[index] = backup() }
        backedUp += index
    }

    companion object {
        /** Replaces a mission that can't be done: hard, not a shortcut. */
        fun backup() = MissionConfig(kind = MissionKind.MATH, difficulty = MissionDifficulty.HARD, target = 5)
    }
}
