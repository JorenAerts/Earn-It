package be.gloop.app.ui

import android.media.AudioAttributes
import android.media.MediaPlayer
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import be.gloop.app.R
import be.gloop.app.alarm.RingService
import be.gloop.core.model.AlarmPlan
import be.gloop.core.model.AlarmSound
import be.gloop.core.model.MissionConfig
import be.gloop.core.model.MissionDifficulty
import be.gloop.core.model.MissionKind
import be.gloop.core.model.QuizTopic
import be.gloop.core.model.SoundChoice

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun EditorScreen(existing: AlarmPlan?, onSave: (AlarmPlan) -> Unit, onCancel: () -> Unit) {
    val context = LocalContext.current
    var plan by remember { mutableStateOf(existing ?: AlarmPlan(isEnabled = true)) }
    var editing by remember { mutableStateOf<Int?>(null) }   // index of the mission being edited
    var adding by remember { mutableStateOf(false) }
    var pickingSound by remember { mutableStateOf(false) }
    var settingUp by remember { mutableStateOf<Pair<Int, SetupScreen>?>(null) }  // mission index + setup screen
    BackHandler(onBack = onCancel)

    Scaffold(topBar = {
        TopAppBar(
            title = { Text(stringResource(if (existing == null) R.string.new_alarm else R.string.edit_alarm)) },
            navigationIcon = { TextButton(onClick = onCancel) { Text(stringResource(R.string.cancel)) } },
            actions = {
                TextButton(enabled = plan.isReady, onClick = { onSave(plan.copy(isEnabled = true)) }) {
                    Text(stringResource(R.string.save), fontWeight = FontWeight.SemiBold)
                }
            },
        )
    }) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            WheelTimePicker(plan.hour, plan.minute, onChange = { h, m -> plan = plan.copy(hour = h, minute = m) }, modifier = Modifier.padding(top = 8.dp))

            OutlinedTextField(plan.label, { plan = plan.copy(label = it.take(40)) }, Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.label_hint)) }, singleLine = true)

            Section(stringResource(R.string.repeat)) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    MONDAY_FIRST.forEach { day ->
                        FilterChip(
                            selected = day in plan.weekdays,
                            onClick = { plan = plan.copy(weekdays = if (day in plan.weekdays) plan.weekdays - day else plan.weekdays + day) },
                            label = { Text(weekdayName(day)) },
                        )
                    }
                }
                Text(repeatText(context, plan), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }

            Section(stringResource(R.string.missions)) {
                Text(stringResource(R.string.missions_order_hint), style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                plan.missions.forEachIndexed { index, mission ->
                    Card(Modifier.fillMaxWidth().clickable { editing = index }) {
                        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(mission.kind.emoji(), fontSize = 24.sp)
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text(stringResource(mission.kind.nameRes()), fontWeight = FontWeight.SemiBold)
                                Text(mission.summary(context), style = MaterialTheme.typography.bodySmall)
                            }
                            if (plan.missions.size > 1) {
                                IconButton(onClick = { plan = plan.copy(missions = plan.missions.filterIndexed { i, _ -> i != index }) }) {
                                    Text("✕", color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                    }
                }
                TextButton(onClick = { adding = true }) { Text("+ " + stringResource(R.string.add_mission)) }
            }

            if (!plan.isReady) {
                Text(stringResource(R.string.register_code_needed), color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium)
            }

            Section(stringResource(R.string.sound)) {
                Card(Modifier.fillMaxWidth().clickable { pickingSound = true }) {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("🔔", fontSize = 22.sp)
                        Spacer(Modifier.width(12.dp))
                        Text(stringResource(plan.sound.builtIn.nameRes()), Modifier.weight(1f), fontWeight = FontWeight.SemiBold)
                        Text("›", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                Text(stringResource(R.string.sound_keeps_playing), style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }

    if (adding) {
        // Full height + scrolling: all ten missions must be reachable on small phones.
        ModalBottomSheet(onDismissRequest = { adding = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
            Column(Modifier.verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(stringResource(R.string.add_mission), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                MissionKind.availableOnAndroid.forEach { kind ->
                    Card(Modifier.fillMaxWidth().clickable {
                        plan = plan.copy(missions = plan.missions + MissionConfig(kind = kind))
                        adding = false
                        // Opens the mission page; code / item / bed setup is right there (iOS: setup page).
                        editing = plan.missions.lastIndex
                    }) {
                        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(kind.emoji(), fontSize = 24.sp)
                            Spacer(Modifier.width(12.dp))
                            Column {
                                Text(stringResource(kind.nameRes()), fontWeight = FontWeight.SemiBold)
                                                Text(stringResource(kind.taglineRes()), style = MaterialTheme.typography.bodySmall)
                            }
                        }
                    }
                }
                Spacer(Modifier.padding(8.dp))
            }
        }
    }

    editing?.let { index ->
        val mission = plan.missions.getOrNull(index)
        if (mission != null) {
            ModalBottomSheet(onDismissRequest = { editing = null }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
                MissionSettings(mission, onSetUp = { screen -> editing = null; settingUp = index to screen }) { updated ->
                    plan = plan.copy(missions = plan.missions.toMutableList().also { it[index] = updated })
                }
                Spacer(Modifier.padding(16.dp))
            }
        }
    }

    settingUp?.let { (index, screen) ->
        plan.missions.getOrNull(index)?.let { mission ->
            MissionSetupDialog(
                screen, mission,
                onDone = { updated ->
                    plan = plan.copy(missions = plan.missions.toMutableList().also { it[index] = updated })
                    settingUp = null
                    editing = index // back to the mission page, now showing ✓
                },
                onCancel = { settingUp = null; editing = index },
            )
        }
    }

    if (pickingSound) {
        ModalBottomSheet(onDismissRequest = { pickingSound = false }) {
            SoundPicker(plan.sound.builtIn) { plan = plan.copy(sound = SoundChoice.of(it)) }
        }
    }
}

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        content()
    }
}

@Composable
private fun Box(modifier: Modifier, contentAlignment: Alignment, content: @Composable () -> Unit) =
    androidx.compose.foundation.layout.Box(modifier, contentAlignment = contentAlignment) { content() }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MissionSettings(mission: MissionConfig, onSetUp: (SetupScreen) -> Unit, onChange: (MissionConfig) -> Unit) {
    val context = LocalContext.current
    Column(Modifier.verticalScroll(rememberScrollState()).navigationBarsPadding().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(mission.kind.emoji() + "  " + stringResource(mission.kind.nameRes()),
            style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        Text(mission.instruction(context), style = MaterialTheme.typography.bodyMedium)
        if (mission.kind.needsPayload) MissionSetupRow(mission, onSetUp)
        if (mission.kind.usesDifficulty) {
            Text(stringResource(R.string.difficulty), fontWeight = FontWeight.SemiBold)
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                MissionDifficulty.entries.forEachIndexed { i, d ->
                    SegmentedButton(selected = mission.difficulty == d, onClick = { onChange(mission.copy(difficulty = d)) },
                        shape = SegmentedButtonDefaults.itemShape(i, MissionDifficulty.entries.size)) { Text(stringResource(d.nameRes())) }
                }
            }
        }
        mission.kind.targetRange?.let { range ->
            // "3 problems", "2 colors" (iOS `MissionKind.targetText`).
            val label = when (mission.kind) {
                MissionKind.MATH -> R.string.target_math
                MissionKind.SHAKE -> R.string.target_shake
                MissionKind.QUIZ -> R.string.target_quiz
                MissionKind.TYPING -> R.string.target_typing
                else -> R.string.summary_colors
            }
            Text(stringResource(label, mission.target), fontWeight = FontWeight.SemiBold)
            val steps = (range.last - range.first) / mission.kind.targetStep - 1
            Slider(
                value = mission.target.toFloat(),
                onValueChange = { v ->
                    val step = mission.kind.targetStep
                    onChange(mission.copy(target = ((v / step).toInt() * step).coerceIn(range)))
                },
                valueRange = range.first.toFloat()..range.last.toFloat(),
                steps = steps.coerceAtLeast(0),
            )
        }
        if (mission.kind == MissionKind.QUIZ) {
            Text(stringResource(R.string.topic), fontWeight = FontWeight.SemiBold)
            Column {
                QuizTopic.entries.forEach { topic ->
                    Row(Modifier.fillMaxWidth().clickable { onChange(mission.withQuizTopic(topic)) }, verticalAlignment = Alignment.CenterVertically) {
                        RadioButton(selected = mission.quizTopic == topic, onClick = { onChange(mission.withQuizTopic(topic)) })
                        Text(stringResource(topic.nameRes()))
                    }
                }
            }
        }
    }
}

@Composable
private fun SoundPicker(selected: AlarmSound, onPick: (AlarmSound) -> Unit) {
    val context = LocalContext.current
    var current by remember { mutableStateOf(selected) }
    val player = remember { mutableStateOf<MediaPlayer?>(null) }
    fun preview(sound: AlarmSound) {
        player.value?.release()
        player.value = MediaPlayer().apply {
            setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build())
            setDataSource(context, RingService.soundUri(context, sound))
            setOnPreparedListener { it.start() }
            prepareAsync()
        }
    }
    DisposableEffect(Unit) { onDispose { player.value?.release() } }
    Column(Modifier.padding(horizontal = 16.dp).verticalScroll(rememberScrollState())) {
        listOf(R.string.tones to AlarmSound.entries.filterNot { it.isMelody }, R.string.melodies to AlarmSound.entries.filter { it.isMelody })
            .forEach { (title, sounds) ->
                Text(stringResource(title), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = 12.dp, bottom = 4.dp))
                sounds.forEach { sound ->
                    Row(Modifier.fillMaxWidth().clickable { current = sound; onPick(sound); preview(sound) },
                        verticalAlignment = Alignment.CenterVertically) {
                        RadioButton(selected = current == sound, onClick = { current = sound; onPick(sound); preview(sound) })
                        Text(stringResource(sound.nameRes()))
                    }
                }
                HorizontalDivider(Modifier.padding(top = 8.dp))
            }
        Spacer(Modifier.padding(16.dp))
    }
}
