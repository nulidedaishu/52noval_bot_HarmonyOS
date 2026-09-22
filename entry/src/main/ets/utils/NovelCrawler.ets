import { fileIo as fs } from '@kit.CoreFileKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import common from '@ohos.app.ability.common';

/*
 * 小说爬虫核心类
 * 整合HTTP请求、HTML解析和文件保存功能
 */
import { HttpClient } from './HttpClient';
import { HtmlParser } from './HtmlParser';
import { FileManager } from './FileManager';

export class NovelCrawler {
  private httpClient: HttpClient;
  private fileManager: FileManager;
  private context: common.UIAbilityContext | undefined = undefined;
  private wantAgentObj: WantAgent | null = null;
  private isBackgroundTaskRunning: boolean = false;

  constructor(context?: common.UIAbilityContext) {
    this.httpClient = new HttpClient();
    this.fileManager = new FileManager();
    this.context = context;
  }

  /**
   * 初始化长时任务相关组件
   */
  private async initBackgroundTask(): Promise<boolean> {
    if (!this.context) {
      console.warn('上下文未提供，无法初始化长时任务');
      return false;
    }

    try {
      // 创建WantAgent信息
      let wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: "com.example.novelbot",
            abilityName: "EntryAbility"
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };

      // 获取WantAgent对象
      this.wantAgentObj = await wantAgent.getWantAgent(wantAgentInfo);
      console.info('长时任务初始化成功');
      return true;
    } catch (error) {
      console.error(`长时任务初始化失败: ${(error as BusinessError).code}, ${(error as BusinessError).message}`);
      return false;
    }
  }

  /**
   * 申请长时任务
   */
  private async startBackgroundTask(): Promise<boolean> {
    if (!this.context || !this.wantAgentObj || this.isBackgroundTaskRunning) {
      return false;
    }

    try {
      // 使用dataTransfer类型确保文件传输不会被中断
      let list: Array<string> = ["dataTransfer"];
      const res = await backgroundTaskManager.startBackgroundRunning(this.context, list, this.wantAgentObj);
      console.info(`长时任务申请成功, notificationId: ${res.notificationId}`);
      this.isBackgroundTaskRunning = true;
      return true;
    } catch (error) {
      console.error(`长时任务申请失败: ${(error as BusinessError).code}, ${(error as BusinessError).message}`);
      return false;
    }
  }

  /**
   * 取消长时任务
   */
  private async stopBackgroundTask(): Promise<void> {
    if (!this.context || !this.isBackgroundTaskRunning) {
      return;
    }

    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
      console.info('长时任务取消成功');
      this.isBackgroundTaskRunning = false;
    } catch (error) {
      console.error(`长时任务取消失败: ${(error as BusinessError).code}, ${(error as BusinessError).message}`);
    }
  }

  /**
   * 爬取小说
   * @param baseUrl 基础URL模板
   * @param startPage 起始页码
   * @param endPage 结束页码
   * @param outputFileName 输出文件名
   * @param onProgress 进度回调函数
   * @returns Promise<boolean> 是否爬取成功
   */
  async crawlNovel(
    baseUrl: string,
    startPage: number,
    endPage: number,
    outputFileName: string,
    onProgress?: (current: number, total: number, message: string) => void
  ): Promise<boolean> {
    try {
      const totalPages = endPage - startPage + 1;

      // 初始化长时任务
      const initSuccess = await this.initBackgroundTask();
      if (!initSuccess) {
        console.warn('长时任务初始化失败，将继续执行但可能被系统中断');
      }

      // 在整个爬取过程开始时就申请长时任务
      onProgress?.(0, totalPages, '正在申请长时任务权限...');
      const taskStarted = await this.startBackgroundTask();
      if (taskStarted) {
        console.log('长时任务已启动，可以在后台持续运行');
      } else {
        console.warn('长时任务启动失败，应用可能在后台被系统限制');
      }

      await this.fileManager.setup(outputFileName);

      console.log(`开始爬取小说，共 ${totalPages} 页`);

      for (let i = 0; i < totalPages; i++) {
        const currentPage = startPage + i;
        const url = baseUrl.replace('{}', currentPage.toString());

        // 更新进度
        const progressMessage = `正在爬取第 ${currentPage} 页: ${url}`;
        onProgress?.(i, totalPages, progressMessage);
        console.log(progressMessage);

        // 获取页面内容
        const html = await this.httpClient.fetchPage(url);
        if (!html) {
          console.error(`获取第 ${currentPage} 页失败`);
          continue;
        }

        // 解析内容
        const content = HtmlParser.extractContent(html);
        if (content) {
          let novelFile = this.fileManager.getNovelFile();
          if (!novelFile) {
            console.error('文件句柄无效');
            return false;
          }
          if (this.fileManager.getIsBusy()) {
            console.warn('文件管理器正忙，请稍后再试');
            return false;
          }
          await fs.write(novelFile.fd, content + '\n\n');
          console.log(`  [OK] 成功提取第 ${currentPage} 页内容`);
        } else {
          console.error(`  [FAIL] 未能提取第 ${currentPage} 页内容`);
        }

        // 添加延时避免请求过于频繁（除了最后一页）
        if (i < totalPages - 1) {
          await new Promise<void>(resolve => setTimeout(resolve, 800));
        }
      }

      // 爬取完成，但不立即保存文件
      console.log(`爬取完成！共处理 ${totalPages} 页`);
      onProgress?.(totalPages, totalPages, `爬取完成！共处理 ${totalPages} 页`);
      return true;
    } catch (error) {
      console.error('爬取过程中发生错误:', error);
      // 如果是网络错误，尝试重置HTTP客户端
      if (error.toString().includes('network') || error.toString().includes('timeout')) {
        console.log('检测到网络错误，尝试重置连接...');
        await this.httpClient.reset();
        // 可以选择重新尝试当前页面
      }
      onProgress?.(0, 0, `爬取失败: ${error}`);
      return false;
    } finally {
      await this.stopBackgroundTask();
    }
  }

  /**
   * 保存已爬取的内容到设备
   * @returns Promise<boolean> 是否保存成功
   */
  async saveCrawledContent(): Promise<boolean> {
    try {
      // 检查沙箱文件是否有内容（不调 setup() 避免 TRUNC 清空已有数据）
      const hasContent: boolean = await this.fileManager.hasContent();
      if (!hasContent) {
        console.warn('沙箱文件中没有可保存的内容');
        return false;
      }

      // 直接保存到 Downloads 目录，文件名与沙箱内一致
      const success: boolean = await this.fileManager.exportToDownload();
      return success;
    } catch (error) {
      console.error('保存爬取内容失败:', error);
      return false;
    }
  }

  /**
   * 获取文件管理器实例
   * @returns FileManager 文件管理器实例
   */
  getFileManager(): FileManager {
    return this.fileManager;
  }
}