# DicomFlow App

Turn hospital CT / MRI archives (zip, rar, 7z) into MP4 or GIF **on this device**. Open them in a normal player — no PACS software.

Fully **offline**. For communication only, **not for diagnosis**.

[中文说明](README.zh.md)

## Features

- Convert locally, preview by slice, pinch or scroll to zoom
- Share on Android; export one dated zip
- History kept 1 / 7 / 30 days (confirm before shortening)

## Platforms

**Android** and **Windows** are the product targets. **macOS** is for development.

## Develop

Flutter 3.44+.

```bash
cd dicomflow_app
flutter pub get
dart run tool/fetch_ffmpeg.dart   # once, for macOS / Windows
flutter test
flutter run -d macos
```

Work on **`dev`**. Push **`main`** to cut a release; GitHub Actions builds an Android APK, a macOS `.app` zip, and a Windows zip.

Engine: [DicomFlow](https://github.com/AlexWuYh/DicomFlow). Agent notes: [AGENTS.md](./AGENTS.md).

## License

MIT ([LICENSE](./LICENSE)). Bundled FFmpeg (libx264) is GPL-3.0; a build that includes it is distributed as GPL-3.0.
