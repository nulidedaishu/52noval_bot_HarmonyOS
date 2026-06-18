/*
 * HTML内容解析器
 * 替代Python中的BeautifulSoup功能
 */

export class HtmlParser {
  /**
   * 从 HTML 中提取小说正文内容
   * @param html HTML 内容
   * @returns 提取的小说内容
   */
  static extractContent(html: string): string | null {
    if (!html) {
      return null;
    }
  
    try {
      // 查找<article id="nr1" class="article-content">标签
      const articleStart = html.indexOf('<article class="article-content" id="nr1">');
      if (articleStart === -1) {
        console.error("未找到文章内容标签 (article#nr1)");
        return null;
      }
  
      // 查找对应的结束标签
      const articleEnd = html.indexOf(' <div class="pagination2">', articleStart);
      if (articleEnd === -1) {
        console.error("未找到文章结束标签");
        return null;
      }
  
      // 提取 article 标签内的内容
      let articleContent =
        html.substring(articleStart + ('<article class="article-content" id="nr1">').length, articleEnd);
  
      // 清理各种干扰元素
      articleContent = HtmlParser.cleanContent(articleContent);
  
      // 提取段落文本
      const paragraphs = HtmlParser.extractParagraphs(articleContent);
  
      // 识别并截断推广内容
      const cleanParagraphs = HtmlParser.removePromotionContent(paragraphs);
  
      // 对每个段落进行 HTML 实体解码
      const decodedParagraphs = cleanParagraphs.map(p => HtmlParser.decodeHtmlEntities(p));
  
      // 返回格式化的内容
      return decodedParagraphs.join('\n\n');
    } catch (error) {
      console.error("解析 HTML 内容时出错:", error);
      return null;
    }
  }

  /**
   * 清理干扰元素
   */
  private static cleanContent(content: string): string {
    // 移除script标签
    content = content.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');

    // 移除分页导航
    content = content.replace(/<div[^>]*class=["'][^"']*pagination2[^"']*["'][^>]*>[\s\S]*?<\/div>/gi, '');

    // 移除回到顶部相关元素
    content = content.replace(/<div[^>]*class=["'][^"']*go_top[^"']*["'][^>]*>[\s\S]*?<\/div>/gi, '');
    content = content.replace(/<button[^>]*id=["']go-top["'][^>]*>[\s\S]*?<\/button>/gi, '');

    return content;
  }

  /**
   * 提取段落文本
   */
  private static extractParagraphs(content: string): string[] {
    content += '</p>';
    const paragraphs: string[] = [];
    const pRegex = /<p[^>]*>([\s\S]*?)<\/p>/gi;
    let match: RegExpExecArray | null;

    while ((match = pRegex.exec(content)) !== null) {
      let text = match[1];
      // 去除HTML标签
      text = text.replace(/<[^>]+>/g, '');
      // 去除首尾空白
      text = text.trim();
      if (text) {
        paragraphs.push(text);
      }
    }
    return paragraphs;
  }

  /**
   * 移除推广内容
   */
  private static removePromotionContent(paragraphs: string[]): string[] {
    const cleanedParagraphs: string[] = [];

    for (const paragraph of paragraphs) {
      // 识别推广内容的特征标记
      if (paragraph.includes('哦豁') && paragraph.includes('52 书库')) {
        break;
      }
      if (paragraph.startsWith('小贴士:') && paragraph.includes('52 书库')) {
        break;
      }
      if (paragraph.includes('小伙伴们如果觉得') && paragraph.includes('52 书库')) {
        break;
      }

      cleanedParagraphs.push(paragraph);
    }

    return cleanedParagraphs;
  }

  /**
   * HTML 实体解码
   * @param text 包含 HTML 实体的文本
   * @returns 解码后的文本
   */
  private static decodeHtmlEntities(text: string): string {
    // 常见实体映射表
    const entityMap: Record<string, string> = {
      '&ldquo;': '“',
      '&rdquo;': '”',
      '&lsquo;': '\'',
      '&rsquo;': '\'',
      '&hellip;': '…',
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&apos;': "'",
      '&middot;': '·',
      '&mdash;': '—',
      // 可继续添加更多实体
    };

    return text.replace(/&[a-z]+;/g, (match) => entityMap[match] || match);
  }
}