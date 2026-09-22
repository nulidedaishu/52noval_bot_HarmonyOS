# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project Overview

HarmonyOS NEXT novel crawling app targeting 52书库 (https://www.52shuku.net/), with a secondary parser branch for 52笔趣阁 (https://www.52bqg.com/). Built with ArkTS + ArkUI using the Stage model, targeting API 6.0.2(22).

## Build & Dev Commands

This project uses DevEco Studio and the hvigor build system. There is no CLI build — build, run, and debug through DevEco Studio.

- **Build:** Open in DevEco Studio → Build → Build App
- **Run on device/emulator:** DevEco Studio → Run → Run 'entry'
- **Run tests:** DevEco Studio → right-click test file → Run
- **Clean:** DevEco Studio → Build → Clean Project
- **SignHap fails with "certificate has expired":** File → Project Structure → Signing Configs → re-check "Automatically generate signature" to renew the local debug cert (expires yearly).

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
    ├── HtmlParser.ets               # Static dual-site HTML parser (52shuku.net + 52bqg.com)
    ├── FileManager.ets              # App-private temp file for crawling, exports via DocumentPicker
    └── SandboxFileManager.ets       # General sandbox file CRUD (list/import/export/delete)
```

**Data flow:** `Index` → `NovelCrawler.crawlNovel()` → `HttpClient.fetchPage()` → `HtmlParser.extractContent()` → `FileManager` (temp file) → `saveCrawledContent()` → export to Downloads.

## Key Patterns

- `getUIContext().getHostContext() as common.UIAbilityContext` — standard way to obtain context in `@Component` pages.
- Lazy init: `getNovelCrawler()` pattern creates the orchestrator on first use.
- Background task lifecycle (`backgroundTaskManager.startBackgroundRunning` / `stopBackgroundRunning`) wraps the crawl.
- `HttpClient` manages a singleton `http.HttpRequest` with `initialize()` / `ensureInitialized()` / `reset()` lifecycle.
- `HtmlParser` is fully static — no instantiation needed.
- `FileManager` uses `isBusy` flag to prevent concurrent file operations.
- **Theme:** UI colors must reference `$r('app.color.*')`; light values in `resources/base/element/color.json`, dark overrides in `resources/dark/element/color.json`. Never hardcode background/text colors — hardcoded light backgrounds with system-default text break in dark mode. Button accent colors may stay hardcoded.

## Crawler Gotchas (from the 2026-09 template breakage)

- **Never exact-string-match site markup.** 52shuku.net changed `<article class="article-content" id="nr1">` to variants without `id` (and with stray whitespace), which made the old `indexOf` parser return null on every page (0-byte output). Match `<article ... class="...article-content..." ...>` by regex and end the segment at `</article>` (page 1 has no pagination div).
- 52shuku.net URL shape: `https://www.52shuku.net/gl/20_b/bkfgU_2.html`; the suffix-less page (`bkfgU.html`) is the book intro, content starts at `_2.html`. The app's URL template uses `{}` in place of the page number.
- 52bqg.com: content lives in `<div class="word_read">`; long chapters base64-obfuscate each paragraph as `qsbs.bb('...')` — decoded by the pure-TS `base64ToUtf8` in HtmlParser.
- **Do not send a manual `Accept-Encoding` header** in HttpClient: the CDN then forces gzip, which the http stack may not auto-decompress; without the header the server returns identity.
- Site nav/promo/repeated-book-header paragraphs are filtered in `HtmlParser.isNoiseParagraph` — when a site update leaks junk into output, extend that list first.
- Verify parser changes against real fetched pages, not hand-written fixtures (the /tmp test harness pattern used in the 2026-09 fix).

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
