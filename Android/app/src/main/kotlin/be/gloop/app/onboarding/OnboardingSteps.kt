package be.gloop.app.onboarding

import android.Manifest
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.LifecycleResumeEffect
import be.gloop.app.R
import be.gloop.app.alarm.RingService
import be.gloop.app.ui.AlarmPermission
import be.gloop.app.ui.CoachAvatar
import be.gloop.app.ui.LegalConsentLine
import be.gloop.app.ui.MONDAY_FIRST
import be.gloop.app.ui.MissionSetupDialog
import be.gloop.app.ui.MissionSetupRow
import be.gloop.app.ui.SetupScreen
import be.gloop.app.ui.WheelTimePicker
import be.gloop.app.ui.emoji
import be.gloop.app.ui.nameRes
import be.gloop.app.ui.taglineRes
import be.gloop.app.ui.weekdayName
import be.gloop.core.coach.CoachIdentity
import be.gloop.core.coach.CoachMood
import be.gloop.core.model.AlarmSound
import be.gloop.core.model.MissionConfig
import be.gloop.core.model.MissionDifficulty
import be.gloop.core.model.MissionKind
import be.gloop.core.model.QuizTopic
import be.gloop.core.model.SoundChoice
import be.gloop.core.onboarding.MorningStruggle
import be.gloop.core.onboarding.OnboardingAnswers
import be.gloop.core.onboarding.OnboardingPersonalization
import be.gloop.core.onboarding.OnboardingStep
import be.gloop.core.onboarding.SocialProof
import kotlinx.coroutines.delay
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle

/** Missions offered in onboarding (iOS `MissionKind.onboardingKinds`); the rest are in the app. */
val ONBOARDING_KINDS = listOf(MissionKind.MATH, MissionKind.SHAKE, MissionKind.QR, MissionKind.OBJECT, MissionKind.QUIZ)

// MARK: Welcome

@Composable
fun WelcomeStep(onNext: () -> Unit) {
    val context = LocalContext.current
    OnboardingPage(footer = {
        PrimaryButton(stringResource(R.string.ob_get_started), onClick = onNext)
        LegalConsentLine()
    }) {
        // Per-app language (Android 13+), like the 🌐 button on iOS.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                Text("🌐  " + stringResource(R.string.ob_language),
                    Modifier.clip(CircleShape).background(MaterialTheme.colorScheme.surfaceContainerHigh)
                        .clickable { context.startActivity(Intent(Settings.ACTION_APP_LOCALE_SETTINGS, Uri.parse("package:${context.packageName}"))) }
                        .padding(horizontal = 12.dp, vertical = 8.dp), fontWeight = FontWeight.SemiBold)
            }
        }
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(22.dp)) {
            CoachAvatar(CoachMood.PROUD, 150.dp)
            Text(stringResource(R.string.ob_welcome_title), fontSize = 44.sp, lineHeight = 48.sp, fontWeight = FontWeight.Black, textAlign = TextAlign.Center)
            SectionCard {
                listOf("⏰" to R.string.ob_point_ring, "🧠" to R.string.ob_point_mission, "🔥" to R.string.ob_point_streaks).forEach { (icon, text) ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        Text(icon, fontSize = 20.sp); Text(stringResource(text), fontWeight = FontWeight.Medium)
                    }
                }
            }
            CoachBubble(context.text(OnboardingPersonalization.coachReaction(OnboardingStep.WELCOME, OnboardingAnswers())!!))
        }
    }
}

// MARK: Name

@Composable
fun NameStep(answers: OnboardingAnswers, update: (OnboardingAnswers) -> Unit, onNext: () -> Unit) {
    val context = LocalContext.current
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { if (answers.name.isEmpty()) runCatching { focus.requestFocus() } }
    OnboardingPage(stringResource(R.string.ob_name_title, CoachIdentity.NAME), stringResource(R.string.ob_name_subtitle), footer = {
        PrimaryButton(stringResource(R.string.ob_continue), enabled = answers.name.isNotBlank(), onClick = onNext)
        SecondaryLink(stringResource(R.string.ob_skip)) { update(answers.copy(name = "")); onNext() }
    }) {
        OutlinedTextField(answers.name, { update(answers.copy(name = it.take(30))) }, Modifier.fillMaxWidth().focusRequester(focus),
            placeholder = { Text(stringResource(R.string.ob_name_hint)) }, singleLine = true, textStyle = MaterialTheme.typography.titleLarge,
            shape = RoundedCornerShape(18.dp),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next),
            keyboardActions = KeyboardActions(onNext = { if (answers.name.isNotBlank()) onNext() }))
        CoachBubble(context.text(OnboardingPersonalization.coachReaction(OnboardingStep.NAME, answers)!!),
            if (answers.name.isEmpty()) CoachMood.SUSPICIOUS else CoachMood.PROUD)
    }
}

// MARK: Single / multi choice

/** A question with single-choice cards (iOS `SingleChoiceStep`). */
@Composable
fun <T> SingleChoiceStep(title: String, subtitle: String? = null, options: List<T>, selected: T?, label: (T) -> String, icon: (T) -> String,
                         coachLine: String? = null, onSelect: (T) -> Unit, onNext: () -> Unit) {
    OnboardingPage(title, subtitle, footer = { PrimaryButton(stringResource(R.string.ob_continue), enabled = selected != null, onClick = onNext) }) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            options.forEach { option -> ChoiceCard(label(option), icon(option), selected == option) { onSelect(option) } }
        }
        if (coachLine != null && selected != null) CoachBubble(coachLine)
    }
}

@Composable
fun StrugglesStep(answers: OnboardingAnswers, update: (OnboardingAnswers) -> Unit, onNext: () -> Unit) {
    val context = LocalContext.current
    OnboardingPage(stringResource(R.string.ob_struggles_title), stringResource(R.string.ob_struggles_subtitle), footer = {
        PrimaryButton(stringResource(R.string.ob_continue), enabled = answers.struggles.isNotEmpty(), onClick = onNext)
    }) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            MorningStruggle.choices.forEach { s ->
                val on = s in answers.struggles
                ChoiceCard(s.label(context), s.icon(), on, multiSelect = true) {
                    update(answers.copy(struggles = if (on) answers.struggles - s else answers.struggles + s))
                }
            }
        }
        if (answers.struggles.isNotEmpty()) OnboardingPersonalization.coachReaction(OnboardingStep.STRUGGLES, answers)?.let {
            CoachBubble(context.text(it), CoachMood.SUSPICIOUS)
        }
    }
}

// MARK: Why it works · wake time · comparison

@Composable
fun WhyItWorksStep(onNext: () -> Unit) = OnboardingPage(stringResource(R.string.ob_why_title), footer = {
    PrimaryButton(stringResource(R.string.ob_continue), onClick = onNext)
}) {
    EnergyChart()
    Text(stringResource(R.string.ob_why_body), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
fun WakeTimeStep(answers: OnboardingAnswers, update: (OnboardingAnswers) -> Unit, onNext: () -> Unit) {
    val context = LocalContext.current
    OnboardingPage(stringResource(R.string.ob_wake_title), footer = {
        PrimaryButton(stringResource(R.string.ob_continue), enabled = answers.weekdays.isNotEmpty(), onClick = onNext)
    }) {
        Text(answers.timeText, Modifier.fillMaxWidth(), fontSize = 76.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        WheelTimePicker(answers.hour, answers.minute, onChange = { h, m -> update(answers.copy(hour = h, minute = m)) })
        Text(stringResource(R.string.ob_on_these_days), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        WeekdayPicker(answers.weekdays) { update(answers.copy(weekdays = it)) }
        CoachBubble(context.text(OnboardingPersonalization.coachReaction(OnboardingStep.WAKE_TIME, answers)!!))
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun WeekdayPicker(selection: Set<Int>, onChange: (Set<Int>) -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        MONDAY_FIRST.forEach { day ->
            FilterChip(selected = day in selection, onClick = { onChange(if (day in selection) selection - day else selection + day) },
                label = { Text(weekdayName(day)) })
        }
    }
}

@Composable
fun ComparisonStep(answers: OnboardingAnswers, onNext: () -> Unit) =
    OnboardingPage(stringResource(R.string.ob_comparison_title), stringResource(R.string.ob_comparison_subtitle), footer = {
        PrimaryButton(stringResource(R.string.ob_continue), onClick = onNext)
    }) { AlarmComparison(answers.hour, answers.minute) }

// MARK: Permissions

/** Everything the alarm needs on Android; one Allow walks through them (iOS: Alarms + Notifications). */
@Composable
fun PermissionsStep(answers: OnboardingAnswers, onNext: () -> Unit) {
    val context = LocalContext.current
    var missing by remember { mutableStateOf(AlarmPermission.missing(context)) }
    var askedOnce by remember { mutableStateOf(false) }
    LifecycleResumeEffect(Unit) { missing = AlarmPermission.missing(context); onPauseOrDispose { } }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        missing = AlarmPermission.missing(context)
        missing.firstOrNull { it != AlarmPermission.NOTIFICATIONS }?.let { context.startActivity(it.settingsIntent(context)) }
    }
    fun allow() {
        askedOnce = true
        if (AlarmPermission.NOTIFICATIONS in missing && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else missing.firstOrNull()?.let { context.startActivity(it.settingsIntent(context)) }
    }
    val required = missing.filter { it != AlarmPermission.BATTERY }
    OnboardingPage(footer = {
        when {
            required.isEmpty() -> PrimaryButton(stringResource(R.string.ob_continue), onClick = onNext)
            askedOnce -> {
                PrimaryButton(stringResource(R.string.open_settings)) { required.first().let { context.startActivity(it.settingsIntent(context)) } }
                SecondaryLink(stringResource(R.string.ob_continue_anyway), onNext)
            }
            else -> PrimaryButton(stringResource(R.string.allow), onClick = ::allow)
        }
    }) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Text(stringResource(R.string.ob_perm_title, answers.timeText), Modifier.padding(top = 20.dp), style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Row(horizontalArrangement = Arrangement.spacedBy(22.dp)) {
                Badge(stringResource(R.string.perm_alarms_badge), "⏰", Orange, AlarmPermission.EXACT_ALARMS !in missing && AlarmPermission.FULL_SCREEN !in missing)
                Badge(stringResource(R.string.perm_notifications_title), "🔔", Color(0xFFE53935), AlarmPermission.NOTIFICATIONS !in missing)
            }
            PermissionIllustration()
            Text(stringResource(R.string.ob_perm_body), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
            if (AlarmPermission.BATTERY in missing && required.isEmpty()) {
                Text(stringResource(R.string.perm_battery_reason), Modifier.clickable { context.startActivity(AlarmPermission.BATTERY.settingsIntent(context)) },
                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary, textAlign = TextAlign.Center)
            }
        }
    }
}

@Composable
private fun Badge(title: String, icon: String, tint: Color, granted: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.size(34.dp).clip(RoundedCornerShape(9.dp)).background(if (granted) Color(0xFF34C759) else tint), contentAlignment = Alignment.Center) {
            Text(if (granted) "✓" else icon, color = Color.White, fontWeight = FontWeight.Bold)
        }
        Text(title, fontWeight = FontWeight.SemiBold)
    }
}

// MARK: Mission · setup · sound

@Composable
fun MissionStep(answers: OnboardingAnswers, update: (OnboardingAnswers) -> Unit, onNext: () -> Unit) {
    val context = LocalContext.current
    val selected = answers.chosenMissions.first().kind
    LaunchedEffect(Unit) { if (answers.missions == null) update(answers.copy(missions = listOf(MissionConfig(kind = answers.suggestedMission)))) }
    OnboardingPage(stringResource(R.string.ob_mission_title), stringResource(R.string.ob_mission_subtitle), footer = {
        PrimaryButton(stringResource(R.string.ob_continue), onClick = onNext)
    }) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ONBOARDING_KINDS.forEach { kind ->
                val duration = stringResource(if (kind == MissionKind.SHAKE) R.string.duration_30s else R.string.duration_1min)
                ChoiceCard(stringResource(kind.nameRes()), kind.emoji(), selected == kind,
                    subtitle = if (kind == answers.suggestedMission) stringResource(R.string.ob_suggested, duration) else stringResource(kind.taglineRes())) {
                    if (answers.missions?.firstOrNull()?.kind != kind) update(answers.copy(missions = listOf(MissionConfig(kind = kind))))
                }
            }
        }
        Text(stringResource(R.string.ob_more_missions), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        CoachBubble(context.text(OnboardingPersonalization.coachReaction(OnboardingStep.MISSION, answers)!!))
    }
}

@Composable
fun MissionSetupStep(answers: OnboardingAnswers, update: (OnboardingAnswers) -> Unit, onNext: () -> Unit) {
    val config = answers.chosenMissions.first()
    fun set(c: MissionConfig) = update(answers.copy(missions = listOf(c)))
    var setup by remember { mutableStateOf<SetupScreen?>(null) }
    val kind = config.kind
    val (title, subtitle) = when (kind) {
        MissionKind.MATH -> R.string.setup_math_title to R.string.setup_math_sub
        MissionKind.SHAKE -> R.string.setup_shake_title to R.string.setup_shake_sub
        MissionKind.QR -> R.string.setup_qr_title to R.string.setup_qr_sub
        MissionKind.OBJECT -> R.string.scan_your_item to R.string.setup_object_sub
        MissionKind.QUIZ -> R.string.setup_quiz_title to R.string.setup_quiz_sub
        MissionKind.MEMORY -> R.string.setup_memory_title to R.string.setup_memory_sub
        MissionKind.TYPING -> R.string.setup_typing_title to R.string.setup_typing_sub
        else -> kind.nameRes() to kind.taglineRes()
    }
    OnboardingPage(stringResource(title), stringResource(subtitle), footer = {
        if (kind.needsPayload && !config.isReady) {
            PrimaryButton(stringResource(R.string.ob_continue), enabled = false) {}
            SecondaryLink(stringResource(R.string.setup_later)) { set(MissionConfig(kind = MissionKind.MATH)); onNext() }
        } else PrimaryButton(stringResource(R.string.ob_continue), onClick = onNext)
    }) {
        when (kind) {
            MissionKind.MATH -> { DifficultyCards(config, ::set); CountCard(stringResource(R.string.problems_in_a_row), config, ::set) }
            MissionKind.SHAKE -> CountCard(stringResource(R.string.shakes), config, ::set)
            MissionKind.QUIZ -> { QuizTopicGrid(config.quizTopic) { set(config.withQuizTopic(it)) }; CountCard(stringResource(R.string.correct_answers), config, ::set) }
            MissionKind.MEMORY -> DifficultyCards(config, ::set)
            MissionKind.TYPING -> { DifficultyCards(config, ::set); CountCard(stringResource(R.string.tongue_twisters_count), config, ::set) }
            else -> SectionCard { MissionSetupRow(config) { setup = it } }
        }
    }
    setup?.let { screen -> MissionSetupDialog(screen, config, onDone = { set(it); setup = null }, onCancel = { setup = null }) }
}

@Composable
private fun DifficultyCards(config: MissionConfig, onChange: (MissionConfig) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        MissionDifficulty.entries.forEach { level ->
            val on = config.difficulty == level
            val example = when (config.kind) {
                MissionKind.MEMORY -> stringResource(R.string.pairs_n, config.copy(difficulty = level).memoryPairs)
                MissionKind.TYPING -> stringResource(when (level) { MissionDifficulty.EASY -> R.string.len_short; MissionDifficulty.MEDIUM -> R.string.len_medium; MissionDifficulty.HARD -> R.string.len_long })
                else -> when (level) { MissionDifficulty.EASY -> "5 + 9"; MissionDifficulty.MEDIUM -> "5 × 8 + 7"; MissionDifficulty.HARD -> "17 × 9 − 46" }
            }
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(if (on) Orange.copy(alpha = 0.14f) else MaterialTheme.colorScheme.surfaceContainerHigh)
                .border(2.5.dp, if (on) Orange else Color.Transparent, RoundedCornerShape(18.dp)).clickable { onChange(config.copy(difficulty = level)) }.padding(18.dp)) {
                Text(stringResource(level.nameRes()), Modifier.weight(1f), fontWeight = FontWeight.SemiBold)
                Text(example, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/** "Problems in a row  ⊖ 3 ⊕" (iOS `countCard`). */
@Composable
private fun CountCard(label: String, config: MissionConfig, onChange: (MissionConfig) -> Unit) {
    val range = config.kind.targetRange ?: return
    val step = config.kind.targetStep
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(18.dp),
        verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f), fontWeight = FontWeight.SemiBold)
        RoundIcon("−", config.target > range.first) { onChange(config.copy(target = maxOf(range.first, config.target - step))) }
        Text("${config.target}", Modifier.widthIn(min = 56.dp), fontSize = 28.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        RoundIcon("+", config.target < range.last) { onChange(config.copy(target = minOf(range.last, config.target + step))) }
    }
}

@Composable
private fun RoundIcon(symbol: String, enabled: Boolean, onClick: () -> Unit) =
    Box(Modifier.size(38.dp).clip(CircleShape).background(if (enabled) Orange else Orange.copy(alpha = 0.3f)).clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center) { Text(symbol, color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold) }

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun QuizTopicGrid(topic: QuizTopic, onPick: (QuizTopic) -> Unit) {
    val icons = mapOf(QuizTopic.GENERAL to "💡", QuizTopic.GEOGRAPHY to "🌍", QuizTopic.SCIENCE to "⚛️", QuizTopic.ANIMALS to "🐾",
        QuizTopic.HISTORY to "🏛️", QuizTopic.SPORTS to "🏟️", QuizTopic.MOVIES_MUSIC to "🎬", QuizTopic.FOOD to "🍴")
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        QuizTopic.entries.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { t ->
                    val on = t == topic
                    Text(icons[t] + "  " + stringResource(t.nameRes()), Modifier.weight(1f).clip(RoundedCornerShape(16.dp))
                        .background(if (on) Orange.copy(alpha = 0.14f) else MaterialTheme.colorScheme.surfaceContainerHigh)
                        .border(2.5.dp, if (on) Orange else Color.Transparent, RoundedCornerShape(16.dp)).clickable { onPick(t) }.padding(14.dp),
                        fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                }
            }
        }
    }
}

@Composable
fun SoundStep(answers: OnboardingAnswers, update: (OnboardingAnswers) -> Unit, onNext: () -> Unit) {
    val context = LocalContext.current
    var playing by remember { mutableStateOf<AlarmSound?>(null) }
    val player = remember { mutableStateOf<MediaPlayer?>(null) }
    fun stop() { player.value?.release(); player.value = null; playing = null }
    fun toggle(sound: AlarmSound) {
        val wasPlaying = playing == sound
        stop()
        if (wasPlaying) return
        playing = sound
        player.value = MediaPlayer().apply {
            setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build())
            setDataSource(context, RingService.soundUri(context, sound))
            setOnPreparedListener { it.start() }; setOnCompletionListener { playing = null }
            prepareAsync()
        }
    }
    DisposableEffect(Unit) { onDispose { stop() } }
    OnboardingPage(stringResource(R.string.ob_sound_title), stringResource(R.string.ob_sound_subtitle), footer = {
        PrimaryButton(stringResource(R.string.ob_continue)) { stop(); onNext() }
    }) {
        listOf(R.string.tones to AlarmSound.entries.filter { !it.isMelody }, R.string.melodies to AlarmSound.entries.filter { it.isMelody && it != AlarmSound.RISE_AND_CONQUER })
            .forEach { (title, sounds) ->
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(stringResource(title).uppercase(), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Column(Modifier.clip(RoundedCornerShape(20.dp)).background(MaterialTheme.colorScheme.surfaceContainerHigh)) {
                        sounds.forEachIndexed { i, sound ->
                            val selected = answers.sound.builtIn == sound
                            Row(Modifier.fillMaxWidth().clickable { toggle(sound); update(answers.copy(sound = SoundChoice.of(sound))) }
                                .padding(horizontal = 14.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Text(if (playing == sound) "🔊" else "▶️", fontSize = 20.sp)
                                Column(Modifier.weight(1f)) {
                                    Text(stringResource(sound.nameRes()))
                                    creditRes(sound)?.let { Text(stringResource(it), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                                }
                                Text(if (selected) "◉" else "○", fontSize = 20.sp, color = if (selected) Orange else MaterialTheme.colorScheme.outline)
                            }
                            if (i < sounds.lastIndex) HorizontalDivider(Modifier.padding(start = 56.dp))
                        }
                    }
                }
            }
    }
}

private fun creditRes(sound: AlarmSound): Int? = when (sound) {
    AlarmSound.REVEILLE -> R.string.credit_reveille; AlarmSound.MORNING_MOOD -> R.string.credit_morning_mood; AlarmSound.FUR_ELISE -> R.string.credit_fur_elise
    else -> null
}

// MARK: Building · summary

/** "Getting your mornings ready": a counter + checklist while the alarm is really created (iOS `BuildingStep`). */
@Composable
fun BuildingStep(answers: OnboardingAnswers, work: suspend () -> Unit, onNext: () -> Unit) {
    val context = LocalContext.current
    var percent by remember { mutableIntStateOf(0) }
    val mission = stringResource(answers.chosenMissions.first().kind.nameRes())
    val tasks = listOf(stringResource(R.string.build_alarm, answers.timeText), stringResource(R.string.build_loading, mission),
        stringResource(R.string.build_sound), stringResource(R.string.build_waking, CoachIdentity.NAME))
    val proof = remember { SocialProof.decode(be.gloop.app.data.AppContent(context).read("SocialProof.json")) }
    LaunchedEffect(Unit) {
        work()
        for (v in 1..100) { delay(if (v < 90) 32 else 60); percent = v }
        delay(400); onNext()
    }
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
        Spacer(Modifier.height(40.dp))
        Text("$percent%", fontSize = 88.sp, fontWeight = FontWeight.Black)
        Text(stringResource(R.string.build_title), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        LinearProgressIndicator(progress = { percent / 100f }, Modifier.fillMaxWidth().widthIn(max = 420.dp), color = Orange)
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            tasks.forEachIndexed { i, task ->
                val done = i < percent / 25
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(if (done) "✅" else "◌", color = if (done) Color(0xFF34C759) else MaterialTheme.colorScheme.outline)
                    Text(task, fontWeight = FontWeight.Medium, color = if (done) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        QuoteCarousel(proof)
    }
}

@Composable
fun SummaryStep(answers: OnboardingAnswers, onNext: () -> Unit) {
    val context = LocalContext.current
    val pop = remember { Animatable(0.4f) }
    LaunchedEffect(Unit) { pop.animateTo(1f, spring(dampingRatio = Spring.DampingRatioMediumBouncy)) }
    val nextDay = remember {
        answers.firstAlarm("").nextFireTime(System.currentTimeMillis())
            ?.let { java.time.Instant.ofEpochMilli(it).atZone(ZoneId.systemDefault()).toLocalDate() }
    }
    val whenText = when (nextDay) {
        null -> stringResource(R.string.sum_when)
        LocalDate.now() -> stringResource(R.string.sum_today)
        LocalDate.now().plusDays(1) -> stringResource(R.string.sum_tomorrow)
        else -> stringResource(R.string.sum_day, nextDay.dayOfWeek.getDisplayName(TextStyle.FULL, androidx.compose.ui.platform.LocalConfiguration.current.locales[0]).replaceFirstChar { it.uppercase() })
    }
    val proof = remember { SocialProof.decode(be.gloop.app.data.AppContent(context).read("SocialProof.json")) }
    OnboardingPage(footer = { PrimaryButton(stringResource(R.string.sum_ready), onClick = onNext) }) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
            Box(Modifier.padding(top = 12.dp).size(64.dp).scale(pop.value).clip(CircleShape).background(Orange), contentAlignment = Alignment.Center) {
                Text("✓", color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(whenText, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(answers.timeText, fontSize = 80.sp, fontWeight = FontWeight.Black)
                Text(context.text(OnboardingPersonalization.goalLine(answers.goal)), style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
            }
            val mission = answers.chosenMissions.first().kind
            SectionCard {
                listOf("🔔" to stringResource(R.string.sum_rings), mission.emoji() to stringResource(R.string.sum_complete, stringResource(mission.nameRes())),
                    "✓" to context.text(OnboardingPersonalization.finishLine(answers.goal))).forEachIndexed { i, (icon, text) ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Box(Modifier.size(44.dp).clip(CircleShape).background(Orange), contentAlignment = Alignment.Center) { Text(icon, color = Color.White, fontSize = 18.sp) }
                        Text(text, fontWeight = FontWeight.SemiBold)
                    }
                    if (i < 2) Box(Modifier.padding(start = 20.dp).size(3.dp, 18.dp).background(Orange.copy(alpha = 0.35f)))
                }
            }
            Text(stringResource(if (answers.weekdays.size == 7) R.string.sum_every_morning else R.string.sum_every_day),
                style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            WeekdayCircles(answers.weekdays)
            OnboardingPersonalization.hoursBackPerWeek(answers.getUpTime, answers.weekdays)?.let { hours ->
                val (number, plural) = OnboardingPersonalization.hoursBackNumber(hours)
                Text(stringResource(if (plural) R.string.sum_hours else R.string.sum_hour, number), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            SocialProofView(proof)
        }
    }
}
