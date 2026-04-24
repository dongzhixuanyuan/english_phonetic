package com.liudong.bookread.ui.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.liudong.bookread.model.WordAnnotation
import com.liudong.bookread.service.PhoneticDictionaryService

@Composable
fun WordPopover(
    annotation: WordAnnotation,
    onSpeak: () -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier
) {
    val meaning = PhoneticDictionaryService.lookupMeaning(annotation.word)

    Column(
        modifier = modifier
            .width(170.dp)
            .shadow(6.dp, RoundedCornerShape(10.dp))
            .background(Color.White, RoundedCornerShape(10.dp))
            .padding(horizontal = 14.dp, vertical = 10.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = annotation.word,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f)
            )
            IconButton(onClick = onSpeak, modifier = Modifier.size(28.dp)) {
                Icon(
                    imageVector = Icons.Default.VolumeUp,
                    contentDescription = "发音",
                    tint = Color(0xFF2196F3),
                    modifier = Modifier.size(18.dp)
                )
            }
            IconButton(onClick = onClose, modifier = Modifier.size(28.dp)) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "关闭",
                    tint = Color.Gray.copy(alpha = 0.6f),
                    modifier = Modifier.size(18.dp)
                )
            }
        }

        if (annotation.phonetic.isNotEmpty()) {
            Text(
                text = annotation.phonetic,
                fontSize = 15.sp,
                color = Color.Gray
            )
        }

        if (!meaning.isNullOrEmpty()) {
            Text(
                text = meaning,
                fontSize = 15.sp,
                color = Color.Black
            )
        }
    }
}
