import { router } from '@kit.ArkUI';
import { Textbook } from '../models/Models';
import { textbookViewModel } from '../viewmodel/TextbookViewModel';
import { dataStoreService } from '../services/DataStoreService';

@Entry
@Component
struct Index {
  @State textbooks: Textbook[] = [];
  @State showAddDialog: boolean = false;
  @State newTextbookName: string = '';

  aboutToAppear(): void {
    const context = getContext(this);
    textbookViewModel.loadTextbooks(context).then(() => {
      this.textbooks = textbookViewModel.textbooks;
    });
  }

  build() {
    Column({ space: 16 }) {
      // 顶部标题区域
      Column({ space: 8 }) {
        Text('英语音标点读')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .width('100%')

        Text('给课本拍张照，秒变会说话的音标点读机')
          .fontSize(14)
          .fontColor('#666666')
          .width('100%')
      }
      .padding({ left: 16, right: 16, top: 16 })
      .alignItems(HorizontalAlign.Start)

      // 我的课本区域
      Row() {
        Text('📚 我的课本')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)

        Blank()

        Button() {
          Text('+')
            .fontSize(24)
            .fontColor(Color.White)
        }
        .width(40)
        .height(40)
        .backgroundColor('#007AFF')
        .onClick(() => {
          this.showAddDialog = true;
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 课本列表或空状态
      if (this.getUserTextbooks().length === 0) {
        EmptyTextbooksView()
      } else {
        List({ space: 12 }) {
          ForEach(this.getUserTextbooks(), (textbook: Textbook) => {
            ListItem() {
              TextbookCard({ textbook: textbook })
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/TextbookDetail',
                    params: { textbookId: textbook.id }
                  });
                })
            }
          }, (textbook: Textbook) => textbook.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
    .bindSheet(this.showAddDialog, this.AddTextbookDialog(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      onDisappear: () => {
        this.showAddDialog = false;
      }
    })
  }

  @Builder
  AddTextbookDialog() {
    Column({ space: 16 }) {
      Text('添加课本')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      TextInput({ placeholder: '请输入课本名称，例如：人教版三年级上册' })
        .width('100%')
        .height(48)
        .onChange((value: string) => {
          this.newTextbookName = value;
        })

      Row({ space: 12 }) {
        Button('取消')
          .width(120)
          .backgroundColor('#E5E5E5')
          .fontColor('#333333')
          .onClick(() => {
            this.showAddDialog = false;
            this.newTextbookName = '';
          })

        Button('添加')
          .width(120)
          .backgroundColor('#007AFF')
          .enabled(this.newTextbookName.length > 0)
          .onClick(() => {
            if (this.newTextbookName.length > 0) {
              textbookViewModel.addTextbook(this.newTextbookName);
              this.textbooks = [...textbookViewModel.textbooks];
              this.showAddDialog = false;
              this.newTextbookName = '';
            }
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 20, topRight: 20 })
  }

  getUserTextbooks(): Textbook[] {
    return this.textbooks.filter(t => t.name !== '示例课本');
  }
}

@Component
struct TextbookCard {
  @Prop textbook: Textbook;

  private get totalPages(): number {
    return this.textbook.units.reduce((sum, unit) => sum + unit.pages.length, 0);
  }

  build() {
    Row({ space: 16 }) {
      // 封面区域
      Column() {
        if (this.textbook.coverImagePath) {
          // 实际加载图片
          Image('memory://' + this.textbook.coverImagePath)
            .width(70)
            .height(90)
            .borderRadius(8)
            .objectFit(ImageFit.Cover)
        } else {
          Text('📖')
            .fontSize(32)
        }
      }
      .width(70)
      .height(90)
      .backgroundColor('#E8F5E9')
      .borderRadius(8)
      .justifyContent(FlexAlign.Center)

      // 信息区域
      Column({ space: 6 }) {
        Text(this.textbook.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(`${this.totalPages} 页 · ${this.textbook.units.length} 个单元`)
          .fontSize(13)
          .fontColor('#888888')
          .width('100%')

        Text(this.formatDate(this.textbook.createdAt))
          .fontSize(11)
          .fontColor('#AAAAAA')
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 箭头
      Text('›')
        .fontSize(24)
        .fontColor('#CCCCCC')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.05)', offsetX: 0, offsetY: 2 })
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    if (days === 0) return '今天';
    if (days === 1) return '昨天';
    if (days < 7) return `${days}天前`;
    if (days < 30) return `${Math.floor(days / 7)}周前`;
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
  }
}

@Component
struct EmptyTextbooksView {
  build() {
    Column({ space: 16 }) {
      Text('📷')
        .fontSize(60)
        .fontColor('#CCCCCC')

      Text('还没有课本')
        .fontSize(16)
        .fontColor('#888888')

      Text('点击右上角 + 号，添加孩子的英语课本')
        .fontSize(13)
        .fontColor('#AAAAAA')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 60, bottom: 60 })
    .backgroundColor('#F0F0F0')
    .borderRadius(12)
    .margin({ left: 16, right: 16 })
  }
}
