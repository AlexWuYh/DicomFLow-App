# 安全

## 原则

1. **本地优先**：转换不访问网络。不得把源文件或结果默认传到公网。
2. **Fail-closed**：解压超限、路径穿越、无可读 DICOM → 明确失败，不继续写盘。
3. **最小权限**：不声明相机、麦克风、定位。分享走系统面板，不接微信 SDK。
4. **无密钥**：本应用无 ACCESS_TOKEN / Turnstile；禁止把任何 secret 写入仓库。

## 隐私

- 历史与日志只保留源**压缩包文件名**、参数、状态、错误码；超过保留天数（默认 7，最多 30）会连结果文件一起删除。设置在 application support 的 `settings.json`。缩短保留天数在设置页保存，且会删文件时必须确认，不能一键误删。
- 不存储 PatientName、PatientID、检查号等 DICOM 患者标签。
- 解压工作目录在转换**任何退出**时删除（`try/finally`）；失败时连 `outputs/<jobId>/` 一起删。历史只留结果媒体。
- `jobs.json` 与输出在 **application support**（`path_provider.getApplicationSupportDirectory`），不放用户 Documents，避免 iCloud/OneDrive 默认同步。

## 解压限额（与 DicomFlow Settings 对齐，M1 起生效）

| 项 | 默认 | 实现 |
|----|------|------|
| 输入包大小 | 1 GiB | `prepareInput` 解压前检查，超限 `ARCHIVE_BOMB` |
| 解压后总大小 | 4 GiB | zip 写盘时累计；rar/7z 搬入 dest 后检查 |
| 解压文件数 | 100_000 | 同上 |
| 压缩比 | 100 | 解压字节 / 压缩包大小，且解压量 > 32 MiB 才判 bomb |

Zip Slip：成员名去掉 Windows 盘符与前导 `/` 后，若规范化路径仍含 `..` 或写出 dest 之外，整单失败并删除不完整目录。医院 zip 常见 `/DICOM/...` 视为包内相对路径，解到 `dest/DICOM/...`，不是穿越。rar/7z：先列成员（跳过 `lsar` 头行 `绝对路径: RAR 5` 与归档自身路径），解到系统临时目录，拒绝 symlink，再搬入 dest。穿越比较用解析符号链接后的规范路径，避免 macOS `/var` → `/private/var` 误报。

## 本机测试胶片

- 真实医院包只放 `testdata/private/`。`.gitignore` 排除该目录以及 `*.rar` / `*.7z` / `*.dcm`。
- 禁止 `git add -f testdata/private/` 或把胶片拷进 `lib/`、`test/fixtures/`。
- 文档只写文件名，不写患者姓名、检查号明文。

## Android / Windows / macOS

- 文件选择用系统选择器（SAF / 文件对话框），不遍历全盘。导出到文件夹只写入用户刚选中的目录，目标路径不得逃出该目录。
- macOS Debug 关闭 App Sandbox。Release 仍沙箱并申请 `files.user-selected.read-write`；编码走包内 `Contents/Resources/ffmpeg`（工作目录在 application support）。
- Android 编码走 FFmpegKit 进程内库，不 `Process.run` 外部 ffmpeg。
- rar/7z 解压后仍做路径穿越检查、symlink 拒绝与体积限额。提取器查找不依赖 Unix `which`。
- Android `allowBackup=false`，`dataExtractionRules` 排除应用数据；结果不进 Google 备份。
- Debug 构建可保留 INTERNET（热重载）；Release 转换路径不得依赖外网。
- GitHub Actions 打的 Android APK 仍用 debug 签名，不能当商店包。不把 `key.properties` / keystore 写入仓库。
