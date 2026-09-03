# AGENTS.md

> 本文件是 Grok / AI 编码助手在本仓库的**执行入口**。  
> 全局规范见 `~/.grok/rules/00-ai-coding-standards.md`。

## 项目

- **名称**：DicomFlow App
- **一句话**：把医院导出的 DICOM 压缩包在本机转成 MP4/GIF，并在 Android / Windows 上预览、分享、管理历史。
- **当前里程碑**：M23 `done`（GitHub；dev 日常 / main 发版流水线）
- **P0 平台**：Android、Windows
- **本机验证**：macOS（开发机可 `flutter run -d macos` / `flutter build macos`，不替代 Android/Windows 发布验收）

## 必读文档

| 文档 | 内容 |
|------|------|
| [`.ai/00_PROJECT.md`](./.ai/00_PROJECT.md) | 目标 / 非目标 / 术语 / Agent 硬约束 |
| [`.ai/MILESTONES.md`](./.ai/MILESTONES.md) | 里程碑与验收 |
| [`.ai/01_DESIGN.md`](./.ai/01_DESIGN.md) | 架构与 UI 契约 |
| [`.ai/02_STRUCTURE.md`](./.ai/02_STRUCTURE.md) | 目录与模块边界 |
| [`.ai/03_SECURITY.md`](./.ai/03_SECURITY.md) | 本地、隐私、解压限额 |

产品语义对照（只读，不改那个仓）：`../DicomFlow/.ai/01-product.md`、`.ai/04-engine.md`。

## 常用命令

Flutter SDK 若未在 PATH：`export PATH="$HOME/development/flutter/bin:$PATH"`

```bash
cd dicomflow_app
flutter pub get
dart run tool/fetch_ffmpeg.dart   # 下载官方 ffmpeg 打进 macOS/Windows 包（约一次）
flutter analyze
flutter test
flutter run -d macos            # 本机验证（开发机）
flutter run -d android          # 需完整 Android SDK + 模拟器或真机
flutter run -d windows          # 仅 Windows 主机
flutter build macos
flutter build apk
flutter build windows
```

Git：日常在 **`dev`** 开发；**`main` 只发版**。向 `main` 推送后，GitHub Actions 打 Android APK、macOS `.app` zip、Windows Release zip，见 Actions 产物。`.github/workflows/ci.yml`。

```bash
git checkout dev
# 发版：把 dev 合并进 main 并 push
git checkout main && git merge dev && git push origin main
```

本机 2026-08-31：Android cmdline-tools 缺失。功能验证用 macOS 打包/运行；不要用 Chrome 勾 P0 验收。

转换用捆绑 **ffmpeg**（`dart run tool/fetch_ffmpeg.dart`）：macOS 为 Resources 内 9.0.1 静态包，Windows 为 exe 旁 `ffmpeg.exe`。Android 走 FFmpegKit min-gpl（x264），不依赖系统 ffmpeg。`flutter run -d android` 仍需本机 Android SDK。

真实医院压缩包只放 `testdata/private/`（已 gitignore）。禁止 `git add -f` 该目录。

## 约定

- 只实现**当前里程碑**；超出部分写入 `.ai/MILESTONES.md` 后续项。
- 引擎语义对齐 DicomFlow（分组、窗位、质量档、错误码），**不嵌 Python、不调公网 API**。
- 行为或接口变更时，同步更新 `.ai/` 与本文件中的命令/阶段说明。
- 禁止提交密钥、真实患者影像、临床 `.dcm` / 医院压缩包。

## 本项目禁止

- 账号体系、Turnstile、访问密码、公网上传
- 诊断级阅片（测量、ROI、HU、调窗、MPR）
- 微信 OpenSDK（分享只用系统 Share Sheet）
- 用 Chrome 运行冒充客户端验收；用 macOS 验证可以，但不能代替 Android/Windows 发布验收
- 手写完整 DICOM 解析器（换库须先改计划）

## 文档同步

代码变更后检查：里程碑状态、设计偏差、README 用户说明是否仍准确。
