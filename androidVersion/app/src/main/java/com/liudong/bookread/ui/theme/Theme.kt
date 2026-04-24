package com.liudong.bookread.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColorScheme = lightColorScheme(
    primary = androidx.compose.ui.graphics.Color(0xFF2196F3),
    secondary = androidx.compose.ui.graphics.Color(0xFF4CAF50),
    tertiary = androidx.compose.ui.graphics.Color(0xFFFF9800)
)

@Composable
fun BookReadTheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        typography = Typography,
        content = content
    )
}
