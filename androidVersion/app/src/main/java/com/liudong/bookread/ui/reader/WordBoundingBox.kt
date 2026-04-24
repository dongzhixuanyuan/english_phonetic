package com.liudong.bookread.ui.reader

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.liudong.bookread.model.WordAnnotation

@Composable
fun WordBoundingBox(
    annotation: WordAnnotation,
    frame: androidx.compose.ui.geometry.Rect,
    isPopoverVisible: Boolean,
    isSpeaking: Boolean,
    isEditMode: Boolean,
    isSelected: Boolean,
    modifier: Modifier = Modifier
) {
    val scale by animateFloatAsState(targetValue = if (isSpeaking) 1.05f else 1f, label = "speak_scale")

    val backgroundColor = when {
        isPopoverVisible -> Color(0xFF2196F3).copy(alpha = 0.15f)
        isSpeaking -> Color(0xFF2196F3).copy(alpha = 0.2f)
        isSelected -> Color(0xFFFFC107).copy(alpha = 0.25f)
        else -> Color.Transparent
    }

    val borderColor = when {
        isPopoverVisible -> Color(0xFF2196F3)
        isSpeaking -> Color(0xFF2196F3)
        isSelected -> Color(0xFFFF9800)
        annotation.phonetic.isEmpty() -> Color(0xFFF44336).copy(alpha = 0.6f)
        else -> Color.Gray.copy(alpha = 0.5f)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .scale(scale)
            .background(backgroundColor)
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = borderColor,
                shape = androidx.compose.foundation.shape.RoundedCornerShape(2.dp)
            )
    )
}
