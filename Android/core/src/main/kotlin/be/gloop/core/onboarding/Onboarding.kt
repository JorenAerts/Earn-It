package be.gloop.core.onboarding

import be.gloop.core.model.AlarmPlan
import be.gloop.core.model.AlarmSound
import be.gloop.core.model.MissionConfig
import be.gloop.core.model.MissionKind
import be.gloop.core.model.SoundChoice
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.intOrNull

// MARK: Answers (raw values match iOS, so saved progress and profile fields are identical)

/** What keeps you in bed (multi-select), used to suggest the mission. */
enum class MorningStruggle(val raw: String, val suggestedMission: MissionKind) {
    PHONE_IN_BED("phoneInBed", MissionKind.MATH),
    SNOOZE("snooze", MissionKind.MATH),
    SLEEP_THROUGH("sleepThrough", MissionKind.MATH),
    STAY_IN_BED("stayInBed", MissionKind.SHAKE),
    NO_ENERGY("noEnergy", MissionKind.SHAKE),
    /** Older saved progress; maps to "awake but staying in bed". */
    FALL_BACK_ASLEEP("fallBackAsleep", MissionKind.SHAKE);

    companion object {
        /** Shown in onboarding (the legacy case is hidden). */
        val choices = listOf(PHONE_IN_BED, SNOOZE, SLEEP_THROUGH, STAY_IN_BED, NO_ENERGY)
        fun fromRaw(raw: String?) = entries.firstOrNull { it.raw == raw }
    }
}

enum class AgeRange(val raw: String) {
    TEEN("13-17"), YOUNG("18-24"), ADULT("25-34"), MID("35-44"), OLDER("45-54"), SENIOR("55+");
    /** "13–17" with an en dash, like iOS. */
    val title: String get() = raw.replace("-", "–")
    companion object { fun fromRaw(raw: String?) = entries.firstOrNull { it.raw == raw } }
}

enum class HeardFrom(val raw: String) {
    INSTAGRAM("instagram"), TIKTOK("tiktok"), YOUTUBE("youtube"), APP_STORE("appStore"), FRIEND("friend"), REDDIT("reddit"), OTHER("other");
    companion object { fun fromRaw(raw: String?) = entries.firstOrNull { it.raw == raw } }
}

/** "What goes through your head when your alarm rings?" */
enum class AlarmReaction(val raw: String) {
    IM_UP("imUp"), FIVE_MORE("fiveMore"), BACKUP_ALARM("backupAlarm"), WHY_SO_EARLY("whySoEarly");
    companion object { fun fromRaw(raw: String?) = entries.firstOrNull { it.raw == raw } }
}

/** "How long until you actually get up?" with the typical minutes lost per morning. */
enum class GetUpTime(val raw: String, val minutesLost: Int) {
    UNDER_10("under10", 5), TEN_TO_30("tenTo30", 20), THIRTY_TO_60("thirtyTo60", 45), OVER_HOUR("overHour", 75);
    companion object { fun fromRaw(raw: String?) = entries.firstOrNull { it.raw == raw } }
}

/** "What would you do with the time back?" */
enum class MorningGoal(val raw: String) {
    ON_TIME("onTime"), WORKOUT("workout"), QUIET_TIME("quietTime"), GET_AHEAD("getAhead"), FEEL_AWAKE("feelAwake");
    companion object { fun fromRaw(raw: String?) = entries.firstOrNull { it.raw == raw } }
}

/** Answers collected during onboarding (port of iOS `OnboardingAnswers`). */
data class OnboardingAnswers(
    val name: String = "",
    val ageRange: AgeRange? = null,
    val heardFrom: HeardFrom? = null,
    val reaction: AlarmReaction? = null,
    val getUpTime: GetUpTime? = null,
    val struggles: Set<MorningStruggle> = emptySet(),
    val goal: MorningGoal? = null,
    val hour: Int = 7,
    val minute: Int = 0,
    val weekdays: Set<Int> = (2..6).toSet(),
    /** Chosen in the mission step (null = use the suggestion). */
    val missions: List<MissionConfig>? = null,
    val sound: SoundChoice = SoundChoice(),
    /** The alarm onboarding created: replaying updates it instead of adding another. */
    val createdPlanID: String? = null,
) {
    /** One mission per distinct suggestion, in mission order; Math if nothing picked. */
    val suggestedMissions: List<MissionKind>
        get() {
            val kinds = struggles.map { it.suggestedMission }.toSet()
            return MissionKind.entries.filter { it in kinds }.ifEmpty { listOf(MissionKind.MATH) }
        }

    val suggestedMission: MissionKind get() = suggestedMissions.first()

    /** What the alarm will use. */
    val chosenMissions: List<MissionConfig> get() = missions ?: listOf(MissionConfig(kind = suggestedMission))

    val timeText: String get() = "%02d:%02d".format(hour, minute)

    /**
     * The first alarm. What the user can't use (free plan, no trial) becomes free: missions → Math,
     * sound → Classic Beep. Unregistered scan missions fall back to Math.
     */
    fun firstAlarm(
        label: String,
        missionLocked: (MissionKind) -> Boolean = { false },
        soundLocked: (AlarmSound) -> Boolean = { false },
        newId: () -> String = { java.util.UUID.randomUUID().toString().uppercase() },
    ): AlarmPlan {
        val ready = chosenMissions.filter { it.isReady }.map { if (missionLocked(it.kind)) MissionConfig(kind = MissionKind.MATH) else it }
        val alarmSound = if (soundLocked(sound.builtIn)) SoundChoice() else sound
        return AlarmPlan(
            id = createdPlanID ?: newId(), label = label, sound = alarmSound, hour = hour, minute = minute,
            weekdays = weekdays, missions = ready.ifEmpty { listOf(MissionConfig(kind = MissionKind.MATH)) },
            reArmMinutes = OnboardingPersonalization.reArmMinutes(getUpTime), isEnabled = true,
        )
    }

    /** Continue on the sound step asks for the trial: a locked sound, except the invite sound. */
    fun soundNeedsPaywall(soundLocked: (AlarmSound) -> Boolean): Boolean =
        soundLocked(sound.builtIn) && sound.builtIn != AlarmSound.RISE_AND_CONQUER

    companion object {
        private val json = Json { ignoreUnknownKeys = true }

        /** Tolerant: progress saved by older versions (fewer fields, removed cases) still loads. */
        fun fromJson(obj: JsonObject?): OnboardingAnswers {
            if (obj == null) return OnboardingAnswers()
            fun str(key: String) = (obj[key] as? JsonPrimitive)?.takeIf { it.isString }?.content
            fun int(key: String) = (obj[key] as? JsonPrimitive)?.intOrNull
            fun ints(key: String) = (obj[key] as? JsonArray)?.mapNotNull { (it as? JsonPrimitive)?.intOrNull }?.toSet()
            return OnboardingAnswers(
                name = str("name") ?: "",
                ageRange = AgeRange.fromRaw(str("ageRange")),
                heardFrom = HeardFrom.fromRaw(str("heardFrom")),
                reaction = AlarmReaction.fromRaw(str("reaction")),
                getUpTime = GetUpTime.fromRaw(str("getUpTime")),
                struggles = (obj["struggles"] as? JsonArray)?.mapNotNull { MorningStruggle.fromRaw((it as? JsonPrimitive)?.content) }?.toSet().orEmpty(),
                goal = MorningGoal.fromRaw(str("goal")),
                hour = int("hour") ?: 7,
                minute = int("minute") ?: 0,
                weekdays = ints("weekdays") ?: (2..6).toSet(),
                missions = (obj["missions"] as? JsonArray)?.let { arr -> runCatching { arr.map { json.decodeFromJsonElement<MissionConfig>(it) } }.getOrNull() },
                sound = obj["sound"]?.let { runCatching { json.decodeFromJsonElement<SoundChoice>(it) }.getOrNull() } ?: SoundChoice(),
                createdPlanID = str("createdPlanID"),
            )
        }

        fun toJson(a: OnboardingAnswers): JsonObject = JsonObject(buildMap {
            put("name", JsonPrimitive(a.name))
            a.ageRange?.let { put("ageRange", JsonPrimitive(it.raw)) }
            a.heardFrom?.let { put("heardFrom", JsonPrimitive(it.raw)) }
            a.reaction?.let { put("reaction", JsonPrimitive(it.raw)) }
            a.getUpTime?.let { put("getUpTime", JsonPrimitive(it.raw)) }
            put("struggles", JsonArray(a.struggles.map { JsonPrimitive(it.raw) }))
            a.goal?.let { put("goal", JsonPrimitive(it.raw)) }
            put("hour", JsonPrimitive(a.hour)); put("minute", JsonPrimitive(a.minute))
            put("weekdays", JsonArray(a.weekdays.sorted().map { JsonPrimitive(it) }))
            a.missions?.let { put("missions", json.encodeToJsonElement(kotlinx.serialization.builtins.ListSerializer(MissionConfig.serializer()), it)) }
            put("sound", json.encodeToJsonElement(SoundChoice.serializer(), a.sound))
            a.createdPlanID?.let { put("createdPlanID", JsonPrimitive(it)) }
        })
    }
}

// MARK: Steps + flow

@Serializable(with = OnboardingStepSerializer::class)
enum class OnboardingStep(val raw: String) {
    WELCOME("welcome"), NAME("name"), AGE_RANGE("ageRange"), HEARD_FROM("heardFrom"), ALARM_REACTION("alarmReaction"),
    WHY_IT_WORKS("whyItWorks"), GET_UP_TIME("getUpTime"), STRUGGLES("struggles"), GOAL("goal"), WAKE_TIME("wakeTime"),
    COMPARISON("comparison"), PERMISSIONS("permissions"), MISSION("mission"), MISSION_SETUP("missionSetup"), SOUND("sound"),
    INVITE_FRIEND("inviteFriend"), ACCOUNT("account"), BUILDING("building"), SUMMARY("summary"), PAYWALL("paywall");

    /** Steps without a progress bar or back button (full-screen moments). */
    val isFullScreen: Boolean get() = this in setOf(WELCOME, BUILDING, SUMMARY, PAYWALL)

    companion object {
        /** Older saved progress may name steps that no longer exist. */
        fun fromRaw(raw: String?): OnboardingStep = when (raw) {
            "howItWorks" -> WHY_IT_WORKS
            "goals" -> STRUGGLES
            "firstAlarm" -> MISSION
            else -> entries.firstOrNull { it.raw == raw } ?: WELCOME
        }
    }
}

object OnboardingStepSerializer : KSerializer<OnboardingStep> {
    override val descriptor = PrimitiveSerialDescriptor("OnboardingStep", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: OnboardingStep) = encoder.encodeString(value.raw)
    override fun deserialize(decoder: Decoder) = OnboardingStep.fromRaw(decoder.decodeString())
}

/** Facts the flow needs to decide which steps to skip. */
data class OnboardingContext(
    val accountsAvailable: Boolean,
    val isSignedIn: Boolean,
    val isPro: Boolean,
    val bonusSoundUnlocked: Boolean = false,
    val missionHasSetup: Boolean = true,
    /** Android: false until Play Billing exists; skips the paywall and the invite (its reward is a Pro sound). */
    val billingAvailable: Boolean = true,
)

/** Pure step logic: order, skipping, back navigation (port of iOS `OnboardingFlow`). */
object OnboardingFlow {
    fun shouldSkip(step: OnboardingStep, c: OnboardingContext): Boolean = when (step) {
        OnboardingStep.ACCOUNT -> !c.accountsAvailable || c.isSignedIn
        OnboardingStep.PAYWALL -> c.isPro || !c.billingAvailable
        OnboardingStep.INVITE_FRIEND -> c.bonusSoundUnlocked || !c.billingAvailable
        OnboardingStep.MISSION_SETUP -> !c.missionHasSetup
        else -> false
    }

    /** Next visible step, or null when onboarding is complete. */
    fun next(after: OnboardingStep, c: OnboardingContext): OnboardingStep? =
        OnboardingStep.entries.drop(after.ordinal + 1).firstOrNull { !shouldSkip(it, c) }

    /** Back stops at the building step: the alarm is already made, so the finale can't be redone. */
    fun previous(before: OnboardingStep, c: OnboardingContext): OnboardingStep? {
        if (before in setOf(OnboardingStep.WELCOME, OnboardingStep.BUILDING, OnboardingStep.SUMMARY)) return null
        return OnboardingStep.entries.take(before.ordinal).lastOrNull { !shouldSkip(it, c) && it != OnboardingStep.BUILDING }
    }

    fun visibleSteps(c: OnboardingContext): List<OnboardingStep> = OnboardingStep.entries.filter { !shouldSkip(it, c) }

    /** 0…1 for the progress bar. */
    fun fraction(at: OnboardingStep, c: OnboardingContext): Double {
        val steps = visibleSteps(c); val index = steps.indexOf(at)
        return if (index < 0 || steps.size < 2) 0.0 else index / (steps.size - 1).toDouble()
    }
}

/** Saved progress so a killed app resumes where the user left off (`gloop.onboarding`). */
data class OnboardingProgress(val step: OnboardingStep = OnboardingStep.WELCOME, val answers: OnboardingAnswers = OnboardingAnswers(), val completed: Boolean = false) {
    fun encode(): String = JsonObject(mapOf(
        "step" to JsonPrimitive(step.raw), "answers" to OnboardingAnswers.toJson(answers), "completed" to JsonPrimitive(completed),
    )).toString()

    companion object {
        fun decode(text: String?): OnboardingProgress? {
            val obj = text?.let { runCatching { Json.parseToJsonElement(it) as? JsonObject }.getOrNull() } ?: return null
            return OnboardingProgress(
                step = OnboardingStep.fromRaw((obj["step"] as? JsonPrimitive)?.content),
                answers = OnboardingAnswers.fromJson(obj["answers"] as? JsonObject),
                completed = (obj["completed"] as? JsonPrimitive)?.booleanOrNull ?: false,
            )
        }
    }
}

/** `Shared/Config/SocialProof.json`: only real numbers and reviews; empty = hidden. */
data class SocialProof(val stats: List<Stat>, val reviews: List<Review>) {
    @Serializable data class Stat(val value: String, val label: String)
    @Serializable data class Review(val name: String, val text: String, val stars: Int)
    @Serializable private data class File(val stats: List<Stat>? = null, val reviews: List<Review>? = null)

    companion object {
        val EMPTY = SocialProof(emptyList(), emptyList())
        fun decode(text: String?): SocialProof {
            val file = text?.let { runCatching { Json { ignoreUnknownKeys = true }.decodeFromString(File.serializer(), it) }.getOrNull() } ?: return EMPTY
            return SocialProof(file.stats.orEmpty(), file.reviews.orEmpty().filter { it.stars in 1..5 })
        }
    }
}

