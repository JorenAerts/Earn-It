package be.gloop.app.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/** Gloop's orange (the classic slime), same accent as the iOS app. */
val GloopOrange = Color(0xFFFF8A2B)

@Composable
fun GloopTheme(content: @Composable () -> Unit) {
    val colors = if (isSystemInDarkTheme()) darkColorScheme(primary = GloopOrange) else lightColorScheme(primary = GloopOrange)
    MaterialTheme(colorScheme = colors, content = content)
}
