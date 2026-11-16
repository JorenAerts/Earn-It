package be.gloop.app.ui

import android.content.Context
import be.gloop.app.R
import be.gloop.core.model.AlarmPlan
import be.gloop.core.model.AlarmSound
import be.gloop.core.model.MissionConfig
import be.gloop.core.model.MissionDifficulty
import be.gloop.core.model.MissionKind
import be.gloop.core.model.QuizTopic
import java.time.DayOfWeek
import java.time.format.TextStyle
import java.util.Locale

/** User-facing names for `:core` models (the models stay text-free, like iOS raw values). */

fun MissionKind.nameRes(): Int = when (this) {
    MissionKind.MATH -> R.string.mission_math
    MissionKind.SHAKE -> R.string.mission_shake
    MissionKind.QR -> R.string.mission_qr
    MissionKind.OBJECT -> R.string.mission_object
    MissionKind.QUIZ -> R.string.mission_quiz
    MissionKind.MEMORY -> R.string.mission_memory
    MissionKind.TYPING -> R.string.mission_typing
    MissionKind.SKY -> R.string.mission_sky
    MissionKind.BED -> R.string.mission_bed
    MissionKind.COLOR_HUNT -> R.string.mission_color_hunt
}

fun MissionKind.taglineRes(): Int = when (this) {
    MissionKind.MATH -> R.string.tagline_math
    MissionKind.SHAKE -> R.string.tagline_shake
    MissionKind.QUIZ -> R.string.tagline_quiz
    MissionKind.MEMORY -> R.string.tagline_memory
    MissionKind.TYPING -> R.string.tagline_typing
    MissionKind.QR -> R.string.tagline_qr
    MissionKind.OBJECT -> R.string.tagline_object
    MissionKind.SKY -> R.string.tagline_sky
    MissionKind.BED -> R.string.tagline_bed
    MissionKind.COLOR_HUNT -> R.string.tagline_color
}

/** Emoji stand-ins for the iOS SF Symbols. */
fun MissionKind.emoji(): String = when (this) {
    MissionKind.MATH -> "➗"; MissionKind.SHAKE -> "📳"; MissionKind.QR -> "🔳"; MissionKind.OBJECT -> "📷"
    MissionKind.QUIZ -> "❓"; MissionKind.MEMORY -> "🃏"; MissionKind.TYPING -> "⌨️"; MissionKind.SKY -> "⛅"
    MissionKind.BED -> "🛏️"; MissionKind.COLOR_HUNT -> "🎨"
}

fun MissionDifficulty.nameRes(): Int = when (this) {
    MissionDifficulty.EASY -> R.string.difficulty_easy
    MissionDifficulty.MEDIUM -> R.string.difficulty_medium
    MissionDifficulty.HARD -> R.string.difficulty_hard
}

fun QuizTopic.nameRes(): Int = when (this) {
    QuizTopic.GENERAL -> R.string.topic_general
    QuizTopic.GEOGRAPHY -> R.string.topic_geography
    QuizTopic.SCIENCE -> R.string.topic_science
    QuizTopic.ANIMALS -> R.string.topic_animals
    QuizTopic.HISTORY -> R.string.topic_history
    QuizTopic.SPORTS -> R.string.topic_sports
    QuizTopic.MOVIES_MUSIC -> R.string.topic_movies_music
    QuizTopic.FOOD -> R.string.topic_food
}

fun AlarmSound.nameRes(): Int = when (this) {
    AlarmSound.CLASSIC -> R.string.sound_classic
    AlarmSound.CHIME -> R.string.sound_chime
    AlarmSound.SIREN -> R.string.sound_siren
    AlarmSound.DIGITAL -> R.string.sound_digital
    AlarmSound.PULSE -> R.string.sound_pulse
    AlarmSound.RADAR -> R.string.sound_radar
    AlarmSound.GENTLE_RISE -> R.string.sound_gentle_rise
    AlarmSound.REVEILLE -> R.string.sound_reveille
    AlarmSound.MORNING_MOOD -> R.string.sound_morning_mood
    AlarmSound.FUR_ELISE -> R.string.sound_fur_elise
    AlarmSound.RISE_AND_CONQUER -> R.string.sound_rise_and_conquer
}

/** "3 problems · Medium" (iOS `MissionConfig.summary`). */
fun MissionConfig.summary(context: Context): String {
    val diff = context.getString(difficulty.nameRes())
    return when (kind) {
        MissionKind.MATH -> context.getString(R.string.summary_math, target, diff)
        MissionKind.SHAKE -> context.getString(R.string.summary_shake, target, diff)
        MissionKind.QUIZ -> context.getString(R.string.summary_quiz, context.getString(quizTopic.nameRes()), target)
        MissionKind.MEMORY -> context.getString(R.string.summary_memory, memoryPairs, diff)
        MissionKind.TYPING -> context.getString(R.string.summary_typing, target, diff)
        MissionKind.QR -> context.getString(if (isReady) R.string.summary_code_registered else R.string.summary_no_code)
        MissionKind.OBJECT -> if (isReady) label?.takeIf { it.isNotBlank() } ?: context.getString(R.string.summary_item_scanned)
            else context.getString(R.string.summary_no_item)
        MissionKind.SKY -> context.getString(R.string.summary_sky)
        MissionKind.BED -> context.getString(if (isReady) R.string.summary_bed_scanned else R.string.summary_no_bed)
        MissionKind.COLOR_HUNT -> context.getString(R.string.summary_colors, target)
    }
}

/** What the mission screen tells the user to do (iOS `MissionConfig.instruction`). */
fun MissionConfig.instruction(context: Context): String = when (kind) {
    MissionKind.MATH -> context.getString(R.string.instruction_math, target)
    MissionKind.SHAKE -> context.getString(R.string.instruction_shake, target)
    MissionKind.QUIZ -> context.getString(R.string.instruction_quiz, target, context.getString(quizTopic.nameRes()))
    MissionKind.MEMORY -> context.getString(R.string.instruction_memory, memoryPairs)
    MissionKind.TYPING -> context.getString(R.string.instruction_typing, target)
    MissionKind.QR -> context.getString(R.string.instruction_qr)
    MissionKind.OBJECT -> label?.takeIf { it.isNotBlank() }
        ?.let { context.getString(R.string.instruction_object_named, if (java.util.Locale.getDefault().language == "de") it else it.lowercase()) }
        ?: context.getString(R.string.instruction_object)
    MissionKind.SKY -> context.getString(R.string.instruction_sky)
    MissionKind.BED -> context.getString(R.string.instruction_bed)
    MissionKind.COLOR_HUNT -> context.getString(R.string.instruction_color, target)
}

private fun MissionKind.titleRes(): Int = when (this) {
    MissionKind.MATH -> R.string.title_math
    MissionKind.SHAKE -> R.string.title_shake
    MissionKind.QUIZ -> R.string.title_quiz
    MissionKind.MEMORY -> R.string.title_memory
    MissionKind.TYPING -> R.string.title_typing
    MissionKind.QR -> R.string.title_qr
    MissionKind.OBJECT -> R.string.title_object
    MissionKind.SKY -> R.string.title_sky
    MissionKind.BED -> R.string.title_bed
    MissionKind.COLOR_HUNT -> R.string.title_color
}

/** "Scan Toothbrush" for a named item (iOS `MissionConfig.alarmTitle`). */
private fun MissionConfig.title(context: Context): String =
    label?.takeIf { kind == MissionKind.OBJECT && it.isNotBlank() }?.let { context.getString(R.string.title_object_named, it) }
        ?: context.getString(kind.titleRes())

/** "Gloop - Math Problem + Shake It" (iOS `AlarmPlan.alarmTitle`). */
fun alarmTitle(context: Context, plan: AlarmPlan): String =
    if (plan.missions.isEmpty()) "Gloop"
    else "Gloop - " + plan.missions.joinToString(" + ") { it.title(context) }

/** "Every day", "Weekdays", "Mon, Wed", "Once" (iOS `AlarmPlan.repeatText`, Monday first). */
fun repeatText(context: Context, plan: AlarmPlan, locale: Locale = Locale.getDefault()): String = when (plan.weekdays) {
    emptySet<Int>() -> context.getString(R.string.repeat_once)
    (1..7).toSet() -> context.getString(R.string.repeat_every_day)
    (2..6).toSet() -> context.getString(R.string.repeat_weekdays)
    setOf(1, 7) -> context.getString(R.string.repeat_weekends)
    else -> MONDAY_FIRST.filter { it in plan.weekdays }.joinToString(", ") { weekdayName(it, locale) }
}

/** iOS weekday numbers (1 = Sunday) in Monday-first display order. */
val MONDAY_FIRST = listOf(2, 3, 4, 5, 6, 7, 1)

fun weekdayName(calendarWeekday: Int, locale: Locale = Locale.getDefault(), style: TextStyle = TextStyle.SHORT): String {
    val day = if (calendarWeekday == 1) DayOfWeek.SUNDAY else DayOfWeek.of(calendarWeekday - 1)
    return day.getDisplayName(style, locale)
}
