import { fileIo as fs, picker, fileUri } from '@kit.CoreFileKit';
import common from '@ohos.app.ability.common';

/**
 * 文件列表项
 */
interface FileItem {
  name: string;
  size: number;
  uri: string;
}

/**
 * 操作结果
 */
interface OpResult {
  success: boolean;
  fileName?: string;
  error?: string;
}

/**
 * 沙箱文件管理器 - 基于 HarmonyOS NEXT 官方 API
 * 管理应用沙箱内的文件，支持导入、导出、删除等操作
 */
export class SandboxFileManager {
  private context: common.UIAbilityContext;
  private sandboxDir: string;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.sandboxDir = context.filesDir;
  }

  /**
   * 获取沙箱目录下的所有文件列表
   */
  async listFiles(): Promise<FileItem[]> {
    try {
      const fileNames: string[] = await fs.listFile(this.sandboxDir);
      const files: FileItem[] = [];

      for (const fileName of fileNames) {
        // 跳过系统目录
        if (fileName === 'cache' || fileName === 'log' || fileName === 'temp') {
          continue;
        }

        const filePath: string = `${this.sandboxDir}/${fileName}`;
        try {
          const stat: fs.Stat = await fs.stat(filePath);
          files.push({
            name: fileName,
            size: stat.size,
            uri: filePath
          });
        } catch {
          // 跳过无法获取信息的文件
        }
      }

      return files;
    } catch (error) {
      console.error(`列出沙箱文件失败：${error}`);
      return [];
    }
  }

  /**
   * 从外部导入文件到沙箱
   * 使用 DocumentViewPicker 让用户选择文件
   */
  async importFile(): Promise<OpResult> {
    try {
      const documentViewPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context);
      const documentSelectOptions: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;

      const result: string[] = await documentViewPicker.select(documentSelectOptions);

      if (!result || result.length === 0) {
        const cancelResult: OpResult = { success: false, error: '用户取消选择' };
        return cancelResult;
      }

      const sourceUri: string = result[0];
      const fileName: string = this.getFileNameFromUri(sourceUri);

      if (!fileName) {
        const noNameResult: OpResult = { success: false, error: '无法获取文件名' };
        return noNameResult;
      }

      // 使用 readText 读取源文件内容
      const content: string = await fs.readText(sourceUri);

      // 确定目标路径，重名自动加序号
      let targetPath: string = `${this.sandboxDir}/${fileName}`;
      let counter: number = 1;
      while (await this.fileExists(targetPath)) {
        const dotIndex: number = fileName.lastIndexOf('.');
        if (dotIndex > 0) {
          const name: string = fileName.substring(0, dotIndex);
          const ext: string = fileName.substring(dotIndex);
          targetPath = `${this.sandboxDir}/${name}_${counter}${ext}`;
        } else {
          targetPath = `${this.sandboxDir}/${fileName}_${counter}`;
        }
        counter++;
      }

      // 写入沙箱
      const targetFile: fs.File = await fs.open(targetPath,
        fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      await fs.write(targetFile.fd, content);
      await fs.close(targetFile);

      const successResult: OpResult = { success: true, fileName: targetPath.split('/').pop() };
      return successResult;
    } catch (error) {
      console.error(`导入文件失败：${error}`);
      const failResult: OpResult = { success: false, error: `导入失败：${error}` };
      return failResult;
    }
  }

  /**
   * 导出沙箱文件到 Download 目录
   */
  async exportFile(fileName: string, exportName?: string): Promise<OpResult> {
    try {
      const sourcePath: string = `${this.sandboxDir}/${fileName}`;

      if (!await this.fileExists(sourcePath)) {
        const notFoundResult: OpResult = { success: false, error: '文件不存在' };
        return notFoundResult;
      }

      // 读取沙箱文件内容
      const content: string = await fs.readText(sourcePath);

      // 使用 DocumentViewPicker DOWNLOAD 模式保存
      const documentViewPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(this.context);
      const documentSaveOptions: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
      documentSaveOptions.newFileNames = [exportName || fileName];

      const result: string[] = await documentViewPicker.save(documentSaveOptions);

      if (!result || result.length === 0) {
        const cancelResult: OpResult = { success: false, error: '用户取消保存' };
        return cancelResult;
      }

      const targetDirectoryUri: string = result[0];
      const targetFileName: string = exportName || fileName;
      const targetFilePath: string = new fileUri.FileUri(`${targetDirectoryUri}/${targetFileName}`).path;

      const targetFile: fs.File = await fs.open(targetFilePath,
        fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      await fs.write(targetFile.fd, content);
      await fs.close(targetFile);

      const successResult: OpResult = { success: true };
      return successResult;
    } catch (error) {
      console.error(`导出文件失败：${error}`);
      const failResult: OpResult = { success: false, error: `导出失败：${error}` };
      return failResult;
    }
  }

  /**
   * 删除沙箱中的文件
   */
  async deleteFile(fileName: string): Promise<OpResult> {
    try {
      const filePath: string = `${this.sandboxDir}/${fileName}`;

      if (!await this.fileExists(filePath)) {
        const notFoundResult: OpResult = { success: false, error: '文件不存在' };
        return notFoundResult;
      }

      await fs.unlink(filePath);
      const successResult: OpResult = { success: true };
      return successResult;
    } catch (error) {
      console.error(`删除文件失败：${error}`);
      const failResult: OpResult = { success: false, error: `删除失败：${error}` };
      return failResult;
    }
  }

  /**
   * 检查文件是否存在
   */
  private async fileExists(filePath: string): Promise<boolean> {
    try {
      await fs.access(filePath);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * 从 URI 中提取文件名
   */
  private getFileNameFromUri(uri: string): string {
    const parts: string[] = uri.split('/');
    let fileName: string = parts[parts.length - 1];

    try {
      fileName = decodeURIComponent(fileName);
    } catch {
      // 忽略解码错误
    }

    return fileName || 'unknown_file';
  }

  /**
   * 格式化文件大小
   */
  formatFileSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    } else if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(2)} KB`;
    } else if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
    } else {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
    }
  }
}
