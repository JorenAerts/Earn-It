package be.gloop.app.mission

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import be.gloop.app.R
import be.gloop.app.data.AppContent
import be.gloop.core.missions.MathSession
import be.gloop.core.missions.MemoryGame
import be.gloop.core.missions.QuizBank
import be.gloop.core.missions.QuizSession
import be.gloop.core.missions.ShakeDetector
import be.gloop.core.missions.TongueTwisters
import be.gloop.core.missions.TypingCheck
import be.gloop.core.model.MissionConfig
import be.gloop.core.model.MissionKind
import be.gloop.core.random.SplitMix64
import kotlinx.coroutines.delay

/** One mission step; `onSuccess` when it's done. */
@Composable
fun MissionStep(config: MissionConfig, onSuccess: () -> Unit, onBackup: () -> Unit) {
    when (config.kind) {
        MissionKind.MATH -> MathMission(config, onSuccess)
        MissionKind.SHAKE -> ShakeMission(config, onSuccess)
        MissionKind.MEMORY -> MemoryMission(config, onSuccess)
        MissionKind.QUIZ -> QuizMission(config, onSuccess)
        MissionKind.TYPING -> TypingMission(config, onSuccess)
        MissionKind.QR -> QrMission(config, onSuccess, onBackup)
        MissionKind.SKY -> SkyMission(onSuccess, onBackup)
        MissionKind.COLOR_HUNT -> ColorHuntMission(config, onSuccess, onBackup)
        MissionKind.OBJECT, MissionKind.BED -> ReferenceMission(config, onSuccess, onBackup)
    }
}

private fun seed() = System.nanoTime()

@Composable
private fun MathMission(config: MissionConfig, onSuccess: () -> Unit) {
    val session = remember(config.id) { MathSession(config.target, config.difficulty, SplitMix64(seed())) }
    var input by remember { mutableStateOf("") }
    var version by remember { mutableIntStateOf(0) } // redraw after submit
    var wrong by remember { mutableStateOf(false) }
    key(version) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(stringResource(R.string.math_progress, session.correctInRow, session.target), style = MaterialTheme.typography.titleMedium)
            Text(session.problem.text, fontSize = 44.sp, fontWeight = FontWeight.Bold)
            Text(if (input.isEmpty()) "?" else input, fontSize = 36.sp,
                color = if (wrong) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary)
            NumberPad(
                onDigit = { if (input.length < 6) { input += it; wrong = false } },
                onMinus = { input = if (input.startsWith("-")) input.drop(1) else "-$input" },
                onDelete = { input = input.dropLast(1) },
                onSubmit = {
                    val value = input.toIntOrNull() ?: return@NumberPad
                    wrong = !session.submit(value)
                    input = ""
                    version++
                    if (session.isComplete) onSuccess()
                },
            )
        }
    }
}

@Composable
private fun key(version: Int, content: @Composable () -> Unit) = androidx.compose.runtime.key(version) { content() }

@Composable
private fun NumberPad(onDigit: (String) -> Unit, onMinus: () -> Unit, onDelete: () -> Unit, onSubmit: () -> Unit) {
    val rows = listOf(listOf("1", "2", "3"), listOf("4", "5", "6"), listOf("7", "8", "9"), listOf("−", "0", "⌫"))
    Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { key ->
                    FilledTonalButton(
                        onClick = { when (key) { "−" -> onMinus(); "⌫" -> onDelete(); else -> onDigit(key) } },
                        modifier = Modifier.weight(1f).height(60.dp),
                    ) { Text(key, fontSize = 24.sp) }
                }
            }
        }
        Button(onClick = onSubmit, modifier = Modifier.fillMaxWidth().height(56.dp)) {
            Text(stringResource(R.string.submit), fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun ShakeMission(config: MissionConfig, onSuccess: () -> Unit) {
    val context = LocalContext.current
    var count by remember { mutableIntStateOf(0) }
    val sensorManager = remember { context.getSystemService(SensorManager::class.java) }
    val accelerometer = remember { sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) }
    val threshold = ShakeDetector.threshold(config.difficulty)
    DisposableEffect(config.id) {
        val detector = ShakeDetector(threshold = threshold)
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val g = ShakeDetector.STANDARD_GRAVITY
                if (detector.process(event.values[0] / g, event.values[1] / g, event.values[2] / g, event.timestamp / 1e9)) {
                    count = detector.count
                    if (detector.count >= config.target) onSuccess()
                }
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        accelerometer?.let { sensorManager.registerListener(listener, it, SensorManager.SENSOR_DELAY_GAME) }
        onDispose { sensorManager?.unregisterListener(listener) }
    }
    val progress by animateFloatAsState(count.coerceAtMost(config.target) / config.target.toFloat(), label = "shake")
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Text("📳", fontSize = 80.sp)
        Text(stringResource(R.string.shake_your_phone), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text("${count.coerceAtMost(config.target)} / ${config.target}", fontSize = 40.sp, fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary)
        LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth().height(10.dp).clip(RoundedCornerShape(5.dp)))
        if (accelerometer == null) {
            Text(stringResource(R.string.no_accelerometer), color = MaterialTheme.colorScheme.error)
            OutlinedButton(onClick = onSuccess) { Text(stringResource(R.string.backup_mission)) } // no sensor: nothing to shake
        }
    }
}

@Composable
private fun MemoryMission(config: MissionConfig, onSuccess: () -> Unit) {
    val game = remember(config.id) { MemoryGame(config.memoryPairs, SplitMix64(seed())) }
    var cards by remember { mutableStateOf(game.cards) }
    var closing by remember { mutableStateOf(false) }
    LaunchedEffect(closing) {
        if (closing) { delay(700); game.closeMismatch(); cards = game.cards; closing = false }
    }
    val matched = cards.count { it.isMatched } / 2
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(stringResource(R.string.memory_progress, matched, config.memoryPairs), style = MaterialTheme.typography.titleMedium)
        // A plain grid (the mission screen scrolls; a lazy grid can't sit inside a scrolling column).
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            cards.chunked(4).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { card ->
                        val index = card.id
                        val up = card.isUp || card.isMatched
                        Box(
                            Modifier.weight(1f).aspectRatio(0.8f).clip(RoundedCornerShape(12.dp))
                                .background(when {
                                    card.isMatched -> MaterialTheme.colorScheme.primaryContainer
                                    up -> MaterialTheme.colorScheme.surfaceVariant
                                    else -> MaterialTheme.colorScheme.primary
                                })
                                .clickable(enabled = !closing && !up) {
                                    if (game.flip(index) == MemoryGame.FlipResult.MISMATCH) closing = true
                                    cards = game.cards
                                    if (game.isComplete) onSuccess()
                                },
                            contentAlignment = Alignment.Center,
                        ) { if (up) Text(card.face, fontSize = 30.sp) }
                    }
                    repeat(4 - row.size) { Box(Modifier.weight(1f)) {} }
                }
            }
        }
    }
}

@Composable
private fun QuizMission(config: MissionConfig, onSuccess: () -> Unit) {
    val context = LocalContext.current
    val session = remember(config.id) {
        val content = AppContent(context)
        QuizSession(QuizBank.load(content, content.language)[config.quizTopic].orEmpty(), config.target, SplitMix64(seed()))
    }
    var version by remember { mutableIntStateOf(0) }
    var feedback by remember { mutableStateOf<Boolean?>(null) }
    LaunchedEffect(feedback) { if (feedback != null) { delay(900); feedback = null } }
    val round = session.round
    if (round == null) { LaunchedEffect(Unit) { onSuccess() }; return }
    androidx.compose.runtime.key(version) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stringResource(R.string.quiz_progress, session.correct, session.target), style = MaterialTheme.typography.titleMedium)
            Text(round.question.question, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
            round.options.forEachIndexed { i, option ->
                OutlinedButton(
                    onClick = {
                        feedback = session.answer(i)
                        version++
                        if (session.isComplete) onSuccess()
                    },
                    enabled = feedback == null,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(option, Modifier.padding(vertical = 6.dp), textAlign = TextAlign.Center) }
            }
            feedback?.let {
                Text(if (it) "✅" else "❌", fontSize = 40.sp, modifier = Modifier.align(Alignment.CenterHorizontally))
            }
        }
    }
}

@Composable
private fun TypingMission(config: MissionConfig, onSuccess: () -> Unit) {
    val context = LocalContext.current
    val twisters = remember(config.id) {
        val content = AppContent(context)
        val list = TongueTwisters.load(content, content.language)[config.difficulty].orEmpty().ifEmpty { listOf("Gloop gets you up.") }
        val rng = SplitMix64(seed())
        List(config.target.coerceAtLeast(1)) { list[rng.nextInt(list.indices)] }
    }
    var index by remember { mutableIntStateOf(0) }
    var typed by remember { mutableStateOf("") }
    val target = twisters.getOrElse(index) { twisters.last() }
    val correct = TypingCheck.correctPrefix(typed, target)
    val total = TypingCheck.normalize(target).length
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("${index + 1} / ${twisters.size}", style = MaterialTheme.typography.titleMedium)
        Text("“$target”", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
        OutlinedTextField(
            value = typed,
            onValueChange = { text ->
                typed = text
                if (TypingCheck.matches(text, target)) {
                    if (index + 1 >= twisters.size) onSuccess() else { index++; typed = "" }
                }
            },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.type_it_here)) },
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
        )
        LinearProgressIndicator(progress = { if (total == 0) 0f else correct / total.toFloat() }, modifier = Modifier.fillMaxWidth())
        Text(stringResource(R.string.typing_hint), style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

