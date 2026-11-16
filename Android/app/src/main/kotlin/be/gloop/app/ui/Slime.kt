package be.gloop.app.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import be.gloop.core.coach.CoachMood
import be.gloop.core.coach.SlimeColor
import be.gloop.core.coach.SlimeEyes
import be.gloop.core.coach.SlimeLook
import be.gloop.core.coach.SlimeMouth
import be.gloop.core.coach.SlimePose
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Gloop the slime, drawn in code (Compose port of iOS `SlimeRenderer` + `SlimeView`): droop and
 * expression from [SlimeLook], breathing bounce, sparkle twinkle, steam and trembling over time.
 */
@Composable
fun SlimeView(look: SlimeLook, size: Dp = 96.dp, color: SlimeColor = SlimeColor.ORANGE, animated: Boolean = true) {
    var time by remember { mutableFloatStateOf(0f) }
    if (animated) LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (true) withFrameNanos { time = (it - start) / 1e9f }
    }
    val droop by animateFloatAsState(look.pose.droop.toFloat(), spring(dampingRatio = 0.55f, stiffness = 60f), label = "droop")
    val px = with(LocalDensity.current) { size.toPx() }
    val t = time.toDouble()
    val squash = sin(t * 2.6) * look.bounce
    val dy = -abs(sin(t * 2.6)) * px * 0.02 * look.bounce * (1 - look.pose.droop)
    val dx = if (look.tremble > 0.3) sin(t * 42) * px * 0.025 * look.tremble * max(0.0, sin(t * 2.4)) else 0.0
    Canvas(Modifier.size(size).semantics { contentDescription = "Gloop" }) {
        translate(dx.toFloat(), dy.toFloat()) {
            drawSlime(look.pose.copy(droop = droop.toDouble()), color, squash, t)
        }
    }
}

/** Shortcut for the coach: Gloop in a mood (onboarding: lively, vitality 0.95). */
@Composable
fun CoachAvatar(mood: CoachMood, size: Dp, vitality: Double = 0.95) =
    SlimeView(remember(mood, vitality) { SlimeLook.make(vitality, mood) }, size)

private val INK = Color(0.16f, 0.09f, 0.14f)

private fun adjust(rgb: DoubleArray, saturation: Double, redness: Double): Color {
    val gray = 0.3 * rgb[0] + 0.59 * rgb[1] + 0.11 * rgb[2]
    val s = saturation.coerceIn(0.0, 1.0); val r = redness.coerceIn(0.0, 1.0)
    val red = doubleArrayOf(0.93, 0.22, 0.18)
    val out = DoubleArray(3) { i -> (gray + (rgb[i] - gray) * s).let { it + (red[i] - it) * r } }
    return Color(out[0].toFloat(), out[1].toFloat(), out[2].toFloat())
}

private fun DrawScope.drawSlime(pose: SlimePose, color: SlimeColor, squash: Double, time: Double) {
    val s = min(size.width, size.height)
    val ox = (size.width - s) / 2; val oy = (size.height - s) / 2
    val d = pose.droop.coerceIn(0.0, 1.0).toFloat()
    val c = ox + s * 0.5f
    val ground = oy + s * 0.88f
    val w = s * (0.70f + 0.26f * d) * (1 - 0.035f * squash.toFloat())
    val h = s * (0.62f - 0.38f * d) * (1 + 0.05f * squash.toFloat())
    val top = ground - h
    val light = adjust(color.top, pose.saturation, pose.redness)
    val deep = adjust(color.bottom, pose.saturation, pose.redness)

    // Contact shadow + puddle skirt when droopy.
    drawOval(Color.Black.copy(alpha = 0.14f), Offset(c - w * 0.55f, ground - s * 0.025f), Size(w * 1.1f, s * 0.06f))
    if (d > 0.45f) {
        val pw = w * (1f + 0.25f * (d - 0.45f) / 0.55f)
        drawOval(deep, Offset(c - pw / 2, ground - s * 0.045f), Size(pw, s * 0.07f))
    }

    val body = bodyPath(c, ground, w, h, d, s)
    drawPath(body, Brush.verticalGradient(listOf(light, deep), startY = top, endY = ground))
    clipPath(body) {
        drawPath(body, Brush.radialGradient(listOf(Color.Transparent, deep.copy(alpha = 0.55f)),
            center = Offset(c - w * 0.08f, top + h * 0.35f), radius = w * 0.75f))
        rotate(degrees = (-0.45 * 180 / PI).toFloat(), pivot = Offset(c - w * 0.22f, top + h * 0.2f)) {
            drawOval(Color.White.copy(alpha = 0.7f), Offset(c - w * 0.34f, top + h * 0.12f), Size(w * 0.24f, h * 0.16f))
        }
        drawOval(Color.White.copy(alpha = 0.8f), Offset(c - w * 0.08f, top + h * 0.09f), Size(s * 0.035f, s * 0.035f))
    }
    drawPath(body, deep.copy(alpha = 0.6f), style = Stroke(width = s * 0.01f))

    // Drips at the base.
    for (i in 0 until min(3, pose.drips)) {
        val side = if (i % 2 == 0) -1f else 1f
        val x = c + side * w * (0.36f + 0.06f * (i / 2))
        val r = s * (0.03f - 0.005f * i)
        drawPath(dropPath(x, ground - s * 0.01f, r, 2.6f, 1.1f, 1.2f), deep)
    }

    drawFace(pose, c, top, w, h, d, s)

    if (pose.sweat) {
        drawPath(dropPath(c + w * 0.36f, top + h * 0.22f, s * 0.035f, 1.8f, 1f, 1f), Color(0.55f, 0.8f, 1f, 0.9f))
    }
    if (pose.sparkle) {
        listOf(-0.42f to 0.05f, 0.40f to 0.0f, 0.30f to -0.12f).forEachIndexed { i, (sx, sy) ->
            val twinkle = (0.75 + 0.25 * sin(time * 3 + i * 2)).toFloat()
            star(Offset(c + w * sx, top + h * sy - s * 0.02f), s * (0.045f - 0.01f * i) * twinkle, Color(1f, 0.85f, 0.3f))
        }
    }
    if (pose.steam) {
        for (i in 0 until 3) {
            val phase = ((time * 0.7 + i / 3.0) % 1.0).toFloat()
            val r = s * (0.035f + 0.03f * phase)
            drawCircle(Color(0.85f, 0.85f, 0.85f, 0.85f * (1 - phase)), r,
                Offset(c + w * (-0.25f + 0.25f * i), top - s * 0.04f - s * 0.14f * phase))
        }
    }
}

private fun bodyPath(c: Float, ground: Float, w: Float, h: Float, d: Float, s: Float): Path {
    val top = ground - h
    val k = s * 0.06f
    val tip = s * 0.035f * (max(0f, 0.45f - d) / 0.45f)
    val belly = s * (0.05f + 0.03f * d)
    return Path().apply {
        moveTo(c, ground)
        lineTo(c - w / 2 + k, ground)
        quadraticTo(c - w / 2 - s * 0.01f, ground, c - w / 2, ground - k)
        cubicTo(c - w / 2 - belly, ground - h * 0.55f, c - w * 0.36f, top - tip * 0.3f, c, top - tip)
        cubicTo(c + w * 0.36f, top - tip * 0.3f, c + w / 2 + belly, ground - h * 0.55f, c + w / 2, ground - k)
        quadraticTo(c + w / 2 + s * 0.01f, ground, c + w / 2 - k, ground)
        close()
    }
}

/** Teardrop pointing up: tip at `y - r * tipK`, round bottom of radius r at y. */
private fun dropPath(x: Float, y: Float, r: Float, tipK: Float, ctrlX: Float, ctrlY: Float) = Path().apply {
    moveTo(x, y - r * tipK)
    quadraticTo(x + r * ctrlX, y - r * ctrlY, x + r, y)
    arcTo(Rect(x - r, y - r, x + r, y + r), 0f, 180f, false)
    quadraticTo(x - r * ctrlX, y - r * ctrlY, x, y - r * tipK)
    close()
}

private fun DrawScope.drawFace(pose: SlimePose, c: Float, top: Float, w: Float, h: Float, d: Float, s: Float) {
    val eyeY = top + h * (0.45f + 0.05f * d)
    val dx = min(w * 0.2f, s * 0.15f)
    val e = s * 0.12f * (1 - 0.25f * d)
    for (side in listOf(-1f, 1f)) {
        val x = c + side * dx
        when (pose.eyes) {
            SlimeEyes.SPARKLY, SlimeEyes.OPEN -> {
                val big = if (pose.eyes == SlimeEyes.SPARKLY) 1.12f else 1f
                drawOval(INK, Offset(x - e * 0.42f * big, eyeY - e * 0.5f * big), Size(e * 0.84f * big, e * big))
                drawCircle(Color.White, e * 0.17f, Offset(x - e * 0.13f, eyeY - e * 0.2f))
                if (pose.eyes == SlimeEyes.SPARKLY) drawCircle(Color.White, e * 0.08f, Offset(x + e * 0.14f, eyeY + e * 0.18f))
            }
            SlimeEyes.SLEEPY, SlimeEyes.TEARY -> {
                drawPath(Path().apply {
                    moveTo(x - e * 0.42f, eyeY); quadraticTo(x, eyeY + e * 0.55f, x + e * 0.42f, eyeY); close()
                }, INK)
                drawLine(INK, Offset(x - e * 0.48f, eyeY - e * 0.02f), Offset(x + e * 0.48f, eyeY - e * 0.02f), s * 0.012f, StrokeCap.Round)
                if (pose.eyes == SlimeEyes.TEARY) {
                    val tx = x + side * e * 0.35f; val ty = eyeY + e * 0.55f
                    drawPath(Path().apply {
                        moveTo(tx, ty - e * 0.25f)
                        quadraticTo(tx + e * 0.3f, ty + e * 0.2f, tx, ty + e * 0.25f)
                        quadraticTo(tx - e * 0.3f, ty + e * 0.2f, tx, ty - e * 0.25f)
                    }, Color(0.5f, 0.78f, 1f))
                }
            }
            SlimeEyes.SQUINT -> {
                drawOval(INK, Offset(x - e * 0.4f, eyeY - e * 0.12f), Size(e * 0.8f, e * 0.36f))
                drawLine(INK, Offset(x - side * e * 0.5f, eyeY - e * 0.62f), Offset(x + side * e * 0.45f, eyeY - e * 0.32f), s * 0.016f, StrokeCap.Round)
            }
        }
    }
    if (pose.blush) {
        for (side in listOf(-1f, 1f)) {
            val x = c + side * (dx + e * 0.45f)
            drawOval(Color(1f, 0.45f, 0.5f, 0.45f), Offset(x - e * 0.35f, eyeY + e * 0.42f), Size(e * 0.7f, e * 0.32f))
        }
    }
    val my = eyeY + e * 0.8f
    val mw = min(w * 0.2f, s * 0.14f)
    val stroke = Stroke(width = s * 0.014f, cap = StrokeCap.Round)
    when (pose.mouth) {
        SlimeMouth.GRIN -> {
            val mouth = Path().apply { moveTo(c - mw / 2, my - e * 0.05f); quadraticTo(c, my + e * 0.75f, c + mw / 2, my - e * 0.05f); close() }
            drawPath(mouth, INK)
            clipPath(mouth) { drawOval(Color(1f, 0.45f, 0.5f), Offset(c - mw * 0.25f, my + e * 0.2f), Size(mw * 0.5f, e * 0.4f)) }
        }
        SlimeMouth.SMILE -> drawPath(Path().apply { moveTo(c - mw * 0.4f, my); quadraticTo(c, my + e * 0.45f, c + mw * 0.4f, my) }, INK, style = stroke)
        SlimeMouth.FLAT -> drawLine(INK, Offset(c - mw * 0.28f, my + e * 0.1f), Offset(c + mw * 0.28f, my + e * 0.1f), s * 0.014f, StrokeCap.Round)
        SlimeMouth.FROWN -> drawPath(Path().apply { moveTo(c - mw * 0.35f, my + e * 0.3f); quadraticTo(c, my - e * 0.15f, c + mw * 0.35f, my + e * 0.3f) }, INK, style = stroke)
        SlimeMouth.OPEN -> drawOval(INK, Offset(c - mw * 0.22f, my - e * 0.05f), Size(mw * 0.44f, e * 0.55f))
    }
}

private fun DrawScope.star(p: Offset, r: Float, color: Color) {
    val path = Path()
    for (i in 0 until 8) {
        val angle = i * PI / 4 - PI / 2
        val radius = if (i % 2 == 0) r else r * 0.32f
        val x = p.x + (cos(angle) * radius).toFloat(); val y = p.y + (sin(angle) * radius).toFloat()
        if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
    }
    path.close()
    drawPath(path, color)
}
