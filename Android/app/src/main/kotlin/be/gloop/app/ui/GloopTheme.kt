package be.gloop.app.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/** Gloop's orange (the classic slime), same accent as the iOS app. */
val GloopOrange = Color(0xFFFF8A2B)

private val Light = lightColorScheme(
    primary = GloopOrange,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFE0C7),
    onPrimaryContainer = Color(0xFF3A1A00),
    secondary = Color(0xFFB4652A),
    secondaryContainer = Color(0xFFFFE8D6),
    onSecondaryContainer = Color(0xFF3A1A00),
    tertiary = Color(0xFF3FA796),
    background = Color(0xFFFFFBF7),
    surface = Color(0xFFFFFBF7),
    surfaceVariant = Color(0xFFF4E9E0),
    surfaceContainerLow = Color(0xFFFBF2EA),
    surfaceContainer = Color(0xFFF7EDE4),
    surfaceContainerHigh = Color(0xFFF2E6DC),
    surfaceContainerHighest = Color(0xFFEDE0D5),
)

private val Dark = darkColorScheme(
    primary = GloopOrange,
    onPrimary = Color(0xFF2B1200),
    primaryContainer = Color(0xFF6A3510),
    onPrimaryContainer = Color(0xFFFFE0C7),
    secondary = Color(0xFFFFB783),
    secondaryContainer = Color(0xFF5A3418),
    onSecondaryContainer = Color(0xFFFFE8D6),
    tertiary = Color(0xFF7FD8C6),
)

@Composable
fun GloopTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (isSystemInDarkTheme()) Dark else Light, content = content)
}
