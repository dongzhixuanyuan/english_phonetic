# EnglishPhoneticApp — 英语课本音标点读机

> 给课本拍张照，秒变会说话的音标点读机。

一款面向小学生家长的英语课本音标点读工具。家长给孩子的英语课本拍照后，APP 自动识别图片中的英文单词并标注音标，孩子点击音标即可听到标准发音。

![Demo](Demo.png)

## 核心功能

- **拍照识别** — 拍摄或导入课本照片，Apple Vision OCR 自动识别英文单词
- **音标标注** — 本地词库自动匹配音标，叠加显示在图片对应位置
- **点击发音** — 点击音标标签即可播放标准英音 / 美音
- **校对模式** — 支持编辑单词、拖拽调整位置、添加 / 删除标注
- **课本管理** — 按课本 → 单元 → 页面组织，支持多本教材

## 多平台代码

本项目包含 iOS、Android、OpenHarmony 三个平台的实现，以 git 子模块管理：

| 平台 | 技术栈 | 子模块 |
|------|--------|--------|
| iOS | Swift 5 + SwiftUI + Apple Vision | [`ios/`](https://github.com/dongzhixuanyuan/english_phonetic-ios) |
| Android | Kotlin + Jetpack Compose | [`android/`](https://github.com/dongzhixuanyuan/english_phonetic-android) |
| OpenHarmony | ArkTS + ArkUI | [`ohos/`](https://github.com/dongzhixuanyuan/english_phonetic-ohos) |

## 快速开始

### 克隆仓库（含子模块）

```bash
git clone --recurse-submodules https://github.com/dongzhixuanyuan/english_phonetic.git
```

如果已克隆但未拉取子模块：

```bash
git submodule update --init --recursive
```

### iOS 运行

1. 进入 `ios/` 子模块，打开 `EnglishPhoneticApp.xcodeproj`
2. 选择 iPhone 模拟器或真机
3. 点击 **Run**（⌘+R）

> 真机调试需要配置 Apple Developer Team。

### Android 运行

1. 进入 `android/` 子模块，用 Android Studio 打开
2. 同步 Gradle，选择设备后运行

### OpenHarmony 运行

1. 进入 `ohos/` 子模块，用 DevEco Studio 打开
2. 连接 HarmonyOS 设备或启动模拟器后运行

## 项目文档

| 文档 | 说明 |
|------|------|
| [`PRD.md`](PRD.md) | 产品需求文档 |
| [`AGENTS.md`](AGENTS.md) | 面向 AI 编程助手的项目说明 |
| [`工程文档.md`](工程文档.md) | 工程实现细节 |

## 技术亮点

- **完全离线** — OCR、音标查询、TTS 均使用原生离线能力，无需网络
- **MVVM 架构** — 统一的 ViewModel + Service 分层设计
- **子模块管理** — 三端代码独立演进，共享产品规划文档

## 当前阶段

MVP 早期开发中。基础框架已完成，持续迭代 OCR 精度、音标字体、示例页预置内容等。
