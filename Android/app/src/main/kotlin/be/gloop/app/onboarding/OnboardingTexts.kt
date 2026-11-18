package be.gloop.app.onboarding

import android.content.Context
import be.gloop.app.R
import be.gloop.core.coach.CoachIdentity
import be.gloop.core.onboarding.AgeRange
import be.gloop.core.onboarding.AlarmReaction
import be.gloop.core.onboarding.GetUpTime
import be.gloop.core.onboarding.HeardFrom
import be.gloop.core.onboarding.MorningGoal
import be.gloop.core.onboarding.MorningStruggle
import be.gloop.core.onboarding.OnboardingPersonalization
import be.gloop.core.onboarding.OnboardingPersonalization.CoachLine
import be.gloop.core.onboarding.OnboardingPersonalization.Line

/** Texts and icons for the `:core` onboarding answers and lines (iOS titles / SF Symbols → emoji). */

fun Context.text(line: CoachLine): String = text(line.line, line.args)

fun Context.text(line: Line, args: List<String> = emptyList()): String {
    val res = when (line) {
        Line.WELCOME -> return getString(R.string.coach_welcome, CoachIdentity.NAME)
        Line.NAME_ASK -> R.string.coach_name_ask
        Line.NAME_LOVE -> R.string.coach_name_love
        Line.AGE -> R.string.coach_age
        Line.HEARD -> R.string.coach_heard
        Line.REACTION_UP -> R.string.coach_up
        Line.REACTION_FIVE -> R.string.coach_five
        Line.REACTION_BACKUP -> R.string.coach_backup
        Line.REACTION_EARLY -> R.string.coach_early
        Line.REACTION_NONE -> R.string.coach_none
        Line.GETUP_UNDER10 -> R.string.coach_under10
        Line.GETUP_10_30 -> R.string.coach_10_30
        Line.GETUP_30_60 -> R.string.coach_30_60
        Line.GETUP_OVER_HOUR -> R.string.coach_over_hour
        Line.STRUGGLE_SNOOZE -> R.string.coach_snooze
        Line.STRUGGLE_PHONE -> R.string.coach_phone
        Line.STRUGGLE_SLEEP -> R.string.coach_sleep
        Line.STRUGGLE_MOVING -> R.string.coach_moving
        Line.STRUGGLE_PICK -> R.string.ob_struggles_subtitle
        Line.GOAL_ASK -> R.string.coach_goal_ask
        Line.GOAL_WORTH -> R.string.coach_goal_worth
        Line.WAKE_TIME -> R.string.coach_wake
        Line.MISSION -> R.string.coach_mission
        Line.SOUND -> R.string.coach_sound
        Line.GOAL_ON_TIME -> R.string.line_goal_on_time
        Line.GOAL_WORKOUT -> R.string.line_goal_workout
        Line.GOAL_QUIET -> R.string.line_goal_quiet
        Line.GOAL_AHEAD -> R.string.line_goal_ahead
        Line.GOAL_AWAKE -> R.string.line_goal_awake
        Line.GOAL_NONE -> R.string.line_goal_none
        Line.FINISH_TRAIN -> R.string.line_finish_train
        Line.FINISH_COFFEE -> R.string.line_finish_coffee
        Line.FINISH_AHEAD -> R.string.line_finish_ahead
        Line.FINISH_DEFAULT -> R.string.youre_up
    }
    val shown = args.map { if (it == OnboardingPersonalization.FALLBACK_NAME) getString(R.string.name_fallback) else it }
    return if (shown.isEmpty()) getString(res) else getString(res, *shown.toTypedArray())
}

fun AgeRange.icon() = when (this) {
    AgeRange.TEEN -> "🎒"; AgeRange.YOUNG -> "🎓"; AgeRange.ADULT -> "💼"; AgeRange.MID -> "👨‍👧"; AgeRange.OLDER -> "🏠"; AgeRange.SENIOR -> "🌍"
}

fun HeardFrom.label(c: Context) = when (this) {
    HeardFrom.INSTAGRAM -> c.getString(R.string.heard_instagram); HeardFrom.TIKTOK -> "TikTok"; HeardFrom.YOUTUBE -> "YouTube"
    HeardFrom.APP_STORE -> c.getString(R.string.heard_play); HeardFrom.FRIEND -> c.getString(R.string.heard_friend)
    HeardFrom.REDDIT -> c.getString(R.string.heard_reddit); HeardFrom.OTHER -> c.getString(R.string.heard_other)
}
fun HeardFrom.icon() = when (this) {
    HeardFrom.INSTAGRAM -> "📷"; HeardFrom.TIKTOK -> "🎵"; HeardFrom.YOUTUBE -> "▶️"; HeardFrom.APP_STORE -> "🛍️"
    HeardFrom.FRIEND -> "👥"; HeardFrom.REDDIT -> "💬"; HeardFrom.OTHER -> "…"
}

fun AlarmReaction.label(c: Context) = c.getString(when (this) {
    AlarmReaction.IM_UP -> R.string.reaction_up; AlarmReaction.FIVE_MORE -> R.string.reaction_five
    AlarmReaction.BACKUP_ALARM -> R.string.reaction_backup; AlarmReaction.WHY_SO_EARLY -> R.string.reaction_early
})
fun AlarmReaction.icon() = when (this) { AlarmReaction.IM_UP -> "⚡"; AlarmReaction.FIVE_MORE -> "💤"; AlarmReaction.BACKUP_ALARM -> "⏰"; AlarmReaction.WHY_SO_EARLY -> "❓" }

fun GetUpTime.label(c: Context) = when (this) {
    GetUpTime.UNDER_10 -> c.getString(R.string.getup_under10); GetUpTime.TEN_TO_30 -> c.getString(R.string.getup_10_30)
    GetUpTime.THIRTY_TO_60 -> c.getString(R.string.getup_30_60); GetUpTime.OVER_HOUR -> c.getString(R.string.getup_over_hour)
}
fun GetUpTime.icon() = when (this) { GetUpTime.UNDER_10 -> "🟢"; GetUpTime.TEN_TO_30 -> "🟡"; GetUpTime.THIRTY_TO_60 -> "🟠"; GetUpTime.OVER_HOUR -> "🔴" }

fun MorningStruggle.label(c: Context) = c.getString(when (this) {
    MorningStruggle.PHONE_IN_BED -> R.string.struggle_phone; MorningStruggle.SNOOZE -> R.string.struggle_snooze
    MorningStruggle.SLEEP_THROUGH -> R.string.struggle_sleep; MorningStruggle.NO_ENERGY -> R.string.struggle_energy
    MorningStruggle.STAY_IN_BED, MorningStruggle.FALL_BACK_ASLEEP -> R.string.struggle_stay
})
fun MorningStruggle.icon() = when (this) {
    MorningStruggle.PHONE_IN_BED -> "📱"; MorningStruggle.SNOOZE -> "🔁"; MorningStruggle.SLEEP_THROUGH -> "😴"
    MorningStruggle.STAY_IN_BED, MorningStruggle.FALL_BACK_ASLEEP -> "🛏️"; MorningStruggle.NO_ENERGY -> "🪫"
}

fun MorningGoal.label(c: Context) = c.getString(when (this) {
    MorningGoal.ON_TIME -> R.string.goal_on_time; MorningGoal.WORKOUT -> R.string.goal_workout; MorningGoal.QUIET_TIME -> R.string.goal_quiet
    MorningGoal.GET_AHEAD -> R.string.goal_ahead; MorningGoal.FEEL_AWAKE -> R.string.goal_awake
})
fun MorningGoal.icon() = when (this) {
    MorningGoal.ON_TIME -> "⏱️"; MorningGoal.WORKOUT -> "🏃"; MorningGoal.QUIET_TIME -> "☕"; MorningGoal.GET_AHEAD -> "🌅"; MorningGoal.FEEL_AWAKE -> "👁️"
}
