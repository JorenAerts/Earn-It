package be.gloop.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

/** Port of iOS `MissionKind`. Raw names match iOS (stored JSON, telemetry). Texts live in the app. */
@Serializable
enum class MissionKind {
    @SerialName("math") MATH,
    @SerialName("shake") SHAKE,
    @SerialName("qr") QR,
    @SerialName("object") OBJECT,
    @SerialName("quiz") QUIZ,
    @SerialName("memory") MEMORY,
    @SerialName("typing") TYPING,
    @SerialName("sky") SKY,
    @SerialName("bed") BED,
    @SerialName("colorHunt") COLOR_HUNT;

    val rawValue: String get() = serializer().descriptor.getElementName(ordinal)

    val category: MissionCategory
        get() = when (this) {
            MATH, QUIZ, MEMORY, TYPING -> MissionCategory.BRAIN
            SHAKE -> MissionCategory.BODY
            QR, OBJECT, SKY, BED, COLOR_HUNT -> MissionCategory.OUT_OF_BED
        }

    val needsCamera: Boolean get() = this in setOf(QR, OBJECT, SKY, BED, COLOR_HUNT)
    val needsPayload: Boolean get() = this == QR || this == OBJECT || this == BED

    val defaultTarget: Int
        get() = when (this) {
            MATH -> 3; SHAKE -> 30; QR, OBJECT -> 1; QUIZ -> 3; MEMORY -> 6; TYPING -> 2
            SKY, BED -> 1; COLOR_HUNT -> 2
        }

    /** Allowed `target` values in setup; null = not configurable. */
    val targetRange: IntRange?
        get() = when (this) {
            MATH -> 1..20; SHAKE -> 5..200; QUIZ -> 1..10; TYPING -> 1..5; COLOR_HUNT -> 1..3
            QR, OBJECT, MEMORY, SKY, BED -> null
        }

    val targetStep: Int get() = if (this == SHAKE) 5 else 1

    val usesDifficulty: Boolean get() = this in setOf(MATH, SHAKE, MEMORY, TYPING)

    /** Seconds on the mission screen before "Can't find it?" is offered; null = never. */
    val backupAfterSeconds: Int? get() = if (this in setOf(OBJECT, BED, COLOR_HUNT)) 120 else null

    companion object {
        /** Missions in the Android picker, in iOS picker order (brain, body, out of bed). */
        val availableOnAndroid: List<MissionKind> = listOf(MATH, QUIZ, MEMORY, TYPING, SHAKE, QR, OBJECT, SKY, BED, COLOR_HUNT)

        /** Camera missions with a flashlight button (iOS `usesTorch`): not the sky. */
        val usesTorch: Set<MissionKind> = setOf(QR, OBJECT, BED, COLOR_HUNT)

        fun fromRaw(raw: String): MissionKind? = entries.firstOrNull { it.rawValue == raw }
    }
}

enum class MissionCategory { BRAIN, BODY, OUT_OF_BED, MINDSET }

@Serializable
enum class MissionDifficulty {
    @SerialName("easy") EASY,
    @SerialName("medium") MEDIUM,
    @SerialName("hard") HARD,
}

@Serializable
enum class QuizTopic {
    @SerialName("general") GENERAL,
    @SerialName("geography") GEOGRAPHY,
    @SerialName("science") SCIENCE,
    @SerialName("animals") ANIMALS,
    @SerialName("history") HISTORY,
    @SerialName("sports") SPORTS,
    @SerialName("moviesMusic") MOVIES_MUSIC,
    @SerialName("food") FOOD;

    val rawValue: String get() = serializer().descriptor.getElementName(ordinal)

    companion object {
        fun fromRaw(raw: String?): QuizTopic? = entries.firstOrNull { it.rawValue == raw }
    }
}

/** Port of iOS `MissionConfig` (same JSON keys). */
@Serializable
data class MissionConfig(
    val id: String = UUID.randomUUID().toString().uppercase(),
    val kind: MissionKind,
    val difficulty: MissionDifficulty = MissionDifficulty.MEDIUM,
    /** Math: correct in a row. Shake: shakes. Quiz: correct answers. Typing: twisters. */
    val target: Int = kind.defaultTarget,
    /** QR: payload. Object: reference id. Quiz: the topic. */
    val payload: String? = null,
    val label: String? = null,
) {
    /** Quiz: the topic is stored in `payload` (default General knowledge). */
    val quizTopic: QuizTopic get() = QuizTopic.fromRaw(payload) ?: QuizTopic.GENERAL

    fun withQuizTopic(topic: QuizTopic) = copy(payload = topic.rawValue)

    /** Memory: pairs on the board, from the difficulty. */
    val memoryPairs: Int
        get() = when (difficulty) {
            MissionDifficulty.EASY -> 6; MissionDifficulty.MEDIUM -> 8; MissionDifficulty.HARD -> 10
        }

    /** Fully configured and playable. */
    val isReady: Boolean get() = !kind.needsPayload || !payload.isNullOrEmpty()
}
