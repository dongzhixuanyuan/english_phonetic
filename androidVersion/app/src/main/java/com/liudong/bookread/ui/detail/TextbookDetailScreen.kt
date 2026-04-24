package com.liudong.bookread.ui.detail

import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import androidx.navigation.NavController
import com.liudong.bookread.model.Textbook
import com.liudong.bookread.model.TextbookPage
import com.liudong.bookread.model.TextbookUnit
import com.liudong.bookread.service.DataStoreService
import com.liudong.bookread.viewmodel.TextbookViewModel
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TextbookDetailScreen(
    viewModel: TextbookViewModel,
    textbookId: String,
    navController: NavController
) {
    val textbooks by viewModel.textbooks.collectAsState()
    val textbook = textbooks.find { it.id == textbookId } ?: return
    val isProcessing by viewModel.isProcessing.collectAsState()
    val processingProgress by viewModel.processingProgress.collectAsState()
    val context = LocalContext.current

    var showAddUnit by remember { mutableStateOf(false) }
    var newUnitName by remember { mutableStateOf("") }
    var showImagePicker by remember { mutableStateOf(false) }
    var selectedUnitId by remember { mutableStateOf<String?>(null) }
    var showRenameDialog by remember { mutableStateOf(false) }
    var pageToRename by remember { mutableStateOf<TextbookPage?>(null) }
    var unitIdForRename by remember { mutableStateOf<String?>(null) }
    var newPageName by remember { mutableStateOf("") }

    var tempImageUri by remember { mutableStateOf<Uri?>(null) }
    val cameraLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        if (success && tempImageUri != null && selectedUnitId != null) {
            val bitmap = com.liudong.bookread.ui.components.getBitmapFromUri(context, tempImageUri!!)
            bitmap?.let {
                addPage(viewModel, textbookId, selectedUnitId!!, it, textbook)
            }
            tempImageUri = null
        }
    }

    val photoPicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null && selectedUnitId != null) {
            val bitmap = com.liudong.bookread.ui.components.getBitmapFromUri(context, uri)
            bitmap?.let {
                addPage(viewModel, textbookId, selectedUnitId!!, it, textbook)
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("课本详情") }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(width = 80.dp, height = 100.dp)
                        .background(Color(0xFFE8F5E9), RoundedCornerShape(12.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.MenuBook,
                        contentDescription = null,
                        tint = Color(0xFF4CAF50),
                        modifier = Modifier.size(40.dp)
                    )
                }
                Column {
                    Text(
                        text = textbook.name,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "${textbook.units.sumOf { it.pages.size }} 页 · ${textbook.units.size} 个单元",
                        fontSize = 14.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Button(
                onClick = { showAddUnit = true },
                shape = RoundedCornerShape(20.dp)
            ) {
                Icon(Icons.Default.Add, contentDescription = null)
                Spacer(modifier = Modifier.width(4.dp))
                Text("添加单元")
            }

            if (textbook.units.isEmpty()) {
                EmptyUnitView()
            } else {
                textbook.units.sortedBy { it.order }.forEach { unit ->
                    UnitSection(
                        viewModel = viewModel,
                        textbookId = textbookId,
                        unit = unit,
                        onAddPage = {
                            selectedUnitId = unit.id
                            showImagePicker = true
                        },
                        onRenamePage = { page, uId ->
                            pageToRename = page
                            unitIdForRename = uId
                            newPageName = page.name
                            showRenameDialog = true
                        },
                        navController = navController
                    )
                }
            }
        }
    }

    if (showAddUnit) {
        AlertDialog(
            onDismissRequest = {
                showAddUnit = false
                newUnitName = ""
            },
            title = { Text("添加单元") },
            text = {
                Column {
                    Text("例如：Unit 1 Hello")
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedTextField(
                        value = newUnitName,
                        onValueChange = { newUnitName = it },
                        label = { Text("单元名称") },
                        singleLine = true
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        if (newUnitName.isNotEmpty()) {
                            viewModel.addUnit(textbookId, newUnitName)
                            newUnitName = ""
                            showAddUnit = false
                        }
                    }
                ) {
                    Text("添加")
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    showAddUnit = false
                    newUnitName = ""
                }) {
                    Text("取消")
                }
            }
        )
    }

    if (showImagePicker) {
        ModalBottomSheet(
            onDismissRequest = { showImagePicker = false },
            sheetState = rememberModalBottomSheetState()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Button(
                    onClick = {
                        showImagePicker = false
                        val file = File(context.cacheDir, "camera_${System.currentTimeMillis()}.jpg")
                        tempImageUri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )
                        tempImageUri?.let { cameraLauncher.launch(it) }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Icon(Icons.Default.PhotoCamera, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("拍照", fontSize = 18.sp)
                }
                Button(
                    onClick = {
                        showImagePicker = false
                        photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant,
                        contentColor = MaterialTheme.colorScheme.onSurface
                    )
                ) {
                    Icon(Icons.Default.PhotoLibrary, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("从相册选择", fontSize = 18.sp)
                }
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }

    if (showRenameDialog) {
        AlertDialog(
            onDismissRequest = {
                showRenameDialog = false
                pageToRename = null
            },
            title = { Text("重命名页面") },
            text = {
                OutlinedTextField(
                    value = newPageName,
                    onValueChange = { newPageName = it },
                    label = { Text("页面名称") },
                    singleLine = true
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        if (pageToRename != null && unitIdForRename != null && newPageName.isNotEmpty()) {
                            viewModel.renamePage(textbookId, unitIdForRename!!, pageToRename!!, newPageName)
                            showRenameDialog = false
                            pageToRename = null
                        }
                    }
                ) {
                    Text("保存")
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    showRenameDialog = false
                    pageToRename = null
                }) {
                    Text("取消")
                }
            }
        )
    }

    if (isProcessing) {
        com.liudong.bookread.ui.components.ProcessingOverlay(message = processingProgress)
    }
}

private fun addPage(
    viewModel: TextbookViewModel,
    textbookId: String,
    unitId: String,
    bitmap: Bitmap,
    textbook: Textbook
) {
    val totalPages = textbook.units.sumOf { it.pages.size }
    val pageName = "Page ${totalPages + 1}"
    viewModel.addPage(textbookId, unitId, bitmap, pageName) { }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun UnitSection(
    viewModel: TextbookViewModel,
    textbookId: String,
    unit: TextbookUnit,
    onAddPage: () -> Unit,
    onRenamePage: (TextbookPage, String) -> Unit,
    navController: NavController
) {
    var isExpanded by remember { mutableStateOf(true) }

    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { isExpanded = !isExpanded }
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = unit.name,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "${unit.pages.size} 页",
                        fontSize = 12.sp,
                        color = Color.Gray
                    )
                    Icon(
                        imageVector = if (isExpanded) Icons.Default.KeyboardArrowUp else Icons.Default.ArrowDropDown,
                        contentDescription = null,
                        tint = Color.Gray
                    )
                }
            }

            AnimatedVisibility(visible = isExpanded) {
                Column(modifier = Modifier.padding(16.dp)) {
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        unit.pages.sortedBy { it.order }.forEach { page ->
                            PageThumbnail(
                                page = page,
                                onClick = {
                                    navController.navigate("reader/$textbookId/${unit.id}/${page.id}")
                                },
                                onRename = { onRenamePage(page, unit.id) },
                                onDelete = {
                                    viewModel.deletePage(textbookId, unit.id, page)
                                }
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))
                    Button(
                        onClick = onAddPage,
                        colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer,
                            contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    ) {
                        Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("添加页面", fontSize = 14.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun PageThumbnail(
    page: TextbookPage,
    onClick: () -> Unit,
    onRename: () -> Unit,
    onDelete: () -> Unit
) {
    var showMenu by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val bitmap = remember(page.imagePath) {
        DataStoreService.loadImage(context, page.imagePath)
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box {
            Box(
                modifier = Modifier
                    .size(width = 100.dp, height = 130.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color(0xFFF5F5F5))
                    .clickable { onClick() },
                contentAlignment = Alignment.Center
            ) {
                if (bitmap != null) {
                    Image(
                        bitmap = bitmap.asImageBitmap(),
                        contentDescription = page.name,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.MenuBook,
                        contentDescription = null,
                        tint = Color.Gray,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }

            Box(modifier = Modifier.align(Alignment.TopEnd)) {
                IconButton(
                    onClick = { showMenu = true },
                    modifier = Modifier.size(28.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.MoreVert,
                        contentDescription = "菜单",
                        tint = Color.White,
                        modifier = Modifier.size(18.dp)
                    )
                }
                DropdownMenu(
                    expanded = showMenu,
                    onDismissRequest = { showMenu = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("重命名") },
                        onClick = {
                            showMenu = false
                            onRename()
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("删除", color = Color.Red) },
                        onClick = {
                            showMenu = false
                            onDelete()
                        }
                    )
                }
            }
        }
        Text(
            text = page.name,
            fontSize = 12.sp,
            maxLines = 1
        )
    }
}

@Composable
fun EmptyUnitView() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 50.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            imageVector = Icons.Default.MenuBook,
            contentDescription = null,
            tint = Color.Gray.copy(alpha = 0.5f),
            modifier = Modifier.size(50.dp)
        )
        Text(
            text = "还没有单元",
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            color = Color.Gray
        )
        Text(
            text = "先添加一个单元，再拍照导入课本页面",
            fontSize = 14.sp,
            color = Color.Gray
        )
    }
}
