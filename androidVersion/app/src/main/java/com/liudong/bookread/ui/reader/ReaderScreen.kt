package com.liudong.bookread.ui.reader

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.FullscreenExit
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.liudong.bookread.model.Textbook
import com.liudong.bookread.model.TextbookPage
import com.liudong.bookread.model.TextbookUnit
import com.liudong.bookread.model.WordAnnotation
import com.liudong.bookread.service.DataStoreService
import com.liudong.bookread.service.PhoneticDictionaryService
import com.liudong.bookread.service.SpeechService
import com.liudong.bookread.viewmodel.TextbookViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReaderScreen(
    viewModel: TextbookViewModel,
    textbookId: String,
    unitId: String,
    pageId: String,
    navController: NavController
) {
    val textbooks by viewModel.textbooks.collectAsState()
    val textbook = textbooks.find { it.id == textbookId } ?: return
    val unit = textbook.units.find { it.id == unitId } ?: return
    val page = unit.pages.find { it.id == pageId } ?: return

    var scale by remember { mutableFloatStateOf(1f) }
    var offsetX by remember { mutableFloatStateOf(0f) }
    var offsetY by remember { mutableFloatStateOf(0f) }
    var isEditMode by remember { mutableStateOf(false) }
    var selectedAnnotationId by remember { mutableStateOf<String?>(null) }
    var selectedPopoverAnnotation by remember { mutableStateOf<WordAnnotation?>(null) }
    var showEditSheet by remember { mutableStateOf(false) }
    var editWord by remember { mutableStateOf("") }
    var editPhonetic by remember { mutableStateOf("") }
    var currentAnnotations by remember(page.annotations) { mutableStateOf(page.annotations) }
    val speechService = SpeechService

    val context = LocalContext.current
    val bitmap = remember(page.imagePath) {
        DataStoreService.loadImage(context, page.imagePath)
    }

    var containerSize by remember { mutableStateOf(Size.Zero) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(page.name) },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Text("返回")
                    }
                }
            )
        },
        bottomBar = {
            BottomToolbar(
                isEditMode = isEditMode,
                onToggleEdit = {
                    isEditMode = !isEditMode
                    selectedAnnotationId = null
                    selectedPopoverAnnotation = null
                },
                onResetZoom = {
                    scale = 1f
                    offsetX = 0f
                    offsetY = 0f
                },
                onReprocess = {
                    bitmap?.let {
                        viewModel.reprocessPage(textbookId, unitId, page, it) { newAnnotations ->
                            currentAnnotations = newAnnotations
                        }
                    }
                },
                scale = scale
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .onGloballyPositioned { coordinates ->
                    containerSize = Size(
                        coordinates.size.width.toFloat(),
                        coordinates.size.height.toFloat()
                    )
                }
        ) {
            bitmap?.let { bmp ->
                val imageWidth = bmp.width.toFloat()
                val imageHeight = bmp.height.toFloat()

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .pointerInput(Unit) {
                            detectTransformGestures { _, pan, zoom, _ ->
                                scale = (scale * zoom).coerceIn(1f, 5f)
                                if (scale > 1f) {
                                    offsetX += pan.x
                                    offsetY += pan.y
                                }
                            }
                        }
                        .graphicsLayer {
                            scaleX = scale
                            scaleY = scale
                            translationX = offsetX
                            translationY = offsetY
                        }
                ) {
                    Image(
                        bitmap = bmp.asImageBitmap(),
                        contentDescription = page.name,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Fit
                    )

                    if (containerSize != Size.Zero) {
                        val pixelSize = Size(imageWidth, imageHeight)
                        val displaySize = calculateImageSize(
                            container = containerSize,
                            image = pixelSize
                        )
                        val xOffset = (containerSize.width - displaySize.width) / 2f
                        val yOffset = (containerSize.height - displaySize.height) / 2f

                        currentAnnotations.forEach { annotation ->
                            val frame = annotationFrame(
                                annotation = annotation,
                                pixelImageSize = pixelSize,
                                displayImageSize = displaySize,
                                xOffset = xOffset,
                                yOffset = yOffset
                            )
                            val isPopoverVisible = selectedPopoverAnnotation?.id == annotation.id
                            val isSpeaking = speechService.currentWord.value?.lowercase() == annotation.word.lowercase()

                            val density = LocalDensity.current
                            val baseModifier = Modifier
                                .graphicsLayer {
                                    translationX = frame.left
                                    translationY = frame.top
                                }
                                .size(
                                    width = with(density) { frame.width.toDp() },
                                    height = with(density) { frame.height.toDp() }
                                )
                                .clickable {
                                    if (isEditMode) {
                                        selectedAnnotationId = annotation.id
                                        editWord = annotation.word
                                        editPhonetic = annotation.phonetic
                                        showEditSheet = true
                                        selectedPopoverAnnotation = null
                                    } else {
                                        selectedPopoverAnnotation = annotation
                                    }
                                }

                            val modifier = if (isEditMode) {
                                baseModifier.pointerInput(annotation.id) {
                                    detectDragGestures { change, dragAmount ->
                                        change.consume()
                                        val deltaX = dragAmount.x / displaySize.width
                                        val deltaY = -dragAmount.y / displaySize.height
                                        currentAnnotations = currentAnnotations.map {
                                            if (it.id == annotation.id) {
                                                it.copy(
                                                    normalizedX = (it.normalizedX + deltaX).coerceIn(0.0, 1.0),
                                                    normalizedY = (it.normalizedY + deltaY).coerceIn(0.0, 1.0)
                                                )
                                            } else it
                                        }
                                    }
                                }
                            } else {
                                baseModifier
                            }

                            WordBoundingBox(
                                annotation = annotation,
                                frame = frame,
                                isPopoverVisible = isPopoverVisible,
                                isSpeaking = isSpeaking,
                                isEditMode = isEditMode,
                                isSelected = selectedAnnotationId == annotation.id,
                                modifier = modifier
                            )
                        }

                        selectedPopoverAnnotation?.let { popoverAnnotation ->
                            val popoverFrame = annotationFrame(
                                annotation = popoverAnnotation,
                                pixelImageSize = pixelSize,
                                displayImageSize = displaySize,
                                xOffset = xOffset,
                                yOffset = yOffset
                            )
                            val popoverPos = calculatePopoverPosition(
                                wordFrame = popoverFrame,
                                containerSize = containerSize,
                                popoverSize = Size(170f, 90f)
                            )

                            WordPopover(
                                annotation = popoverAnnotation,
                                onSpeak = { speechService.speak(popoverAnnotation.word) },
                                onClose = { selectedPopoverAnnotation = null },
                                modifier = Modifier
                                    .graphicsLayer {
                                        translationX = popoverPos.x - 85f
                                        translationY = popoverPos.y - 45f
                                    }
                            )
                        }
                    }
                }
            } ?: run {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text("无法加载图片", color = Color.Gray)
                }
            }
        }
    }

    if (showEditSheet) {
        AlertDialog(
            onDismissRequest = {
                showEditSheet = false
                selectedAnnotationId = null
            },
            title = { Text(if (selectedAnnotationId == null) "添加标注" else "编辑标注") },
            text = {
                Column {
                    OutlinedTextField(
                        value = editWord,
                        onValueChange = { editWord = it },
                        label = { Text("单词") },
                        singleLine = true
                    )
                    Spacer(modifier = Modifier.size(8.dp))
                    OutlinedTextField(
                        value = editPhonetic,
                        onValueChange = { editPhonetic = it },
                        label = { Text("音标（可选）") },
                        singleLine = true
                    )
                    if (editPhonetic.isEmpty() && editWord.isNotEmpty()) {
                        val autoPhonetic = PhoneticDictionaryService.lookup(editWord)
                        if (autoPhonetic != null) {
                            Text("自动匹配: $autoPhonetic", fontSize = 12.sp, color = Color(0xFF4CAF50))
                        } else {
                            Text("词库中未找到该单词，请手动输入音标", fontSize = 12.sp, color = Color(0xFFFF9800))
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        saveEditedAnnotation(
                            selectedAnnotationId = selectedAnnotationId,
                            editWord = editWord,
                            editPhonetic = editPhonetic,
                            currentAnnotations = currentAnnotations,
                            onAnnotationsChange = { currentAnnotations = it },
                            viewModel = viewModel,
                            textbookId = textbookId,
                            unitId = unitId,
                            pageId = pageId
                        )
                        showEditSheet = false
                        selectedAnnotationId = null
                    },
                    enabled = editWord.isNotEmpty()
                ) {
                    Text("保存")
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    showEditSheet = false
                    selectedAnnotationId = null
                }) {
                    Text("取消")
                }
            }
        )
    }
}

@Composable
private fun BottomToolbar(
    isEditMode: Boolean,
    onToggleEdit: () -> Unit,
    onResetZoom: () -> Unit,
    onReprocess: () -> Unit,
    scale: Float
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
            .background(Color.Black.copy(alpha = 0.7f), RoundedCornerShape(20.dp))
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onToggleEdit) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = if (isEditMode) Icons.Default.CheckCircle else Icons.Default.Edit,
                    contentDescription = null,
                    tint = if (isEditMode) Color(0xFF4CAF50) else Color(0xFF2196F3)
                )
                Text(
                    text = if (isEditMode) "完成" else "编辑",
                    fontSize = 10.sp,
                    color = if (isEditMode) Color(0xFF4CAF50) else Color(0xFF2196F3)
                )
            }
        }

        if (isEditMode) {
            IconButton(onClick = onReprocess) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = Icons.Default.Refresh,
                        contentDescription = null,
                        tint = Color(0xFFFF9800)
                    )
                    Text("重识", fontSize = 10.sp, color = Color(0xFFFF9800))
                }
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        if (scale > 1f) {
            IconButton(onClick = onResetZoom) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = Icons.Default.FullscreenExit,
                        contentDescription = null,
                        tint = Color.Gray
                    )
                    Text("重置", fontSize = 10.sp, color = Color.Gray)
                }
            }
        }
    }
}

private fun calculateImageSize(container: Size, image: Size): Size {
    val aspectRatio = image.width / image.height
    val containerAspectRatio = container.width / container.height
    return if (aspectRatio > containerAspectRatio) {
        val width = container.width
        val height = width / aspectRatio
        Size(width, height)
    } else {
        val height = container.height
        val width = height * aspectRatio
        Size(width, height)
    }
}

private fun annotationFrame(
    annotation: WordAnnotation,
    pixelImageSize: Size,
    displayImageSize: Size,
    xOffset: Float,
    yOffset: Float
): Rect {
    val scaleX = displayImageSize.width / pixelImageSize.width
    val scaleY = displayImageSize.height / pixelImageSize.height

    val x = xOffset + annotation.normalizedX.toFloat() * pixelImageSize.width * scaleX
    val y = yOffset + (1.0f - annotation.normalizedY.toFloat() - annotation.normalizedHeight.toFloat()) * pixelImageSize.height * scaleY
    val width = annotation.normalizedWidth.toFloat() * pixelImageSize.width * scaleX
    val height = annotation.normalizedHeight.toFloat() * pixelImageSize.height * scaleY

    return Rect(x, y, x + width, y + height)
}

private fun calculatePopoverPosition(
    wordFrame: Rect,
    containerSize: Size,
    popoverSize: Size
): Offset {
    val margin = 12f
    val safeTop = 60f
    val safeBottom = containerSize.height - 100f

    var y = wordFrame.top - margin - popoverSize.height / 2
    var direction = "top"

    if (y - popoverSize.height / 2 < safeTop) {
        y = wordFrame.bottom + margin + popoverSize.height / 2
        direction = "bottom"
    }

    if (y + popoverSize.height / 2 > safeBottom) {
        y = if (direction == "bottom") {
            wordFrame.center.y - popoverSize.height / 2 - margin
        } else {
            wordFrame.center.y + popoverSize.height / 2 + margin
        }
    }

    var x = wordFrame.center.x
    x = x.coerceIn(margin + popoverSize.width / 2, containerSize.width - margin - popoverSize.width / 2)

    return Offset(x, y)
}

private fun saveEditedAnnotation(
    selectedAnnotationId: String?,
    editWord: String,
    editPhonetic: String,
    currentAnnotations: List<WordAnnotation>,
    onAnnotationsChange: (List<WordAnnotation>) -> Unit,
    viewModel: TextbookViewModel,
    textbookId: String,
    unitId: String,
    pageId: String
) {
    val newAnnotations = if (selectedAnnotationId != null) {
        currentAnnotations.map {
            if (it.id == selectedAnnotationId) {
                val phonetic = if (editPhonetic.isEmpty()) {
                    PhoneticDictionaryService.lookup(editWord) ?: ""
                } else {
                    editPhonetic
                }
                it.copy(word = editWord, phonetic = phonetic)
            } else it
        }
    } else {
        val phonetic = if (editPhonetic.isEmpty()) {
            PhoneticDictionaryService.lookup(editWord) ?: ""
        } else editPhonetic
        currentAnnotations + WordAnnotation(
            word = editWord,
            phonetic = phonetic,
            normalizedX = 0.4,
            normalizedY = 0.4,
            normalizedWidth = 0.2,
            normalizedHeight = 0.05
        )
    }
    onAnnotationsChange(newAnnotations)
    viewModel.updateAnnotations(textbookId, unitId, pageId, newAnnotations)
}
