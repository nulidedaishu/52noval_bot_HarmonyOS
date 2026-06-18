# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HarmonyOS NEXT novel crawling app targeting 52书库 (52bqg.com). Built with ArkTS + ArkUI using the Stage model, targeting API 6.0.2(22).

## Build & Dev Commands

This project uses DevEco Studio and the hvigor build system. There is no CLI build — build, run, and debug through DevEco Studio.

- **Build:** Open in DevEco Studio → Build → Build App
- **Run on device/emulator:** DevEco Studio → Run → Run 'entry'
- **Run tests:** DevEco Studio → right-click test file → Run
- **Clean:** DevEco Studio → Build → Clean Project

## Architecture

```
entry/src/main/ets/
├── entryability/EntryAbility.ets   # App entry, loads pages/Index
├── pages/
│   ├── Index.ets                    # Main crawler UI (URL config, progress, save)
│   └── SandboxFileManagementPage.ets # Sandbox file browser (import/export/delete)
└── utils/
    ├── NovelCrawler.ets             # Orchestrator: crawls pages, manages background task lifecycle
    ├── HttpClient.ets               # Wraps @kit.NetworkKit HTTP with retry + timeout
    ├── HtmlParser.ets               # Static HTML parser targeting 52bqg.com article structure
    ├── FileManager.ets              # App-private temp file for crawling, exports via DocumentPicker
    └── SandboxFileManager.ets       # General sandbox file CRUD (list/import/export/delete)
```

**Data flow:** `Index` → `NovelCrawler.crawlNovel()` → `HttpClient.fetchPage()` → `HtmlParser.extractContent()` → `FileManager` (temp file) → `saveCrawledContent()` → DocumentPicker export.

## Key Patterns

- `getUIContext().getHostContext() as common.UIAbilityContext` — standard way to obtain context in `@Component` pages.
- Lazy init: `getNovelCrawler()` pattern creates the orchestrator on first use.
- Background task lifecycle (`backgroundTaskManager.startBackgroundRunning` / `stopBackgroundRunning`) wraps the crawl to prevent OS from killing the process.
- `HttpClient` manages a singleton `http.HttpRequest` with `initialize()` / `ensureInitialized()` / `reset()` lifecycle.
- `HtmlParser` is fully static — no instantiation needed.
- `FileManager` uses `isBusy` flag to prevent concurrent file operations.

## Permissions (in module.json5)

- `ohos.permission.INTERNET`
- `ohos.permission.KEEP_BACKGROUND_RUNNING` (usedScene: inuse)
- Background mode: `dataTransfer`

## Dependencies (Kit imports)

| Kit | Import |
|-----|--------|
| Network | `import { http } from '@kit.NetworkKit'` |
| Core File | `import { fileIo as fs, picker, fileUri, directoryIo } from '@kit.CoreFileKit'` |
| Background Tasks | `import { backgroundTaskManager } from '@kit.BackgroundTasksKit'` |
| Ability | `import { wantAgent, WantAgent } from '@kit.AbilityKit'` |
| ArkUI (window) | `import { window } from '@kit.ArkUI'` |
| Performance (logging) | `import { hilog } from '@kit.PerformanceAnalysisKit'` |

## Official Documentation

All development follows: https://developer.huawei.com/consumer/cn/doc/
Key entry points: [应用开发导读](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/application-dev-guide), [ArkTS API参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V2/development-intro-0000001478061813-V2)
