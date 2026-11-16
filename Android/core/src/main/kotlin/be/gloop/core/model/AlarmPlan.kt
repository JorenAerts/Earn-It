package be.gloop.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.jsonObject
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.UUID

/** Built-in tones (iOS `AlarmSound`; files `res/raw/gloop_<snake_name>`). */
@Serializable
enum class AlarmSound {
    @SerialName("classic") CLASSIC,
    @SerialName("chime") CHIME,
    @SerialName("siren") SIREN,
    @SerialName("digital") DIGITAL,
    @SerialName("pulse") PULSE,
    @SerialName("radar") RADAR,
    @SerialName("gentleRise") GENTLE_RISE,
    @SerialName("reveille") REVEILLE,
    @SerialName("morningMood") MORNING_MOOD,
    @SerialName("furElise") FUR_ELISE,
    /** Bonus: unlocked for free users by inviting a friend. */
    @SerialName("riseAndConquer") RISE_AND_CONQUER;

    val rawValue: String get() = serializer().descriptor.getElementName(ordinal)

    /** Android raw resource name: "gentleRise" → "gloop_gentle_rise". */
    val resourceName: String get() = "gloop_" + rawValue.replace(Regex("([A-Z])")) { "_" + it.value.lowercase() }

    val isMelody: Boolean get() = this in setOf(CHIME, GENTLE_RISE, REVEILLE, MORNING_MOOD, FUR_ELISE, RISE_AND_CONQUER)

    companion object {
        fun fromRaw(raw: String?): AlarmSound? = entries.firstOrNull { it.rawValue == raw }
    }
}

/** Same shape as iOS `SoundChoice.builtIn` (`{"type":"builtIn","sound":"classic"}`). */
@Serializable
data class SoundChoice(val type: String = "builtIn", val sound: String = AlarmSound.CLASSIC.rawValue) {
    val builtIn: AlarmSound get() = AlarmSound.fromRaw(sound) ?: AlarmSound.CLASSIC

    companion object {
        fun of(sound: AlarmSound) = SoundChoice(sound = sound.rawValue)
    }
}

/** Port of iOS `AlarmPlan` (same JSON keys; weekdays 1 = Sunday … 7 = Saturday, empty = once). */
@Serializable
data class AlarmPlan(
    val id: String = UUID.randomUUID().toString().uppercase(),
    val label: String = "",
    val sound: SoundChoice = SoundChoice(),
    val hour: Int = 7,
    val minute: Int = 0,
    val weekdays: Set<Int> = (1..7).toSet(),
    val missions: List<MissionConfig> = listOf(MissionConfig(kind = MissionKind.MATH)),
    val reArmMinutes: Int = 2,
    /** Fail-safe: after this many re-ring intervals the alarm gives up (nobody gets stuck). */
    val maxReArms: Int = 15,
    val isEnabled: Boolean = false,
) {
    /** "07:00" */
    val timeText: String get() = "%02d:%02d".format(hour, minute)

    val isOnce: Boolean get() = weekdays.isEmpty()

    /** Every mission is configured. */
    val isReady: Boolean get() = missions.isNotEmpty() && missions.all { it.isReady }

    /** Next ring strictly after `after`. */
    fun nextFireTime(after: ZonedDateTime): ZonedDateTime? {
        val start = after.toLocalDate()
        for (offset in 0..7) {
            val day = start.plusDays(offset.toLong())
            val fire = day.atTime(hour, minute).atZone(after.zone)
            if (fire.isAfter(after) && (weekdays.isEmpty() || weekdays.contains(day.calendarWeekday()))) return fire
        }
        return null
    }

    fun nextFireTime(afterMillis: Long, zone: ZoneId = ZoneId.systemDefault()): Long? =
        nextFireTime(ZonedDateTime.ofInstant(java.time.Instant.ofEpochMilli(afterMillis), zone))?.toInstant()?.toEpochMilli()

    companion object {
        private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
        private val REQUIRED = listOf("id", "hour", "minute")

        fun encodeList(plans: List<AlarmPlan>): String = json.encodeToString(kotlinx.serialization.builtins.ListSerializer(serializer()), plans)

        /**
         * Tolerant, like iOS: missions of unknown kinds are dropped, an alarm is never left without
         * a mission, and an unreadable alarm is skipped instead of losing the whole list.
         */
        fun decodeList(text: String?): List<AlarmPlan> {
            if (text.isNullOrBlank()) return emptyList()
            val array = runCatching { json.parseToJsonElement(text) as? JsonArray }.getOrNull() ?: return emptyList()
            return array.mapNotNull { element ->
                val obj = element as? JsonObject ?: return@mapNotNull null
                // Like iOS: an alarm needs at least its id and time; anything else has a default.
                if (REQUIRED.any { it !in obj }) return@mapNotNull null
                val missions = (obj["missions"] as? JsonArray).orEmpty().mapNotNull {
                    runCatching { json.decodeFromJsonElement<MissionConfig>(it) }.getOrNull()
                }.ifEmpty { listOf(MissionConfig(kind = MissionKind.MATH)) }
                val withoutMissions = JsonObject(obj.jsonObject - "missions")
                runCatching { json.decodeFromJsonElement<AlarmPlan>(withoutMissions).copy(missions = missions) }.getOrNull()
            }
        }
    }
}

/** iOS calendar weekday: 1 = Sunday … 7 = Saturday. */
fun LocalDate.calendarWeekday(): Int = if (dayOfWeek == DayOfWeek.SUNDAY) 1 else dayOfWeek.value + 1

/** One ring cycle (port of iOS `SessionState`; times in epoch millis, day = local date). */
@Serializable
data class SessionState(
    /** "yyyy-MM-dd" of the day this cycle started. */
    val day: String,
    /** When the alarm first rang (iOS: first press of X). */
    val firstEndedAt: Long? = null,
    val missionCompletedAt: Long? = null,
    val reArmCount: Int = 0,
    val failSafeTriggered: Boolean = false,
    /** The alarm that started this cycle: its missions, sound and re-ring settings apply. */
    val planID: String? = null,
) {
    val missionDone: Boolean get() = missionCompletedAt != null
    val isFinished: Boolean get() = missionDone || failSafeTriggered
    val awaitingMission: Boolean get() = firstEndedAt != null && !missionDone && !failSafeTriggered
}
