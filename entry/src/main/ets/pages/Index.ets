import { NovelCrawler } from '../utils/NovelCrawler';

@Entry
@Component
struct Index {
  @State baseUrl: string = '';
  @State startPage: string = '2';
  @State endPage: string = '';
  @State outputFileName: string = '';
  @State statusMessage: string = '';
  @State isRunning: boolean = false;
  @State progress: number = 0;
  @State savedNovels: string[] = [];
  private novelCrawler: NovelCrawler | null = null;

  private getNovelCrawler(): NovelCrawler {
    if (!this.novelCrawler) {
      this.novelCrawler = new NovelCrawler();
    }
    return this.novelCrawler;
  }

  // 自动转换URL格式，并提取页码设置结束页码
  autoConvertUrl() {
    if (this.baseUrl) {
      this.baseUrl = this.baseUrl.replace(/(_)(\d+)(\.html)/, (_match: string, p1: string, p2: string, p3: string) => {
        this.endPage = p2;
        return `${p1}{}${p3}`;
      });
    }
  }

  // 开始爬取逻辑
  async startCrawling() {

    if (!this.baseUrl) {
      this.statusMessage = '请先输入基础URL';
      return;
    }

    // 验证起始页码
    let startNum = parseInt(this.startPage) || 2;
    if (isNaN(startNum) || startNum <= 0 || !Number.isInteger(startNum)) {
      this.statusMessage = '起始页码必须是正整数';
      return;
    }

    // 验证结束页码
    let endNum = parseInt(this.endPage) || 2;
    if (isNaN(endNum) || endNum <= 0 || !Number.isInteger(endNum)) {
      this.statusMessage = '结束页码必须是正整数';
      return;
    }

    if (startNum > endNum) {
      this.statusMessage = '起始页码不能大于结束页码';
      return;
    }

    if (!this.outputFileName) {
      this.outputFileName = '小说.txt';
    }

    this.isRunning = true;
    this.progress = 0;
    this.statusMessage = '开始爬取...';

    try {
      const success = await this.getNovelCrawler().crawlNovel(
        this.baseUrl,
        startNum,
        endNum,
        this.outputFileName,
        (current: number, total: number, message: string) => {
          this.progress = Math.round((current / total) * 100);
          this.statusMessage = message;
        }
      );

      if (success) {
        this.statusMessage = '爬取完成！';
      } else {
        this.statusMessage = '爬取失败，请检查网络连接和URL格式';
      }
    } catch (error) {
      this.statusMessage = `爬取失败: ${error}`;
    } finally {
      this.isRunning = false;
      this.progress = 100;
    }
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        // 标题
        Text('52书库小说爬虫')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 20 })

        // URL输入框
        Column({ space: 5 }) {
          Text('基础URL:')
            .fontSize(16)
            .alignSelf(ItemAlign.Start)
          TextInput({})
            .onChange((value: string) => {
              this.baseUrl = value;
              this.autoConvertUrl();
            })
            .width('90%')
        }

        // 起始页码
        Column({ space: 5 }) {
          Text('起始页码:')
            .fontSize(16)
            .alignSelf(ItemAlign.Start)
          TextInput({ text: this.startPage })
            .onChange((value: string) => {
              this.startPage = value;
            })
            .width('90%')
        }

        // 结束页码
        Column({ space: 5 }) {
          Text('结束页码:')
            .fontSize(16)
            .alignSelf(ItemAlign.Start)
          TextInput({ text: this.endPage })
            .onChange((value: string) => {
              this.endPage = value;
            })
            .width('90%')
        }

        // 文件名输入
        Column({ space: 5 }) {
          Text('输出文件名:')
            .fontSize(16)
            .alignSelf(ItemAlign.Start)
          TextInput({ text: this.outputFileName })
            .onChange((value: string) => {
              this.outputFileName = value || '小说.txt';
              if (!this.outputFileName.endsWith('.txt')) {
                this.outputFileName += '.txt';
              }
            })
            .width('90%')
        }

        // 状态显示
        Text(this.statusMessage)
          .fontSize(14)
          .fontColor('#666666')
          .textAlign(TextAlign.Center)
          .width('90%')

        // 进度条
        if (this.isRunning) {
          Progress({ value: this.progress, total: 100 })
            .width('90%')
            .height(8)
        }

        // 开始爬取按钮
        Button('开始爬取')
          .width('80%')
          .height(50)
          .backgroundColor(this.isRunning ? '#cccccc' : '#007AFF')
          .enabled(!this.isRunning)
          .onClick(() => {
            this.startCrawling();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .backgroundColor('#f5f5f5')
  }
}
