import textToSpeech from '@hms.ai.textToSpeech';
import { BusinessError } from '@kit.BasicServicesKit';

const ACCENT_KEY = 'speech_accent';
const RATE_KEY = 'speech_rate';

class SpeechService {
  private engine: textToSpeech.TextToSpeechEngine | null = null;
  private _accent: string = 'en-US';
  private _speechRate: number = 1.0;
  private isSpeakingFlag: boolean = false;
  private currentWordValue: string | null = null;

  // 使用 AppStorage 做持久化
  async init(): Promise<void> {
    this._accent = AppStorage.get<string>(ACCENT_KEY) ?? 'en-US';
    this._speechRate = AppStorage.get<number>(RATE_KEY) ?? 1.0;
    await this.createEngine();
  }

  private async createEngine(): Promise<void> {
    try {
      const params: textToSpeech.CreateEngineParams = {
        language: this._accent,
        person: this._accent === 'en-GB' ? 1 : 0,
        online: 1 // 1 = 离线
      };
      this.engine = await textToSpeech.createEngine(params);

      this.engine.setListener({
        onStart: (requestId: string, response: textToSpeech.StartResponse) => {
          this.isSpeakingFlag = true;
        },
        onComplete: (requestId: string, response: textToSpeech.CompleteResponse) => {
          this.isSpeakingFlag = false;
          this.currentWordValue = null;
        },
        onStop: (requestId: string, response: textToSpeech.StopResponse) => {
          this.isSpeakingFlag = false;
          this.currentWordValue = null;
        },
        onError: (requestId: string, errorCode: number, errorMessage: string) => {
          console.error('TTS 错误:', errorCode, errorMessage);
          this.isSpeakingFlag = false;
          this.currentWordValue = null;
        }
      });
    } catch (err) {
      console.error('创建 TTS 引擎失败:', JSON.stringify(err));
    }
  }

  get accent(): string {
    return this._accent;
  }

  set accent(value: string) {
    this._accent = value;
    AppStorage.setOrCreate(ACCENT_KEY, value);
    this.createEngine(); // 重新创建引擎
  }

  get speechRate(): number {
    return this._speechRate;
  }

  set speechRate(value: number) {
    this._speechRate = value;
    AppStorage.setOrCreate(RATE_KEY, value);
  }

  get isSpeaking(): boolean {
    return this.isSpeakingFlag;
  }

  get currentWord(): string | null {
    return this.currentWordValue;
  }

  speak(word: string): void {
    if (!this.engine) {
      console.error('TTS 引擎未初始化');
      return;
    }
    if (this.engine.isBusy()) {
      this.engine.stop();
    }
    this.currentWordValue = word;
    const params: textToSpeech.SpeakParams = {
      requestId: Date.now().toString()
    };
    this.engine.speak(word, params);
  }

  stop(): void {
    if (this.engine) {
      this.engine.stop();
    }
  }

  shutdown(): void {
    if (this.engine) {
      this.engine.shutdown();
      this.engine = null;
    }
  }
}

export const speechService = new SpeechService();
