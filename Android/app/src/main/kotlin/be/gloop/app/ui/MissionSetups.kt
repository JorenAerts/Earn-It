package be.gloop.app.ui

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color as AColor
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import be.gloop.app.R
import be.gloop.app.camera.CameraState
import be.gloop.app.camera.CameraStatus
import be.gloop.app.camera.CameraView
import be.gloop.app.camera.Recognizers
import be.gloop.app.camera.ReferenceStore
import be.gloop.app.camera.forAnalysis
import be.gloop.app.mission.ReferenceMission
import be.gloop.app.mission.TorchButton
import be.gloop.core.camera.CodeMatcher
import be.gloop.core.camera.Embeddings
import be.gloop.core.camera.MatchRules
import be.gloop.core.model.MissionConfig
import be.gloop.core.model.MissionKind
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.concurrent.atomic.AtomicReference

/** Which full-screen setup to show for a mission (iOS: the sheets behind the setup row). */
enum class SetupScreen { QR_SCAN, QR_CREATE, ITEM, BED }

/**
 * The setup row inside the mission sheet (iOS `QRSetupRow` / `BedSetupRow` / item row): status
 * with a thumbnail, and the buttons that open the setup screens.
 */
@Composable
fun MissionSetupRow(mission: MissionConfig, onOpen: (SetupScreen) -> Unit) {
    val context = LocalContext.current
    val thumb = remember(mission.payload) { if (mission.kind == MissionKind.QR) null else ReferenceStore(context).thumbnail(mission.payload) }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            thumb?.let { Image(it.asImageBitmap(), null, Modifier.size(48.dp, 64.dp).clip(RoundedCornerShape(10.dp)), contentScale = ContentScale.Crop) }
            val ready = mission.isReady
            Text(
                (if (ready) "✓ " else "! ") + when (mission.kind) {
                    MissionKind.QR -> stringResource(if (ready) R.string.summary_code_registered else R.string.register_code_needed)
                    MissionKind.BED -> stringResource(if (ready) R.string.summary_bed_scanned else R.string.take_3)
                    else -> if (ready) mission.label ?: stringResource(R.string.summary_item_scanned) else stringResource(R.string.summary_no_item)
                },
                color = if (ready) Color(0xFF2E9E4F) else Color(0xFFE07A00), fontWeight = FontWeight.SemiBold,
            )
        }
        when (mission.kind) {
            MissionKind.QR -> Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = { onOpen(SetupScreen.QR_SCAN) }) { Text(stringResource(R.string.scan_existing)) }
                OutlinedButton(onClick = { onOpen(SetupScreen.QR_CREATE) }) { Text(stringResource(R.string.create_code)) }
            }
            MissionKind.BED -> Button(onClick = { onOpen(SetupScreen.BED) }) {
                Text(stringResource(if (mission.isReady) R.string.scan_again else R.string.scan_made_bed))
            }
            else -> Button(onClick = { onOpen(SetupScreen.ITEM) }) {
                Text(stringResource(if (mission.isReady) R.string.scan_again else R.string.scan_your_item))
            }
        }
    }
}

/** Full-screen setup with a title bar (Cancel · title · optional action), like an iOS sheet. */
@Composable
fun MissionSetupDialog(screen: SetupScreen, mission: MissionConfig, onDone: (MissionConfig) -> Unit, onCancel: () -> Unit) {
    Dialog(onDismissRequest = onCancel, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        Surface(Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize().safeDrawingPadding()) {
                when (screen) {
                    SetupScreen.QR_SCAN -> QrScanSetup(onCancel) { onDone(mission.copy(payload = it)) }
                    SetupScreen.QR_CREATE -> QrCreateSetup(onCancel) { onDone(mission.copy(payload = it)) }
                    SetupScreen.ITEM -> ItemSetup(mission, onCancel) { id, label -> onDone(mission.copy(payload = id, label = label)) }
                    SetupScreen.BED -> BedSetup(onCancel) { id, label -> onDone(mission.copy(payload = id, label = label)) }
                }
            }
        }
    }
}

@Composable
private fun TitleBar(title: String, leading: String, onLeading: () -> Unit, action: String? = null, onAction: () -> Unit = {}) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        TextButton(onClick = onLeading) { Text(leading) }
        Text(title, Modifier.weight(1f), textAlign = TextAlign.Center, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        if (action != null) TextButton(onClick = onAction) { Text(action, fontWeight = FontWeight.SemiBold) }
        else Spacer(Modifier.widthIn(min = 72.dp))
    }
}

@Composable
private fun Body(content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp), horizontalAlignment = Alignment.CenterHorizontally, content = content)
}

/** Camera with corners, flashlight and a busy spinner. */
@Composable
private fun SetupCamera(camera: CameraState, busy: Boolean = false, onFrame: (Bitmap) -> Unit) {
    Box(Modifier.fillMaxWidth().heightIn(max = 440.dp).aspectRatio(3f / 4f).clip(RoundedCornerShape(24.dp)).background(Color.Black)) {
        if (camera.status != CameraStatus.DENIED && camera.status != CameraStatus.UNAVAILABLE) CameraView(camera, 250, Modifier.fillMaxSize(), onFrame)
        Box(Modifier.fillMaxSize().padding(28.dp).border(3.dp, Color.White.copy(alpha = 0.8f), RoundedCornerShape(20.dp)))
        val message = when (camera.status) {
            CameraStatus.DENIED -> stringResource(R.string.camera_off)
            CameraStatus.UNAVAILABLE -> stringResource(R.string.no_camera)
            CameraStatus.ASKING, CameraStatus.STARTING -> stringResource(R.string.starting_camera)
            CameraStatus.RUNNING -> null
        }
        message?.let { Text(it, color = Color.White, textAlign = TextAlign.Center, modifier = Modifier.align(Alignment.Center).padding(24.dp)) }
        if (busy) CircularProgressIndicator(Modifier.align(Alignment.Center), color = Color.White)
        if (camera.torchAvailable) TorchButton(camera, Modifier.align(Alignment.TopEnd).padding(12.dp))
    }
}

// MARK: QR

@Composable
private fun QrScanSetup(onCancel: () -> Unit, onRegistered: (String) -> Unit) {
    val context = LocalContext.current
    val camera = remember { CameraState(context, "qrSetup") }
    var registered by remember { mutableStateOf(false) }
    TitleBar(stringResource(R.string.register_code), stringResource(R.string.cancel), onCancel)
    Body {
        Text(stringResource(R.string.qr_setup_body), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        // Registers the first code it sees and closes, like iOS.
        SetupCamera(camera) { bitmap ->
            Recognizers.codes(bitmap.forAnalysis(1080)).firstOrNull()?.let { code ->
                ContextCompat.getMainExecutor(context).execute { if (!registered) { registered = true; onRegistered(code) } }
            }
        }
    }
}

@Composable
private fun QrCreateSetup(onCancel: () -> Unit, onRegistered: (String) -> Unit) {
    val context = LocalContext.current
    val payload = remember { CodeMatcher.newPayload() }
    val bitmap = remember { qrBitmap(payload) }
    TitleBar(stringResource(R.string.your_code), stringResource(R.string.cancel), onCancel, stringResource(R.string.use_this_code)) { onRegistered(payload) }
    Body {
        Text(stringResource(R.string.code_print_hint), textAlign = TextAlign.Center, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Image(bitmap.asImageBitmap(), null, Modifier.widthIn(max = 260.dp).fillMaxWidth().aspectRatio(1f)
            .clip(RoundedCornerShape(16.dp)).background(Color.White).padding(16.dp))
        OutlinedButton(onClick = { shareImage(context, bitmap) }) { Text("⇪  " + stringResource(R.string.share_print)) }
    }
}

private fun qrBitmap(payload: String, size: Int = 900): Bitmap {
    val matrix = QRCodeWriter().encode(payload, BarcodeFormat.QR_CODE, size, size)
    val pixels = IntArray(size * size) { i -> if (matrix[i % size, i / size]) AColor.BLACK else AColor.WHITE }
    return Bitmap.createBitmap(pixels, size, size, Bitmap.Config.ARGB_8888)
}

private fun shareImage(context: android.content.Context, bitmap: Bitmap) {
    val file = File(context.cacheDir, "shared/gloop-code.png").apply { parentFile?.mkdirs() }
    file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
    val send = Intent(Intent.ACTION_SEND).setType("image/png").putExtra(Intent.EXTRA_STREAM, uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    context.startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

// MARK: Item (name → 5 shots → registered + test)

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ItemSetup(mission: MissionConfig, onCancel: () -> Unit, onSaved: (String, String) -> Unit) {
    val context = LocalContext.current
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val rules = MatchRules.ITEM
    var phase by remember { mutableStateOf(0) } // 0 name, 1 capture, 2 done
    var name by remember { mutableStateOf(mission.label.orEmpty()) }
    val prints = remember { mutableStateListOf<FloatArray>() }
    val shots = remember { mutableStateListOf<Bitmap>() }
    var problem by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    var savedId by remember { mutableStateOf<String?>(null) }
    var testing by remember { mutableStateOf(false) }
    val latest = remember { AtomicReference<Bitmap?>(null) }
    val camera = remember { CameraState(context, "objectSetup") }
    val prompts = listOf(R.string.prompt_front, R.string.prompt_left, R.string.prompt_right, R.string.prompt_other, R.string.prompt_above).map { stringResource(it) }
    val notFound = stringResource(R.string.item_not_found)
    val sameShot = stringResource(R.string.same_shot)

    TitleBar(stringResource(R.string.scan_your_item), stringResource(if (phase == 2) R.string.done else R.string.cancel), {
        if (phase == 2) savedId?.let { onSaved(it, name.trim()) } else onCancel()
    })
    when (phase) {
        0 -> Body {
            val focus = remember { FocusRequester() }
            LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
            Text(stringResource(R.string.pick_item), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Text(stringResource(R.string.item_tip), color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedTextField(name, { name = it.take(30) }, Modifier.fillMaxWidth().focusRequester(focus),
                placeholder = { Text(stringResource(R.string.item_name_hint)) }, singleLine = true)
            val suggestions = listOf(R.string.item_toothbrush, R.string.item_coffee, R.string.item_kettle, R.string.item_shoes, R.string.item_bottle, R.string.item_book).map { stringResource(it) }
            FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                suggestions.forEach { s -> SuggestionChip(onClick = { name = s }, label = { Text(s) }) }
            }
            Spacer(Modifier.height(12.dp))
            Button(onClick = { phase = 1 }, Modifier.fillMaxWidth().height(54.dp), enabled = name.isNotBlank()) {
                Text(stringResource(R.string.start_scanning), fontWeight = FontWeight.SemiBold)
            }
        }
        1 -> Body {
            SetupCamera(camera, busy) { latest.set(it) }
            Text(stringResource(R.string.shot_of, (prints.size + 1).coerceAtMost(rules.requiredShots), rules.requiredShots).uppercase(),
                style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Black, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(prompts[prints.size.coerceAtMost(prompts.lastIndex)], style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            problem?.let { Text(it, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center, fontSize = 14.sp) }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                repeat(rules.requiredShots) { i ->
                    Box(Modifier.size(46.dp).clip(RoundedCornerShape(10.dp)).background(MaterialTheme.colorScheme.surfaceVariant), contentAlignment = Alignment.Center) {
                        shots.getOrNull(i)?.let { Image(it.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop) }
                            ?: Text("📷", fontSize = 16.sp, color = Color.Gray)
                    }
                }
            }
            // The round shutter button, as on iOS.
            Box(
                Modifier.size(72.dp).clip(CircleShape).background(Color.White).border(5.dp, MaterialTheme.colorScheme.primary, CircleShape)
                    .clickable(enabled = camera.status == CameraStatus.RUNNING && !busy) {
                        val frame = latest.get() ?: return@clickable
                        busy = true; problem = null
                        scope.launch {
                            val result = withContext(Dispatchers.Default) {
                                Recognizers.itemCrop(frame.forAnalysis(960))?.let { crop -> Recognizers.embed(context, crop)?.let { crop to it } }
                            }
                            busy = false
                            if (result == null) { problem = notFound; haptics.performHapticFeedback(HapticFeedbackType.Reject); return@launch }
                            val (crop, print) = result
                            if (prints.isNotEmpty() && !rules.isDistinctShot(Embeddings.cosineDistance(print, prints.last()))) {
                                problem = sameShot; haptics.performHapticFeedback(HapticFeedbackType.Reject); return@launch
                            }
                            prints += print; shots += crop
                            haptics.performHapticFeedback(HapticFeedbackType.Confirm)
                            if (prints.size >= rules.requiredShots) {
                                val threshold = rules.threshold(Embeddings.pairwise(prints))
                                android.util.Log.d("GloopCamera", "item setup threshold=$threshold pairwise=${Embeddings.pairwise(prints)}")
                                savedId = ReferenceStore(context).save(prints.toList(), threshold, shots.first())
                                phase = 2
                            }
                        }
                    },
            )
        }
        else -> Body {
            Spacer(Modifier.height(24.dp))
            shots.firstOrNull()?.let {
                Image(it.asImageBitmap(), null, Modifier.size(140.dp).clip(RoundedCornerShape(24.dp)).background(MaterialTheme.colorScheme.surfaceVariant),
                    contentScale = ContentScale.Crop)
            }
            Text(stringResource(R.string.item_registered, name.trim()), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Text(stringResource(R.string.registered_body), textAlign = TextAlign.Center, color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedButton(onClick = { testing = true }) { Text(stringResource(R.string.test_recognition)) }
            Spacer(Modifier.height(24.dp))
            Button(onClick = { savedId?.let { onSaved(it, name.trim()) } }, Modifier.fillMaxWidth().height(54.dp)) {
                Text(stringResource(R.string.done), fontWeight = FontWeight.SemiBold)
            }
        }
    }
    if (testing) {
        val test = mission.copy(payload = savedId, label = name.trim())
        Dialog(onDismissRequest = { testing = false }, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
            Surface(Modifier.fillMaxSize()) {
                Column(Modifier.fillMaxSize().safeDrawingPadding()) {
                    var recognised by remember { mutableStateOf(false) }
                    var round by remember { mutableStateOf(0) }
                    TitleBar(stringResource(R.string.test), stringResource(R.string.close), { testing = false })
                    Body {
                        if (recognised) Text("✅ " + stringResource(R.string.recognised), style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold, color = Color(0xFF2E9E4F))
                        androidx.compose.runtime.key(round) {
                            ReferenceMission(test, onSuccess = { recognised = true; round++ }, onBackup = { testing = false })
                        }
                    }
                }
            }
        }
    }
}

// MARK: Bed (3 photos, saves by itself)

@Composable
private fun BedSetup(onCancel: () -> Unit, onSaved: (String, String) -> Unit) {
    val context = LocalContext.current
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val rules = MatchRules.BED
    val prints = remember { mutableStateListOf<FloatArray>() }
    var thumb by remember { mutableStateOf<Bitmap?>(null) }
    var problem by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val latest = remember { AtomicReference<Bitmap?>(null) }
    val camera = remember { CameraState(context, "bedSetup") }
    val prompts = listOf(R.string.bed_prompt_foot, R.string.bed_prompt_left, R.string.bed_prompt_right).map { stringResource(it) }
    val readFailed = stringResource(R.string.read_failed)
    val samePhoto = stringResource(R.string.same_photo)
    val bedLabel = stringResource(R.string.bed)

    TitleBar(stringResource(R.string.scan_made_bed), stringResource(R.string.cancel), onCancel)
    Body {
        Text(prompts[prints.size.coerceAtMost(prompts.lastIndex)], style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Text(stringResource(R.string.bed_setup_body), textAlign = TextAlign.Center, color = MaterialTheme.colorScheme.onSurfaceVariant)
        SetupCamera(camera, busy) { latest.set(it) }
        problem?.let { Text(it, color = Color(0xFFE07A00), textAlign = TextAlign.Center) }
        Text(stringResource(R.string.photo_of, (prints.size + 1).coerceAtMost(rules.requiredShots), rules.requiredShots),
            style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Button(
            onClick = {
                val frame = latest.get() ?: return@Button
                busy = true
                scope.launch {
                    val print = withContext(Dispatchers.Default) { Recognizers.embed(context, frame.forAnalysis(480)) }
                    busy = false
                    when {
                        print == null -> problem = readFailed
                        prints.isNotEmpty() && Embeddings.cosineDistance(print, prints.last()) < rules.minimumShotChange -> problem = samePhoto
                        else -> {
                            problem = null
                            if (prints.isEmpty()) thumb = frame
                            prints += print
                            haptics.performHapticFeedback(HapticFeedbackType.Confirm)
                            if (prints.size >= rules.requiredShots) {
                                val threshold = rules.threshold(Embeddings.pairwise(prints))
                                android.util.Log.d("GloopCamera", "bed setup threshold=$threshold pairwise=${Embeddings.pairwise(prints)}")
                                onSaved(ReferenceStore(context).save(prints.toList(), threshold, thumb), bedLabel)
                            }
                        }
                    }
                }
            },
            modifier = Modifier.fillMaxWidth().height(54.dp),
            enabled = camera.status == CameraStatus.RUNNING && !busy,
        ) { Text("📷  " + stringResource(R.string.take_photo), fontWeight = FontWeight.SemiBold) }
    }
}
