# DicomFlow App

Turn hospital **CT / MRI scans** into MP4 or GIF **on this device**. Play them in a normal player — no PACS software.

[中文说明](README.zh.md)

<p align="center">
  <img src="docs/screenshot.png" alt="DicomFlow convert screen: open a hospital zip, rar, or 7z and convert on this device" width="880">
</p>

Fully **offline**. For communication only, **not for diagnosis**.

## Download

Installers are on [Releases](https://github.com/AlexWuYh/DicomFLow-App/releases/latest):

| Platform | File | Notes |
|----------|------|--------|
| **Android** | `DicomFlow-v*-android.apk` | Sideload the APK. Not on Play Store. |
| **Windows** | `DicomFlow-v*-windows.zip` | Unzip and run. ffmpeg and 7-Zip are included. |
| macOS | `DicomFlow-v*-macos.zip` | For trying the app on a Mac. Not a store build. |

Android and Windows are the product targets.

## How to use

1. Open the zip / rar / 7z the hospital gave you.
2. Choose **MP4** (best for sending to a doctor) or **GIF**. Optionally merge series into one file.
3. Preview by slice, pinch or scroll to zoom, then **share this file** or **export** all results as a dated zip.

**Share** sends only the file you are previewing. **Export** packs every result.

History stays on this device for 1, 7, or 30 days. Shortening the period asks for confirmation because it deletes files.

## What it does not do

- Diagnose — no measurements, windowing, or MPR
- Upload — nothing leaves the device unless you share it yourself
- Accounts, passwords, or a cloud

## Build from source

Flutter 3.44+.

```bash
cd dicomflow_app
flutter pub get
dart run tool/fetch_ffmpeg.dart   # once, for macOS / Windows
dart run tool/fetch_7zip.dart     # once, bundled 7-Zip for rar / 7z
flutter test
flutter run -d macos
```

Work on **`dev`**. Merge to **`main`** for the release branch. Push a **`v*`** tag to build installers. Write a few lines in [`.github/release-notes.md`](.github/release-notes.md) before tagging.

Engine: [DicomFlow](https://github.com/AlexWuYh/DicomFlow). Contributor notes: [AGENTS.md](./AGENTS.md).

## What you can convert

| You have | We accept |
|----------|-----------|
| Hospital CT / MRI scans | DICOM images (the files on the disc the hospital copied for you) |
| Archive | zip, rar, 7z |
| Files inside | `.dcm`, `.dicom`, `.ima`, or DICOM files with no extension |
| Output | MP4 video or GIF |

Uncompressed, JPEG, and RLE images usually convert. JPEG 2000 and some other hospital compressions may not — ask for an uncompressed or JPEG export.

## License

MIT ([LICENSE](./LICENSE)). Bundled FFmpeg (libx264) is GPL-3.0; a build that includes it is distributed as GPL-3.0. Bundled 7-Zip is LGPL with the unRAR restriction.
