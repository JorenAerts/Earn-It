package be.gloop.core.onboarding

import be.gloop.core.coach.CoachIntensity

/**
 * Pure: how onboarding answers change the app, and what Gloop says about them (port of iOS
 * `OnboardingPersonalization`). Lines are returned as ids + arguments; the app has the texts.
 */
object OnboardingPersonalization {
    fun suggestedTone(reaction: AlarmReaction?): CoachIntensity = when (reaction) {
        AlarmReaction.IM_UP -> CoachIntensity.GENTLE
        AlarmReaction.WHY_SO_EARLY -> CoachIntensity.SAVAGE
        else -> CoachIntensity.TOUGH_LOVE
    }

    /** Re-ring time: the longer you usually linger, the less time you get. */
    fun reArmMinutes(getUpTime: GetUpTime?): Int = when (getUpTime) {
        GetUpTime.UNDER_10 -> 3
        GetUpTime.OVER_HOUR -> 1
        else -> 2
    }

    /** Hours won back per week (half hours, rounded down); null under one hour. */
    fun hoursBackPerWeek(getUpTime: GetUpTime?, weekdays: Set<Int>): Double? {
        getUpTime ?: return null
        val days = if (weekdays.isEmpty()) 1 else weekdays.size
        val hours = getUpTime.minutesLost * days / 60.0
        val rounded = Math.floor(hours * 2) / 2
        return if (rounded >= 1) rounded else null
    }

    /** "1½", "3", "½" for the hours-back sentence; `plural` picks "hours" vs "hour". */
    fun hoursBackNumber(hours: Double): Pair<String, Boolean> {
        val whole = hours.toInt(); val half = hours - whole >= 0.5
        val number = if (half) (if (whole == 0) "½" else "$whole½") else "$whole"
        return number to (hours > 1)
    }

    /** Name argument when the user gave none; the app shows its translation (iOS `L10n.tr("friend")`). */
    const val FALLBACK_NAME = "friend"

    /** Coach / summary lines (ids). Arguments: name or [FALLBACK_NAME], time text. */
    enum class Line {
        WELCOME, NAME_ASK, NAME_LOVE, AGE, HEARD,
        REACTION_UP, REACTION_FIVE, REACTION_BACKUP, REACTION_EARLY, REACTION_NONE,
        GETUP_UNDER10, GETUP_10_30, GETUP_30_60, GETUP_OVER_HOUR,
        STRUGGLE_SNOOZE, STRUGGLE_PHONE, STRUGGLE_SLEEP, STRUGGLE_MOVING, STRUGGLE_PICK,
        GOAL_ASK, GOAL_WORTH, WAKE_TIME, MISSION, SOUND,
        GOAL_ON_TIME, GOAL_WORKOUT, GOAL_QUIET, GOAL_AHEAD, GOAL_AWAKE, GOAL_NONE,
        FINISH_TRAIN, FINISH_COFFEE, FINISH_AHEAD, FINISH_DEFAULT,
    }

    data class CoachLine(val line: Line, val args: List<String> = emptyList())

    fun goalLine(goal: MorningGoal?): Line = when (goal) {
        MorningGoal.ON_TIME -> Line.GOAL_ON_TIME
        MorningGoal.WORKOUT -> Line.GOAL_WORKOUT
        MorningGoal.QUIET_TIME -> Line.GOAL_QUIET
        MorningGoal.GET_AHEAD -> Line.GOAL_AHEAD
        MorningGoal.FEEL_AWAKE -> Line.GOAL_AWAKE
        null -> Line.GOAL_NONE
    }

    fun finishLine(goal: MorningGoal?): Line = when (goal) {
        MorningGoal.WORKOUT -> Line.FINISH_TRAIN
        MorningGoal.QUIET_TIME -> Line.FINISH_COFFEE
        MorningGoal.GET_AHEAD -> Line.FINISH_AHEAD
        else -> Line.FINISH_DEFAULT
    }

    /** Gloop reacting to an answer (speech bubble). null = stay quiet. */
    fun coachReaction(step: OnboardingStep, answers: OnboardingAnswers): CoachLine? {
        val name = answers.name.trim()
        val who = name.ifEmpty { FALLBACK_NAME }
        return when (step) {
            OnboardingStep.WELCOME -> CoachLine(Line.WELCOME)
            OnboardingStep.NAME -> if (name.isEmpty()) CoachLine(Line.NAME_ASK) else CoachLine(Line.NAME_LOVE, listOf(name))
            OnboardingStep.AGE_RANGE -> CoachLine(Line.AGE)
            OnboardingStep.HEARD_FROM -> CoachLine(Line.HEARD)
            OnboardingStep.ALARM_REACTION -> when (answers.reaction) {
                AlarmReaction.IM_UP -> CoachLine(Line.REACTION_UP)
                AlarmReaction.FIVE_MORE -> CoachLine(Line.REACTION_FIVE)
                AlarmReaction.BACKUP_ALARM -> CoachLine(Line.REACTION_BACKUP)
                AlarmReaction.WHY_SO_EARLY -> CoachLine(Line.REACTION_EARLY, listOf(who))
                null -> CoachLine(Line.REACTION_NONE)
            }
            OnboardingStep.GET_UP_TIME -> when (answers.getUpTime) {
                GetUpTime.UNDER_10 -> CoachLine(Line.GETUP_UNDER10)
                GetUpTime.TEN_TO_30 -> CoachLine(Line.GETUP_10_30)
                GetUpTime.THIRTY_TO_60 -> CoachLine(Line.GETUP_30_60)
                GetUpTime.OVER_HOUR -> CoachLine(Line.GETUP_OVER_HOUR, listOf(who))
                null -> null
            }
            OnboardingStep.STRUGGLES -> when {
                MorningStruggle.SNOOZE in answers.struggles -> CoachLine(Line.STRUGGLE_SNOOZE)
                MorningStruggle.PHONE_IN_BED in answers.struggles -> CoachLine(Line.STRUGGLE_PHONE)
                MorningStruggle.SLEEP_THROUGH in answers.struggles -> CoachLine(Line.STRUGGLE_SLEEP)
                answers.struggles.isNotEmpty() -> CoachLine(Line.STRUGGLE_MOVING)
                else -> CoachLine(Line.STRUGGLE_PICK)
            }
            OnboardingStep.GOAL -> if (answers.goal == null) CoachLine(Line.GOAL_ASK, listOf(who)) else CoachLine(Line.GOAL_WORTH)
            OnboardingStep.WAKE_TIME -> CoachLine(Line.WAKE_TIME, listOf(answers.timeText))
            OnboardingStep.MISSION -> CoachLine(Line.MISSION)
            OnboardingStep.SOUND -> CoachLine(Line.SOUND)
            else -> null
        }
    }
}
