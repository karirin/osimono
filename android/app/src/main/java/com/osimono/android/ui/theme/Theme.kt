package com.osimono.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightScheme = lightColorScheme(
    primary = OshiPink,
    secondary = OshiPurple,
    tertiary = OshiIndigo,
    background = OshiBackground,
    surface = OshiSurface,
    surfaceVariant = OshiSurfaceAlt,
    secondaryContainer = OshiSurfaceAlt,
    outline = OshiBorder,
    onPrimary = Color.White,
    onSecondary = Color.White,
    onTertiary = Color.White,
    onBackground = OshiTextPrimary,
    onSurface = OshiTextPrimary,
    onSurfaceVariant = OshiTextSecondary,
)

private val DarkScheme = darkColorScheme(
    primary = OshiPink,
    secondary = OshiPurple,
    tertiary = OshiIndigo,
    background = Color(0xFF0F0F23),
    surface = Color(0xFF1A1A2E),
    surfaceVariant = Color(0xFF252542),
    onPrimary = Color.White,
    onSecondary = Color.White,
    onTertiary = Color.White,
)

@Composable
fun OsimonoTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkScheme else LightScheme,
        content = content,
    )
}
