package be.gloop.app.mission

import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import be.gloop.app.GloopApplication
import be.gloop.app.R
import be.gloop.app.alarm.RingService
import be.gloop.app.data.AppContent
import be.gloop.app.ui.GloopTheme
import be.gloop.app.ui.emoji
import be.gloop.app.ui.instruction
import be.gloop.app.ui.nameRes
import be.gloop.core.coach.MorningTip
import be.gloop.core.coach.MorningTips
import be.gloop.core.missions.MissionRun
import be.gloop.core.progress.StreakCalculator
import java.time.LocalDate

/**
 * The mission over the lock screen while the alarm rings (opened by the full-screen notification,
 * or by the launcher while a mission is due). Back does nothing until every mission is done.
 */
class MissionActivity : ComponentActivity() {
    override fun onResume() {
        super.onResume()
        RingService.setMissionVisible(this, true)
    }

    override fun onStop() {
        super.onStop()
        // Left without finishing: the alarm banner (and full-screen intent) comes back.
        if (!isFinishing) RingService.setMissionVisible(this, false)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        enableEdgeToEdge()
        val controller = GloopApplication.controller(this)
        controller.reloadSession()
        val plan = controller.activePlan
        if (plan == null || !controller.needsMission) { finish(); return }
        setContent {
            GloopTheme {
                Surface(Modifier.fillMaxSize()) {
                    var finished by remember { mutableStateOf(false) }
                    BackHandler(enabled = !finished) { /* no way out but the mission */ }
                    if (!finished) {
                        MissionFlow(MissionRun(plan.missions)) {
                            controller.missionSucceeded()
                            finished = true
                        }
                    } else {
                        SuccessScreen(onDone = { finish() })
                    }
                }
            }
        }
    }
}

@Composable
private fun MissionFlow(run: MissionRun, onFinished: () -> Unit) {
    val context = LocalContext.current
    var index by remember { mutableIntStateOf(run.index) }
    var backups by remember { mutableIntStateOf(0) }
    Column(
        Modifier.fillMaxSize().safeDrawingPadding().padding(20.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        @Suppress("UNUSED_EXPRESSION") backups // recompose after a backup swap
        val step = run.current ?: return@Column
        if (run.steps.size > 1) {
            Text(stringResource(R.string.step_of, index + 1, run.steps.size), style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary)
            LinearProgressIndicator(progress = { index / run.steps.size.toFloat() }, modifier = Modifier.fillMaxWidth())
        }
        Text(step.kind.emoji() + "  " + stringResource(step.kind.nameRes()), style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold)
        Text(step.instruction(context), style = MaterialTheme.typography.bodyLarge)
        AnimatedContent(targetState = index to backups, label = "step") { (current, _) ->
            val config = run.steps.getOrNull(current) ?: return@AnimatedContent
            androidx.compose.runtime.key(current, run.backedUp.contains(current)) {
                MissionStep(
                    config,
                    onSuccess = {
                        when (run.apply(MissionRun.Result.SUCCESS)) {
                            MissionRun.Outcome.FINISHED -> onFinished()
                            else -> index = run.index
                        }
                    },
                    // Can't do it (camera off, item gone, no sky): hard math instead, never a free pass.
                    onBackup = { run.apply(MissionRun.Result.NEEDS_BACKUP); backups++ },
                )
            }
        }
    }
}

@Composable
private fun SuccessScreen(onDone: () -> Unit) {
    val context = LocalContext.current
    val controller = GloopApplication.controller(context)
    val streak = remember {
        StreakCalculator.currentStreak(controller.dayLog.value.filter { it.missionDone }.map { LocalDate.parse(it.day) }, LocalDate.now())
    }
    val tip: MorningTip? = remember {
        val content = AppContent(context)
        MorningTips.pick(MorningTips.load(content, content.language), LocalDate.now())
    }
    Column(
        Modifier.fillMaxSize().safeDrawingPadding().padding(24.dp).verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Spacer(Modifier.height(24.dp))
        Text("✅", fontSize = 72.sp)
        Text(stringResource(R.string.mission_done), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(stringResource(R.string.youre_up), style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
        Text(
            if (streak > 1) "🔥 " + stringResource(R.string.streak_days, streak) else stringResource(R.string.streak_first),
            style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary, textAlign = TextAlign.Center,
        )
        tip?.let {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(stringResource(if (it.kind == MorningTip.Kind.QUOTE) R.string.quote_of_the_morning else R.string.tip_of_the_morning),
                        style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                    Text(if (it.kind == MorningTip.Kind.QUOTE) "“${it.text}”" else it.text, style = MaterialTheme.typography.bodyLarge,
                        fontStyle = if (it.kind == MorningTip.Kind.QUOTE) FontStyle.Italic else FontStyle.Normal)
                    it.author?.let { author -> Text("— $author", style = MaterialTheme.typography.bodyMedium) }
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        Button(onClick = onDone, modifier = Modifier.fillMaxWidth().height(56.dp)) {
            Text(stringResource(R.string.done), fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}
