import { SandboxFileManager } from '../utils/SandboxFileManager';
import common from '@ohos.app.ability.common';

interface FileInfo {
  name: string;
  size: number;
  uri: string;
}

@Entry
@Component
struct SandboxFileManagementPage {
  @State files: FileInfo[] = [];
  @State isLoading: boolean = false;
  @State statusMessage: string = '';
  @State selectedFiles: string[] = [];
  private fileManager: SandboxFileManager | null = null;
  private context: common.UIAbilityContext | undefined = undefined;

  aboutToAppear() {
    // 获取上下文并初始化文件管理器
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (this.context) {
      this.fileManager = new SandboxFileManager(this.context);
      this.loadFiles();
    }
  }

  // 加载文件列表
  async loadFiles() {
    if (!this.fileManager) return;
    
    this.isLoading = true;
    this.statusMessage = '加载中...';
    
    try {
      const fileList = await this.fileManager.listFiles();
      this.files = fileList;
      this.statusMessage = fileList.length === 0 ? '沙箱目录为空' : `共 ${fileList.length} 个文件`;
    } catch (error) {
      this.statusMessage = `加载失败：${error}`;
    } finally {
      this.isLoading = false;
    }
  }

  // 导入文件
  async importFile() {
    if (!this.fileManager) {
      this.statusMessage = '文件管理器未初始化';
      return;
    }

    this.statusMessage = '请选择要导入的文件...';
    
    try {
      const result = await this.fileManager.importFile();
      
      if (result.success && result.fileName) {
        this.statusMessage = `成功导入：${result.fileName}`;
        await this.loadFiles(); // 刷新列表
      } else {
        this.statusMessage = result.error || '导入失败';
      }
    } catch (error) {
      this.statusMessage = `导入错误：${error}`;
    }
  }

  // 导出单个文件
  async exportFile(fileName: string) {
    if (!this.fileManager) {
      this.statusMessage = '文件管理器未初始化';
      return;
    }

    this.statusMessage = '正在导出...';
    
    try {
      const result = await this.fileManager.exportFile(fileName);
      
      if (result.success) {
        this.statusMessage = `已导出：${fileName}`;
      } else {
        this.statusMessage = result.error || '导出失败';
      }
    } catch (error) {
      this.statusMessage = `导出错误：${error}`;
    }
  }

  // 删除单个文件
  async deleteFile(fileName: string) {
    if (!this.fileManager) {
      this.statusMessage = '文件管理器未初始化';
      return;
    }

    this.statusMessage = '正在删除...';
    
    try {
      const result = await this.fileManager.deleteFile(fileName);
      
      if (result.success) {
        this.statusMessage = `已删除：${fileName}`;
        await this.loadFiles(); // 刷新列表
      } else {
        this.statusMessage = result.error || '删除失败';
      }
    } catch (error) {
      this.statusMessage = `删除错误：${error}`;
    }
  }

  // 切换文件选择状态（用于批量操作）
  toggleFileSelection(fileName: string) {
    const index = this.selectedFiles.indexOf(fileName);
    if (index > -1) {
      this.selectedFiles.splice(index, 1);
    } else {
      this.selectedFiles.push(fileName);
    }
  }

  // 批量导出选中的文件
  async batchExport() {
    if (this.selectedFiles.length === 0) {
      this.statusMessage = '请先选择要导出的文件';
      return;
    }

    this.statusMessage = `正在导出 ${this.selectedFiles.length} 个文件...`;
    
    let successCount = 0;
    for (const fileName of this.selectedFiles) {
      try {
        const result = await this.fileManager!.exportFile(fileName);
        if (result.success) {
          successCount++;
        }
      } catch (error) {
        console.error(`导出 ${fileName} 失败：${error}`);
      }
    }
    
    this.statusMessage = `导出完成：成功 ${successCount}/${this.selectedFiles.length}`;
    this.selectedFiles = []; // 清空选择
  }

  // 批量删除选中的文件
  async batchDelete() {
    if (this.selectedFiles.length === 0) {
      this.statusMessage = '请先选择要删除的文件';
      return;
    }

    this.statusMessage = `正在删除 ${this.selectedFiles.length} 个文件...`;
    
    let successCount = 0;
    for (const fileName of this.selectedFiles) {
      try {
        const result = await this.fileManager!.deleteFile(fileName);
        if (result.success) {
          successCount++;
        }
      } catch (error) {
        console.error(`删除 ${fileName} 失败：${error}`);
      }
    }
    
    this.statusMessage = `删除完成：成功 ${successCount}/${this.selectedFiles.length}`;
    this.selectedFiles = []; // 清空选择
    await this.loadFiles(); // 刷新列表
  }

  build() {
    Column({ space: 10 }) {
      // 顶部导航栏
      Row() {
        Button('← 返回')
          .width(80)
          .height(40)
          .fontSize(16)
          .onClick(() => {
            this.getUIContext().getRouter().back();
          })
        
        Text('沙箱文件管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .flexGrow(1)
          .textAlign(TextAlign.Center)
        
        Button('刷新')
          .width(80)
          .height(40)
          .fontSize(14)
          .onClick(() => {
            this.loadFiles();
          })
      }
      .width('100%')
      .padding({ left: 15, right: 15, top: 10, bottom: 10 })
      .backgroundColor('#f0f0f0')

      // 状态信息
      Text(this.statusMessage)
        .fontSize(14)
        .fontColor('#666666')
        .width('100%')
        .padding({ left: 15, right: 15 })

      // 文件列表
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
          Text('加载中...')
            .fontSize(14)
            .fontColor('#999999')
        }
        .width('100%')
        .height(300)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.files, (file: FileInfo) => {
            ListItem() {
              Row() {
                // 复选框
                Checkbox({ name: file.name, group: 'fileSelect' })
                .select(this.selectedFiles.includes(file.name))
                .onChange(() => {
                  this.toggleFileSelection(file.name);
                })

                // 文件信息
                Column({ space: 5 }) {
                  Text(file.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  
                  Text(this.fileManager?.formatFileSize(file.size) || '')
                    .fontSize(12)
                    .fontColor('#999999')
                }
                .layoutWeight(1)
                .margin({ left: 10, right: 10 })

                // 操作按钮
                Row({ space: 10 }) {
                  Button('导出')
                    .width(60)
                    .height(32)
                    .fontSize(12)
                    .backgroundColor('#34C759')
                    .onClick(() => {
                      this.exportFile(file.name);
                    })

                  Button('删除')
                    .width(60)
                    .height(32)
                    .fontSize(12)
                    .backgroundColor('#FF3B30')
                    .onClick(() => {
                      this.deleteFile(file.name);
                    })
                }
              }
              .width('100%')
              .padding(15)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
      }

      // 底部操作栏
      Row({ space: 15 }) {
        Button('导入文件')
          .width('45%')
          .height(45)
          .fontSize(16)
          .backgroundColor('#007AFF')
          .onClick(() => {
            this.importFile();
          })

        if (this.selectedFiles.length > 0) {
          Button(`批量导出 (${this.selectedFiles.length})`)
            .width('45%')
            .height(45)
            .fontSize(16)
            .backgroundColor('#34C759')
            .onClick(() => {
              this.batchExport();
            })
          
          Button(`批量删除 (${this.selectedFiles.length})`)
            .width('45%')
            .height(45)
            .fontSize(16)
            .backgroundColor('#FF3B30')
            .onClick(() => {
              this.batchDelete();
            })
        }
      }
      .width('100%')
      .padding({ left: 15, right: 15, top: 10, bottom: 15 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ffffff')
  }
}
