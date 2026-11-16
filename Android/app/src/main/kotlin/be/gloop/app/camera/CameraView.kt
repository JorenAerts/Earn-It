package be.gloop.app.camera

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Matrix
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.CaptureResult
import android.hardware.camera2.TotalCaptureResult
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import be.gloop.core.camera.AutoTorch
import be.gloop.core.camera.CameraDarkness
import be.gloop.core.camera.TorchMode
import java.util.concurrent.Executors

enum class CameraStatus { ASKING, DENIED, STARTING, RUNNING, UNAVAILABLE }

/** Live camera state for one screen: status, flashlight and the latest exposure. */
class CameraState(context: Context, private val torchKey: String?) {
    private val prefs = context.getSharedPreferences("gloop", Context.MODE_PRIVATE)
    var status by mutableStateOf(CameraStatus.ASKING)
    var hasTorch by mutableStateOf(false)
    var torchMode by mutableStateOf(prefs.getString("gloop.camera.torch", null)?.let { runCatching { TorchMode.valueOf(it.uppercase()) }.getOrNull() } ?: TorchMode.AUTO)
        private set
    var torchLit by mutableStateOf(false); private set
    var autoJustTurnedOn by mutableStateOf(false)
    internal var camera: Camera? = null
    private val auto = AutoTorch()
    @Volatile internal var iso: Int? = null
    @Volatile internal var exposureSeconds: Double? = null

    /** Flashlight available on this screen (none for the sky, none without a flash). */
    val torchAvailable: Boolean get() = torchKey != null && hasTorch && status == CameraStatus.RUNNING

    fun cycleTorch() {
        torchMode = torchMode.next
        prefs.edit().putString("gloop.camera.torch", torchMode.name.lowercase()).apply()
        apply()
    }

    /** One brightness reading per analysed frame (analysis thread). */
    internal fun reading(meanLuma: Double) {
        if (torchKey == null || torchMode != TorchMode.AUTO || auto.latched) return
        if (auto.record(CameraDarkness.isDark(iso, exposureSeconds, meanLuma))) {
            ContextCompat.getMainExecutor(prefsContext).execute { autoJustTurnedOn = true; apply() }
        }
    }

    private val prefsContext = context.applicationContext

    internal fun apply() {
        val on = torchKey != null && status == CameraStatus.RUNNING && (torchMode == TorchMode.ON || (torchMode == TorchMode.AUTO && auto.latched))
        torchLit = on
        camera?.takeIf { hasTorch }?.cameraControl?.enableTorch(on)
    }
}

/**
 * Back camera preview + frame analysis. `analyze` runs on a background thread with an upright
 * bitmap about every `intervalMs`. Asks for the camera permission itself.
 */
@Composable
fun CameraView(
    state: CameraState,
    intervalMs: Long,
    modifier: Modifier = Modifier,
    analyze: (Bitmap) -> Unit,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentAnalyze by rememberUpdatedState(analyze)
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        state.status = if (granted) CameraStatus.STARTING else CameraStatus.DENIED
    }
    LaunchedEffect(Unit) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            state.status = CameraStatus.STARTING
        } else launcher.launch(Manifest.permission.CAMERA)
    }
    val previewView = remember { PreviewView(context).apply { scaleType = PreviewView.ScaleType.FILL_CENTER } }
    Box(modifier) {
        AndroidView({ previewView }, Modifier.fillMaxSize())
    }
    if (state.status == CameraStatus.STARTING || state.status == CameraStatus.RUNNING) {
        DisposableEffect(lifecycleOwner) {
            val executor = Executors.newSingleThreadExecutor()
            var provider: ProcessCameraProvider? = null
            var lastRun = 0L
            val future = ProcessCameraProvider.getInstance(context)
            future.addListener({
                try {
                    val p = future.get().also { provider = it }
                    if (!p.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)) { state.status = CameraStatus.UNAVAILABLE; return@addListener }
                    val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
                    val analysisBuilder = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    exposureCallback(analysisBuilder, state)
                    val analysis = analysisBuilder.build()
                    analysis.setAnalyzer(executor) { proxy ->
                        val now = System.currentTimeMillis()
                        if (now - lastRun < intervalMs) { proxy.close(); return@setAnalyzer }
                        lastRun = now
                        val bitmap = try { proxy.toBitmap().rotated(proxy.imageInfo.rotationDegrees) } finally { proxy.close() }
                        state.reading(Recognizers.meanLuma(bitmap))
                        runCatching { currentAnalyze(bitmap) }.onFailure { Log.w("GloopCamera", "analyze failed", it) }
                    }
                    p.unbindAll()
                    val camera = p.bindToLifecycle(lifecycleOwner, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
                    state.camera = camera
                    state.hasTorch = camera.cameraInfo.hasFlashUnit()
                    state.status = CameraStatus.RUNNING
                    state.apply()
                } catch (e: Exception) {
                    Log.w("GloopCamera", "camera start failed", e)
                    state.status = CameraStatus.UNAVAILABLE
                }
            }, ContextCompat.getMainExecutor(context))
            onDispose {
                state.camera?.cameraControl?.enableTorch(false)
                state.camera = null
                provider?.unbindAll()
                executor.shutdown()
            }
        }
    }
}

/** ISO + exposure time from every capture, for "is it dark?" (Camera2 interop). */
@SuppressLint("UnsafeOptInUsageError")
private fun exposureCallback(builder: ImageAnalysis.Builder, state: CameraState) {
    Camera2Interop.Extender(builder).setSessionCaptureCallback(object : CameraCaptureSession.CaptureCallback() {
        override fun onCaptureCompleted(session: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
            state.iso = result.get(CaptureResult.SENSOR_SENSITIVITY)
            state.exposureSeconds = result.get(CaptureResult.SENSOR_EXPOSURE_TIME)?.let { it / 1e9 }
        }
    })
}

private fun Bitmap.rotated(degrees: Int): Bitmap =
    if (degrees == 0) this else Bitmap.createBitmap(this, 0, 0, width, height, Matrix().apply { postRotate(degrees.toFloat()) }, true)

/** Downscaled copy for the recognisers (they don't need full resolution). */
fun Bitmap.forAnalysis(maxSide: Int = 640): Bitmap {
    val scale = maxSide.toFloat() / maxOf(width, height)
    return if (scale >= 1f) this else Bitmap.createScaledBitmap(this, (width * scale).toInt(), (height * scale).toInt(), true)
}
