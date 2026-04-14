# AGENTS.md — EnglishPhoneticApp

> 本文档面向 AI 编程助手。若你第一次接触本项目，请先阅读本文件，再修改代码。

---

## 项目概述

**EnglishPhoneticApp** 是一款面向小学生家长的 iOS 应用，核心目标是：让家长给孩子的英语课本拍照后，APP 自动识别图片中的英文单词并标注音标，孩子点击音标即可听到标准发音。

- **产品 Slogan**：给课本拍张照，秒变会说话的音标点读机。
- **目标平台**：iOS（iPhone / iPad），最低支持 iOS 18.2（当前 Xcode 项目配置）。
- **核心用户**：小学生家长（操作者），终端用户为小学生（使用者）。
- **开发语言**：Swift 5.0 + SwiftUI。
- **项目创建时间**：2026-04-14。

### 当前阶段

项目处于 **MVP 早期开发阶段**。基础框架已搭建完成，包含：
- 课本 / 单元 / 页面的数据模型与本地存储
- 拍照 / 相册选图导入页面
- Apple Vision OCR 自动识别单词
- 本地音标词库查询与标注渲染
- AVSpeechSynthesizer TTS 点击发音
- 基础校对模式（编辑单词、拖拽位置、删除 / 添加标注）

尚未完成的功能包括：示例页预置精校内容、音标字体嵌入、图片透视校正、OCR 后处理优化、iPad 适配、设置页等。

---

## 技术栈

| 模块 | 技术方案 | 说明 |
|------|----------|------|
| 开发框架 | SwiftUI + UIKit (混合) | 主界面使用 SwiftUI；相机调用使用 `UIImagePickerController`（UIKit 桥接） |
| OCR | Apple Vision (`VNRecognizeTextRequest`) | 完全离线，识别英文印刷体 |
| 音标查询 | 本地 JSON 词库 + UserDefaults 扩展词库 | 基础词库计划以 `phonetic_dictionary.json` 嵌入 Bundle；目前尚未放入实际词库文件 |
| TTS 发音 | `AVSpeechSynthesizer` | 支持美音 (`en-US`) / 英音 (`en-GB`)，可调整语速 |
| 数据持久化 | `UserDefaults`（JSON 编码）+ APP Sandbox `Documents` 目录（图片）| 当前未使用 Core Data / SQLite |
| 构建工具 | Xcode 16.2 | 标准 `.xcodeproj` 项目，无 CocoaPods / SPM / Carthage 依赖 |

---

## 项目结构

```
EnglishPhoneticApp/
├── EnglishPhoneticApp.xcodeproj/   # Xcode 项目文件
└── EnglishPhoneticApp/             # 源代码目录
    ├── EnglishPhoneticAppApp.swift # App 入口 (@main)
    ├── Models/
    │   └── Models.swift            # 数据模型：Textbook / TextbookUnit / TextbookPage / WordAnnotation
    ├── Services/
    │   ├── DataStoreService.swift  # 本地数据存取（UserDefaults + Documents 图片）
    │   ├── OCRService.swift        # Apple Vision 文字识别封装
    │   ├── PhoneticDictionaryService.swift  # 音标词库查询与管理
    │   └── SpeechService.swift     # TTS 发音服务
    ├── ViewModels/
    │   └── TextbookViewModel.swift # 课本数据的统一 ViewModel
    └── Views/
        ├── ContentView.swift       # 根视图（NavigationStack 包裹 HomeView）
        ├── HomeView.swift          # 首页：示例入口 + 我的课本列表
        ├── TextbookDetailView.swift# 课本详情：单元列表、页面缩略图、添加页面
        ├── ReaderView.swift        # 点读页核心：图片展示 + 音标标签叠加 + 编辑/发音
        └── CameraPicker.swift      # 相机拍照封装（UIViewControllerRepresentable）
```

---

## 构建与运行

### 环境要求

- **macOS** + **Xcode 16.2** 或更高版本
- 真机调试需要有效的 Apple Developer Team（项目已配置 `DEVELOPMENT_TEAM = 25372VQL85`）
- 模拟器可运行大部分功能，但 **相机拍照需要真机**

### 构建步骤

1. 打开 `EnglishPhoneticApp/EnglishPhoneticApp/EnglishPhoneticApp.xcodeproj`。
2. 选择目标设备（iPhone 模拟器或真机）。
3. 点击 **Run**（⌘+R）编译并运行。

> 注意：项目使用 Xcode 16 新增的 `PBXFileSystemSynchronizedRootGroup`（文件夹引用），因此直接在 Finder 中增删 `EnglishPhoneticApp/` 目录下的文件，Xcode 会自动同步，无需手动修改 `project.pbxproj`。
> 
> **约束**：不需要每次修改后都编译运行。

---

## 代码风格与约定

- **语言**：所有业务代码、注释、文档均使用 **中文**（面向中国家长用户的个人项目）。
- **命名**：
  - Swift 类型使用 PascalCase（如 `TextbookViewModel`）。
  - 方法/属性使用 camelCase。
  - 中文注释常见于视图和 ViewModel 中，描述业务逻辑。
- **架构模式**：MVVM（`ViewModel` 负责数据变更，`View` 负责 UI 渲染）。
- **状态管理**：使用 `@StateObject`、`@ObservedObject`、`@State`、`@Binding` 等 SwiftUI 原生方案。
- **服务类**：采用单例模式（`DataStoreService.shared`、`PhoneticDictionaryService.shared`、`SpeechService.shared`）。

---

## 测试策略

**当前项目尚未引入任何测试框架或测试用例。**

后续建议按以下优先级补充：
1. **单元测试**：针对 `OCRService` 的过滤逻辑、`PhoneticDictionaryService` 的查询逻辑、`DataStoreService` 的存取逻辑。
2. **UI 测试**：验证首页 → 添加课本 → 添加单元 → 导入页面 → 进入点读页的完整流程。
3. **快照测试**：`ReaderView` 在不同尺寸设备上的音标标签布局。

---

## 数据模型速查

```swift
// 标注（音标标签）
WordAnnotation {
    id: UUID
    word: String
    phonetic: String
    normalizedX: Double    // 0.0 ~ 1.0，基于图片宽度
    normalizedY: Double    // 0.0 ~ 1.0，基于图片高度（Vision 坐标系原点在左下角）
    normalizedWidth: Double
    normalizedHeight: Double
}

// 页面
TextbookPage {
    id: UUID
    name: String
    imagePath: String      // 仅文件名，实际存储在 Documents 目录
    order: Int
    annotations: [WordAnnotation]
}

// 单元
TextbookUnit {
    id: UUID
    name: String
    order: Int
    pages: [TextbookPage]
}

// 课本
Textbook {
    id: UUID
    name: String
    coverImagePath: String?
    createdAt: Date
    units: [TextbookUnit]
}
```

---

## 已知问题与注意事项

1. **音标词库缺失**：`phonetic_dictionary.json` 尚未放入 Bundle。当前 `PhoneticDictionaryService` 在加载时会打印 `📚 音标词库加载完成，共 0 个单词`。需要尽快补充小学常见单词音标数据。
2. **示例页为空**：`setupSamplePages()` 仅创建了空的示例课本和单元结构，没有预置真实图片和精校标注。
3. **坐标系转换**：`ReaderView.annotationFrame` 中处理了 Vision 坐标系（原点在左下角）到 UIKit/SwiftUI（原点在左上角）的 Y 轴翻转，修改此处需谨慎。
4. **无网络依赖**：OCR、音标查询、TTS 均使用 iOS 原生离线能力，无需网络权限。
5. **隐私权限**：项目尚未显式配置 `NSCameraUsageDescription` 和 `NSPhotoLibraryUsageDescription` Info.plist 字段，若提交 App Store 或真机测试时需补充。

---

## 相关文档

项目根目录还包含以下规划文档，可供了解产品背景：

- `PRD.md` — 产品需求文档（功能详述、页面流转、MVP 规划）
- `Personal_App_Plan.md` — 个人定制版 APP 计划（核心思路、技术实现、开发排期）
- `App_Concept_Evaluation.md` — 概念评估文档（竞品分析、教育理念建议）
- `Implementation_Strategy_Comparison.md` — 两种实现策略对比（预置全套 vs 通用工具）

---

## 给 AI 助手的快速检查清单

在修改代码前，请确认：
- [ ] 是否需要补充/更新 `phonetic_dictionary.json`？
- [ ] 是否涉及 Vision 坐标系转换？请双重验证 Y 轴翻转逻辑。
- [ ] 是否新增相机/相册权限？记得在 Info.plist 添加对应描述。
- [ ] 是否修改了数据模型？`UserDefaults` 中的旧数据可能无法解码，需考虑版本兼容或迁移策略。
- [ ] 是否添加了新的 SwiftUI View？建议在 `#Preview` 中提供可运行的预览数据。
