package be.gloop.app.ui

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
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
import androidx.lifecycle.compose.LifecycleResumeEffect
import be.gloop.app.R
import be.gloop.app.alarm.AlarmController
import be.gloop.core.model.AlarmPlan
import be.gloop.core.progress.StreakCalculator
import java.time.LocalDate
import java.time.ZoneId

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun HomeScreen(controller: AlarmController, onEdit: (AlarmPlan?) -> Unit, onReplayOnboarding: () -> Unit = {}) {
    val context = LocalContext.current
    val plans by controller.plans.collectAsState()
    val dayLog by controller.dayLog.collectAsState()
    var missing by remember { mutableStateOf(AlarmPermission.missing(context)) }
    LifecycleResumeEffect(Unit) {
        missing = AlarmPermission.missing(context)
        controller.reloadSession()
        onPauseOrDispose { }
    }
    var menuOpen by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf<AlarmPlan?>(null) }
    val notificationLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        missing = AlarmPermission.missing(context)
    }
    // Ask for notifications once on first launch (Android 13+), like the iOS onboarding step.
    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && AlarmPermission.NOTIFICATIONS in missing) {
            notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
    val streak = remember(dayLog) {
        StreakCalculator.currentStreak(dayLog.filter { it.missionDone }.map { LocalDate.parse(it.day) }, LocalDate.now())
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.alarms), fontWeight = FontWeight.Bold) },
                actions = {
                    IconButton(onClick = { menuOpen = true }) { Text("⋯", fontSize = 22.sp) }
                    DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.test_ring_10s)) },
                            enabled = plans.isNotEmpty(),
                            onClick = {
                                menuOpen = false
                                (plans.firstOrNull { it.isEnabled } ?: plans.firstOrNull())?.let { controller.testRing(it.id) }
                            },
                        )
                        // Developer tool (debug builds only), like iOS Settings › Developer › Replay onboarding.
                        if (be.gloop.app.BuildConfig.DEBUG) DropdownMenuItem(
                            text = { Text(stringResource(R.string.replay_onboarding)) },
                            onClick = { menuOpen = false; onReplayOnboarding() },
                        )
                    }
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { onEdit(null) }, containerColor = MaterialTheme.colorScheme.primary) {
                Text("+", fontSize = 28.sp, color = MaterialTheme.colorScheme.onPrimary)
            }
        },
    ) { padding ->
        LazyColumn(
            Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item { NextAlarmHeader(controller, plans, streak) }
            if (missing.isNotEmpty()) {
                item {
                    PermissionCard(missing) { permission ->
                        // Android still shows its dialog after one "Don't allow"; after that only Settings works.
                        if (permission == AlarmPermission.NOTIFICATIONS && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            (context as androidx.activity.ComponentActivity).shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)) {
                            notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else {
                            context.startActivity(permission.settingsIntent(context))
                        }
                    }
                }
            }
            if (plans.isEmpty()) {
                item {
                    Text(stringResource(R.string.no_alarms), style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(vertical = 32.dp))
                }
            }
            items(plans, key = { it.id }) { plan ->
                Card(
                    Modifier.fillMaxWidth().combinedClickable(onClick = { onEdit(plan) }, onLongClick = { deleting = plan }),
                    colors = CardDefaults.cardColors(),
                ) {
                    Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(plan.timeText, fontSize = 36.sp, fontWeight = FontWeight.SemiBold,
                                color = if (plan.isEnabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant)
                            val label = plan.label.ifBlank { null }
                            Text(listOfNotNull(label, repeatText(context, plan)).joinToString(" · "), style = MaterialTheme.typography.bodyMedium)
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                plan.missions.forEach {
                                    Text(it.kind.emoji() + " " + stringResource(it.kind.nameRes()),
                                        style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                        Switch(checked = plan.isEnabled, onCheckedChange = { controller.setEnabled(plan.id, it) })
                    }
                }
            }
        }
    }

    deleting?.let { plan ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            title = { Text(stringResource(R.string.delete_this_alarm)) },
            text = { Text(plan.timeText + " · " + repeatText(context, plan)) },
            confirmButton = { TextButton(onClick = { controller.delete(plan.id); deleting = null }) { Text(stringResource(R.string.delete)) } },
            dismissButton = { TextButton(onClick = { deleting = null }) { Text(stringResource(R.string.cancel)) } },
        )
    }
}

@Composable
private fun NextAlarmHeader(controller: AlarmController, plans: List<AlarmPlan>, streak: Int) {
    val next = remember(plans) { controller.nextAlarm() }
    val session by controller.session.collectAsState()
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(stringResource(R.string.next_alarm), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
        if (next == null) {
            Text(stringResource(R.string.all_alarms_off), style = MaterialTheme.typography.titleMedium)
        } else {
            val time = java.time.Instant.ofEpochMilli(next.second).atZone(ZoneId.systemDefault())
            val formatter = java.time.format.DateTimeFormatter.ofPattern("EEEE HH:mm")
            Text(time.format(formatter).replaceFirstChar { it.uppercase() }, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        }
        if (streak > 0) Text("🔥 " + stringResource(R.string.streak_days, streak), style = MaterialTheme.typography.bodyMedium)
        if (session?.failSafeTriggered == true && session?.day == LocalDate.now().toString()) {
            Text(stringResource(R.string.fail_safe_hit), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
        }
    }
}

@Composable
private fun PermissionCard(missing: List<AlarmPermission>, onFix: (AlarmPermission) -> Unit) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stringResource(R.string.permissions), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            missing.forEach { permission ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(stringResource(permission.titleRes), fontWeight = FontWeight.SemiBold)
                        Text(stringResource(permission.reasonRes), style = MaterialTheme.typography.bodySmall)
                    }
                    Spacer(Modifier.width(8.dp))
                    FilledTonalButton(onClick = { onFix(permission) }) { Text(stringResource(R.string.allow)) }
                }
            }
        }
    }
}

