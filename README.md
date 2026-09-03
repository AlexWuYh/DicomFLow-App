# DicomFlow App

把医院导出的 CT / MRI 压缩包，在手机或电脑上转成 MP4、GIF。医生用系统播放器就能看，不必安装专业阅片软件。

当前阶段：**M23**（本机转换 + GitHub 发版流水线）。产品优先平台：**Android** 与 **Windows**。本机可用 **macOS** 验证。

源码：[DicomFLow-App](https://github.com/AlexWuYh/DicomFLow-App)。日常开发用 **`dev`** 分支；**`main` 只用于打包发版**。向 `main` 推送后，GitHub Actions 自动构建 Android APK、macOS 应用 zip、Windows 程序 zip（见仓库 Actions 产物）。Android 商店签名、macOS 公证、Windows 安装程序仍需本机证书。

引擎语义源码：[DicomFlow](https://github.com/AlexWuYh/DicomFlow)

## 能做什么

- 本机选择 zip / rar / 7z，按检查序列转成视频或动图
- 预览时按片拖动进度条（MP4 与 GIF）、捏合或滚轮放大看细节
- Android 用系统分享发给医生，或保存到文件；也可导出一个带日期时间的 zip 到自选文件夹
- 预览可播放、按片拖动，并用按钮或捏合/滚轮放大
- 历史记录可再预览、再分享、删除；默认保留 7天，可在设置里改为 1天或 30天（缩短且会删文件时需确认）
- 「关于」页含简介、GitHub 作者 [@AlexWuYh](https://github.com/AlexWuYh)（头像）、开源地址与许可说明；桌面端加宽一屏看完

转换全程离线。便于沟通查阅，**不作诊断依据**。

## 开发

需要 [Flutter](https://flutter.dev) 3.44+（本仓库验证于 3.44.7）。若 `flutter` 不在 PATH：

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

```bash
cd dicomflow_app
flutter pub get
flutter analyze
flutter test
flutter run -d macos      # 本机验证
flutter build macos
flutter run -d android    # 需完整 Android SDK；无捆绑 ffmpeg 时无法转换
flutter run -d windows    # 仅 Windows 主机
```

### ffmpeg（打进安装包，用户不用另装）

```bash
cd dicomflow_app
dart run tool/fetch_ffmpeg.dart
```

- **macOS**：Martin Riedl 静态 **9.0.1**（arm64+x64 universal，含 libx264）→ `DicomFlow.app/Contents/Resources/ffmpeg`
- **Windows**：Gyan essentials **9.0.1**（libx264）→ `ffmpeg.exe` 与应用 exe 同目录
- **Android**：`ffmpeg_kit_flutter_new_min_gpl`（FFmpeg 8.1.2 + x264），随 APK 走，不依赖系统 ffmpeg

二进制体积大，不进 git。克隆仓库后先跑上面的 fetch，再 `flutter run` / `flutter build`。解 rar/7z 仍建议安装 `unar` 或 7-Zip（没有则请先转 zip）。

Release APK 在配置 `android/key.properties` 之前仍用 debug 签名，**不能**当商店包。

Windows 本机打包：`flutter build windows`（产出 `runner/Release` 目录）。发版 zip 由 `main` 上的 GitHub Actions 生成。

手动试转换：打开 App，选择 [`testdata/synthetic_5.zip`](./testdata/synthetic_5.zip)，点「开始转换」。医院真实包仍放 [`testdata/private/`](./testdata/README.md)，不要提交。

Agent 与里程碑说明见 [AGENTS.md](./AGENTS.md) 和 [.ai/MILESTONES.md](./.ai/MILESTONES.md)。

## 许可

MIT，见 [LICENSE](./LICENSE)。
