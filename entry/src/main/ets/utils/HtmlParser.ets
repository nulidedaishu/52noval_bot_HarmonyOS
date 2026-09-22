/*
 * HTML内容解析器(双站兼容)
 *
 * 站点A: 52书库 www.52shuku.net (主目标)
 *   正文容器: <article class="article-content" ...> ... </article>
 *   注意: 开标签属性可能带空格/省略 id,必须用正则匹配,不能精确字符串匹配;
 *   结束边界用 </article> 闭合标签(第1页没有 pagination2,不能再用它当边界)
 *
 * 站点B: 52笔趣阁 www.52bqg.com (备用)
 *   正文容器: <div class="word_read">,段落可能被 base64 混淆为
 *   <script>qsbs.bb('...')</script>,需解码(等价于站点 yueduqsbs.js 的 qsbs.bb)
 */

export class HtmlParser {
  private static readonly B64_TABLE: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  /**
   * 从 HTML 中提取小说正文内容
   * @param html HTML 内容
   * @returns 段落以空行分隔的正文,失败返回 null
   */
  static extractContent(html: string): string | null {
    if (!html) {
      return null;
    }

    try {
      let rawParagraphs: string[] = [];

      // 分支A: <article class="...article-content..."> (52shuku.net)
      const articleRegex = /<article[^>]*class\s*=\s*["'][^"']*article-content[^"']*["'][^>]*>/i;
      const articleMatch = articleRegex.exec(html);
      if (articleMatch) {
        rawParagraphs = HtmlParser.parseArticleBranch(html, articleMatch.index + articleMatch[0].length);
      } else {
        // 分支B: <div class="word_read"> (52bqg.com)
        rawParagraphs = HtmlParser.parseWordReadBranch(html);
      }

      if (rawParagraphs.length === 0) {
        console.error('未提取到任何正文段落');
        return null;
      }

      const paragraphs: string[] = [];
      for (const p of rawParagraphs) {
        if (!p || HtmlParser.isNoiseParagraph(p)) {
          continue;
        }
        paragraphs.push(HtmlParser.decodeHtmlEntities(p));
      }

      if (paragraphs.length === 0) {
        console.error('正文字段全部被判定为噪声');
        return null;
      }
      return paragraphs.join('\n\n');
    } catch (error) {
      console.error('解析 HTML 内容时出错:', error);
      return null;
    }
  }

  /**
   * 站点A: 提取 <article ...> 到 </article> 之间的段落
   */
  private static parseArticleBranch(html: string, contentStart: number): string[] {
    const end = html.indexOf('</article>', contentStart);
    if (end === -1) {
      console.error('未找到 </article> 结束标签');
      return [];
    }
    let seg: string = html.substring(contentStart, end);
    // 清理脚本/分页导航/回顶按钮等干扰元素
    seg = seg.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    seg = seg.replace(/<div[^>]*class=["'][^"']*pagination2[^"']*["'][^>]*>[\s\S]*?<\/div>/gi, '');
    seg = seg.replace(/<div[^>]*class=["'][^"']*go_top[^"']*["'][^>]*>[\s\S]*?<\/div>/gi, '');
    seg = seg.replace(/<button[^>]*id=["']go-top["'][^>]*>[\s\S]*?<\/button>/gi, '');
    return HtmlParser.extractPParagraphs(seg);
  }

  /**
   * 站点B: 提取 <div class="word_read"> 区内段落(含 qsbs.bb base64 混淆)
   */
  private static parseWordReadBranch(html: string): string[] {
    const paragraphs: string[] = [];
    const start = html.indexOf('<div class="word_read">');
    if (start === -1) {
      console.error('未找到正文容器 (article-content / word_read)');
      return paragraphs;
    }
    const end1 = html.indexOf('<div class="row row-section', start);
    const end2 = html.indexOf('<div class="footer', start);
    let end = -1;
    if (end1 !== -1 && end2 !== -1) {
      end = end1 < end2 ? end1 : end2;
    } else {
      end = end1 !== -1 ? end1 : end2;
    }
    if (end === -1) {
      console.error('未找到正文结束边界');
      return paragraphs;
    }
    const seg: string = html.substring(start, end);

    // 1) 混淆段落: qsbs.bb('BASE64') 解码后为 <p>..</p>
    const b64Regex = /qsbs\.bb\('([A-Za-z0-9+/=]+)'\)/g;
    let match: RegExpExecArray | null;
    while ((match = b64Regex.exec(seg)) !== null) {
      const decoded = HtmlParser.base64ToUtf8(match[1]);
      const pMatch = decoded.match(/^<p>([\s\S]*?)<\/p>$/);
      const text = (pMatch ? pMatch[1] : decoded).replace(/<[^>]+>/g, '').trim();
      if (text) {
        paragraphs.push(text);
      }
    }

    // 2) 明文段落
    const plain = HtmlParser.extractPParagraphs(seg);
    for (const p of plain) {
      paragraphs.push(p);
    }
    return paragraphs;
  }

  /**
   * 提取 <p>..</p> 段落并去除内嵌标签
   */
  private static extractPParagraphs(seg: string): string[] {
    const paragraphs: string[] = [];
    const pRegex = /<p[^>]*>([\s\S]*?)<\/p>/gi;
    let match: RegExpExecArray | null;
    while ((match = pRegex.exec(seg)) !== null) {
      const text = match[1].replace(/<[^>]+>/g, '').trim();
      if (text) {
        paragraphs.push(text);
      }
    }
    return paragraphs;
  }

  /**
   * 噪声段落判定(两站通用)
   */
  private static isNoiseParagraph(p: string): boolean {
    // 站点A(52shuku)页头/页尾导航与重复书名头
    if (p.includes('传送门') || p.includes('排行榜单') || p.includes('所属专题')) {
      return true;
    }
    if (p.startsWith('开始阅读') || p.includes('阅读记录')) {
      return true;
    }
    if (p.includes('》') && p.includes('作者：')) {
      return true;
    }
    // 站点B(52bqg)推广/提示
    if (p.includes('相邻推荐') || p.includes('请关闭浏览器阅读模式')) {
      return true;
    }
    // 站点A尾部推广: "网址 https://www.52shuku.net/ 或推荐给朋友哦~..."
    if (p.includes('52shuku')) {
      return true;
    }
    // 旧版推广标记(保留兼容)
    if ((p.includes('哦豁') && p.includes('52')) || p.startsWith('小贴士') || p.includes('小伙伴们如果觉得')) {
      return true;
    }
    return false;
  }

  /**
   * 纯 TS 实现 base64 -> UTF-8 字符串(等价于站点 yueduqsbs.js 的 qsbs.bb)
   */
  private static base64ToUtf8(input: string): string {
    const clean = input.replace(/[^A-Za-z0-9+/=]/g, '');
    const bytes: number[] = [];
    let i = 0;
    while (i < clean.length) {
      const e1 = HtmlParser.b64Index(clean.charAt(i++));
      const e2 = HtmlParser.b64Index(clean.charAt(i++));
      const e3 = HtmlParser.b64Index(clean.charAt(i++));
      const e4 = HtmlParser.b64Index(clean.charAt(i++));
      if (e1 < 0 || e2 < 0 || e1 === 64 || e2 === 64) {
        break;
      }
      bytes.push((e1 << 2) | (e2 >> 4));
      if (e3 >= 0 && e3 !== 64) {
        bytes.push(((e2 & 15) << 4) | (e3 >> 2));
      }
      if (e4 >= 0 && e4 !== 64) {
        bytes.push(((e3 & 3) << 6) | e4);
      }
    }

    let out: string = '';
    let j = 0;
    while (j < bytes.length) {
      const b = bytes[j];
      if (b < 0x80) {
        out += String.fromCharCode(b);
        j += 1;
      } else if (b < 0xE0) {
        out += String.fromCharCode(((b & 0x1F) << 6) | (bytes[j + 1] & 0x3F));
        j += 2;
      } else if (b < 0xF0) {
        out += String.fromCharCode(((b & 0x0F) << 12) | ((bytes[j + 1] & 0x3F) << 6) | (bytes[j + 2] & 0x3F));
        j += 3;
      } else {
        const cp = ((b & 0x07) << 18) | ((bytes[j + 1] & 0x3F) << 12) | ((bytes[j + 2] & 0x3F) << 6) | (bytes[j + 3] & 0x3F);
        const v = cp - 0x10000;
        out += String.fromCharCode(0xD800 | (v >> 10), 0xDC00 | (v & 0x3FF));
        j += 4;
      }
    }
    return out;
  }

  private static b64Index(c: string): number {
    if (c === '' || c === '=') {
      return 64;
    }
    return HtmlParser.B64_TABLE.indexOf(c);
  }

  /**
   * HTML 实体解码
   */
  private static decodeHtmlEntities(text: string): string {
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
      '&mdash;': '—'
    };

    return text.replace(/&[a-z]+;/g, (match) => entityMap[match] || match);
  }
}
