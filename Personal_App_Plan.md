# 个人定制版英语教材音标 APP 计划

## 一、核心思路

**不是做通用产品，而是为孩子的英语课本做一款"智能点读机"。**

- 输入：孩子英语教材的实拍照片
- 处理：自动识别图片中的单词，并在对应位置标注音标
- 交互：点击音标（或单词）即可播放标准发音

## 二、功能设计

### 2.1 MVP 功能（第一阶段）

| 功能 | 说明 |
|------|------|
| **教材拍照上传** | 家长将课本每一页拍照，导入 APP |
| **OCR 识别单词** | 自动识别图片中的英文单词 |
| **自动标注音标** | 根据识别结果，在单词附近生成音标标注 |
| **点击发音** | 点击音标或单词，播放标准发音（TTS 或预录音频） |
| **手动校对** | 允许家长对识别错误、音标位置进行手动调整 |

### 2.2 扩展功能（第二阶段）

| 功能 | 说明 |
|------|------|
| **跟读打分** | 孩子跟读后，AI 对比发音准确度 |
| **单词收藏** | 将读不准的单词加入收藏夹，重点复习 |
| **单元切换** | 按课本单元组织图片，方便快速跳转 |
| **离线使用** | 下载音频和音标数据后，无需联网 |

## 三、技术实现方案

### 3.1 技术栈建议

| 模块 | 推荐方案 | 说明 |
|------|----------|------|
| **开发平台** | iOS (Swift + SwiftUI/UIKit) | 你明确要做 iOS APP |
| **OCR 识别** | Apple Vision (VNRecognizeTextRequest) | iOS 原生，免费，支持英文识别，无需网络 |
| **音标数据** | 自建本地词库（如 CMUdict 或自建 JSON） | 小学课本单词量有限，可预先整理 |
| **TTS 发音** | Apple AVSpeechSynthesizer | iOS 原生，免费，支持英音/美音 |
| **音标渲染** | 自定义 UIView 叠加在 UIImageView 上 | 在识别出的单词坐标附近绘制音标标签 |
| **数据存储** | Core Data / Realm / 本地 JSON | 存储课本页、单词位置、音标等信息 |

### 3.2 核心流程

```
拍照上传 → OCR 识别单词及坐标 → 查询本地词库获取音标
    → 在图片对应位置渲染音标标签 → 点击标签播放 TTS 发音
```

### 3.3 关键技术点

#### OCR 识别

使用 Apple Vision 框架：

```swift
import Vision

let request = VNRecognizeTextRequest { request, error in
    guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
    for observation in observations {
        let candidate = observation.topCandidates(1).first
        let word = candidate?.string ?? ""
        let boundingBox = observation.boundingBox
        // 将 word 和 boundingBox 保存，用于后续标注音标
    }
}
request.recognitionLevel = .accurate
request.recognitionLanguages = ["en-US"]
```

#### 音标标注渲染

将 OCR 返回的 `boundingBox`（归一化坐标）转换为 UIImageView 上的实际坐标，然后在该位置附近添加 UILabel：

```swift
let label = UILabel()
label.text = "/kæt/"
label.font = UIFont.systemFont(ofSize: 12)
label.textColor = .red
label.backgroundColor = UIColor.white.withAlphaComponent(0.8)
label.frame = CGRect(x: actualX, y: actualY - 20, width: 50, height: 20)
imageView.addSubview(label)
```

#### TTS 发音

```swift
import AVFoundation

let synthesizer = AVSpeechSynthesizer()
let utterance = AVSpeechUtterance(string: "cat")
utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
synthesizer.speak(utterance)
```

## 四、需要预先准备的数据

### 4.1 课本单词音标库

由于小学课本单词量有限（一个学期约 100-200 个单词），你可以：

1. **手动整理一份 Excel/JSON**，包含：
   - 单词（如 `cat`）
   - 音标（如 `/kæt/`）
   - 可选：自然拼读拆解（如 `c-a-t`）

2. **JSON 格式示例**：

```json
{
  "cat": {
    "phonetic": "/kæt/",
    "syllables": ["c", "a", "t"]
  },
  "apple": {
    "phonetic": "/ˈæpl/",
    "syllables": ["a", "pple"]
  }
}
```

### 4.2 音标字体

iOS 默认字体对 IPA 音标支持一般，建议：
- 使用 **Doulos SIL** 或 **Charis SIL** 等专业音标字体
- 将字体文件嵌入 APP Bundle

## 五、潜在问题与解决方案

| 问题 | 解决方案 |
|------|----------|
| **OCR 识别不准** | 对课本这种印刷体，Apple Vision 识别率通常很高；识别后提供手动校对功能 |
| **音标位置重叠** | 实现简单的碰撞检测算法，自动调整标签位置；或允许手动拖拽 |
| **课本图片变形** | 拍照时尽量正对课本，减少透视变形；可在 APP 内提供简单的裁剪/透视校正 |
| **单词不在词库中** | 提供"添加新单词"功能，家长手动输入音标 |
| **TTS 发音不够标准** | 对重点单词，可预录真人发音音频；TTS 作为兜底方案 |

## 六、开发优先级（MVP）

1. **Week 1**：搭建项目，实现拍照/选图功能
2. **Week 2**：集成 Apple Vision OCR，提取单词和坐标
3. **Week 3**：建立本地音标词库，实现音标查询和渲染
4. **Week 4**：实现点击发音（TTS），添加手动校对功能
5. **Week 5**：按单元组织图片，完善 UI 交互

## 七、后续可扩展方向

- 支持多本教材（如语文、数学也可以做类似的点读工具）
- 将整理好的音标词库和教材页数据开放，形成社区共享
- 逐步演进为面向更多家长的通用产品

## 八、一句话总结

> **给孩子的英语课本拍张照，APP 自动变成"会说话的音标点读机"。**
