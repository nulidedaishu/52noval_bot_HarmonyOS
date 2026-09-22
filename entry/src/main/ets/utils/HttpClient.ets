/*
 * HTTP客户端工具类
 * 替代Python中的requests库功能
 */
// import http from '@ohos.net.http';
import { http } from '@kit.NetworkKit';

export class HttpClient {
  private httpRequest: http.HttpRequest | null = null;  // 修改：添加null类型
  private isInitialized: boolean = false;

  constructor() {
    this.httpRequest = http.createHttp();
    this.initialize();

  }

  /**
   * 初始化HTTP客户端
   */
  private async initialize(): Promise<void> {
    try {
      if (this.httpRequest) {
        this.destroy();
      }
      this.httpRequest = http.createHttp();
      this.isInitialized = true;
      console.log('HTTP客户端初始化成功');
    } catch (error) {
      console.error('HTTP客户端初始化失败:', error);
      this.isInitialized = false;
    }
  }

  /**
   * 确保HTTP客户端可用
   */
  private async ensureInitialized(): Promise<boolean> {
    if (!this.isInitialized || !this.httpRequest) {
      await this.initialize();
    }
    return this.isInitialized && this.httpRequest !== null;
  }

  /**
   * 发送GET请求获取页面内容
   * @param url 请求URL
   * @param retries 重试次数
   * @returns Promise<string> HTML内容
   */
  async fetchPage(url: string, retries: number = 3): Promise<string | null> {
    const isReady = await this.ensureInitialized();
    if (!isReady || !this.httpRequest) {
      console.error('HTTP客户端未准备好');
      return null;
    }
    interface Headers {
      'User-Agent': string;
      'Accept': string;
      'Accept-Language': string;
      'Connection'?: string;
    }

    const headers: Headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      // 不要手动发送 Accept-Encoding: 新版 CDN 会据此返回 gzip,
      // 而 http 栈对手动声明的 gzip 不一定自动解压,会导致拿到二进制乱码。
      // 不发送时服务器返回明文(已验证)。
      'Connection': 'close' // 改为close避免连接保持
    };

    for (let i = 0; i < retries; i++) {
      try {
        console.log(`发送请求 (${i + 1}/${retries}): ${url}`);

        const response = await this.httpRequest!.request(url, {
          method: http.RequestMethod.GET,
          header: headers,
          connectTimeout: 30000, // 30秒连接超时
          readTimeout: 30000, // 30秒读取超时
          usingCache: false      // 禁用缓存
        });

        // 检查响应状态码
        if (response.responseCode === 200) {
          return response.result as string;
        } else {
          console.error(`HTTP请求失败，状态码: ${response.responseCode}`);
        }
      } catch (error) {
        console.error(`请求失败 (${i + 1}/${retries}): ${url}, 错误: ${error}`);
        if (i < retries - 1) {
          // 等待2秒后重试
          await new Promise<void>(resolve => setTimeout(resolve, 2000));
        }
      }
    }
    return null;
  }

  /**
   * 销毁HTTP请求对象
   */
  destroy(): void {
    try {
      if (this.httpRequest) {
        this.httpRequest.destroy();
        this.httpRequest = null;
        this.isInitialized = false;
        console.log('HTTP客户端已销毁');
      }
    } catch (error) {
      console.error('销毁HTTP客户端时出错:', error);
    }
  }

  /**
   * 重置HTTP客户端（用于解决连接问题）
   */
  async reset(): Promise<void> {
    console.log('重置HTTP客户端');
    this.destroy();
    await this.initialize();
  }
}