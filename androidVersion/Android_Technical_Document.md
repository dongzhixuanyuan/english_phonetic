# EnglishPhoneticApp — Android 版本技术文档

> 本文档面向 Android 开发工程师，基于 iOS MVP 版本进行技术映射与架构设计。UI 框架采用 **Jetpack Compose**。

---

## 1. 项目概述

### 1.1 产品定位

**EnglishPhoneticApp（课本读）** 是一款面向小学生家长的 Android 应用：
- 家长给孩子的英语课本拍照
- APP 自动识别图片中的英文单词并标注音标
- 孩子点击音标即可听到标准发音

**Slogan**：给课本拍张照，秒变会说话的音标点读机。

### 1.2 目标平台

| 项目 | 要求 |
|------|------|
| 最低 API 级别 | API 26 (Android 8.0) |
| 目标 API 级别 | API 35 (Android 15) |
| 开发语言 | Kotlin 2.0+ |
| UI 框架 | Jetpack Compose (BOM 2024.02+) |
| 架构模式 | MVVM + Repository + 单例 Service |

### 1.3 与 iOS 版本的功能对齐

Android 版本需完整复现 iOS MVP 的全部功能：

1. 课本 / 单元 / 页面的数据模型与本地存储
2. 拍照 / 相册选图导入页面
3. OCR 自动识别英文单词（ML Kit）
4. 本地音标词库查询与标注渲染
5. TTS 点击发音（TextToSpeech）
6. 基础校对模式（编辑单词、拖拽位置、删除 / 添加标注）
7. 图片缩放与拖拽浏览
8. 新手引导遮罩

---

## 2. 技术栈选型

### 2.1 核心模块映射表

| 功能模块 | iOS 技术方案 | Android 技术方案 | 说明 |
|----------|-------------|-----------------|------|
| UI 框架 | SwiftUI | Jetpack Compose | 声明式 UI，完全对标 |
| 导航 | NavigationStack | Jetpack Navigation Compose | 类型安全导航 |
| 状态管理 | @StateObject / @ObservedObject | ViewModel + StateFlow / Compose State | 响应式数据流 |
| OCR | Apple Vision (VNRecognizeTextRequest) | ML Kit Text Recognition v2 | 离线识别英文印刷体 |
| 音标查询 | 本地 JSON 词库 + SharedPreferences 扩展 | assets 内 JSON + DataStore Preferences | 完全离线 |
| TTS 发音 | AVSpeechSynthesizer | android.speech.tts.TextToSpeech | 支持美音/英音 |
| 数据持久化 | UserDefaults (JSON) + Documents 目录图片 | DataStore (JSON 字符串) + filesDir 图片 | 无需 Room/SQLite |
| 图片加载 | SwiftUI Image | Coil (Compose 专用) | 轻量高效 |
| 权限申请 | Info.plist + 运行时申请 | Android Runtime Permissions | 相机 + 存储 |
| 依赖注入 | 手动单例 | Hilt (可选) 或手动单例 | 项目规模小，手动单例即可 |

### 2.2 Gradle 关键依赖

```kotlin
// build.gradle.kts (Module: app)

dependencies {
    // Compose BOM
    val composeBom = platform("androidx.compose:compose-bom:2024.02.00")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    // Compose UI
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")

    // Compose Navigation
    implementation("androidx.navigation:navigation-compose:2.7.7")

    // ViewModel + Compose 集成
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")

    // DataStore Preferences
    implementation("androidx.datastore:datastore-preferences:1.0.0")

    // ML Kit OCR
    implementation("com.google.mlkit:text-recognition:16.0.0")

    // Coil 图片加载
    implementation("io.coil-kt:coil-compose:2.5.0")

    // JSON 序列化
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.2")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Testing
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
```

---

## 3. 架构设计

### 3.1 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                            │
│  ┌──────────┐ ┌──────────────┐ ┌──────────┐ ┌──────────┐   │
│  │ HomeScreen │ │ TextbookDetail │ │ ReaderScreen │ │ CameraPicker │
│  └──────────┘ └──────────────┘ └──────────┘ └──────────┘   │
│                    Jetpack Compose                           │
├─────────────────────────────────────────────────────────────┤
│                      ViewModel Layer                         │
│              TextbookViewModel (StateFlow)                   │
├─────────────────────────────────────────────────────────────┤
│                     Service Layer                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │ DataStoreSvc │ │ OCRService  │ │ PhoneticSvc │            │
│  └─────────────┘ └─────────────┘ └─────────────┘            │
│  ┌─────────────┐ ┌─────────────┐                             │
│  │ SpeechService│ │ FileStorage │                             │
│  └─────────────┘ └─────────────┘                             │
├─────────────────────────────────────────────────────────────┤
│                     Data Layer                               │
│  DataStore (JSON)  +  filesDir (Images)  +  assets (Dict)   │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 架构原则

1. **MVVM**：View 只负责 UI 渲染，ViewModel 持有业务逻辑与状态
2. **单向数据流**：ViewModel 暴露 `StateFlow<UiState>`，View 只读；用户操作通过回调/事件流向 ViewModel
3. **Service 单例**：数据存取、OCR、音标查询、TTS 均采用 Kotlin `object` 单例
4. **完全离线**：OCR、音标查询、TTS 均不依赖网络

---

## 4. 数据模型设计

采用 Kotlin `data class` + `@Serializable` 实现与 iOS 的 `Codable` 对等序列化。

> **重要**：Android 的坐标系原点在左上角，与 iOS Vision 坐标系（原点在左下角）一致，因此 `annotationFrame` 中的 Y 轴翻转逻辑需保持与 iOS 相同。

```kotlin
@Serializable
data class WordAnnotation(
    val id: String = UUID.randomUUID().toString(),
    var word: String,
    var phonetic: String,
    var normalizedX: Double,
    var normalizedY: Double,
    var normalizedWidth: Double,
    var normalizedHeight: Double
)

@Serializable
data class TextbookPage(
    val id: String = UUID.randomUUID().toString(),
    var name: String,
    var imagePath: String,
    var order: Int,
    var annotations: List<WordAnnotation> = emptyList()
)

@Serializable
data class TextbookUnit(
    val id: String = UUID.randomUUID().toString(),
    var name: String,
    var order: Int,
    var pages: List<TextbookPage> = emptyList()
)

@Serializable
data class Textbook(
    val id: String = UUID.randomUUID().toString(),
    var name: String,
    var coverImagePath: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    var units: List<TextbookUnit> = emptyList()
)
```

---

## 5. 核心模块详细设计

### 5.1 DataStoreService — 数据持久化

```kotlin
object DataStoreService {
    private const val TEXTBOOKS_KEY = "saved_textbooks"
    private val json = Json { ignoreUnknownKeys = true }

    // 使用 DataStore Preferences 替代 iOS UserDefaults
    private val Context.dataStore by preferencesDataStore(name = "app_preferences")

    suspend fun saveTextbooks(context: Context, textbooks: List<Textbook>) {
        val jsonStr = json.encodeToString(textbooks)
        context.dataStore.edit { prefs ->
            prefs[stringPreferencesKey(TEXTBOOKS_KEY)] = jsonStr
        }
    }

    suspend fun loadTextbooks(context: Context): List<Textbook> {
        val prefs = context.dataStore.data.first()
        val jsonStr = prefs[stringPreferencesKey(TEXTBOOKS_KEY)] ?: return emptyList()
        return json.decodeFromString(jsonStr)
    }

    // 图片存储到 filesDir（对应 iOS Documents 目录）
    fun saveImage(context: Context, bitmap: Bitmap, pageId: String): String? {
        val filename = "$pageId.jpg"
        val file = File(context.filesDir, filename)
        return try {
            file.outputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
            }
            filename
        } catch (e: Exception) {
            Log.e("DataStore", "保存图片失败", e)
            null
        }
    }

    fun loadImage(context: Context, filename: String): Bitmap? {
        val file = File(context.filesDir, filename)
        return if (file.exists()) BitmapFactory.decodeFile(file.absolutePath) else null
    }

    fun deleteImage(context: Context, filename: String) {
        File(context.filesDir, filename).delete()
    }
}
```

### 5.2 OCRService — 文字识别

使用 ML Kit Text Recognition v2，完全离线运行。

```kotlin
object OCRService {
    data class OCRResult(
        val text: String,
        val boundingBox: Rect  // Android.graphics.Rect，像素坐标
    )

    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    fun recognizeText(bitmap: Bitmap): Flow<List<OCRResult>> = flow {
        val image = InputImage.fromBitmap(bitmap, 0)
        val result = recognizer.process(image).await()
        val results = mutableListOf<OCRResult>()

        for (block in result.textBlocks) {
            for (line in block.lines) {
                val text = line.text.trim()
                if (!shouldKeep(text)) continue

                val words = text.split(Regex("\\s+")).filter { it.isNotEmpty() }
                if (words.size > 1) {
                    // 尝试按单词拆分定位（ML Kit line 级别没有内置字符级 boundingBox，
                    // 需要按比例估算或使用 element 级别）
                    for (element in line.elements) {
                        val word = element.text.trim()
                        if (shouldKeep(word)) {
                            results.add(OCRResult(word, element.boundingBox ?: line.boundingBox!!))
                        }
                    }
                } else {
                    results.add(OCRResult(text, line.boundingBox!!))
                }
            }
        }
        emit(results)
    }.flowOn(Dispatchers.IO)

    private fun shouldKeep(text: String): Boolean {
        if (text.all { it.isDigit() }) return false
        if (text.length < 2 && text != "I" && text != "a") return false
        val letters = text.filter { it.isLetter() }
        return letters.isNotEmpty()
    }
}
```

> **坐标系注意**：ML Kit 返回的 `boundingBox` 原点在图片左上角，与 Android 屏幕坐标一致。但 iOS Vision 坐标系是归一化的（0~1）且原点在左下角。Android 版本在存储时直接保存像素坐标比例（0~1），与 iOS 保持数据兼容。

### 5.3 PhoneticDictionaryService — 音标词库

```kotlin
object PhoneticDictionaryService {
    private var phoneticDict: MutableMap<String, String> = mutableMapOf()
    private var meaningDict: MutableMap<String, String> = mutableMapOf()
    private const val USER_EXTENSIONS_KEY = "user_phonetic_extensions"
    private val json = Json { ignoreUnknownKeys = true }

    fun loadDictionary(context: Context) {
        // 加载 assets 中的基础词库
        try {
            context.assets.open("phonetic_dictionary.json").use { stream ->
                val content = stream.bufferedReader().readText()
                val map: Map<String, Map<String, String>> = json.decodeFromString(content)
                for ((word, info) in map) {
                    val key = word.lowercase()
                    phoneticDict[key] = info["phonetic"]
                    meaningDict[key] = info["meaning"]
                }
            }
        } catch (e: Exception) {
            Log.w("PhoneticDict", "基础词库加载失败或不存在", e)
        }

        // 加载用户扩展词库（DataStore / SharedPreferences）
        val prefs = context.getSharedPreferences("phonetic_prefs", Context.MODE_PRIVATE)
        val saved = prefs.getString(USER_EXTENSIONS_KEY, null)
        saved?.let {
            val extensions: Map<String, String> = json.decodeFromString(it)
            phoneticDict.putAll(extensions.mapKeys { entry -> entry.key.lowercase() })
        }

        Log.d("PhoneticDict", "音标词库加载完成，共 ${phoneticDict.size} 个单词")
    }

    fun lookup(word: String): String? {
        val clean = word.lowercase().trim { it in ".,;:!?\"'()[]{}" }
        return phoneticDict[clean]
    }

    fun lookupMeaning(word: String): String? {
        val clean = word.lowercase().trim { it in ".,;:!?\"'()[]{}" }
        return meaningDict[clean]
    }

    fun addCustomPhonetic(context: Context, word: String, phonetic: String) {
        val key = word.lowercase()
        phoneticDict[key] = phonetic
        saveUserExtensions(context)
    }

    private fun saveUserExtensions(context: Context) {
        val prefs = context.getSharedPreferences("phonetic_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString(USER_EXTENSIONS_KEY, json.encodeToString(phoneticDict)).apply()
    }
}
```

### 5.4 SpeechService — TTS 发音

```kotlin
object SpeechService {
    private var tts: TextToSpeech? = null
    private var isInitialized = false

    // 使用 MutableStateFlow 替代 iOS @Published
    private val _isSpeaking = MutableStateFlow(false)
    val isSpeaking: StateFlow<Boolean> = _isSpeaking.asStateFlow()

    private val _currentWord = MutableStateFlow<String?>(null)
    val currentWord: StateFlow<String?> = _currentWord.asStateFlow()

    var accent: String = "en-US"  // 或 "en-GB"
    var speechRate: Float = 1.0f

    fun initialize(context: Context) {
        tts = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                isInitialized = true
                tts?.language = Locale.US
            }
        }
    }

    fun speak(word: String) {
        if (!isInitialized) return
        tts?.stop()
        _currentWord.value = word
        _isSpeaking.value = true

        val locale = when (accent) {
            "en-GB" -> Locale.UK
            else -> Locale.US
        }
        tts?.language = locale
        tts?.setSpeechRate(speechRate)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            tts?.speak(word, TextToSpeech.QUEUE_FLUSH, null, word)
        }

        // TextToSpeech 没有直接的完成回调（需用 UtteranceProgressListener）
        // 生产环境建议设置 UtteranceProgressListener 来更新 _isSpeaking
    }

    fun stop() {
        tts?.stop()
        _isSpeaking.value = false
        _currentWord.value = null
    }

    fun shutdown() {
        tts?.shutdown()
    }
}
```

> **注意**：生产环境需设置 `UtteranceProgressListener` 以精确跟踪发音开始/结束状态，用于 UI 动画同步。

---

## 6. ViewModel 设计

```kotlin
class TextbookViewModel(application: Application) : AndroidViewModel(application) {
    private val context get() = application.applicationContext

    private val _textbooks = MutableStateFlow<List<Textbook>>(emptyList())
    val textbooks: StateFlow<List<Textbook>> = _textbooks.asStateFlow()

    private val _isProcessing = MutableStateFlow(false)
    val isProcessing: StateFlow<Boolean> = _isProcessing.asStateFlow()

    private val _processingProgress = MutableStateFlow("")
    val processingProgress: StateFlow<String> = _processingProgress.asStateFlow()

    init {
        viewModelScope.launch {
            loadTextbooks()
            setupSamplePages()
        }
        PhoneticDictionaryService.loadDictionary(context)
        SpeechService.initialize(context)
    }

    private suspend fun loadTextbooks() {
        _textbooks.value = DataStoreService.loadTextbooks(context)
    }

    private fun saveTextbooks() {
        viewModelScope.launch {
            DataStoreService.saveTextbooks(context, _textbooks.value)
        }
    }

    private fun setupSamplePages() {
        if (_textbooks.value.any { it.name == "示例课本" }) return
        val sampleUnit = TextbookUnit(name = "Unit 1 Hello", order = 0)
        val sampleTextbook = Textbook(name = "示例课本", units = listOf(sampleUnit))
        _textbooks.value = listOf(sampleTextbook) + _textbooks.value
        saveTextbooks()
    }

    fun addTextbook(name: String): Textbook {
        val textbook = Textbook(name = name)
        _textbooks.value = _textbooks.value + textbook
        saveTextbooks()
        return textbook
    }

    fun deleteTextbook(textbook: Textbook) {
        textbook.units.flatMap { it.pages }.forEach { page ->
            DataStoreService.deleteImage(context, page.imagePath)
        }
        _textbooks.value = _textbooks.value.filter { it.id != textbook.id }
        saveTextbooks()
    }

    fun addPage(
        textbookId: String,
        unitId: String,
        bitmap: Bitmap,
        pageName: String,
        onComplete: (TextbookPage?) -> Unit
    ) {
        viewModelScope.launch {
            _isProcessing.value = true
            _processingProgress.value = "正在识别文字..."

            val pageId = UUID.randomUUID().toString()
            val imageFilename = DataStoreService.saveImage(context, bitmap, pageId)
                ?: run {
                    _isProcessing.value = false
                    onComplete(null)
                    return@launch
                }

            val ocrResults = OCRService.recognizeText(bitmap).first()

            _processingProgress.value = "正在生成音标..."
            val annotations = ocrResults.map { result ->
                WordAnnotation(
                    word = result.text,
                    phonetic = PhoneticDictionaryService.lookup(result.text) ?: "",
                    normalizedX = result.boundingBox.left.toDouble() / bitmap.width,
                    normalizedY = 1.0 - (result.boundingBox.bottom.toDouble() / bitmap.height),
                    normalizedWidth = result.boundingBox.width().toDouble() / bitmap.width,
                    normalizedHeight = result.boundingBox.height().toDouble() / bitmap.height
                )
            }

            val page = TextbookPage(
                id = pageId,
                name = pageName,
                imagePath = imageFilename,
                order = 0,
                annotations = annotations
            )

            val updated = _textbooks.value.map { tb ->
                if (tb.id == textbookId) {
                    tb.copy(units = tb.units.map { unit ->
                        if (unit.id == unitId) unit.copy(pages = unit.pages + page) else unit
                    })
                } else tb
            }
            _textbooks.value = updated
            saveTextbooks()

            _isProcessing.value = false
            _processingProgress.value = ""
            onComplete(page)
        }
    }

    fun updateAnnotations(textbookId: String, unitId: String, pageId: String, annotations: List<WordAnnotation>) {
        val updated = _textbooks.value.map { tb ->
            if (tb.id == textbookId) {
                tb.copy(units = tb.units.map { unit ->
                    if (unit.id == unitId) {
                        unit.copy(pages = unit.pages.map { page ->
                            if (page.id == pageId) page.copy(annotations = annotations) else page
                        })
                    } else unit
                })
            } else tb
        }
        _textbooks.value = updated
        saveTextbooks()
    }

    fun deletePage(textbookId: String, unitId: String, page: TextbookPage) {
        DataStoreService.deleteImage(context, page.imagePath)
        val updated = _textbooks.value.map { tb ->
            if (tb.id == textbookId) {
                tb.copy(units = tb.units.map { unit ->
                    if (unit.id == unitId) unit.copy(pages = unit.pages.filter { it.id != page.id })
                    else unit
                })
            } else tb
        }
        _textbooks.value = updated
        saveTextbooks()
    }

    fun addUnit(textbookId: String, name: String): TextbookUnit? {
        val textbook = _textbooks.value.find { it.id == textbookId } ?: return null
        val order = textbook.units.size
        val unit = TextbookUnit(name = name, order = order)
        val updated = _textbooks.value.map { tb ->
            if (tb.id == textbookId) tb.copy(units = tb.units + unit) else tb
        }
        _textbooks.value = updated
        saveTextbooks()
        return unit
    }
}
```

---

## 7. UI 层设计（Compose）

### 7.1 屏幕导航图

```
HomeScreen ──► TextbookDetailScreen ──► ReaderScreen
                    │
                    └──► CameraPicker / PhotoPicker (BottomSheet)
```

### 7.2 核心 Composable 映射

| iOS View | Android Composable | 说明 |
|----------|-------------------|------|
| `ContentView` | `AppNavigation()` | 根导航图 |
| `HomeView` | `HomeScreen()` | 首页，LazyColumn 列表 |
| `TextbookDetailView` | `TextbookDetailScreen()` | 单元折叠面板 + 页面网格 |
| `ReaderView` | `ReaderScreen()` | 最复杂页面：图片 + 标注叠加 |
| `CameraPicker` | `CameraLauncher()` | ActivityResultContracts |
| `PhotoLibraryPicker` | `PhotoPickerLauncher()` | ActivityResultContracts |
| `WordPopoverView` | `WordPopover()` | 点击单词后的浮层 |
| `TapGuideOverlay` | `TapGuideOverlay()` | 新手引导遮罩 |

### 7.3 ReaderScreen 核心实现要点

`ReaderScreen` 是 Android 版本最复杂的页面，需精确还原 iOS 的交互：

1. **图片展示**：使用 `SubcomposeAsyncImage` (Coil) 或 `Image(bitmap = ...)` 加载本地图片
2. **缩放与拖拽**：使用 `Modifier.pointerInput` 实现双指缩放 + 单指拖拽（Compose 无内置 `MagnificationGesture`）
3. **标注框叠加**：在 `Box` 内使用 `Modifier.offset` + `Modifier.size` 叠加标注框
4. **坐标转换**：保持与 iOS 相同的 `annotationFrame` 计算逻辑（Y 轴翻转）
5. **浮层定位**：使用 `Popup` 或自定义 `Box` 内叠加层实现 `WordPopover`

```kotlin
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
    var selectedAnnotation by remember { mutableStateOf<WordAnnotation?>(null) }
    var showEditSheet by remember { mutableStateOf(false) }

    val context = LocalContext.current
    val bitmap = remember(page.imagePath) {
        DataStoreService.loadImage(context, page.imagePath)
    }

    Box(modifier = Modifier.fillMaxSize()) {
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

                // 标注框叠加
                page.annotations.forEach { annotation ->
                    val frame = annotationFrame(
                        annotation = annotation,
                        pixelImageSize = Size(imageWidth, imageHeight),
                        displayImageSize = // 根据 ContentScale.Fit 计算实际显示尺寸
                    )
                    WordBoundingBox(
                        annotation = annotation,
                        frame = frame,
                        isEditMode = isEditMode,
                        onTap = { /* ... */ },
                        onDrag = { /* ... */ }
                    )
                }
            }
        }

        // 底部工具栏
        BottomToolbar(
            isEditMode = isEditMode,
            onToggleEdit = { isEditMode = !isEditMode },
            onResetZoom = { scale = 1f; offsetX = 0f; offsetY = 0f },
            scale = scale
        )
    }
}
```

### 7.4 权限配置

在 `AndroidManifest.xml` 中声明：

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<!-- Android 13 以下兼容 -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

使用 `ActivityResultContracts.RequestPermission()` 在运行时申请相机权限；相册使用 `ActivityResultContracts.PickVisualMedia()`（Photo Picker，无需权限）。

---

## 8. 资源文件规划

```
app/src/main/
├── assets/
│   └── phonetic_dictionary.json      # 音标词库（与 iOS 同一份 JSON）
├── res/
│   ├── values/
│   │   ├── colors.xml
│   │   ├── strings.xml               # 中文文案
│   │   └── themes.xml
│   └── xml/
│       └── file_paths.xml            # FileProvider 配置（相机拍照用）
└── java/com/example/englishphonetic/
    ├── MainActivity.kt
    ├── ui/
    │   ├── navigation/
    │   │   └── AppNavigation.kt
    │   ├── home/
    │   │   └── HomeScreen.kt
    │   ├── detail/
    │   │   └── TextbookDetailScreen.kt
    │   ├── reader/
    │   │   ├── ReaderScreen.kt
    │   │   ├── WordBoundingBox.kt
    │   │   ├── WordPopover.kt
    │   │   └── TapGuideOverlay.kt
    │   └── components/
    │       ├── CameraPicker.kt
    │       ├── ProcessingOverlay.kt
    │       └── EmptyState.kt
    ├── viewmodel/
    │   └── TextbookViewModel.kt
    ├── model/
    │   └── Models.kt
    └── service/
        ├── DataStoreService.kt
        ├── OCRService.kt
        ├── PhoneticDictionaryService.kt
        └── SpeechService.kt
```

---

## 9. 已知问题与风险

| 风险点 | 说明 | 缓解措施 |
|--------|------|----------|
| ML Kit OCR 精度差异 | ML Kit 与 Apple Vision 的识别结果可能不同 | 保留 iOS 的 `shouldKeep` 过滤逻辑，统一后处理 |
| TTS 引擎差异 | Android TTS 依赖系统引擎，不同厂商效果差异大 | 引导用户下载 Google TTS 数据包；提供语速调节 |
| 坐标系兼容性 | iOS Vision 坐标系原点在左下角，Android ML Kit 在左上角 | 存储时统一使用归一化坐标 + Y 翻转逻辑 |
| DataStore 性能 | 大量课本数据时 JSON 序列化可能变慢 | MVP 阶段数据量小，可接受；后续可迁移至 Room |
| 图片旋转 | 相机拍照后图片方向可能不正确 | 读取 EXIF Orientation 并校正 |

---

## 10. 开发环境

- **Android Studio**：Ladybug | 2024.2.1 或更高版本
- **Gradle**：8.4+
- **Kotlin**：2.0.0+
- **Compose Compiler**：与 Kotlin 版本匹配
- **JDK**：17

---

## 11. 附录：iOS → Android 命名对照表

| iOS (Swift) | Android (Kotlin) |
|-------------|------------------|
| `UUID` | `java.util.UUID` |
| `UserDefaults` | `DataStore Preferences` / `SharedPreferences` |
| `Documents` 目录 | `context.filesDir` |
| `Bundle.main.url(forResource:)` | `context.assets.open(...)` |
| `UIImage` | `android.graphics.Bitmap` |
| `VNRecognizeTextRequest` | `com.google.mlkit.vision.text.TextRecognition` |
| `AVSpeechSynthesizer` | `android.speech.tts.TextToSpeech` |
| `@StateObject` | `viewModel()` + `collectAsState()` |
| `@Published` | `MutableStateFlow` |
| `NavigationStack` | `NavHost` + `rememberNavController()` |
| `.sheet` | `ModalBottomSheet` / 自定义 Dialog |
| `.alert` | `AlertDialog` (Material3) |
| `GeometryReader` | `BoxWithConstraints` / `onGloballyPositioned` |
| `MagnificationGesture` | `detectTransformGestures` (pointerInput) |
