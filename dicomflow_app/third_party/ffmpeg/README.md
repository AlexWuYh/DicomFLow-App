# Bundled FFmpeg

Run from `dicomflow_app`:

```bash
dart run tool/fetch_ffmpeg.dart
```

This downloads the latest **release** static builds:

| Platform | Source | Destination |
|----------|--------|-------------|
| macOS arm64/x64 | [Martin Riedl](https://ffmpeg.martin-riedl.de/) | `macos/Runner/Resources/ffmpeg` (+ ffprobe) |
| Windows x64 | [Gyan 9.0.1 essentials](https://github.com/GyanD/codexffmpeg/releases) (libx264) | `windows/runner/resources/ffmpeg/` |

Android uses `ffmpeg_kit_flutter_new_min_gpl` (FFmpeg 8.1 + x264), not these CLI files.

Binaries are gitignored. The built `.app` / `.exe` / `.apk` contains them so the app is ready to convert without Homebrew.
