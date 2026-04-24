package com.liudong.bookread.ui.reader

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.liudong.bookread.model.WordAnnotation

@Composable
fun TapGuideOverlay(
    targetFrame: Rect,
    annotation: WordAnnotation,
    onDismiss: () -> Unit
) {
    var pulse by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        pulse = 1f
    }
    val pulseScale by animateFloatAsState(
        targetValue = pulse,
        animationSpec = infiniteRepeatable(
            animation = tween(1200),
            repeatMode = RepeatMode.Restart
        ),
        label = "pulse"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clickable { onDismiss() }
            .drawBehind {
                drawOverlay(targetFrame)
            }
    ) {
        Box(
            modifier = Modifier
                .padding(
                    start = (targetFrame.left - if (pulseScale > 0.5f) 8f else 0f).dp,
                    top = (targetFrame.top - if (pulseScale > 0.5f) 8f else 0f).dp
                )
                .size(
                    width = (targetFrame.width + if (pulseScale > 0.5f) 16f else 0f).dp,
                    height = (targetFrame.height + if (pulseScale > 0.5f) 16f else 0f).dp
                )
                .border(
                    width = 2.dp,
                    color = Color.Yellow,
                    shape = RoundedCornerShape(4.dp)
                )
        )

        val tooltipY = if (targetFrame.top > 180f) {
            targetFrame.top - 80f
        } else {
            targetFrame.bottom + 80f
        }

        Column(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = tooltipY.dp)
                .background(Color.Black.copy(alpha = 0.6f), RoundedCornerShape(12.dp))
                .padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = Icons.Default.TouchApp,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(36.dp)
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "点击单词",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Text(
                text = "查看释义、音标和发音",
                fontSize = 14.sp,
                color = Color.White.copy(alpha = 0.85f)
            )
        }
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawOverlay(targetFrame: Rect) {
    val overlay = Path().apply {
        addRect(androidx.compose.ui.geometry.Rect(0f, 0f, size.width, size.height))
    }
    val hole = Path().apply {
        addRect(targetFrame)
    }

    drawPath(
        path = overlay,
        color = Color.Black.copy(alpha = 0.7f)
    )
    drawPath(
        path = hole,
        color = Color.Transparent,
        blendMode = androidx.compose.ui.graphics.BlendMode.Clear
    )
}
