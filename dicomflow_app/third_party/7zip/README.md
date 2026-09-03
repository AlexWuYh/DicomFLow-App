# Bundled 7-Zip

Run from `dicomflow_app`:

```bash
dart run tool/fetch_7zip.dart
```

Official **7-Zip 25.01** CLI for extracting hospital `rar` / `7z` without installing Unarchiver or 7-Zip on the machine.

| Platform | Source | Destination |
|----------|--------|-------------|
| macOS universal | [7-zip.org mac tar.xz](https://www.7-zip.org/a/7z2501-mac.tar.xz) | `macos/Runner/Resources/7zz` |
| Windows x64 | [7-zip.org x64 installer](https://www.7-zip.org/a/7z2501-x64.exe) (`7z.exe` + `7z.dll`) | `windows/runner/resources/7zip/` |

Android uses [7-Zip-JBinding-4Android](https://github.com/omicronapps/7-Zip-JBinding-4Android) (p7zip 16.02, RAR5, 16 KB ELF), not these CLI files.

Binaries are gitignored. Rebuild the app so the installers contain them.
