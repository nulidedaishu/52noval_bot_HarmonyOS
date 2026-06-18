import { fileIo as fs, picker, fileUri } from '@kit.CoreFileKit';
import common from '@ohos.app.ability.common';

/**
 * 应用全局常量接口
 */
interface IConstants {
  readonly NOVEL_FILE_NAME: string; // 小说文件的名称
  readonly NOVEL_FILE_ACCESS_MODE: number; // 文件操作模式（读写、创建、追加）
  readonly DOWNLOAD_FILE_ACCESS_MODE: number; // 文件操作模式（读写、创建、覆盖）
}

const Constants: IConstants = {
  NOVEL_FILE_NAME: 'novel.txt',
  NOVEL_FILE_ACCESS_MODE: fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC,
  DOWNLOAD_FILE_ACCESS_MODE: fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC,
};

export class FileManager {
  /** 标志位，防止文件导出等耗时操作并发执行 */
  private isBusy: boolean = false;
  // --- 私有属性 ---
  /** UIAbility的上下文，用于获取应用信息、文件目录、发起权限请求等 */
  private context = getContext(this) as common.UIAbilityContext;
  /** 日志文件的完整路径 */
  private novelFilePath: string = `${this.context.filesDir}/${Constants.NOVEL_FILE_NAME}`;
  /** 日志文件的文件对象 */
  private novelFile: fs.File | null = null;

  /**
   * 初始化文件。
   */
  async setup() {
    try {
      this.novelFile = await fs.open(this.novelFilePath, Constants.NOVEL_FILE_ACCESS_MODE);
    } catch (error) {
      // TODO: Implement error handling.
    }
  }

  /**
   * 检查沙箱文件是否存在且有内容
   * @returns Promise<boolean> 是否有内容
   */
  async hasContent(): Promise<boolean> {
    try {
      await fs.access(this.novelFilePath);
      const stat = await fs.stat(this.novelFilePath);
      return stat.size > 0;
    } catch {
      return false;
    }
  }

  /**
   * 检查文件管理器是否忙碌
   * @returns boolean 是否忙碌
   */
  getIsBusy(): boolean {
    return this.isBusy;
  }

  /**
   * 获取小说文件对象
   * @returns fs.File | null 文件对象
   */
  getNovelFile(): fs.File | null {
    return this.novelFile;
  }

  /**
   * 导出内部文件到公共的Download目录。
   * 使用 DocumentPicker 的 DOWNLOAD 模式，无需用户交互即可保存。
   * @param exportFileName 导出文件的名称
   * @returns {Promise<boolean>} 导出操作是否成功。
   */
  async exportToDownload(exportFileName: string): Promise<boolean> {
    if (this.isBusy) {
      return false;
    }
    this.isBusy = true;
    try {
      await fs.access(this.novelFilePath);
      const novelContent = await fs.readText(this.novelFilePath);
      const documentViewPicker = new picker.DocumentViewPicker(this.context);
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
      const documentSaveResult = await documentViewPicker.save(documentSaveOptions);
      const targetDirectoryUri = documentSaveResult[0];
      const targetFilePath = new fileUri.FileUri(`${targetDirectoryUri}/${exportFileName}`).path;
      const targetFile = await fs.open(targetFilePath, Constants.DOWNLOAD_FILE_ACCESS_MODE);
      await fs.write(targetFile.fd, novelContent);
      await fs.close(targetFile);
      return true;
    } catch (error) {
      return false;
    } finally {
      this.isBusy = false;
    }
  }
}