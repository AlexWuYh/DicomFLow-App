# DicomFlow App

把医院 CT / MRI 压缩包（zip / rar / 7z）在**本机**转成 MP4 或 GIF，用普通播放器就能看，不必装专业阅片软件。

全程**离线**。便于沟通查阅，**不作诊断依据**。

[English](README.md)

## 能做什么

- 本机转换，按片预览，捏合或滚轮放大
- Android 系统分享；导出一个带日期的 zip
- 历史保留 1 / 7 / 30 天（缩短且会删文件时需确认）

## 平台

产品目标是 **Android** 与 **Windows**。**macOS** 用于开发验证。

## 开发

需要 Flutter 3.44+。

```bash
cd dicomflow_app
flutter pub get
dart run tool/fetch_ffmpeg.dart   # macOS / Windows 打进包内，约一次
flutter test
flutter run -d macos
```

日常在 **`dev`** 开发。发版代码合进 **`main`**。打并推送 **`v*`** 标签才会编译安装包并发布 GitHub Release。

引擎：[DicomFlow](https://github.com/AlexWuYh/DicomFlow)。Agent 说明：[AGENTS.md](./AGENTS.md)。

## 许可

MIT（[LICENSE](./LICENSE)）。捆绑的 FFmpeg（libx264）为 GPL-3.0；带编码器的安装包按 GPL-3.0 分发。
