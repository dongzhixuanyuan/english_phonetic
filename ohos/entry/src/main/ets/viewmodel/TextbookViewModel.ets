import { Textbook, TextbookUnit, TextbookPage, WordAnnotation } from '../models/Models';
import { dataStoreService } from '../services/DataStoreService';
import { ocrService } from '../services/OCRService';
import { phoneticDictionaryService } from '../services/PhoneticDictionaryService';
import { image } from '@kit.ImageKit';

class TextbookViewModel {
  textbooks: Textbook[] = [];
  isProcessing: boolean = false;
  processingProgress: string = '';

  async loadTextbooks(context: Context): Promise<void> {
    await dataStoreService.init(context);
    await phoneticDictionaryService.init(context);
    this.textbooks = await dataStoreService.loadTextbooks();
    this.setupSamplePages();
  }

  private setupSamplePages(): void {
    if (this.textbooks.some(t => t.name === '示例课本')) {
      return;
    }
    const sampleUnit = new TextbookUnit('Unit 1 Hello', 0);
    const sampleTextbook = new Textbook('示例课本', null, Date.now(), [sampleUnit]);
    this.textbooks.unshift(sampleTextbook);
    this.saveTextbooks();
  }

  private async saveTextbooks(): Promise<void> {
    await dataStoreService.saveTextbooks(this.textbooks);
  }

  addTextbook(name: string): Textbook {
    const textbook = new Textbook(name);
    this.textbooks.push(textbook);
    this.saveTextbooks();
    return textbook;
  }

  deleteTextbook(textbook: Textbook, context: Context): void {
    for (const unit of textbook.units) {
      for (const page of unit.pages) {
        dataStoreService.deleteImage(context, page.imagePath);
      }
    }
    this.textbooks = this.textbooks.filter(t => t.id !== textbook.id);
    this.saveTextbooks();
  }

  addUnit(textbookId: string, name: string): TextbookUnit | null {
    const textbook = this.textbooks.find(t => t.id === textbookId);
    if (!textbook) return null;
    const order = textbook.units.length;
    const unit = new TextbookUnit(name, order);
    textbook.units.push(unit);
    this.saveTextbooks();
    return unit;
  }

  async addPage(context: Context, textbookId: string, unitId: string, pixelMap: image.PixelMap,
    pageName: string): Promise<TextbookPage | null> {
    this.isProcessing = true;
    this.processingProgress = '正在识别文字...';

    const pageId = new TextbookPage().id;

    // 将 PixelMap 保存为图片文件
    const imagePacker = image.createImagePacker();
    const packOpts: image.PackingOption = { format: 'image/jpeg', quality: 80 };
    const imageBuffer = await imagePacker.packing(pixelMap, packOpts);
    imagePacker.release();

    const imageFilename = await dataStoreService.saveImage(context, imageBuffer, pageId);
    if (!imageFilename) {
      this.isProcessing = false;
      this.processingProgress = '';
      return null;
    }

    this.processingProgress = '正在生成音标...';

    // OCR 识别
    const ocrResults = await ocrService.recognizeText(pixelMap);
    const annotations: WordAnnotation[] = [];

    for (const result of ocrResults) {
      const phonetic = phoneticDictionaryService.lookup(result.word) ?? '';
      const annotation = new WordAnnotation(
        result.word,
        phonetic,
        result.normalizedX,
        result.normalizedY,
        result.normalizedWidth,
        result.normalizedHeight
      );
      annotations.push(annotation);
    }

    const page = new TextbookPage(pageName, imageFilename, 0, annotations);

    const textbook = this.textbooks.find(t => t.id === textbookId);
    const unit = textbook?.units.find(u => u.id === unitId);
    if (unit) {
      unit.pages.push(page);
      await this.saveTextbooks();
    }

    this.isProcessing = false;
    this.processingProgress = '';
    return page;
  }

  async updateAnnotations(textbookId: string, unitId: string, pageId: string,
    annotations: WordAnnotation[]): Promise<void> {
    const textbook = this.textbooks.find(t => t.id === textbookId);
    const unit = textbook?.units.find(u => u.id === unitId);
    const page = unit?.pages.find(p => p.id === pageId);
    if (page) {
      page.annotations = annotations;
      await this.saveTextbooks();
    }
  }

  async deletePage(context: Context, textbookId: string, unitId: string, page: TextbookPage): Promise<void> {
    await dataStoreService.deleteImage(context, page.imagePath);
    const textbook = this.textbooks.find(t => t.id === textbookId);
    const unit = textbook?.units.find(u => u.id === unitId);
    if (unit) {
      unit.pages = unit.pages.filter(p => p.id !== page.id);
      await this.saveTextbooks();
    }
  }

  async renamePage(textbookId: string, unitId: string, pageId: string, newName: string): Promise<void> {
    const textbook = this.textbooks.find(t => t.id === textbookId);
    const unit = textbook?.units.find(u => u.id === unitId);
    const page = unit?.pages.find(p => p.id === pageId);
    if (page) {
      page.name = newName;
      await this.saveTextbooks();
    }
  }
}

export const textbookViewModel = new TextbookViewModel();
