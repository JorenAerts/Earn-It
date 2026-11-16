package be.gloop.app.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import be.gloop.app.R
import be.gloop.app.ui.CoachAvatar
import be.gloop.core.coach.CoachMood
import be.gloop.core.onboarding.SocialProof
import kotlinx.coroutines.delay

val Orange = Color(0xFFFF8A2B)

/** Step layout (iOS `OnboardingPage`): big title + subtitle, scrolling content, footer pinned at the bottom. */
@Composable
fun OnboardingPage(
    title: String? = null,
    subtitle: String? = null,
    footer: @Composable ColumnScope.() -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 22.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)) {
            title?.let { Text(it, style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold) }
            subtitle?.let { Text(it, Modifier.offset(y = (-8).dp), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            content()
        }
        Column(Modifier.fillMaxWidth().padding(start = 22.dp, end = 22.dp, top = 8.dp, bottom = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp), horizontalAlignment = Alignment.CenterHorizontally, content = footer)
    }
}

/** Orange capsule button (iOS `PrimaryButton`). */
@Composable
fun PrimaryButton(title: String, enabled: Boolean = true, onClick: () -> Unit) {
    Button(onClick, Modifier.fillMaxWidth().height(54.dp), enabled = enabled, shape = CircleShape,
        colors = ButtonDefaults.buttonColors(containerColor = Orange, contentColor = Color.White)) {
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun SecondaryLink(title: String, onClick: () -> Unit) {
    Text(title, Modifier.clickable(onClick = onClick).padding(8.dp), color = MaterialTheme.colorScheme.onSurfaceVariant,
        style = MaterialTheme.typography.bodyLarge)
}

/** One answer: icon circle, label, radio / checkbox, orange border when picked (iOS `ChoiceCard`). */
@Composable
fun ChoiceCard(title: String, icon: String, selected: Boolean, subtitle: String? = null, multiSelect: Boolean = false,
               badge: String? = null, onClick: () -> Unit) {
    val haptics = LocalHapticFeedback.current
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    Row(
        Modifier.fillMaxWidth().scale(if (pressed) 0.97f else 1f).clip(RoundedCornerShape(22.dp))
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .border(2.5.dp, if (selected) Orange else Color.Transparent, RoundedCornerShape(22.dp))
            .clickable(interaction, indication = null) { haptics.performHapticFeedback(HapticFeedbackType.SegmentTick); onClick() }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(Modifier.size(46.dp).clip(CircleShape).background(if (selected) Orange else Orange.copy(alpha = 0.13f)), contentAlignment = Alignment.Center) {
            Text(icon, fontSize = 21.sp)
        }
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
                badge?.let { Text(it, Modifier.background(Orange, CircleShape).padding(horizontal = 6.dp, vertical = 2.dp), color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Black) }
            }
            subtitle?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        val mark = if (multiSelect) (if (selected) "☑" else "☐") else (if (selected) "◉" else "○")
        Text(mark, fontSize = 22.sp, color = if (selected) Orange else MaterialTheme.colorScheme.outline)
    }
}

/** Gloop commenting on the answers: the slime + a speech bubble with a tail (iOS `CoachBubble`). */
@Composable
fun CoachBubble(line: String, mood: CoachMood = CoachMood.PROUD) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        CoachAvatar(mood, 54.dp)
        val px = androidx.compose.ui.platform.LocalDensity.current.density
        val bubble = remember(px) {
            GenericShape { size, _ ->
                addRoundRect(RoundRect(0f, 0f, size.width, size.height, CornerRadius(16 * px)))
                moveTo(0f, size.height - 14 * px); lineTo(-8 * px, size.height - 4 * px); lineTo(12 * px, size.height - 2 * px); close()
            }
        }
        androidx.compose.animation.AnimatedContent(line, label = "coach") { text ->
            Text(text, Modifier.background(Orange.copy(alpha = 0.14f), bubble).padding(horizontal = 14.dp, vertical = 10.dp),
                style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
        }
    }
}

/** Morning energy: snoozing (red zig-zag in the groggy zone) vs. one clean wake-up (orange) — iOS `EnergyChart`. */
@Composable
fun EnergyChart() {
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) { progress.animateTo(1f, tween(1800, easing = FastOutSlowInEasing)) }
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(stringResource(R.string.chart_energy), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        BoxWithConstraints(Modifier.fillMaxWidth().height(190.dp)) {
            val red = Color(0xFFE53935)
            Canvas(Modifier.fillMaxSize()) {
                val w = size.width; val h = size.height
                drawRect(red.copy(alpha = 0.06f), Offset(0f, h * 0.65f), androidx.compose.ui.geometry.Size(w, h * 0.35f))
                val snooze = Path().apply {
                    moveTo(0f, h * 0.92f)
                    for (i in 0 until 3) {
                        val x0 = w * (0.05f + i * 0.2f)
                        quadraticTo(x0 + w * 0.03f, h * 0.5f, x0 + w * 0.08f, h * (0.45f + i * 0.08f))
                        quadraticTo(x0 + w * 0.12f, h * 0.9f, x0 + w * 0.17f, h * 0.9f)
                    }
                    cubicTo(w * 0.75f, h * 0.92f, w * 0.85f, h * 0.8f, w * 0.98f, h * 0.6f)
                }
                val gloop = Path().apply { moveTo(0f, h * 0.92f); cubicTo(w * 0.25f, h * 0.92f, w * 0.4f, h * 0.35f, w * 0.62f, h * 0.18f) }
                fun trimmed(p: Path): Path { val m = PathMeasure(); m.setPath(p, false); return Path().also { m.getSegment(0f, m.length * progress.value, it, true) } }
                drawPath(trimmed(snooze), red.copy(alpha = 0.75f), style = Stroke(3.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
                drawPath(trimmed(gloop), Orange, style = Stroke(5.dp.toPx(), cap = StrokeCap.Round))
            }
            Text(stringResource(R.string.chart_groggy), Modifier.align(Alignment.BottomEnd).padding(end = 6.dp, bottom = 6.dp),
                color = red.copy(alpha = 0.6f), fontSize = 10.sp, fontWeight = FontWeight.Black)
            Text("Gloop", Modifier.offset(x = maxWidth * 0.64f, y = maxHeight * 0.06f).background(Orange, CircleShape).padding(horizontal = 8.dp, vertical = 3.dp)
                .let { if (progress.value > 0.6f) it else it.scale(0f) }, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.chart_snooze_cycle), Modifier.align(Alignment.BottomStart).offset(x = maxWidth * 0.3f)
                .background(MaterialTheme.colorScheme.surface, CircleShape).padding(horizontal = 8.dp, vertical = 3.dp), color = red, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Legend(Color(0xFFE53935), stringResource(R.string.chart_snoozing)); Legend(Orange, stringResource(R.string.chart_one_alarm))
        }
    }
}

@Composable
private fun Legend(color: Color, text: String) = Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
    Box(Modifier.size(8.dp).clip(CircleShape).background(color)); Text(text, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

/** "Normal alarm" (four alarms, all on) vs. Gloop (one alarm with a mission) — iOS `AlarmComparison`. */
@Composable
fun AlarmComparison(hour: Int, minute: Int) {
    var shown by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) { for (i in 1..4) { delay(420); shown = i } }
    fun time(plus: Int): String { val t = (hour * 60 + minute + plus) % (24 * 60); return "%02d:%02d".format(t / 60, t % 60) }
    val red = Color(0xFFE53935)
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f).clip(RoundedCornerShape(22.dp)).background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(stringResource(R.string.cmp_normal), fontWeight = FontWeight.SemiBold)
            listOf(R.string.cmp_first, R.string.cmp_second, R.string.cmp_third, R.string.cmp_fourth).forEachIndexed { i, label ->
                AlarmTile(stringResource(label), time(i * 5), shown > i, red)
            }
        }
        Column(Modifier.weight(1f).clip(RoundedCornerShape(22.dp)).background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Gloop", fontWeight = FontWeight.SemiBold)
            AlarmTile(stringResource(R.string.cmp_with_mission), time(0), shown > 0, Orange)
            AnimatedVisibility(shown >= 4, enter = fadeIn()) {
                Text("✔ " + stringResource(R.string.cmp_rings_until), color = Orange, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun AlarmTile(label: String, time: String, on: Boolean, tint: Color) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.surfaceContainerHighest).padding(10.dp),
        verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(label, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
            Text(time, fontSize = 19.sp, fontWeight = FontWeight.Bold)
        }
        Box(Modifier.size(36.dp, 22.dp).clip(CircleShape).background(if (on) tint else Color(0xFFD1D1D6)).padding(2.dp),
            contentAlignment = if (on) Alignment.CenterEnd else Alignment.CenterStart) {
            Box(Modifier.size(18.dp).clip(CircleShape).background(Color.White))
        }
    }
}

/** Mock Android permission dialog with a tapping finger (iOS `PermissionIllustration`, Android style). */
@Composable
fun PermissionIllustration() {
    val pulse by rememberInfiniteTransition(label = "pulse").animateFloat(0f, 1f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "p")
    Column(Modifier.widthIn(max = 300.dp).fillMaxWidth().clip(RoundedCornerShape(28.dp)).background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(22.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("🔔", fontSize = 24.sp)
        Text(stringResource(R.string.ob_perm_mock_title), textAlign = TextAlign.Center, style = MaterialTheme.typography.titleMedium)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.ob_perm_dont_allow), color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 12.dp))
            Box(contentAlignment = Alignment.Center) {
                Box(Modifier.size(64.dp).scale(0.85f + 0.25f * pulse).border(3.dp, Color(0xFF1A73E8).copy(alpha = 0.9f - 0.7f * pulse), CircleShape))
                Text(stringResource(R.string.allow), color = Color(0xFF1A73E8), fontWeight = FontWeight.SemiBold)
                Text("👆", Modifier.offset(x = 14.dp, y = (30 - 8 * pulse).dp), fontSize = 30.sp)
            }
        }
    }
}

/** M T W T F S S circles, filled on alarm days (iOS `WeekdayCircles`). */
@Composable
fun WeekdayCircles(weekdays: Set<Int>) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        be.gloop.app.ui.MONDAY_FIRST.forEach { day ->
            val on = day in weekdays
            Box(Modifier.size(38.dp).clip(CircleShape).background(if (on) Orange else Color.Transparent)
                .border(2.dp, if (on) Orange else MaterialTheme.colorScheme.outline.copy(alpha = 0.5f), CircleShape), contentAlignment = Alignment.Center) {
                Text(be.gloop.app.ui.weekdayName(day, style = java.time.format.TextStyle.NARROW), fontWeight = FontWeight.Bold,
                    color = if (on) Color.White else MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/** Real numbers from `SocialProof.json`; nothing while it's empty. */
@Composable
fun SocialProofView(proof: SocialProof) {
    if (proof.stats.isEmpty()) return
    Row(Modifier.fillMaxWidth()) {
        proof.stats.forEach { stat ->
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(stat.value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text(stat.label, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
            }
        }
    }
}

/** Coach quotes, or real reviews when `SocialProof.json` has them, sliding by (iOS `QuoteCarousel`). */
@Composable
fun QuoteCarousel(proof: SocialProof) {
    val quotes = listOf(R.string.quote_1, R.string.quote_2, R.string.quote_3, R.string.quote_4).map { stringResource(it) }
    val items = if (proof.reviews.isNotEmpty()) proof.reviews.map { Triple(it.name, it.text, it.stars) } else quotes.map { Triple("Gloop", it, 0) }
    var index by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) { while (true) { delay(2600); index++ } }
    androidx.compose.animation.AnimatedContent(index, label = "quotes") { i ->
        val (title, text, stars) = items[i % items.size]
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (stars == 0) CoachAvatar(CoachMood.PROUD, 40.dp)
                Column {
                    Text(title, fontWeight = FontWeight.SemiBold)
                    if (stars > 0) Text("★".repeat(stars), color = Orange, fontSize = 12.sp)
                }
            }
            Text(text, style = MaterialTheme.typography.bodyLarge)
        }
    }
}

@Composable
fun SectionCard(content: @Composable ColumnScope.() -> Unit) =
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp), content = content)

