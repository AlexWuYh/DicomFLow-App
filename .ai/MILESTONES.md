# 里程碑

当前：`M25` `done`

产品 P0 平台：**Android + Windows**。

M0–M4 产品主线已完成（macOS + 本机 ffmpeg 可验证）。M5–M9 消化全量审查项；**每轮开发后必须 review + 文档同步（D2D）再进入下一里程碑**。

| ID | 目标 | 状态 |
|----|------|------|
| M0 | 仓库骨架 + Flutter 空壳（转换 \| 历史） | `done` |
| M1 | tracer：zip → 发现 → 一条可播 MP4 | `done` |
| M2 | 三步 UI + 预览器（按片定位 + 局部放大）+ 保存 + Android 分享 + 任务落盘 | `done` |
| M3 | 历史查看与管理 + quality / fps / gif / 多序列 zip | `done` |
| M4 | merge 黑场、RAR/7z 尽力、压缩传输语法、Windows 安装包 | `done`（安装包文档化，需 Windows 主机） |
| M5 | 安全闭环：失败必删 PHI、1 GiB、rar/7z slip、Windows 7z、stem 死循环、禁止备份 | `done` |
| M6 | 平台动作与错误可读：Android 保存、语法错误上抛、历史/片号/底栏 | `done` |
| M7 | 像素与 GIF 编码：palette、多帧 JPEG、RLE 组帧、彩色 photometric | `done` |
| M8 | 预览器稳健 + 转换不卡 UI：isolate、流式帧、GIF 按片、播放器竞态 | `done` |
| M9 | P0 打包路径：捆绑/定位 ffmpeg、签名与文档收口 | `done` |
| M10 | 开箱即用：官方 ffmpeg 打进 macOS/Windows 包；Android 用 FFmpegKit min-gpl | `done` |
| M11 | 原生 App 壳：手机底栏 + 桌面侧栏/拖放，去掉网页三步长页 | `done` |
| M12 | 界面加厚 + 启动页 + 医院 zip Zip Slip 误报 | `done` |
| M13 | 导出到文件夹、结果页易用性、预览播放/缩放、关于页 | `done` |
| M14 | 历史标题可见；导出仅带时间戳的打包 zip | `done` |
| M15 | GitHub 作者跳转、应用图标对齐品牌标、首页转换步骤示意 | `done` |
| M16 | 历史列表可读；只保留最近 7 天 | `done` |
| M17 | 默认窗口加大；预览保持比例；结果页醒目「再转一个」与关闭 | `done` |
| M18 | 历史保留 1天/7天/30天可配；关于页排版；去掉个人网站地址 | `done` |
| M19 | 独立设置页改保留天数；缩短需确认；历史提示改版 | `done` |
| M20 | 关于页桌面加宽一屏看完；作者显示 GitHub 头像 | `done` |
| M21 | 关于页对称双栏；历史保留橙色提示；GIF 切文件不卡 UI | `done` |
| M22 | 历史详情文件列表加高，多文件可滚动选择 | `done` |
| M23 | GitHub 仓库；dev 日常 / main 发版；v* 标签编译安装包并发布 Release | `done` |
| M24 | README 英文为默认；GitHub 仓库 About 中英对照 | `done` |
| M25 | 安装包捆绑 rar/7z 解压（Android JNI + 桌面 7-Zip） | `done` |

---

## M0 — 脚手架

**目标**：文档齐全，Flutter 工程可分析/测试，空壳对齐线上站三步布局。

**范围内**

- `AGENTS.md`、`.ai/*`、`README.md`、`.gitignore`
- `flutter create --platforms=android,windows`
- 设计 token、底栏「转换 | 历史」、三步占位卡、历史空状态、主题切换
- 开始转换按钮禁用

**范围外**：引擎、选文件真实通路、ffmpeg、分享、真历史数据、预览器缩放。

**验收**

- [x] `flutter analyze` 无 issue（2026-08-31）
- [x] `flutter test` 3 passed：转换壳、历史空状态、主题切换；开始转换按钮 `onPressed == null`
- [ ] Android 模拟器或真机打开空壳 — **本机缺口**：无完整 Android SDK / cmdline-tools / 模拟器。补齐 SDK 后再勾。
- [x] macOS 本机验证：`flutter build macos --debug` 产出 `DicomFlow.app`（2026-08-31）。开发机验证，不替代 Android 发布验收。运行：`flutter run -d macos` 或打开 `dicomflow_app/build/macos/Build/Products/Debug/DicomFlow.app`

---

## M1 — 转换 tracer

**目标**：选 zip → 解压 → 发现 DICOM → 窗位 → 一条 MP4。UI 可以简陋。

**范围内**：zip；未压缩 Explicit/Implicit LE；合成夹具。

**范围外**：RAR、JPEG Lossless、GIF、合并、分享、历史页。

**验收**

- [x] 合成 5 帧 zip → MP4，`ffprobe` 读到 5 帧（`flutter test test/engine_convert_test.dart`）
- [x] 引擎无网络调用；本机 `ffmpeg` 编码
- [x] 空 zip / 无 DICOM → `NO_DICOM`
- [x] Zip Slip → `INVALID_ARCHIVE`

M1 界面：选择 zip、进度、完成后「打开」。macOS Debug 需系统已安装 ffmpeg（`/opt/homebrew/bin/ffmpeg`）。rar 仍范围外。

---

## M2 — 主流程 UI + 预览器 + 分享

**目标**：网页同款三步；预览可按片拖条、可局部放大；Android 能分享给医生。

**范围内**：进度相位、结果列表、自定义片号滑条、捏合/滚轮缩放、Share Sheet、任务落盘。

**范围外**：历史管理 UI、GIF/merge、测量标注。

**验收**

- [x] 片号滑条显示 `当前片 / 总片数`（`slice_index` + `SliceScrubBar` 测试）；seek 按编码 fps 换算
- [x] `ZoomableStage` 1x–8x，双击 2x / 回 1x，滚轮缩放（widget 测试覆盖缩放矩阵）
- [x] 结果页「分享给医生 / 分享」走系统 Share Sheet（`share_plus`）；桌面另有「打开所在文件夹」
- [x] 成功/失败任务写入 `Documents/DicomFlow/jobs.json`（不落患者姓名）
- [ ] Android 真机捏合 + 分享面板 — 本机仍无 Android SDK，待补设备后手工勾

macOS 验证：转换后第三步出现预览器。历史列表仍是空壳（M3）。

---

## M3 — 历史 + 其余输出选项

**目标**：历史列表可再预览/再分享/删除；质量档、fps、GIF、多序列 zip。

**验收**

- [x] 历史按时间倒序（JobStore）；点进详情用同一 `SeriesPreviewer`，可再分享
- [x] 单条删除同时删输出文件；清空需确认对话框
- [x] 转换页可选 MP4/GIF、高清/标准/流畅、帧率；多序列额外打 `result.zip`（`flutter test` 覆盖 zip 与 gif）
- [x] 合并成单文件（M4）

---

## M4 — 合并、RAR、压缩语法

**目标**：勾选合并时按序列拼接并插入约 0.4s 黑场；rar/7z 在本机有 unar/7z 时尽力解压；RLE / JPEG Baseline 尽力解码。

**范围内**

- `merge=true`：个体序列仍产出，另出 `merged.mp4|gif`；序列间 0.4s 黑场，末段后不加
- rar/7z：调用 `unar` / `7z`；没有工具则明确错误，建议转 zip
- 像素：未压缩 LE/BE、RLE Lossless、JPEG Baseline/Extended（ffmpeg）；JPEG Lossless / JPEG2000 跳过并可读报错
- Windows 安装包：文档记录 `flutter build windows`，本 Mac 不产出安装程序

**验收**

- [x] 两序列各 2 帧、10 fps、merge → `merged` 共 8 帧（2+4 黑场+2）（`engine_convert_test`）
- [x] 转换页可勾选「合并成一个文件」；文件选择允许 zip/rar/7z
- [x] 无 unar/7z 时 rar 给出可读错误
- [ ] Windows `flutter build windows` 安装包 — 需 Windows 主机
- [ ] 真实医院 `testdata/private/*.rar` 手工验证（含 PHI，不进 CI）

---

## M5 — 安全闭环

**目标**：失败或取消后磁盘上不留解压 DICOM；解压限额与 slip 与 `.ai/03_SECURITY.md` 一致；Windows 能找到 7-Zip。

**范围内**

- `convertDicomPackage` 用 `try/finally` 删除自有 `_work`
- 转换失败时删除整个 `outputs/<jobId>/`；`JobStore` 按 job id 删输出目录
- 输入包 `> 1 GiB` fail-closed（`ARCHIVE_BOMB`）
- rar/7z：解压前列成员、拒绝 `..`/绝对路径；解到 staging；拒绝 symlink；搬入 dest 时计数限额
- 提取器查找不依赖 Unix `which`（Windows 试 `7z` PATH 与常见安装路径）
- `uniqueOutputStem` 截断后仍保证唯一，禁止死循环
- Android `allowBackup=false` + 排除 data extraction

**范围外**：捆绑 ffmpeg、isolate、GIF 调色板、Android 保存按钮（M6+）。

**验收**

- [x] 空 zip / `NO_DICOM` 后 `outputDir/_work` 不存在
- [x] `maxInputBytes` 可测：超限 → `ARCHIVE_BOMB`，不解压
- [x] Zip Slip 抛 `INVALID_ARCHIVE` **且** dest 被删
- [x] 超长同名序列两次 `uniqueOutputStem` 得到不同、≤120 字符的名字
- [x] 解压树内 symlink → `INVALID_ARCHIVE`
- [x] `flutter analyze` 无 issue；相关测试通过（2026-08-31）

---

## M6 — 平台动作与错误可读

**目标**：Android 能真正保存文件；不支持的传输语法有可读原因；历史与预览状态与磁盘一致。

**范围内**

- Android「保存到文件」走系统保存（`FilePicker.saveFile` 或等价）；不能保存则不画空按钮
- 历史详情 CTA 与首页对齐（「分享给医生」）
- `framesForInstance` 失败原因汇总；零帧成功时抛出语法/解码信息
- 片号 `sliceFromPosition` 用 `floor`；低清晰度 fps 上限反映在下拉
- `JobOutput` 持久化 width/height；历史预览不再写死 32×32
- 历史 load 后标记缺失文件，分享/保存前存在性检查
- 底栏 `extendBody` 与列表底边距，避免挡住第三步按钮
- 转换页辅助文案随格式/合并变化

**范围外**：isolate、GIF 按片解码、ffmpeg 捆绑。

**验收**

- [x] `revealInFolder` / 保存：非 Android 仍打开文件夹；Android 走 `FilePicker.saveFile`
- [x] 全 JPEG2000 合成 UID → 错误信息含传输语法
- [x] `sliceFromPosition` 测试：帧区间用 floor
- [x] 历史 JobOutput 含宽高；缺失文件禁用分享/保存
- [x] 列表底部 padding ≥ NavigationBar 高度

---

## M7 — 像素与 GIF 编码正确性

**目标**：压缩语法与彩色帧对齐 M4 契约；GIF 质量档的颜色数真正进编码器。

**范围内**

- JPEG Baseline/Extended：按 encapsulated fragment / 帧拆分，禁止把 `flatBytes` 当单张 JPEG
- RLE：按 DICOM Annex G 组帧（`RleFramingStrategy` 或等价）
- `samplesPerPixel` / photometric：真彩色跳过 VOI，写入 RGB；YBR/planar 尽力或可读跳过
- `writeGif` 使用 `gifColors`（文件 paletttegen/paletteuse，避免 stdin 死锁）
- GIF 缩放应用 `profile.scale`；merge GIF 再套 `gifMaxFrames`

**范围外**：isolate、预览器 GIF scrub（M8）。

**验收**

- [x] JPEG fragment 按 SOI 拆帧（`pixels_test`）
- [x] GIF `palettegen`/`paletteuse` 使用 `gifColors`；失败回退 `-c:v gif`
- [x] RGB 跳过 VOI；YBR/PALETTE 可读错误；planar 去平面
- [x] `flutter analyze` + `flutter test` 通过

---

## M8 — 预览器 + 转换不卡 UI

**目标**：医院体量转换时 UI 可刷新、手机不易 OOM；GIF 可按片；播放器不泄漏。

**范围内**

- 转换在 isolate / worker 中跑；进度经 port 回主 isolate
- 非 merge 不把所有序列 RGB 常驻；merge 从已写媒体或逐序列 raw 拼接
- ffmpeg / unar / 7z `Process` 超时
- GIF 预览：按帧 scrub（`image` 解码或逐帧控制器），或明确「动图无法按片」并去掉误导文案——**本里程碑做按片**
- `VideoPlayerController` 世代 token；`initialize` 失败显示「无法播放」
- 选文件 `path == null` 时给出可读错误；转换成功后清理 file_picker 缓存

**范围外**：商店签名、捆绑 ffmpeg 二进制（M9）。

**验收**

- [x] UI 走 `convertDicomPackageInBackground`（isolate）；测试覆盖 isolate 转换
- [x] `merge=false` 不积累 `preparedSeries`
- [x] GIF 预览有 `SliceScrubBar`（`image` 解码帧）
- [x] `VideoPlayerController` 世代 token；initialize 失败显示「无法播放」
- [x] `flutter analyze` + `flutter test`

---

## M9 — P0 打包路径与文档收口

**目标**：Android/Windows 转换不再依赖「用户自己装了 Homebrew ffmpeg」；文档与实现一致。

**范围内**

- 捆绑或明确解析应用内 ffmpeg（macOS Release、Windows 旁路、Android 可行方案：插件或 jniLibs）；解析只走绝对路径
- JPEG 解码复用同一 `resolveFfmpeg`
- Release APK 不用 debug 密钥作为「可分发」状态：`key.properties` 文档化，未配置则构建说明为 unsigned/debug-only
- 工作目录与 `jobs.json` 放到 application support（非 iCloud/OneDrive Documents）；用户可见结果仍可导出
- 同步 `AGENTS.md`、`.ai/01_DESIGN.md`（JSON 而非 SQLite；isolate 已落地）、`02_STRUCTURE.md`、`README.md`；M4「主线完成」改为「引擎完成，P0 打包见 M9」
- 去掉未使用 `cupertino_icons`（若仍未用）

**范围外**：Windows 安装程序制作（仍需 Windows 主机）；Play 上架。

**验收**

- [x] `resolveFfmpeg` 优先 `DICOMFLOW_FFMPEG`、可执行文件旁 `ffmpeg`、macOS `Resources/ffmpeg`，再 PATH/Homebrew
- [x] README/AGENTS 写明 Android 无捆绑 ffmpeg 时无法转换；桌面可拷贝二进制到应用目录
- [x] 设计文档为 JSON JobStore + isolate worker；结构文档为当前模块
- [x] `flutter analyze` 无 issue

---

## M10 — 开箱即用 ffmpeg

**目标**：用户拿到的安装包自带编码器，不必再装 Homebrew / 系统 ffmpeg。

**范围内**

- `dart run tool/fetch_ffmpeg.dart` 下载最新 **release** 静态包：macOS Martin Riedl 9.0.1（universal arm64+x64，含 libx264）、Windows Gyan 9.0.1 essentials
- macOS 打进 `Contents/Resources/ffmpeg`；Windows 安装到 exe 同目录
- Android 使用 `ffmpeg_kit_flutter_new_min_gpl`（FFmpeg 8.1.2 + x264）；转换在 UI isolate 跑（Kit 不能进 Dart isolate）
- 二进制 gitignore；克隆后先 fetch 再打包

**范围外**：把 150MB+ 二进制提交进 git；Windows 安装程序。

**验收**

- [x] 本机 `macos/Runner/Resources/ffmpeg -version` 为 9.0.1 且含 `--enable-libx264`
- [x] Windows `ffmpeg.exe` 已下载到 `windows/runner/resources/ffmpeg/`
- [x] `flutter analyze` 无 issue；`flutter test` 通过
- [x] 文档写明：打包前 `dart run tool/fetch_ffmpeg.dart`；分发的 app 内含 ffmpeg

---

## M11 — 原生 App 壳

**目标**：界面按手机 / 桌面 App 操作，不再把网页三步营销长页搬进 Flutter。

**范围内**

- 窄屏：底栏「转换 | 历史」；转换页空状态 + 选文件；选后选项与主按钮；完成后全宽预览
- 宽屏：左侧 NavigationRail；拖放打开；菜单「文件 → 打开压缩包」；完成后左侧预览、右侧文件列表
- 历史用系统 ListTile；去掉极光背景、玻璃步骤卡、首页使用说明
- 品牌色保留

**验收**

- [x] 无「医院给你的专业影像」等网页 hero 文案
- [x] 宽屏 NavigationRail、窄屏 NavigationBar（widget 测试）
- [x] 未选文件时「开始转换」禁用
- [x] `flutter test` 通过

---

## M12 — 界面加厚、启动页、Zip Slip 误报

**目标**：原生壳保留，但空状态不再像未完成的线框；冷启动有品牌页；真实医院压缩包能开始转换。

**范围内**

- 转换页：虚线投递区、格式卡片、清晰度/帧率芯片、错误卡片
- 历史：卡片列表；侧栏带品牌标
- 启动页约 1.6s（`DicomFlowApp(showSplash: false)` 供测试跳过）
- 解压：去掉盘符与前导 `/` 后再判 Zip Slip；`/DICOM/a.dcm` 解到 dest 内；`..` 仍拒绝
- 不恢复网页三步营销长页

**验收**

- [x] 启动页出现「影像随手看」，超时后进入转换空状态（widget 测试）
- [x] 未选文件时「开始转换」仍禁用
- [x] `/DICOM/a.dcm` 与嵌套 `series/b.dcm` 解压进 dest；`../` 仍 `INVALID_ARCHIVE`
- [x] `lsar` 头行 `/abs/archive.rar: RAR 5` 不当成 Zip Slip（医院 `C252708.rar` 复现）
- [x] `flutter analyze` / `flutter test`

---

## M13 — 导出、结果页、预览控制、关于

**目标**：转换结果更好带走、更好预览；「再转一个」回到空首页；补关于页。

**范围内**

- 导出到用户选择的文件夹（复制本次全部结果文件；重名自动加后缀）
- 「再转一个」清空已选压缩包，回到转换空状态
- 预览画面中央播放按钮；右上角放大 / 缩小
- 结果页操作条固定（分享 / 导出 / 打开文件夹），文件列表单独滚动；窄屏横向序列条
- 关于页：简介、作者、开源链接、MIT + 捆绑 FFmpeg 的 GPL 说明
- 导航增加「关于」

**范围外**：云同步、账号、诊断工具。

**验收**

- [x] `copyOutputsToDirectory` 复制并处理重名（测试）
- [x] 关于页含简介、作者、GitHub、MIT/GPL（widget 测试）
- [x] ZoomableStage `zoomIn` / `zoomOut`（测试）
- [x] `flutter analyze` / `flutter test`

---

## M14 — 历史名称与打包导出

**目标**：历史列表能看清来源文件名；导出只给一个带时间的 zip。

**范围内**

- 历史标题用 `displayTitle`（有源文件名则显示，否则回退，不为空）
- 导出只写入一个 zip：已有 `result.zip` 则改名复制，否则把本次媒体打成 zip
- 文件名 `{源文件名}_{yyyyMMdd_HHmmss}.zip`

**验收**

- [x] `displayTitle`：有源文件名则显示，空则回退，不为空白（测试）
- [x] `C252708.rar` + 2026-09-01 18:30:45 → `C252708_20260901_183045.zip`，目录里只有这一个文件
- [x] `flutter analyze` / `flutter test`

---

## M15 — 作者主页、应用图标、首页步骤

**目标**：关于页用 GitHub 账号并可跳转；桌面/手机图标与应用内品牌标一致；首页空状态一眼能看懂怎么转。

**范围内**

- 关于页作者为 `@AlexWuYh`，点击打开 `https://github.com/AlexWuYh`（不联网拉头像）
- `tool/render_app_icon.py` 按 BrandMark 生成 macOS / Android / Windows 图标
- 首页空状态「转换流程」：选压缩包 → 本机转换 → 预览导出

**验收**

- [x] 关于页可见 `@AlexWuYh`（widget 测试）
- [x] 空状态可见「转换流程」三步（widget 测试）
- [x] `flutter analyze` / `flutter test`

---

## M16 — 历史可读与 7 天保留

**目标**：历史条目能看清文件名；超过 7 天的记录及结果文件自动删掉。

**范围内**

- 历史用 ListTile：标题为源压缩包名，副标题为日期与状态
- `JobStore` 在 load / upsert 时丢掉 `createdAt` 早于 7 天的任务并删除输出文件
- 空状态说明只保留最近 7 天

**验收**

- [x] 8 天前的任务在 upsert/load 后消失，输出文件被删（测试）
- [x] 2 天内任务保留
- [x] `flutter analyze` / `flutter test`

---

## M17 — 窗口、预览比例、结果页返回

**目标**：桌面默认窗口能放下首页；预览不拉变形；结果页能一眼回到上传。

**范围内**

- macOS 默认 1280×840，最小 1024×720；Windows 默认 1280×840
- 预览按片幅比例居中，黑边留白，不拉伸
- 结果页「再转一个」为填充主按钮；顶栏 × 关闭结果回到首页（不再并排放两个相同操作）

**验收**

- [x] `flutter analyze` / `flutter test`

---

## M18 — 历史保留天数、关于页、去掉个人网站

**目标**：历史页能配置保留时长（按天数、最多 30天）；关于页排版更完整；文档与界面不出现个人线上网页地址。

**范围内**

- 历史页始终显示提示：默认保留 7天，过期自动删结果
- 快捷档 **1天 / 7天 / 30天**（不写「1周」「1月」）；写入 `settings.json`，立刻按新窗口裁剪
- 关于页分区块（简介 / 作者 / 开源 / 许可）；引擎只链 GitHub DicomFlow
- 仓库文档与关于页去掉个人线上网页版地址

**验收**

- [x] 历史空状态可见「默认保留 7天」与「1天 / 7天 / 30天」（widget 测试）
- [x] `normalizeRetentionDays` 只落到 1 / 7 / 30；1天窗口会删掉更早任务（测试）
- [x] 关于页无「线上网页版」（widget 测试）
- [x] `flutter analyze` / `flutter test`

---

## M19 — 设置页与保留确认

**目标**：改保留天数不再一键立刻删文件；历史页提示与整体卡片风格一致。

**范围内**

- 独立「设置」页：选项 1天 / 7天 / 30天，点选只预览，点「保存」才写入
- 缩短且会删记录时弹出确认（取消则不删）；设置页用与工作区相同的卡片提示，不用浅色横幅
- 历史页顶栏卡片显示当前保留天数，点卡片或齿轮进入设置；关于页也可进入

**验收**

- [x] 历史页可见「记录保留 7天」，不可见立刻切换的 1天/7天/30天（widget 测试）
- [x] 设置页点 1天 不删文件；保存后取消则仍保留；确认「删除过期记录」后才删（widget 测试）
- [x] `countExpired` 只计数不删文件（测试）
- [x] `flutter analyze` / `flutter test`

---

## M20 — 关于页桌面布局与作者头像

**目标**：桌面端关于页加宽、一屏看完；作者使用 GitHub 主页头像（打包进安装包，运行时不联网）。

**范围内**

- 桌面（≥ 720）关于页最大宽度约 1100，双栏排布
- 作者行显示 `assets/author_github.png`（来自 GitHub 主页头像）
- 窄屏仍单列滚动

**验收**

- [x] 桌面 1280×840 关于页可见简介/作者/开源/许可，无需 skipOffstage（widget 测试）
- [x] 关于页有 `author-avatar`（widget 测试）
- [x] `flutter analyze` / `flutter test`

---

## M21 — 关于页整齐、历史警示、GIF 预览不卡

**目标**：关于页左右对称、手机/桌面都整齐；历史保留与记录项颜色区分；切换 GIF 文件时界面不冻结。

**范围内**

- 关于：桌面居中 880 宽，等宽双栏（简介|作者，设置|开源），卡片按内容高度；窄屏单列
- 历史保留入口用橙色警示图标与左边条，记录项仍为蓝色影片图标
- GIF 在 isolate 解码（PNG level 1），先让出一帧画加载圈；按路径缓存最近 2 个

**验收**

- [x] 桌面关于页可见简介/作者/开源/许可（widget 测试）
- [x] 历史空状态可见橙色 `warning_amber_rounded`（widget 测试）
- [x] `decodeGifPreviewFile` 可在 isolate 运行（测试）
- [x] `flutter analyze` / `flutter test`

---

## M22 — 历史详情文件列表

**目标**：历史预览页能方便地在很多结果文件之间切换。

**范围内**

- 去掉 120px 锁死高度
- 桌面：左侧预览，右侧 320 宽操作 + 文件列表通栏滚动
- 窄屏：预览与文件列表 3:2 分高，列表可滚动

**验收**

- [x] `flutter analyze` / `flutter test`

---

## M23 — GitHub 仓库与发版流水线

**目标**：代码上 GitHub；日常在 `dev` 开发；`main` 只作发版；打 `v*` 标签才编译安装包并发布 GitHub Release。

**范围内**

- 仓库 `AlexWuYh/DicomFLow-App`；默认工作分支 `dev`
- `.github/workflows/ci.yml`：`dev` / `main` / PR 跑 analyze + test；仅 `v*` 标签编译三端包并发布 GitHub Release
- Android 为 debug 签名 APK（无商店证书）；macOS 为 ad-hoc `.app` zip；Windows 为 Release 目录 zip（含 ffmpeg）

**验收**

- [x] 工作流文件在仓库中
- [x] `flutter analyze` / `flutter test`

---

## M24 — README 英文默认、仓库 About 中英对照

**目标**：GitHub 默认 README 为精简英文；仓库 About 描述中英对照。

**范围内**

- `README.md` 英文；`README.zh.md` 中文
- GitHub 仓库 description 中英对照；不写个人网站地址

**验收**

- [x] `README.md` 为英文，链到 `README.zh.md`
- [x] `flutter analyze` / `flutter test`

---

## M25 — 捆绑 rar / 7z 解压，开箱即用

**目标**：Android / Windows / macOS 安装包都能直接解医院 rar、7z，不必再装 Unarchiver 或 7-Zip。

**范围内**

- 桌面：官方 7-Zip 25.01（macOS `7zz`，Windows `7z.exe` + `7z.dll`），`dart run tool/fetch_7zip.dart` 打进包内
- Android：7-Zip-JBinding-4Android（RAR5、16 KB 对齐），转换在 UI isolate 走 MethodChannel
- 解压后仍做 Zip Slip、symlink 拒绝与体积限额
- 无解压组件时错误改为「安装包内解压组件不可用」，建议转 zip

**范围外**：密码包、分卷 rar、商店签名、把 `testdata/private` 的医院包纳入 CI。

**验收**

- [x] `flutter analyze` / `flutter test`
- [x] 本机 `7zz` 能列出并抽出医院 `C252708.rar`（RAR5）
- [x] macOS / Windows 包内有 7-Zip；Android 不依赖系统 unar

每轮完成定义：**代码 + 测试 + 对本里程碑的 review（无新的 must-fix）+ D2D 文档同步。**
