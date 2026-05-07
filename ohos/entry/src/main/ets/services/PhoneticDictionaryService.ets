import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';

const USER_EXTENSIONS_KEY = 'user_phonetic_extensions';
const PREFERENCES_NAME = 'phonetic_dictionary';

class PhoneticDictionaryService {
  private phoneticDict: Map<string, string> = new Map();
  private meaningDict: Map<string, string> = new Map();
  private pref: preferences.Preferences | null = null;
  private initialized = false;

  async init(context: Context): Promise<void> {
    if (this.initialized) return;

    // 加载内置词库
    await this.loadBuiltinDictionary(context);

    // 加载用户扩展词库
    this.pref = await preferences.getPreferences(context, PREFERENCES_NAME);
    const userData = await this.pref.get(USER_EXTENSIONS_KEY, '{}') as string;
    try {
      const userDict = JSON.parse(userData) as Record<string, string>;
      for (const [word, phonetic] of Object.entries(userDict)) {
        this.phoneticDict.set(word.toLowerCase(), phonetic);
      }
    } catch (e) {
      // 忽略解析错误
    }

    this.initialized = true;
    console.log('📚 音标词库加载完成，共', this.phoneticDict.size, '个单词');
  }

  private async loadBuiltinDictionary(context: Context): Promise<void> {
    try {
      const resourceManager = context.resourceManager;
      const rawData = await resourceManager.getRawFileContent('phonetic_dictionary.json');
      const decoder = new util.TextDecoder('utf-8');
      const jsonStr = decoder.decodeToString(rawData);
      const json = JSON.parse(jsonStr) as Record<string, Record<string, string>>;

      for (const [word, info] of Object.entries(json)) {
        const key = word.toLowerCase();
        this.phoneticDict.set(key, info['phonetic'] ?? '');
        this.meaningDict.set(key, info['meaning'] ?? '');
      }
    } catch (err) {
      console.error('加载内置词库失败:', JSON.stringify(err));
    }
  }

  lookup(word: string): string | undefined {
    const cleanWord = word.toLowerCase().trim().replace(/[^a-zA-Z]/g, '');
    return this.phoneticDict.get(cleanWord);
  }

  lookupMeaning(word: string): string | undefined {
    const cleanWord = word.toLowerCase().trim().replace(/[^a-zA-Z]/g, '');
    return this.meaningDict.get(cleanWord);
  }

  async addCustomPhonetic(word: string, phonetic: string): Promise<void> {
    const key = word.toLowerCase().trim();
    this.phoneticDict.set(key, phonetic);

    if (this.pref) {
      const userData = await this.pref.get(USER_EXTENSIONS_KEY, '{}') as string;
      let userDict: Record<string, string> = {};
      try {
        userDict = JSON.parse(userData);
      } catch (e) {
        // 忽略
      }
      userDict[key] = phonetic;
      await this.pref.put(USER_EXTENSIONS_KEY, JSON.stringify(userDict));
      await this.pref.flush();
    }
  }
}

export const phoneticDictionaryService = new PhoneticDictionaryService();
