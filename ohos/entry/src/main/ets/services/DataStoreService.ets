import { preferences } from '@kit.ArkData';
import fs from '@ohos.file.fs';
import { Textbook } from '../models/Models';

const TEXTBOOKS_KEY = 'saved_textbooks';
const PREFERENCES_NAME = 'english_phonetic_app';

class DataStoreService {
  private pref: preferences.Preferences | null = null;

  async init(context: Context): Promise<void> {
    this.pref = await preferences.getPreferences(context, PREFERENCES_NAME);
  }

  async saveTextbooks(textbooks: Textbook[]): Promise<void> {
    if (!this.pref) return;
    const jsonStr = JSON.stringify(textbooks.map(t => t.toJSON()));
    await this.pref.put(TEXTBOOKS_KEY, jsonStr);
    await this.pref.flush();
  }

  async loadTextbooks(): Promise<Textbook[]> {
    if (!this.pref) return [];
    const jsonStr = await this.pref.get(TEXTBOOKS_KEY, '[]') as string;
    try {
      const arr = JSON.parse(jsonStr) as Array<Record<string, Object>>;
      return arr.map(item => Textbook.fromJSON(item));
    } catch (e) {
      return [];
    }
  }

  async saveImage(context: Context, imageBuffer: ArrayBuffer, pageId: string): Promise<string | null> {
    try {
      const dir = context.filesDir + '/images';
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir);
      }
      const filePath = dir + '/' + pageId + '.jpg';
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, imageBuffer);
      fs.closeSync(file);
      return pageId + '.jpg';
    } catch (err) {
      console.error('保存图片失败:', JSON.stringify(err));
      return null;
    }
  }

  async loadImage(context: Context, filename: string): Promise<ArrayBuffer | null> {
    try {
      const filePath = context.filesDir + '/images/' + filename;
      if (!fs.accessSync(filePath)) {
        return null;
      }
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      return buf;
    } catch (err) {
      return null;
    }
  }

  async deleteImage(context: Context, filename: string): Promise<void> {
    try {
      const filePath = context.filesDir + '/images/' + filename;
      if (fs.accessSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    } catch (err) {
      // 忽略删除失败
    }
  }
}

export const dataStoreService = new DataStoreService();
