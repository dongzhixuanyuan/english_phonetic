import { router } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import fs from '@ohos.file.fs';
import { Textbook, TextbookUnit, TextbookPage } from '../models/Models';
import { textbookViewModel } from '../viewmodel/TextbookViewModel';
import { dataStoreService } from '../services/DataStoreService';

@Entry
@Component
struct TextbookDetail {
  @State textbook: Textbook | null = null;
  @State textbookId: string = '';
  @State expandedUnits: Set<string> = new Set();
  @State showAddUnitDialog: boolean = false;
  @State newUnitName: string = '';
  @State showImagePicker: boolean = false;
  @State selectedUnitId: string = '';
  @State showRenameDialog: boolean = false;
  @State renamePageName: string = '';
  @State renamePageId: string = '';
  @State renameUnitId: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.textbookId = params['textbookId'] ?? '';
    this.refreshTextbook();
  }

  private refreshTextbook(): void {
    this.textbook = textbookViewModel.textbooks.find(t => t.id === this.textbookId) ?? null;
  }

  build() {
    Column() {
      if (this.textbook) {
        // 课本信息头
        TextbookHeader({ textbook: this.textbook })

        // 添加单元按钮
        Button('添加单元')
          .width('90%')
          .height(44)
          .backgroundColor('#007AFF')
          .margin({ top: 12, bottom: 12 })
          .onClick(() => {
            this.showAddUnitDialog = true;
          })

        // 单元列表
        if (this.textbook.units.length === 0) {
          EmptyUnitView()
        } else {
          List({ space: 8 }) {
            ForEach(this.textbook.units.sort((a, b) => a.order - b.order), (unit: TextbookUnit) => {
              ListItem() {
                UnitSection({
                  unit: unit,
                  textbookId: this.textbookId,
                  isExpanded: this.expandedUnits.has(unit.id),
                  onToggle: () => {
                    const newSet = new Set(this.expandedUnits);
                    if (newSet.has(unit.id)) {
                      newSet.delete(unit.id);
                    } else {
                      newSet.add(unit.id);
                    }
                    this.expandedUnits = newSet;
                  },
                  onAddPage: (unitId: string) => {
                    this.selectedUnitId = unitId;
                    this.showImagePicker = true;
                  },
                  onPageClick: (page: TextbookPage, unit: TextbookUnit) => {
                    router.pushUrl({
                      url: 'pages/ReaderPage',
                      params: {
                        textbookId: this.textbookId,
                        unitId: unit.id,
                        pageId: page.id
                      }
                    });
                  },
                  onRenamePage: (page: TextbookPage, unitId: string) => {
                    this.renamePageId = page.id;
                    this.renameUnitId = unitId;
                    this.renamePageName = page.name;
                    this.showRenameDialog = true;
                  },
                  onDeletePage: async (page: TextbookPage, unitId: string) => {
                    const context = getContext(this);
                    await textbookViewModel.deletePage(context, this.textbookId, unitId, page);
                    this.refreshTextbook();
                  }
                })
              }
            }, (unit: TextbookUnit) => unit.id)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
          .edgeEffect(EdgeEffect.Spring)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
    .bindSheet(this.showAddUnitDialog, this.AddUnitDialog(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      onDisappear: () => { this.showAddUnitDialog = false; }
    })
    .bindSheet(this.showImagePicker, this.ImagePickerDialog(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      onDisappear: () => { this.showImagePicker = false; }
    })
    .bindSheet(this.showRenameDialog, this.RenameDialog(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      onDisappear: () => { this.showRenameDialog = false; }
    })
  }

  @Builder
  AddUnitDialog() {
    Column({ space: 16 }) {
      Text('添加单元')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      TextInput({ placeholder: '例如：Unit 1 Hello' })
        .width('100%')
        .height(48)
        .onChange((value: string) => { this.newUnitName = value; })

      Row({ space: 12 }) {
        Button('取消')
          .width(120)
          .backgroundColor('#E5E5E5')
          .fontColor('#333333')
          .onClick(() => {
            this.showAddUnitDialog = false;
            this.newUnitName = '';
          })

        Button('添加')
          .width(120)
          .backgroundColor('#007AFF')
          .enabled(this.newUnitName.length > 0)
          .onClick(() => {
            if (this.newUnitName.length > 0) {
              textbookViewModel.addUnit(this.textbookId, this.newUnitName);
              this.refreshTextbook();
              this.showAddUnitDialog = false;
              this.newUnitName = '';
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

  @Builder
  ImagePickerDialog() {
    Column({ space: 20 }) {
      Text('选择图片')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      Button('从相册选择')
        .width('100%')
        .height(56)
        .backgroundColor('#007AFF')
        .onClick(() => {
          this.pickFromGallery();
        })

      Button('取消')
        .width('100%')
        .height(56)
        .backgroundColor('#E5E5E5')
        .fontColor('#333333')
        .onClick(() => {
          this.showImagePicker = false;
        })
    }
    .width('100%')
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 20, topRight: 20 })
  }

  @Builder
  RenameDialog() {
    Column({ space: 16 }) {
      Text('重命名页面')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      TextInput({ text: this.renamePageName })
        .width('100%')
        .height(48)
        .onChange((value: string) => { this.renamePageName = value; })

      Row({ space: 12 }) {
        Button('取消')
          .width(120)
          .backgroundColor('#E5E5E5')
          .fontColor('#333333')
          .onClick(() => {
            this.showRenameDialog = false;
          })

        Button('保存')
          .width(120)
          .backgroundColor('#007AFF')
          .enabled(this.renamePageName.length > 0)
          .onClick(async () => {
            await textbookViewModel.renamePage(this.textbookId, this.renameUnitId,
              this.renamePageId, this.renamePageName);
            this.refreshTextbook();
            this.showRenameDialog = false;
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

  private async pickFromGallery(): Promise<void> {
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });

      if (result.photoUris.length > 0) {
        const uri = result.photoUris[0];
        await this.processSelectedImage(uri);
      }
      this.showImagePicker = false;
    } catch (err) {
      console.error('选图失败:', JSON.stringify(err));
    }
  }

  private async processSelectedImage(uri: string): Promise<void> {
    try {
      const context = getContext(this);
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);

      const imageSource = image.createImageSource(buf);
      const pixelMap = await imageSource.createPixelMap();
      imageSource.release();

      const totalPages = this.textbook?.units.reduce((sum, u) => sum + u.pages.length, 0) ?? 0;
      const pageName = `Page ${totalPages + 1}`;

      const page = await textbookViewModel.addPage(context, this.textbookId, this.selectedUnitId,
        pixelMap, pageName);

      pixelMap.release();

      if (page) {
        this.refreshTextbook();
        // 导航到点读页
        router.pushUrl({
          url: 'pages/ReaderPage',
          params: {
            textbookId: this.textbookId,
            unitId: this.selectedUnitId,
            pageId: page.id
          }
        });
      }
    } catch (err) {
      console.error('处理图片失败:', JSON.stringify(err));
    }
  }
}

@Component
struct TextbookHeader {
  @Prop textbook: Textbook;

  private get totalPages(): number {
    return this.textbook.units.reduce((sum, unit) => sum + unit.pages.length, 0);
  }

  build() {
    Row({ space: 16 }) {
      Column() {
        Text('📖')
          .fontSize(40)
      }
      .width(80)
      .height(100)
      .backgroundColor('#E8F5E9')
      .borderRadius(8)
      .justifyContent(FlexAlign.Center)

      Column({ space: 6 }) {
        Text(this.textbook.name)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(`${this.totalPages} 页 · ${this.textbook.units.length} 个单元`)
          .fontSize(14)
          .fontColor('#888888')
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ left: 16, right: 16, top: 12 })
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.05)', offsetX: 0, offsetY: 2 })
  }
}

@Component
struct UnitSection {
  @Prop unit: TextbookUnit;
  @Prop textbookId: string;
  @Prop isExpanded: boolean;
  onToggle: () => void = () => {};
  onAddPage: (unitId: string) => void = () => {};
  onPageClick: (page: TextbookPage, unit: TextbookUnit) => void = () => {};
  onRenamePage: (page: TextbookPage, unitId: string) => void = () => {};
  onDeletePage: (page: TextbookPage, unitId: string) => void = () => {};

  build() {
    Column({ space: 0 }) {
      // 单元标题（可点击折叠）
      Row() {
        Text(this.unit.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(`${this.unit.pages.length} 页`)
          .fontSize(12)
          .fontColor('#888888')

        Text(this.isExpanded ? '▲' : '▼')
          .fontSize(12)
          .fontColor('#888888')
          .margin({ left: 8 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F8F8F8')
      .onClick(() => {
        this.onToggle();
      })

      // 展开的页面列表
      if (this.isExpanded) {
        Column({ space: 12 }) {
          if (this.unit.pages.length > 0) {
            Grid() {
              ForEach(this.unit.pages.sort((a, b) => a.order - b.order), (page: TextbookPage) => {
                GridItem() {
                  PageThumbnail({
                    page: page,
                    onClick: () => this.onPageClick(page, this.unit),
                    onRename: () => this.onRenamePage(page, this.unit.id),
                    onDelete: () => this.onDeletePage(page, this.unit.id)
                  })
                }
              }, (page: TextbookPage) => page.id)
            }
            .columnsTemplate('1fr 1fr 1fr')
            .columnsGap(8)
            .rowsGap(8)
            .width('100%')
          }

          Button('添加页面')
            .width('100%')
            .height(40)
            .backgroundColor('#E3F2FD')
            .fontColor('#007AFF')
            .onClick(() => {
              this.onAddPage(this.unit.id);
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(Color.White)
      }
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.04)', offsetX: 0, offsetY: 2 })
  }
}

@Component
struct PageThumbnail {
  @Prop page: TextbookPage;
  onClick: () => void = () => {};
  onRename: () => void = () => {};
  onDelete: () => void = () => {};

  build() {
    Column({ space: 4 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
          if (this.page.imagePath) {
            Image('memory://' + this.page.imagePath)
              .width('100%')
              .height(100)
              .borderRadius(6)
              .objectFit(ImageFit.Cover)
          } else {
            Text('📄')
              .fontSize(24)
              .fontColor('#CCCCCC')
          }
        }
        .width('100%')
        .height(100)
        .backgroundColor('#F5F5F5')
        .borderRadius(6)
        .justifyContent(FlexAlign.Center)

        Text('⋯')
          .fontSize(16)
          .fontColor('#333333')
          .backgroundColor('rgba(255,255,255,0.8)')
          .borderRadius(10)
          .width(24)
          .height(24)
          .textAlign(TextAlign.Center)
          .onClick((event: ClickEvent) => {
            event.stopPropagation();
            this.showMenu();
          })
          .margin(4)
      }
      .width('100%')

      Text(this.page.name)
        .fontSize(11)
        .fontColor('#333333')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .onClick(() => {
      this.onClick();
    })
  }

  private showMenu(): void {
    // 简化处理，直接显示 AlertDialog
    AlertDialog.show({
      title: '页面操作',
      message: this.page.name,
      buttons: [
        {
          value: '重命名',
          action: () => this.onRename()
        },
        {
          value: '删除',
          fontColor: '#FF3B30',
          action: () => this.onDelete()
        },
        {
          value: '取消',
          action: () => {}
        }
      ]
    });
  }
}

@Component
struct EmptyUnitView {
  build() {
    Column({ space: 16 }) {
      Text('📁')
        .fontSize(50)
        .fontColor('#CCCCCC')

      Text('还没有单元')
        .fontSize(16)
        .fontColor('#888888')

      Text('先添加一个单元，再拍照导入课本页面')
        .fontSize(13)
        .fontColor('#AAAAAA')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 50, bottom: 50 })
    .backgroundColor('#F0F0F0')
    .borderRadius(12)
    .margin({ left: 16, right: 16 })
  }
}
