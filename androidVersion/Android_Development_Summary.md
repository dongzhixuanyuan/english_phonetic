# EnglishPhoneticApp — Android 版本开发摘要

> 本文档是 Android 版本的快速开发指南，包含：目录结构、核心代码文件映射、关键实现要点、以及从 iOS 到 Android 的逐文件迁移 checklist。UI 框架为 **Jetpack Compose**。

---

## 1. 项目目录结构

```
androidVersion/
├── Android_Technical_Document.md     # 完整技术文档（架构、模块、API 设计）
├── Android_Development_Summary.md    # 本文件：开发摘要与快速指南
└── src/                              # 建议的 Android Studio 项目源码结构
    ├── app/
    │   ├── build.gradle.kts
    │   └── src/main/
    │       ├── AndroidManifest.xml
    │       ├── assets/
    │       │   └── phonetic_dictionary.json
    │       ├── java/com/example/englishphonetic/
    │       │   ├── MainActivity.kt
    │       │   ├── model/
    │       │   │   └── Models.kt
    │       │   ├── service/
    │       │   │   ├── DataStoreService.kt
    │       │   │   ├── OCRService.kt
    │       │   │   ├── PhoneticDictionaryService.kt
    │       │   │   └── SpeechService.kt
    │       │   ├── viewmodel/
    │       │   │   └── TextbookViewModel.kt
    │       │   └── ui/
    │       │       ├── navigation/
    │       │       │   └── AppNavigation.kt
    │       │       ├── home/
    │       │       │   └── HomeScreen.kt
    │       │       ├── detail/
    │       │       │   └── TextbookDetailScreen.kt
    │       │       ├── reader/
    │       │       │   ├── ReaderScreen.kt
    │       │       │   ├── WordBoundingBox.kt
    │       │       │   ├── WordPopover.kt
    │       │       │   └── TapGuideOverlay.kt
    │       │       └── components/
    │       │           ├── CameraPicker.kt
    │       │           ├── ProcessingOverlay.kt
    │       │           └── EmptyState.kt
    │       └── res/
    │           ├── values/
    │           │   ├── colors.xml
    │           │   ├── strings.xml
    │           │   └── themes.xml
    │           └── xml/
    │               └── file_paths.xml
    └── build.gradle.kts
```

---

## 2. 核心代码文件映射（iOS → Android）

### 2.1 数据层

| iOS 文件 | Android 文件 | 说明 |
|----------|-------------|------|
| `Models.swift` | `model/Models.kt` | 4 个 data class，字段一一对应 |
| `DataStoreService.swift` | `service/DataStoreService.kt` | UserDefaults → DataStore；Documents → filesDir |
| `OCRService.swift` | `service/OCRService.kt` | Vision → ML Kit；回调改为 Flow |
| `PhoneticDictionaryService.swift` | `service/PhoneticDictionaryService.kt` | Bundle → assets；逻辑完全一致 |
| `SpeechService.swift` | `service/SpeechService.kt` | AVSpeechSynthesizer → TextToSpeech |

### 2.2 视图层

| iOS 文件 | Android 文件 | 说明 |
|----------|-------------|------|
| `EnglishPhoneticAppApp.swift` | `MainActivity.kt` + `ui/navigation/AppNavigation.kt` | @main → MainActivity；NavigationStack → NavHost |
| `ContentView.swift` | `ui/navigation/AppNavigation.kt` | 根导航容器 |
| `HomeView.swift` | `ui/home/HomeScreen.kt` | ScrollView → LazyColumn；NavigationLink → navigate() |
| `TextbookDetailView.swift` | `ui/detail/TextbookDetailScreen.kt` | sheet → BottomSheet；alert → AlertDialog |
| `ReaderView.swift` | `ui/reader/ReaderScreen.kt` | 最复杂页面，需重点处理 |
| `CameraPicker.swift` | `ui/components/CameraPicker.kt` | UIImagePickerController → ActivityResultContracts |

### 2.3 ViewModel

| iOS 文件 | Android 文件 | 说明 |
|----------|-------------|------|
| `TextbookViewModel.swift` | `viewmodel/TextbookViewModel.kt` | ObservableObject → ViewModel；@Published → StateFlow |

---

## 3. 逐文件实现要点

### 3.1 `model/Models.kt`

- 使用 `@Serializable`（kotlinx.serialization）替代 iOS 的 `Codable`
- `UUID` 使用 `java.util.UUID`，序列化为 `String`
- `Date` 使用 `Long`（时间戳）替代，保持跨平台兼容
- **坐标字段含义与 iOS 完全一致**：`normalizedX/Y/Width/Height` 均为 0.0~1.0 的归一化值

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
```

### 3.2 `service/DataStoreService.kt`

- **数据存储**：使用 `DataStore Preferences`（`androidx.datastore:datastore-preferences`）替代 iOS `UserDefaults`
- **图片存储**：使用 `context.filesDir`（`/data/data/<package>/files/`）替代 iOS `Documents` 目录
- 图片格式保持 JPEG，压缩质量 80%
- 文件名规则与 iOS 一致：`"${pageId}.jpg"`

```kotlin
// 关键 API 对照
// iOS: UserDefaults.standard.set(data, forKey:)  →  Android: dataStore.edit { prefs[KEY] = jsonStr }
// iOS: FileManager.default.urls(for: .documentDirectory)  →  Android: context.filesDir
```

### 3.3 `service/OCRService.kt`

- **核心替换**：`VNRecognizeTextRequest` → `com.google.mlkit.vision.text.TextRecognition`
- **返回类型**：iOS 使用回调 `completion: ([OCRResult]) -> Void`，Android 使用 `Flow<List<OCRResult>>`
- **坐标处理**：
  - iOS Vision：`boundingBox` 是归一化坐标（0~1），原点在左下角
  - Android ML Kit：`boundingBox` 是像素坐标 `android.graphics.Rect`，原点在左上角
  - **存储时统一转换为归一化坐标**，与 iOS 数据格式兼容

```kotlin
// 归一化转换（与 iOS 兼容）
normalizedX = rect.left.toDouble() / bitmap.width
normalizedY = 1.0 - (rect.bottom.toDouble() / bitmap.height)  // Y 轴翻转
normalizedWidth = rect.width().toDouble() / bitmap.width
normalizedHeight = rect.height().toDouble() / bitmap.height
```

- **过滤逻辑**：`shouldKeep()` 与 iOS 完全一致

### 3.4 `service/PhoneticDictionaryService.kt`

- **词库加载**：iOS `Bundle.main.url(forResource:)` → Android `context.assets.open("phonetic_dictionary.json")`
- **用户扩展存储**：iOS `UserDefaults` → Android `SharedPreferences`（简单 KV 场景）
- JSON 结构完全复用 iOS 的 `phonetic_dictionary.json`

```json
{
  "hello": { "phonetic": "/həˈloʊ/", "meaning": "你好" },
  "world": { "phonetic": "/wɜːrld/", "meaning": "世界" }
}
```

### 3.5 `service/SpeechService.kt`

- **核心替换**：`AVSpeechSynthesizer` → `android.speech.tts.TextToSpeech`
- **状态暴露**：iOS 使用 `@Published var isSpeaking` → Android 使用 `MutableStateFlow<Boolean>`
- **发音设置**：
  - 美音：`Locale.US`
  - 英音：`Locale.UK`
- **注意**：Android TTS 初始化是异步的，需在 `onInit` 回调成功后再允许发音
- **生产建议**：设置 `UtteranceProgressListener` 来同步 `isSpeaking` 状态

### 3.6 `viewmodel/TextbookViewModel.kt`

- **基类**：继承 `AndroidViewModel(application)`，以便获取 `Application` 上下文
- **状态管理**：

| iOS | Android |
|-----|---------|
| `@Published var textbooks: [Textbook]` | `private val _textbooks = MutableStateFlow<List<Textbook>>(emptyList())` |
| `@Published var isProcessing` | `private val _isProcessing = MutableStateFlow(false)` |
| `ObservableObject` | `AndroidViewModel` |

- **协程作用域**：使用 `viewModelScope.launch { ... }` 替代 iOS 的 GCD `DispatchQueue.global`
- **数据不可变性**：Kotlin `data class` 的 `copy()` 替代 Swift `struct` 的自动拷贝

### 3.7 `ui/home/HomeScreen.kt`

- **列表容器**：`LazyColumn` 替代 `ScrollView + VStack`
- **卡片布局**：`Card` (Material3) 替代 `RoundedRectangle + shadow`
- **空状态**：`EmptyState.kt` 复用组件
- **导航**：点击课本卡片调用 `navController.navigate("detail/${textbook.id}")`
- **对话框**：`AlertDialog` 替代 `.alert`

```kotlin
@Composable
fun HomeScreen(
    viewModel: TextbookViewModel,
    navController: NavController
) {
    val textbooks by viewModel.textbooks.collectAsState()
    // ...
}
```

### 3.8 `ui/detail/TextbookDetailScreen.kt`

- **单元折叠**：使用 `AnimatedVisibility` 替代 iOS `withAnimation { isExpanded.toggle() }`
- **页面网格**：`LazyVerticalGrid(columns = GridCells.Adaptive(100.dp))` 替代 `LazyVGrid`
- **页面菜单**：`DropdownMenu` 替代 iOS `Menu`
- **底部弹窗**：`ModalBottomSheet` 替代 iOS `.sheet`
- **图片选择**：使用 Android Photo Picker（无需权限）+ 相机 Intent

```kotlin
// 相册选择器（Android 13+ 推荐，无需权限）
val photoPicker = rememberLauncherForActivityResult(
    ActivityResultContracts.PickVisualMedia()
) { uri ->
    uri?.let { /* 处理选中的图片 */ }
}

// 相机拍照
val cameraLauncher = rememberLauncherForActivityResult(
    ActivityResultContracts.TakePicture()
) { success ->
    if (success) { /* 处理拍照结果 */ }
}
```

### 3.9 `ui/reader/ReaderScreen.kt` ⭐ 最复杂页面

这是 Android 版本开发的核心难点，需精确还原以下 iOS 功能：

#### A. 图片展示与缩放

- iOS：`Image(uiImage: image).resizable().scaledToFit().scaleEffect(scale).offset(offset)`
- Android：`Image(bitmap = ...).contentScale(ContentScale.Fit).graphicsLayer { scaleX = scale; ... }`
- **手势处理**：Compose 没有内置 `MagnificationGesture`，需用 `pointerInput + detectTransformGestures`

```kotlin
Modifier.pointerInput(Unit) {
    detectTransformGestures { _, pan, zoom, _ ->
        scale = (scale * zoom).coerceIn(1f, 5f)
        if (scale > 1f) {
            offsetX += pan.x
            offsetY += pan.y
        }
    }
}
```

#### B. 标注框叠加

- iOS 使用 `GeometryReader` 计算图片实际显示尺寸
- Android 使用 `BoxWithConstraints` 或 `onGloballyPositioned` 获取容器尺寸
- **坐标转换公式与 iOS 完全一致**：

```kotlin
fun annotationFrame(
    annotation: WordAnnotation,
    pixelImageSize: Size,      // 图片原始像素尺寸
    displayImageSize: Size,    // ContentScale.Fit 后的实际显示尺寸
    xOffset: Float,            // 居中时的水平偏移
    yOffset: Float             // 居中时的垂直偏移
): Rect {
    val scaleX = displayImageSize.width / pixelImageSize.width
    val scaleY = displayImageSize.height / pixelImageSize.height

    val x = xOffset + annotation.normalizedX.toFloat() * pixelImageSize.width * scaleX
    val y = yOffset + (1.0f - annotation.normalizedY.toFloat() - annotation.normalizedHeight.toFloat()) * pixelImageSize.height * scaleY
    val width = annotation.normalizedWidth.toFloat() * pixelImageSize.width * scaleX
    val height = annotation.normalizedHeight.toFloat() * pixelImageSize.height * scaleY

    return Rect(x, y, x + width, y + height)
}
```

#### C. 浮层（WordPopover）

- iOS：使用 `ZStack` + `position` 叠加
- Android：在 `Box` 内使用 `Popup` 或自定义叠加层
- **定位逻辑**：`calculatePopoverPosition()` 算法与 iOS 完全一致

#### D. 编辑模式

- iOS：`isEditMode` + `DragGesture` 拖拽标注
- Android：`Modifier.pointerInput { detectDragGestures { change, dragAmount -> ... } }`
- 拖拽后更新 `normalizedX/Y`，调用 `viewModel.updateAnnotations()`

#### E. 新手引导遮罩

- iOS：使用 `Canvas` + `Path.subtracting` 实现镂空效果
- Android：使用 `Canvas` + `PorterDuff.Mode.CLEAR` 实现镂空，或使用自定义 `DrawScope`

### 3.10 `ui/navigation/AppNavigation.kt`

```kotlin
@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    val viewModel: TextbookViewModel = viewModel()

    NavHost(navController = navController, startDestination = "home") {
        composable("home") {
            HomeScreen(viewModel = viewModel, navController = navController)
        }
        composable(
            "detail/{textbookId}",
            arguments = listOf(navArgument("textbookId") { type = NavType.StringType })
        ) { backStackEntry ->
            val textbookId = backStackEntry.arguments?.getString("textbookId")!!
            TextbookDetailScreen(viewModel, textbookId, navController)
        }
        composable(
            "reader/{textbookId}/{unitId}/{pageId}",
            arguments = listOf(
                navArgument("textbookId") { type = NavType.StringType },
                navArgument("unitId") { type = NavType.StringType },
                navArgument("pageId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val textbookId = backStackEntry.arguments?.getString("textbookId")!!
            val unitId = backStackEntry.arguments?.getString("unitId")!!
            val pageId = backStackEntry.arguments?.getString("pageId")!!
            ReaderScreen(viewModel, textbookId, unitId, pageId, navController)
        }
    }
}
```

---

## 4. 配置文件模板

### 4.1 `build.gradle.kts` (Module: app)

```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    kotlin("plugin.serialization") version "1.9.22"
}

android {
    namespace = "com.example.englishphonetic"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.englishphonetic"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.10"
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.02.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.navigation:navigation-compose:2.7.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")
    implementation("androidx.datastore:datastore-preferences:1.0.0")
    implementation("com.google.mlkit:text-recognition:16.0.0")
    implementation("io.coil-kt:coil-compose:2.5.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
```

### 4.2 `AndroidManifest.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission
        android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@style/Theme.EnglishPhonetic">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/Theme.EnglishPhonetic">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
    </application>
</manifest>
```

### 4.3 `res/xml/file_paths.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <files-path name="images" path="." />
    <cache-path name="cache_images" path="." />
</paths>
```

---

## 5. 开发 Checklist

### Phase 1：基础框架（1-2 天）

- [ ] 创建 Android Studio 项目（Empty Activity + Compose）
- [ ] 配置 `build.gradle.kts` 依赖
- [ ] 创建 `Models.kt`（4 个 data class）
- [ ] 创建 `DataStoreService.kt`（DataStore + 图片存取）
- [ ] 创建 `AppNavigation.kt` + `MainActivity.kt`
- [ ] 实现 `HomeScreen.kt`（空列表 + 添加课本对话框）

### Phase 2：核心服务（2-3 天）

- [ ] 实现 `PhoneticDictionaryService.kt`（加载 assets JSON）
- [ ] 实现 `OCRService.kt`（ML Kit 集成，Flow 返回）
- [ ] 实现 `SpeechService.kt`（TextToSpeech 初始化 + speak）
- [ ] 实现 `TextbookViewModel.kt`（全部业务逻辑）
- [ ] 验证：添加课本 → 添加单元 → 拍照 → OCR → 保存数据

### Phase 3：详情与点读页（3-4 天）

- [ ] 实现 `TextbookDetailScreen.kt`（单元折叠 + 页面网格）
- [ ] 实现 `CameraPicker.kt` + `PhotoPicker`（ActivityResultContracts）
- [ ] 实现 `ReaderScreen.kt` 基础布局（图片 + 标注框）
- [ ] 实现 `ReaderScreen.kt` 手势（缩放 + 拖拽）
- [ ] 实现 `WordPopover.kt`（点击发音 + 关闭）
- [ ] 实现 `WordBoundingBox.kt`（边框 + 背景色状态）
- [ ] 实现编辑模式（拖拽标注 + 编辑对话框 + 删除）

### Phase 4：体验优化（1-2 天）

- [ ] 实现 `TapGuideOverlay.kt`（新手引导遮罩）
- [ ] 实现 `ProcessingOverlay.kt`（OCR 处理中遮罩）
- [ ] 配置运行时权限（相机）
- [ ] 处理图片旋转（EXIF Orientation）
- [ ] 添加 `strings.xml` 中文文案
- [ ] 真机测试（OCR 精度 + TTS 效果）

---

## 6. 常见问题速查

### Q1：Compose 如何实现 iOS 的 `.scaledToFit()`？

```kotlin
Image(
    bitmap = bmp.asImageBitmap(),
    contentDescription = null,
    modifier = Modifier.fillMaxSize(),
    contentScale = ContentScale.Fit  // 等价于 iOS .scaledToFit()
)
```

### Q2：Compose 如何实现 iOS 的 `NavigationLink`？

```kotlin
// iOS
NavigationLink(value: textbook) { TextbookCard(textbook) }

// Android
Card(
    onClick = { navController.navigate("detail/${textbook.id}") }
) { /* ... */ }
```

### Q3：Compose 如何实现 iOS 的 `.sheet`？

```kotlin
// iOS
.sheet(isPresented: $showingSheet) { SheetContent() }

// Android
var showSheet by remember { mutableStateOf(false) }
if (showSheet) {
    ModalBottomSheet(onDismissRequest = { showSheet = false }) {
        SheetContent()
    }
}
```

### Q4：Compose 如何实现 iOS 的 `.alert`？

```kotlin
// iOS
.alert("添加课本", isPresented: $showingAlert) { /* TextField + Buttons */ }

// Android
var showDialog by remember { mutableStateOf(false) }
if (showDialog) {
    AlertDialog(
        onDismissRequest = { showDialog = false },
        title = { Text("添加课本") },
        text = { OutlinedTextField(value = name, onValueChange = { name = it }) },
        confirmButton = { TextButton(onClick = { /* 添加 */ }) { Text("添加") } },
        dismissButton = { TextButton(onClick = { showDialog = false }) { Text("取消") } }
    )
}
```

### Q5：ML Kit OCR 返回的坐标如何与 iOS 兼容？

iOS Vision 的 `boundingBox` 是归一化的（0~1），原点在左下角。Android ML Kit 返回像素坐标 `Rect`，原点在左上角。

转换公式：
```kotlin
normalizedX = rect.left.toDouble() / bitmap.width
normalizedY = 1.0 - (rect.bottom.toDouble() / bitmap.height)  // 翻转 Y
normalizedWidth = rect.width().toDouble() / bitmap.width
normalizedHeight = rect.height().toDouble() / bitmap.height
```

渲染时的 `annotationFrame` 公式与 iOS 完全一致：
```kotlin
val x = xOffset + normalizedX * pixelWidth * scaleX
val y = yOffset + (1.0 - normalizedY - normalizedHeight) * pixelHeight * scaleY
```

---

## 7. 附录：与 iOS 版本的数据兼容性

Android 版本与 iOS 版本使用**完全相同的数据模型字段和 JSON 序列化格式**，因此理论上可以共享 `phonetic_dictionary.json` 文件。

如果未来需要跨平台同步用户数据，建议：
1. 将 `createdAt` 统一为时间戳（Long）
2. `UUID` 统一为字符串格式
3. 图片文件名规则统一：`"${pageId}.jpg"`
