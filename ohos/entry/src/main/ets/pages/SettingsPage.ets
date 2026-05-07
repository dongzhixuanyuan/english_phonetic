import { router } from '@kit.ArkUI';
import { speechService } from '../services/SpeechService';
import { textbookViewModel } from '../viewmodel/TextbookViewModel';
import { dataStoreService } from '../services/DataStoreService';

@Entry
@Component
struct SettingsPage {
  @State accent: string = 'en-US';
  @State speechRate: number = 1.0;

  aboutToAppear(): void {
    this.accent = speechService.accent;
    this.speechRate = speechService.speechRate;
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Button() {
          Text('‹ 返回')
            .fontSize(16)
            .fontColor('#007AFF')
        }
        .backgroundColor('rgba(0,0,0,0)')
        .onClick(() => {
          router.back();
        })

        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)

        Blank()
          .width(60)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      List({ space: 12 }) {
        ListItem() {
          Column({ space: 8 }) {
            Text('发音偏好')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')

            Row({ space: 16 }) {
              Button('美音 (en-US)')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(this.accent === 'en-US' ? '#007AFF' : '#E5E5E5')
                .fontColor(this.accent === 'en-US' ? Color.White : '#333333')
                .onClick(() => {
                  this.accent = 'en-US';
                  speechService.accent = 'en-US';
                })

              Button('英音 (en-GB)')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(this.accent === 'en-GB' ? '#007AFF' : '#E5E5E5')
                .fontColor(this.accent === 'en-GB' ? Color.White : '#333333')
                .onClick(() => {
                  this.accent = 'en-GB';
                  speechService.accent = 'en-GB';
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
        }

        ListItem() {
          Column({ space: 8 }) {
            Text('发音速度')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')

            Row({ space: 16 }) {
              Button('慢速')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(this.speechRate === 0.5 ? '#007AFF' : '#E5E5E5')
                .fontColor(this.speechRate === 0.5 ? Color.White : '#333333')
                .onClick(() => {
                  this.speechRate = 0.5;
                  speechService.speechRate = 0.5;
                })

              Button('常速')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(this.speechRate === 1.0 ? '#007AFF' : '#E5E5E5')
                .fontColor(this.speechRate === 1.0 ? Color.White : '#333333')
                .onClick(() => {
                  this.speechRate = 1.0;
                  speechService.speechRate = 1.0;
                })

              Button('快速')
                .layoutWeight(1)
                .height(44)
                .backgroundColor(this.speechRate === 1.5 ? '#007AFF' : '#E5E5E5')
                .fontColor(this.speechRate === 1.5 ? Color.White : '#333333')
                .onClick(() => {
                  this.speechRate = 1.5;
                  speechService.speechRate = 1.5;
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
        }

        ListItem() {
          Column({ space: 8 }) {
            Text('数据管理')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .width('100%')

            Button('清除所有数据')
              .width('100%')
              .height(48)
              .backgroundColor('#FF3B30')
              .onClick(() => {
                AlertDialog.show({
                  title: '确认清除',
                  message: '这将删除所有课本和自定义数据，此操作不可恢复。',
                  primaryButton: {
                    value: '取消',
                    action: () => {}
                  },
                  secondaryButton: {
                    value: '清除',
                    fontColor: '#FF3B30',
                    action: async () => {
                      const context = getContext(this);
                      for (const textbook of textbookViewModel.textbooks) {
                        for (const unit of textbook.units) {
                          for (const page of unit.pages) {
                            await dataStoreService.deleteImage(context, page.imagePath);
                          }
                        }
                      }
                      textbookViewModel.textbooks = [];
                      await dataStoreService.saveTextbooks([]);
                      router.back();
                    }
                  }
                });
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
        }
      }
      .width('100%')
      .padding(16)
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }
}
