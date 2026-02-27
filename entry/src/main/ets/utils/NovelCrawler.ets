import { fileIo as fs } from '@kit.CoreFileKit';

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

  constructor() {
    this.httpClient = new HttpClient();
    this.fileManager = new FileManager();
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
      let novelContent = '';
      await this.fileManager.setup();

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
          await new Promise<void>(resolve => setTimeout(resolve, 2000));
        }
      }

      // 保存小说内容
      onProgress?.(totalPages, totalPages, '正在保存文件...');
      const success = await this.fileManager.exportToDownload(outputFileName);
      if (success) {
        console.log(`爬取完成！文件已保存至: ${outputFileName}`);
        onProgress?.(totalPages, totalPages, `爬取完成！文件已保存至: ${outputFileName}`);
        return true;
      } else {
        console.error('保存文件失败');
        onProgress?.(totalPages, totalPages, '保存文件失败');
        return false;
      }
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
    }
  }
}