package be.gloop.core.coach

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** The coach's five moods, best to worst (iOS `CoachMood`). */
@Serializable
enum class CoachMood {
    @SerialName("proud") PROUD,
    @SerialName("calm") CALM,
    @SerialName("suspicious") SUSPICIOUS,
    @SerialName("angry") ANGRY,
    @SerialName("disappointed") DISAPPOINTED,
}

/** How harsh he talks (iOS `CoachIntensity`, stored as `gloop.coach.intensity`). */
@Serializable
enum class CoachIntensity(val rawValue: String) {
    @SerialName("gentle") GENTLE("gentle"),
    @SerialName("toughLove") TOUGH_LOVE("toughLove"),
    @SerialName("savage") SAVAGE("savage");

    companion object {
        fun fromRaw(raw: String?): CoachIntensity? = entries.firstOrNull { it.rawValue == raw }
    }
}

/** The character's name, used in lines like "Hi, I'm Gloop!" (iOS `CoachIdentity`). */
object CoachIdentity { const val NAME = "Gloop" }
