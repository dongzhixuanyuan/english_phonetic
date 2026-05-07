import { router } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { Textbook, TextbookUnit, TextbookPage, WordAnnotation } from '../models/Models';
import { textbookViewModel } from '../viewmodel/TextbookViewModel';
import { phoneticDictionaryService } from '../services/PhoneticDictionaryService';
import { speechService } from '../services/SpeechService';
import { ocrService } from '../services/OCRService';
import { dataStoreService } from '../services/DataStoreService';

@Entry
@Component
struct ReaderPage {
  @State textbookId: string = '';
  @State unitId: string = '';
  @State pageId: string = '';
  @State page: TextbookPage | null = null;
  @State pixelMap: image.PixelMap | null = null;
  @State imgWidth: number = 0;
  @State imgHeight: number = 0;

  // 缩放与拖拽
  @State scale: number = 1.0;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State lastScale: number = 1.0;
  @State lastOffsetX: number = 0;
  @State lastOffsetY: number = 0;

  // 编辑模式
  @State isEditMode: boolean = false;
  @State selectedAnnotationId: string | null = null;

  // 浮层
  @State popoverAnnotation: WordAnnotation | null = null;

  // 编辑对话框
  @State showEditDialog: boolean = false;
  @State editWord: string = '';
  @State editPhonetic: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.textbookId = params['textbookId'] ?? '';
    this.unitId = params['unitId'] ?? '';
    this.pageId = params['pageId'] ?? '';
    this.loadPage();
  }

  aboutToDisappear(): void {
    if (this.pixelMap) {
      this.pixelMap.release();
      this.pixelMap = null;
    }
  }

  private async loadPage(): Promise<void> {
    const textbook = textbookViewModel.textbooks.find(t => t.id === this.textbookId);
    const unit = textbook?.units.find(u => u.id === this.unitId);
    const page = unit?.pages.find(p => p.id === this.pageId);
    if (!page) return;

    this.page = page;

    // 加载图片
    const context = getContext(this);
    const imageBuf = await dataStoreService.loadImage(context, page.imagePath);
    if (imageBuf) {
      const imageSource = image.createImageSource(imageBuf);
      this.pixelMap = await imageSource.createPixelMap();
      imageSource.release();
      const info = this.pixelMap.getImageInfo();
      this.imgWidth = info.size.width;
      this.imgHeight = info.size.height;
    }
  }

  build() {
    Stack() {
      Column() {
        if (this.pixelMap) {
          Stack({ alignContent: Alignment.Center }) {
            // 图片层
            Image(this.pixelMap)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .scale({ x: this.scale, y: this.scale })
              .translate({ x: this.offsetX, y: this.offsetY })
              .gesture(
                GestureGroup(GestureMode.Parallel,
                  PinchGesture()
                    .onActionStart(() => {
                      this.lastScale = this.scale;
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      this.scale = this.lastScale * event.scale;
                    })
                    .onActionEnd(() => {
                      if (this.scale < 1.0) {
                        this.scale = 1.0;
                        this.offsetX = 0;
                        this.offsetY = 0;
                      }
                      this.lastScale = this.scale;
                    }),
                  PanGesture()
                    .onActionStart(() => {
                      this.lastOffsetX = this.offsetX;
                      this.lastOffsetY = this.offsetY;
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      if (this.scale > 1.0) {
                        this.offsetX = this.lastOffsetX + event.offsetX;
                        this.offsetY = this.lastOffsetY + event.offsetY;
                      }
                    })
                )
              )
              .onClick(() => {
                this.popoverAnnotation = null;
              })

            // 标注层
            ForEach(this.page?.annotations ?? [], (annotation: WordAnnotation) => {
              const frame = this.calculateFrame(annotation);
              WordBoundingBox({
                annotation: annotation,
                frame: frame,
                isPopoverVisible: this.popoverAnnotation?.id === annotation.id,
                isSpeaking: speechService.currentWord?.toLowerCase() === annotation.word.toLowerCase(),
                isEditMode: this.isEditMode,
                isSelected: this.selectedAnnotationId === annotation.id
              })
                .position({ x: frame.x, y: frame.y })
                .width(frame.width)
                .height(frame.height)
                .scale({ x: this.scale, y: this.scale })
                .translate({ x: this.offsetX, y: this.offsetY })
                .onClick((event: ClickEvent) => {
                  event.stopPropagation();
                  this.handleAnnotationTap(annotation);
                })
                .gesture(
                  PanGesture()
                    .onActionUpdate((event: GestureEvent) => {
                      if (this.isEditMode) {
                        this.moveAnnotation(annotation, event.offsetX, event.offsetY);
                      }
                    })
                    .onActionEnd(() => {
                      if (this.isEditMode) {
                        this.saveAnnotations();
                      }
                    })
                )
            }, (annotation: WordAnnotation) => annotation.id)

            // 浮层
            if (this.popoverAnnotation) {
              const popoverFrame = this.calculateFrame(this.popoverAnnotation);
              WordPopover({
                annotation: this.popoverAnnotation,
                onSpeak: () => {
                  speechService.speak(this.popoverAnnotation!.word);
                },
                onClose: () => {
                  this.popoverAnnotation = null;
                }
              })
                .position({
                  x: this.clampPopoverX(popoverFrame),
                  y: this.clampPopoverY(popoverFrame)
                })
                .scale({ x: this.scale, y: this.scale })
                .translate({ x: this.offsetX, y: this.offsetY })
            }
          }
          .width('100%')
          .height('100%')
        } else {
          Text('无法加载图片')
            .fontColor('#888888')
        }
      }
      .width('100%')
      .height('100%')

      // 底部工具栏
      Column() {
        Blank()
        BottomToolbar({
          isEditMode: this.isEditMode,
          canReset: this.scale > 1.0,
          onToggleEdit: () => {
            this.isEditMode = !this.isEditMode;
            this.selectedAnnotationId = null;
            this.popoverAnnotation = null;
          },
          onReprocess: () => {
            this.reprocessPage();
          },
          onResetZoom: () => {
            this.scale = 1.0;
            this.lastScale = 1.0;
            this.offsetX = 0;
            this.offsetY = 0;
            this.lastOffsetX = 0;
            this.lastOffsetY = 0;
          }
        })
        .padding({ bottom: 16 })
      }
      .width('100%')
      .height('100%')
      .pointerEvents(PointerEvents.None)

      // 编辑对话框遮罩
      if (this.showEditDialog) {
        Column() {
          AnnotationEditDialog({
            word: this.editWord,
            phonetic: this.editPhonetic,
            isNew: this.selectedAnnotationId === null,
            onWordChange: (value: string) => { this.editWord = value; },
            onPhoneticChange: (value: string) => { this.editPhonetic = value; },
            onSave: () => { this.saveEditedAnnotation(); },
            onDelete: () => { this.deleteSelectedAnnotation(); },
            onCancel: () => { this.showEditDialog = false; }
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .justifyContent(FlexAlign.Center)
        .padding(24)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }

  private calculateFrame(annotation: WordAnnotation): FrameResult {
    // 获取图片在容器中的实际显示尺寸
    const containerW = px2vp(display.getDefaultDisplaySync().width);
    const containerH = px2vp(display.getDefaultDisplaySync().height);
    const aspectRatio = this.imgWidth / this.imgHeight;
    const containerAspectRatio = containerW / containerH;

    let displayW = 0;
    let displayH = 0;
    if (aspectRatio > containerAspectRatio) {
      displayW = containerW;
      displayH = containerW / aspectRatio;
    } else {
      displayH = containerH;
      displayW = containerH * aspectRatio;
    }

    const xOffset = (containerW - displayW) / 2;
    const yOffset = (containerH - displayH) / 2;

    const scaleX = displayW / this.imgWidth;
    const scaleY = displayH / this.imgHeight;

    const x = xOffset + annotation.normalizedX * this.imgWidth * scaleX;
    const y = yOffset + (1.0 - annotation.normalizedY - annotation.normalizedHeight) * this.imgHeight * scaleY;
    const width = annotation.normalizedWidth * this.imgWidth * scaleX;
    const height = annotation.normalizedHeight * this.imgHeight * scaleY;

    return { x, y, width, height };
  }

  private handleAnnotationTap(annotation: WordAnnotation): void {
    if (this.isEditMode) {
      this.selectedAnnotationId = annotation.id;
      this.editWord = annotation.word;
      this.editPhonetic = annotation.phonetic;
      this.showEditDialog = true;
      this.popoverAnnotation = null;
    } else {
      this.popoverAnnotation = annotation;
    }
  }

  private moveAnnotation(annotation: WordAnnotation, deltaX: number, deltaY: number): void {
    const containerW = px2vp(display.getDefaultDisplaySync().width);
    const containerH = px2vp(display.getDefaultDisplaySync().height);
    const aspectRatio = this.imgWidth / this.imgHeight;
    const containerAspectRatio = containerW / containerH;

    let displayW = 0;
    let displayH = 0;
    if (aspectRatio > containerAspectRatio) {
      displayW = containerW;
      displayH = containerW / aspectRatio;
    } else {
      displayH = containerH;
      displayW = containerH * aspectRatio;
    }

    annotation.normalizedX += deltaX / displayW;
    annotation.normalizedY -= deltaY / displayH;
  }

  private async saveAnnotations(): Promise<void> {
    if (!this.page) return;
    await textbookViewModel.updateAnnotations(this.textbookId, this.unitId, this.pageId, this.page.annotations);
  }

  private async saveEditedAnnotation(): Promise<void> {
    if (!this.page) return;

    if (this.selectedAnnotationId) {
      const idx = this.page.annotations.findIndex(a => a.id === this.selectedAnnotationId);
      if (idx >= 0) {
        this.page.annotations[idx].word = this.editWord;
        if (this.editPhonetic.length === 0) {
          const autoPhonetic = phoneticDictionaryService.lookup(this.editWord);
          if (autoPhonetic) {
            this.page.annotations[idx].phonetic = autoPhonetic;
          }
        } else {
          this.page.annotations[idx].phonetic = this.editPhonetic;
          await phoneticDictionaryService.addCustomPhonetic(this.editWord, this.editPhonetic);
        }
      }
    } else {
      // 新建标注
      const phonetic = this.editPhonetic.length === 0
        ? (phoneticDictionaryService.lookup(this.editWord) ?? '')
        : this.editPhonetic;
      const newAnnotation = new WordAnnotation(this.editWord, phonetic, 0.4, 0.4, 0.2, 0.05);
      this.page.annotations.push(newAnnotation);
    }

    await this.saveAnnotations();
    this.showEditDialog = false;
    this.selectedAnnotationId = null;
  }

  private async deleteSelectedAnnotation(): Promise<void> {
    if (!this.page || !this.selectedAnnotationId) return;
    this.page.annotations = this.page.annotations.filter(a => a.id !== this.selectedAnnotationId);
    await this.saveAnnotations();
    this.showEditDialog = false;
    this.selectedAnnotationId = null;
  }

  private async reprocessPage(): Promise<void> {
    if (!this.page || !this.pixelMap) return;

    textbookViewModel.isProcessing = true;
    textbookViewModel.processingProgress = '重新识别中...';

    const results = await ocrService.recognizeText(this.pixelMap);
    const annotations: WordAnnotation[] = [];

    for (const result of results) {
      const phonetic = phoneticDictionaryService.lookup(result.word) ?? '';
      const annotation = new WordAnnotation(
        result.word, phonetic,
        result.normalizedX, result.normalizedY,
        result.normalizedWidth, result.normalizedHeight
      );
      annotations.push(annotation);
    }

    this.page.annotations = annotations;
    await this.saveAnnotations();

    textbookViewModel.isProcessing = false;
    textbookViewModel.processingProgress = '';
  }

  private clampPopoverX(frame: FrameResult): number {
    const containerW = px2vp(display.getDefaultDisplaySync().width);
    const popoverW = 170;
    let x = frame.midX - popoverW / 2;
    x = Math.max(12, Math.min(containerW - popoverW - 12, x));
    return x;
  }

  private clampPopoverY(frame: FrameResult): number {
    const containerH = px2vp(display.getDefaultDisplaySync().height);
    const popoverH = 90;
    let y = frame.minY - 12 - popoverH;
    if (y < 60) {
      y = frame.maxY + 12;
    }
    if (y + popoverH > containerH - 100) {
      y = frame.midY - popoverH / 2;
    }
    return y;
  }
}

interface FrameResult {
  x: number;
  y: number;
  width: number;
  height: number;
  minX: number;
  minY: number;
  maxX: number;
  maxY: number;
  midX: number;
  midY: number;
}

// 扩展 String 原型判断空字符串
  return str.length === 0;
}

  return this.length === 0;
};

    isEmpty(): boolean;
  }
}

@Component
struct WordBoundingBox {
  @Prop annotation: WordAnnotation;
  @Prop frame: FrameResult;
  @Prop isPopoverVisible: boolean;
  @Prop isSpeaking: boolean;
  @Prop isEditMode: boolean;
  @Prop isSelected: boolean;

  build() {
    Column()
      .width('100%')
      .height('100%')
      .borderWidth(this.isSelected ? 2 : 1)
      .borderStyle(BorderStyle.Dashed)
      .borderColor(this.getBorderColor())
      .backgroundColor(this.getBackgroundColor())
      .scale({ x: this.isSpeaking ? 1.05 : 1.0, y: this.isSpeaking ? 1.05 : 1.0 })
      .animation({ duration: 200, curve: Curve.Spring })
  }

  private getBorderColor(): ResourceColor {
    if (this.isPopoverVisible) return '#007AFF';
    if (this.isSpeaking) return '#007AFF';
    if (this.isSelected) return '#FF9500';
    if (this.annotation.phonetic.length === 0) return 'rgba(255,59,48,0.6)';
    return 'rgba(128,128,128,0.5)';
  }

  private getBackgroundColor(): ResourceColor {
    if (this.isPopoverVisible) return 'rgba(0,122,255,0.15)';
    if (this.isSpeaking) return 'rgba(0,122,255,0.2)';
    if (this.isSelected) return 'rgba(255,204,0,0.25)';
    return 'rgba(0,0,0,0)';
  }
}

@Component
struct WordPopover {
  @Prop annotation: WordAnnotation;
  onSpeak: () => void = () => {};
  onClose: () => void = () => {};

  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.annotation.word)
          .fontSize(17)
          .fontWeight(FontWeight.SemiBold)

        Blank()

        Button() {
          Text('🔊')
            .fontSize(16)
        }
        .width(32)
        .height(32)
        .backgroundColor('rgba(0,0,0,0)')
        .onClick(() => this.onSpeak())

        Button() {
          Text('✕')
            .fontSize(16)
            .fontColor('#888888')
        }
        .width(32)
        .height(32)
        .backgroundColor('rgba(0,0,0,0)')
        .onClick(() => this.onClose())
      }
      .width('100%')

      if (this.annotation.phonetic.length > 0) {
        Text(this.annotation.phonetic)
          .fontSize(15)
          .fontColor('#666666')
          .width('100%')
      }

      const meaning = phoneticDictionaryService.lookupMeaning(this.annotation.word);
      if (meaning && meaning.length > 0) {
        Text(meaning)
          .fontSize(15)
          .fontColor('#333333')
          .width('100%')
      }
    }
    .width(170)
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor(Color.White)
    .borderRadius(10)
    .shadow({ radius: 6, color: 'rgba(0,0,0,0.18)', offsetX: 0, offsetY: 3 })
    .border({ width: 0.5, color: 'rgba(0,0,0,0.08)' })
  }
}

@Component
struct BottomToolbar {
  @Prop isEditMode: boolean;
  @Prop canReset: boolean;
  onToggleEdit: () => void = () => {};
  onReprocess: () => void = () => {};
  onResetZoom: () => void = () => {};

  build() {
    Row({ space: 20 }) {
      Column({ space: 4 }) {
        Text(this.isEditMode ? '✓' : '✎')
          .fontSize(28)
          .fontColor(this.isEditMode ? '#34C759' : '#007AFF')
        Text(this.isEditMode ? '完成' : '编辑')
          .fontSize(12)
          .fontColor(this.isEditMode ? '#34C759' : '#007AFF')
      }
      .onClick(() => this.onToggleEdit())

      if (this.isEditMode) {
        Column({ space: 4 }) {
          Text('↻')
            .fontSize(28)
            .fontColor('#FF9500')
          Text('重识')
            .fontSize(12)
            .fontColor('#FF9500')
        }
        .onClick(() => this.onReprocess())
      }

      Blank()

      if (this.canReset) {
        Column({ space: 4 }) {
          Text('⤢')
            .fontSize(28)
            .fontColor('#888888')
          Text('重置')
            .fontSize(12)
            .fontColor('#888888')
        }
        .onClick(() => this.onResetZoom())
      }
    }
    .width('90%')
    .padding(16)
    .backgroundColor('rgba(255,255,255,0.9)')
    .borderRadius(20)
    .pointerEvents(PointerEvents.Auto)
  }
}

@Component
struct AnnotationEditDialog {
  @Prop word: string;
  @Prop phonetic: string;
  @Prop isNew: boolean;
  onWordChange: (value: string) => void = () => {};
  onPhoneticChange: (value: string) => void = () => {};
  onSave: () => void = () => {};
  onDelete: () => void = () => {};
  onCancel: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text(this.isNew ? '添加标注' : '编辑标注')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      Column({ space: 8 }) {
        Text('单词')
          .fontSize(14)
          .fontColor('#666666')
          .width('100%')
        TextInput({ text: this.word, placeholder: '输入单词' })
          .width('100%')
          .height(44)
          .onChange((value: string) => this.onWordChange(value))
      }
      .width('100%')

      Column({ space: 8 }) {
        Text('音标')
          .fontSize(14)
          .fontColor('#666666')
          .width('100%')
        TextInput({ text: this.phonetic, placeholder: '输入音标（可选）' })
          .width('100%')
          .height(44)
          .onChange((value: string) => this.onPhoneticChange(value))

        if (this.phonetic.length === 0 && this.word.length > 0) {
          const autoPhonetic = phoneticDictionaryService.lookup(this.word);
          if (autoPhonetic) {
            Text('自动匹配: ' + autoPhonetic)
              .fontSize(12)
              .fontColor('#34C759')
              .width('100%')
          } else {
            Text('词库中未找到该单词，请手动输入音标')
              .fontSize(12)
              .fontColor('#FF9500')
              .width('100%')
          }
        }
      }
      .width('100%')

      Row({ space: 12 }) {
        if (!this.isNew) {
          Button('删除')
            .width(100)
            .backgroundColor('#FF3B30')
            .onClick(() => this.onDelete())
        }

        Blank()

        Button('取消')
          .width(100)
          .backgroundColor('#E5E5E5')
          .fontColor('#333333')
          .onClick(() => this.onCancel())

        Button('保存')
          .width(100)
          .backgroundColor('#007AFF')
          .enabled(this.word.length > 0)
          .onClick(() => this.onSave())
      }
      .width('100%')
    }
    .width('100%')
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .pointerEvents(PointerEvents.Auto)
  }
}
