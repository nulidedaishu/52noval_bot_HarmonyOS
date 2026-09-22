import { fileIo as fs, picker, fileUri } from '@kit.CoreFileKit';
import common from '@ohos.app.ability.common';

const NOVEL_FILE_ACCESS_MODE: number = fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC;
const DOWNLOAD_FILE_ACCESS_MODE: number = fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC;

export class FileManager {
  /** 标志位，防止文件导出等耗时操作并发执行 */
  private isBusy: boolean = false;
  /** UIAbility的上下文 */
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  /** 当前小说的文件名 */
  private fileName: string = '';
  /** 小说文件的完整路径 */
  private novelFilePath: string = '';
  /** 小说文件的文件对象 */
  private novelFile: fs.File | null = null;

  /**
   * 初始化文件，使用指定的文件名。
   * @param fileName 文件名（如 "小说.txt"）
   */
  async setup(fileName: string): Promise<void> {
    this.fileName = fileName;
    this.novelFilePath = `${this.context.filesDir}/${fileName}`;
    try {
      this.novelFile = await fs.open(this.novelFilePath, NOVEL_FILE_ACCESS_MODE);
    } catch (error) {
      console.error(`初始化文件失败：${error}`);
    }
  }

  /**
   * 检查沙箱文件是否存在且有内容
   */
  async hasContent(): Promise<boolean> {
    if (!this.novelFilePath) {
      return false;
    }
    try {
      await fs.access(this.novelFilePath);
      const stat: fs.Stat = await fs.stat(this.novelFilePath);
      return stat.size > 0;
    } catch {
      return false;
    }
  }

  /**
   * 检查文件管理器是否忙碌
   */
  getIsBusy(): boolean {
    return this.isBusy;
  }

  /**
   * 获取小说文件对象
   */
  getNovelFile(): fs.File | null {
    return this.novelFile;
  }

  /**
   * 导出内部文件到公共的 Download 目录。
   * 文件名与沙箱内保存的一致。
   */
  async exportToDownload(): Promise<boolean> {
    if (this.isBusy || !this.fileName || !this.novelFilePath) {
      return false;
    }
    this.isBusy = true;
    try {
      await fs.access(this.novelFilePath);
      const novelContent: string = await fs.readText(this.novelFilePath);
      const documentViewPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context);
      const documentSaveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
      documentSaveOptions.newFileNames = [this.fileName];
      const documentSaveResult: string[] = await documentViewPicker.save(documentSaveOptions);
      const targetDirectoryUri: string = documentSaveResult[0];
      const targetFilePath: string = new fileUri.FileUri(`${targetDirectoryUri}/${this.fileName}`).path;
      const targetFile: fs.File = await fs.open(targetFilePath, DOWNLOAD_FILE_ACCESS_MODE);
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
