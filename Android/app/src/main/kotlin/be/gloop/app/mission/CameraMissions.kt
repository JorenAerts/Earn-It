package be.gloop.app.mission

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import be.gloop.app.R
import be.gloop.app.camera.CameraState
import be.gloop.app.camera.CameraStatus
import be.gloop.app.camera.CameraView
import be.gloop.app.camera.Recognizers
import be.gloop.app.camera.ReferenceStore
import be.gloop.app.camera.forAnalysis
import be.gloop.app.ui.nameRes
import be.gloop.core.camera.CodeMatcher
import be.gloop.core.camera.ColorMatch
import be.gloop.core.camera.ColorTarget
import be.gloop.core.camera.ConsecutiveHits
import be.gloop.core.camera.Embeddings
import be.gloop.core.camera.MatchRules
import be.gloop.core.camera.SkyPolicy
import be.gloop.core.camera.TorchMode
import be.gloop.core.model.MissionConfig
import be.gloop.core.model.MissionKind
import be.gloop.core.random.SplitMix64
import kotlinx.coroutines.delay

/** Main-thread hop for results coming from the analysis thread. */
private fun post(context: android.content.Context, block: () -> Unit) = ContextCompat.getMainExecutor(context).execute(block)

/**
 * Camera screen shared by the camera missions (iOS `CameraMissionScreen`): preview with corners,
 * flashlight, camera-off / no-camera overlays with the backup, a hint and a progress bar.
 */
@Composable
fun CameraMissionScreen(
    camera: CameraState,
    hint: String,
    progress: Float,
    matching: Boolean,
    onBackup: () -> Unit,
    wayOut: String? = null,
    showWayOutAfterSeconds: Int? = 0,
    intervalMs: Long = 300,
    header: @Composable () -> Unit = {},
    analyze: (android.graphics.Bitmap) -> Unit,
) {
    val context = LocalContext.current
    var elapsed by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) { while (true) { delay(1000); elapsed++ } }
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        header()
        Box(Modifier.fillMaxWidth().aspectRatio(3f / 4f).clip(RoundedCornerShape(24.dp)).background(Color.Black.copy(alpha = 0.85f))) {
            if (camera.status != CameraStatus.DENIED && camera.status != CameraStatus.UNAVAILABLE) {
                CameraView(camera, intervalMs, Modifier.fillMaxSize(), analyze)
            }
            Box(Modifier.fillMaxSize().padding(28.dp).border(3.dp, if (matching) Color(0xFF34C759) else Color.White.copy(alpha = 0.8f), RoundedCornerShape(20.dp)))
            when (camera.status) {
                CameraStatus.DENIED -> Overlay(stringResource(R.string.camera_off)) {
                    OutlinedButton(onClick = {
                        context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    }) { Text(stringResource(R.string.open_settings), color = Color.White) }
                    Button(onClick = onBackup) { Text(stringResource(R.string.backup_mission)) }
                }
                CameraStatus.UNAVAILABLE -> Overlay(stringResource(R.string.no_camera)) {
                    Button(onClick = onBackup) { Text(stringResource(R.string.backup_mission)) }
                }
                CameraStatus.ASKING, CameraStatus.STARTING -> Overlay(stringResource(R.string.starting_camera)) {}
                CameraStatus.RUNNING -> {}
            }
            if (camera.torchAvailable) TorchButton(camera, Modifier.align(Alignment.TopEnd).padding(12.dp))
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(hint, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth(),
                color = if (matching) Color(0xFF34C759) else MaterialTheme.colorScheme.primary)
        }
        if (wayOut != null && showWayOutAfterSeconds != null && elapsed >= showWayOutAfterSeconds) {
            TextButton(onClick = onBackup, modifier = Modifier.align(Alignment.CenterHorizontally)) { Text(wayOut, fontWeight = FontWeight.SemiBold) }
        }
    }
}

@Composable
private fun Overlay(message: String, buttons: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally) {
        Text(message, color = Color.White, textAlign = TextAlign.Center)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { buttons() }
    }
}

/** Round flashlight button + the "It's dark" notice (iOS `TorchButton`). */
@Composable
fun TorchButton(camera: CameraState, modifier: Modifier = Modifier) {
    val label = stringResource(when (camera.torchMode) { TorchMode.AUTO -> R.string.torch_auto; TorchMode.ON -> R.string.torch_on; TorchMode.OFF -> R.string.torch_off })
    LaunchedEffect(camera.autoJustTurnedOn) { if (camera.autoJustTurnedOn) { delay(2500); camera.autoJustTurnedOn = false } }
    Column(modifier, horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        TextButton(
            onClick = { camera.cycleTorch() },
            modifier = Modifier.size(52.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.45f)),
        ) {
            Text(when (camera.torchMode) { TorchMode.AUTO -> "⚡A"; TorchMode.ON -> "⚡"; TorchMode.OFF -> "⚡̸" },
                color = if (camera.torchLit) Color(0xFFFFD60A) else Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold)
        }
        Text(stringResource(R.string.flashlight, label), color = Color.White, fontSize = 11.sp,
            modifier = Modifier.background(Color.Black.copy(alpha = 0.45f), RoundedCornerShape(8.dp)).padding(horizontal = 6.dp, vertical = 2.dp))
        AnimatedVisibility(camera.autoJustTurnedOn) {
            Text(stringResource(R.string.torch_dark), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.background(Color.Black.copy(alpha = 0.6f), RoundedCornerShape(12.dp)).padding(horizontal = 10.dp, vertical = 6.dp))
        }
    }
}

@Composable
private fun rememberCamera(kind: MissionKind): CameraState {
    val context = LocalContext.current
    return remember { CameraState(context, if (kind in MissionKind.usesTorch) kind.rawValue else null) }
}

// MARK: Missions

@Composable
fun QrMission(config: MissionConfig, onSuccess: () -> Unit, onBackup: () -> Unit) {
    val context = LocalContext.current
    val camera = rememberCamera(MissionKind.QR)
    var wrong by remember { mutableStateOf(false) }
    var done by remember { mutableStateOf(false) }
    CameraMissionScreen(camera, when {
        done -> stringResource(R.string.object_done)
        wrong -> stringResource(R.string.qr_wrong)
        else -> stringResource(R.string.qr_point)
    }, if (done) 1f else 0f, done, onBackup, intervalMs = 250) { bitmap ->
        val codes = Recognizers.codes(bitmap.forAnalysis(1080))
        if (codes.isEmpty() || done) return@CameraMissionScreen
        val ok = codes.any { CodeMatcher.matches(it, config.payload) }
        post(context) { if (ok) { done = true; onSuccess() } else wrong = true }
    }
}

@Composable
fun SkyMission(onSuccess: () -> Unit, onBackup: () -> Unit) {
    val context = LocalContext.current
    val camera = rememberCamera(MissionKind.SKY)
    val hits = remember { ConsecutiveHits(SkyPolicy.REQUIRED_FRAMES) }
    var progress by remember { mutableFloatStateOf(0f) }
    var done by remember { mutableStateOf(false) }
    CameraMissionScreen(camera,
        when { done -> stringResource(R.string.sky_done); progress > 0 -> stringResource(R.string.sky_hold); else -> stringResource(R.string.sky_point) },
        progress, progress > 0, onBackup, wayOut = stringResource(R.string.sky_way_out), showWayOutAfterSeconds = 0,
        header = { Text(stringResource(R.string.sky_any), style = MaterialTheme.typography.bodySmall) }) { bitmap ->
        val score = SkyPolicy.score(Recognizers.labels(bitmap.forAnalysis()))
        post(context) {
            if (done) return@post
            hits.record(SkyPolicy.isSky(score)); progress = hits.progress.toFloat()
            android.util.Log.d("GloopCamera", "sky score=$score streak=${hits.streak}")
            if (hits.isComplete) { done = true; onSuccess() }
        }
    }
}

@Composable
fun ColorHuntMission(config: MissionConfig, onSuccess: () -> Unit, onBackup: () -> Unit) {
    val context = LocalContext.current
    val camera = rememberCamera(MissionKind.COLOR_HUNT)
    val targets = remember { ColorMatch.targets(config.target, SplitMix64(System.nanoTime())) }
    var index by remember { mutableIntStateOf(0) }
    val hits = remember { ConsecutiveHits(ColorMatch.REQUIRED_FRAMES) }
    var streak by remember { mutableIntStateOf(0) }
    val target = targets[index.coerceAtMost(targets.lastIndex)]
    val done = index >= targets.size
    CameraMissionScreen(camera,
        when { done -> stringResource(R.string.color_done); streak > 0 -> stringResource(R.string.hold_still); else -> stringResource(R.string.color_fill) },
        (index + hits.progress.toFloat()) / targets.size, streak > 0, onBackup,
        wayOut = stringResource(R.string.backup_after), showWayOutAfterSeconds = MissionKind.COLOR_HUNT.backupAfterSeconds,
        header = {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(28.dp).clip(CircleShape).background(swatch(target)))
                Text(stringResource(R.string.color_find, stringResource(target.nameRes())), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text("${(index + 1).coerceAtMost(targets.size)} / ${targets.size}", style = MaterialTheme.typography.bodyMedium)
            }
        }) { bitmap ->
        val (h, s, b) = Recognizers.centerColor(bitmap)
        post(context) {
            if (index >= targets.size) return@post
            hits.record(ColorMatch.matches(h, s, b, targets[index])); streak = hits.streak
            if (hits.isComplete) { hits.reset(); streak = 0; index++; if (index >= targets.size) onSuccess() }
        }
    }
}

fun ColorTarget.nameRes(): Int = when (this) {
    ColorTarget.RED -> R.string.color_red; ColorTarget.ORANGE -> R.string.color_orange; ColorTarget.YELLOW -> R.string.color_yellow
    ColorTarget.GREEN -> R.string.color_green; ColorTarget.BLUE -> R.string.color_blue; ColorTarget.PURPLE -> R.string.color_purple
    ColorTarget.PINK -> R.string.color_pink
}

private fun swatch(t: ColorTarget) = Color.hsv(t.hueCenter.toFloat(), if (t == ColorTarget.PINK) 0.45f else 0.85f, 0.95f)

/** Scan your item / made bed: embeddings vs. the registered reference (iOS item + bed missions). */
@Composable
fun ReferenceMission(config: MissionConfig, onSuccess: () -> Unit, onBackup: () -> Unit) {
    val context = LocalContext.current
    val isBed = config.kind == MissionKind.BED
    val rules = if (isBed) MatchRules.BED else MatchRules.ITEM
    val camera = rememberCamera(config.kind)
    val reference = remember { ReferenceStore(context).load(config.payload) }
    val hits = remember { ConsecutiveHits(rules.requiredFrames) }
    var streak by remember { mutableIntStateOf(0) }
    var closeness by remember { mutableFloatStateOf(0f) }
    var inView by remember { mutableStateOf(isBed) }
    var done by remember { mutableStateOf(false) }
    if (reference == null) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stringResource(if (isBed) R.string.bed_missing else R.string.item_missing))
            Button(onClick = onBackup) { Text(stringResource(R.string.backup_mission)) }
        }
        return
    }
    val label = config.label?.takeIf { it.isNotBlank() }?.let { if (java.util.Locale.getDefault().language == "de") it else it.lowercase() }
        ?: stringResource(R.string.mission_object).lowercase()
    val hint = when {
        done -> stringResource(if (isBed) R.string.bed_done else R.string.object_done)
        streak > 0 -> stringResource(R.string.hold_still)
        isBed && closeness > 0.3f -> stringResource(R.string.bed_almost)
        isBed -> stringResource(R.string.bed_point)
        !inView -> stringResource(R.string.object_point, label)
        closeness > 0.5f -> stringResource(R.string.object_closer)
        else -> stringResource(R.string.object_not, label)
    }
    CameraMissionScreen(camera, hint, if (done) 1f else hits.progress.toFloat(), streak > 0, onBackup,
        wayOut = stringResource(R.string.backup_after), showWayOutAfterSeconds = config.kind.backupAfterSeconds, intervalMs = 250) { bitmap ->
        // Item: compare only the item cut out of the frame (like iOS); bed: the whole frame.
        val source = if (isBed) bitmap.forAnalysis(480) else Recognizers.itemCrop(bitmap.forAnalysis(960))
        if (source == null) {
            post(context) { if (!done) { inView = false; hits.record(false); streak = 0; closeness = 0f } }
            return@CameraMissionScreen
        }
        val frame = Recognizers.embed(context, source) ?: return@CameraMissionScreen
        val distance = Embeddings.nearest(frame, reference.first) ?: return@CameraMissionScreen
        android.util.Log.d("GloopCamera", "${config.kind.rawValue} distance=${"%.3f".format(distance)} threshold=${"%.3f".format(reference.second)}")
        post(context) {
            if (done) return@post
            inView = true
            hits.record(rules.isMatch(distance, reference.second)); streak = hits.streak
            closeness = rules.closeness(distance, reference.second).toFloat()
            if (hits.isComplete) { done = true; onSuccess() }
        }
    }
}

