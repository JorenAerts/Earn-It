package be.gloop.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlin.math.abs

private val ROW = 48.dp
private const val VISIBLE = 5 // rows shown; the middle one is selected

/** iOS-style time wheels: swipe hours and minutes, no typing. 24-hour, both wheels loop. */
@Composable
fun WheelTimePicker(hour: Int, minute: Int, onChange: (hour: Int, minute: Int) -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        // Selection band behind the middle row, like the iOS picker.
        Box(Modifier.fillMaxWidth().padding(horizontal = 24.dp).height(ROW)
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(12.dp)))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Wheel(count = 24, selected = hour, label = "hour") { onChange(it, minute) }
            Text(":", fontSize = 30.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(horizontal = 8.dp))
            Wheel(count = 60, selected = minute, label = "minute") { onChange(hour, it) }
        }
    }
}

@Composable
private fun Wheel(count: Int, selected: Int, label: String, onSelect: (Int) -> Unit) {
    // A long list that repeats 0..count-1 gives the endless wheel; start in the middle.
    val loops = 400
    val start = (loops / 2) * count + selected - VISIBLE / 2
    val state = rememberLazyListState(initialFirstVisibleItemIndex = start)
    val haptics = LocalHapticFeedback.current
    val centered by remember {
        derivedStateOf {
            val offset = if (state.firstVisibleItemScrollOffset > state.layoutInfo.visibleItemsInfo.firstOrNull()?.size?.div(2) ?: 0) 1 else 0
            state.firstVisibleItemIndex + offset + VISIBLE / 2
        }
    }
    LaunchedEffect(state) {
        snapshotFlow { centered % count }.distinctUntilChanged().collect { value ->
            if (value != selected) { haptics.performHapticFeedback(HapticFeedbackType.SegmentFrequentTick); onSelect(value) }
        }
    }
    LazyColumn(
        state = state,
        flingBehavior = rememberSnapFlingBehavior(state),
        modifier = Modifier.width(84.dp).height(ROW * VISIBLE).semantics { contentDescription = label },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        items(count * loops) { index ->
            val distance = abs(index - centered)
            Box(Modifier.height(ROW).width(84.dp), contentAlignment = Alignment.Center) {
                Text(
                    "%02d".format(index % count),
                    fontSize = if (distance == 0) 32.sp else 26.sp,
                    fontWeight = if (distance == 0) FontWeight.SemiBold else FontWeight.Normal,
                    modifier = Modifier.graphicsLayer {
                        alpha = when (distance) { 0 -> 1f; 1 -> 0.5f; else -> 0.22f }
                        rotationX = ((index - centered) * 18f).coerceIn(-60f, 60f)
                    },
                )
            }
        }
    }
}
