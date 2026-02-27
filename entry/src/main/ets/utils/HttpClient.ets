/*
 * HTTP客户端工具类
 * 替代Python中的requests库功能
 */
// import http from '@ohos.net.http';
import { http } from '@kit.NetworkKit';

export class HttpClient {
  private httpRequest: http.HttpRequest;

  constructor() {
    this.httpRequest = http.createHttp();
  }

  /**
   * 发送GET请求获取页面内容
   * @param url 请求URL
   * @param retries 重试次数
   * @returns Promise<string> HTML内容
   */
  async fetchPage(url: string, retries: number = 3): Promise<string | null> {
    interface Headers {
      'User-Agent': string;
      'Accept': string;
      'Accept-Language': string;
      'Accept-Encoding'?: string;  // 可选属性
      'Connection'?: string;       // 可选属性
    }
    const headers: Headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate', // 添加压缩支持
      'Connection': 'keep-alive'
    };

    for (let i = 0; i < retries; i++) {
      try {
        const response = await this.httpRequest.request(url, {
          method: http.RequestMethod.GET,
          header: { 'Content-Type': 'application/json' }
          // header: headers,
          // connectTimeout: 30000, // 30秒超时
          // readTimeout: 30000
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
    this.httpRequest.destroy();
  }
}