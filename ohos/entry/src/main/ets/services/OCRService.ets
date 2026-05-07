import { image } from '@kit.ImageKit';
import textRecognition from '@hms.ai.ocr.textRecognition';
import { WordAnnotation } from '../models/Models';

export interface OCRResult {
  word: string;
  normalizedX: number;
  normalizedY: number;
  normalizedWidth: number;
  normalizedHeight: number;
}

class OCRService {
  async recognizeText(pixelMap: image.PixelMap): Promise<OCRResult[]> {
    try {
      const imageInfo = await pixelMap.getImageInfo();
      const imgWidth = imageInfo.size.width;
      const imgHeight = imageInfo.size.height;

      const visionInfo: textRecognition.VisionInfo = {
        pixelMap: pixelMap
      };

      const result = await textRecognition.recognizeText(visionInfo);
      const ocrResults: OCRResult[] = [];

      for (const block of result.blocks) {
        for (const line of block.lines) {
          for (const word of line.words) {
            const text = word.value.trim();
            if (!this.shouldKeep(text)) {
              continue;
            }

            // 从 cornerPoints 计算边界框
            const points = word.cornerPoints;
            if (points.length < 4) continue;

            let minX = Number.MAX_VALUE;
            let minY = Number.MAX_VALUE;
            let maxX = Number.MIN_VALUE;
            let maxY = Number.MIN_VALUE;

            for (const p of points) {
              minX = Math.min(minX, p.x);
              minY = Math.min(minY, p.y);
              maxX = Math.max(maxX, p.x);
              maxY = Math.max(maxY, p.y);
            }

            const width = maxX - minX;
            const height = maxY - minY;

            ocrResults.push({
              word: text,
              normalizedX: minX / imgWidth,
              normalizedY: minY / imgHeight,
              normalizedWidth: width / imgWidth,
              normalizedHeight: height / imgHeight
            });
          }
        }
      }

      return ocrResults;
    } catch (err) {
      console.error('OCR 识别失败:', JSON.stringify(err));
      return [];
    }
  }

  private shouldKeep(text: string): boolean {
    if (text.length === 0) return false;
    if (/^\d+$/.test(text)) return false;
    if (text.length < 2 && text !== 'I' && text !== 'a') return false;
    const letters = text.replace(/[^a-zA-Z]/g, '');
    if (letters.length === 0) return false;
    return true;
  }
}

export const ocrService = new OCRService();
