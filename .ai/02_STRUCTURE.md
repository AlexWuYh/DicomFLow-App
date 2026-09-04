# 目录结构

```
.
├── AGENTS.md
├── README.md                  # English (default)
├── README.zh.md
├── .github/workflows/ci.yml   # v* 标签打三端包；dev/main 只测
├── .ai/
│   ├── 00_PROJECT.md
│   ├── 01_DESIGN.md
│   ├── 02_STRUCTURE.md
│   ├── 03_SECURITY.md
│   └── MILESTONES.md
├── testdata/
│   ├── README.md
│   ├── synthetic_5.zip
│   └── private/            # 禁止入库
└── dicomflow_app/
    ├── lib/
    │   ├── main.dart
    │   ├── domain/
    │   ├── engine/
    │   ├── history/
    │   ├── share/
    │   └── ui/
    ├── assets/author_github.png  # GitHub 作者头像（离线）
    ├── test/
    ├── tool/fetch_ffmpeg.dart
    ├── tool/fetch_7zip.dart     # 官方 7-Zip → macOS Resources / Windows resources
    ├── tool/render_app_icon.py  # BrandMark → 各平台图标
    ├── third_party/ffmpeg/ # 下载缓存（gitignore）
    ├── third_party/7zip/   # 下载缓存（gitignore）
    ├── android/            # P0；FFmpegKit；rar/7z 用 koni_archive
    ├── windows/            # P0；runner/resources/ffmpeg + 7zip
    └── macos/              # Runner/Resources/ffmpeg + 7zz
```

## 模块边界

| 目录 | 职责 |
|------|------|
| `lib/ui/` | 主题、启动页、转换页、历史、设置、详情、关于、工作区卡片 |
| `lib/ui/viewer/` | 片号滑条、缩放、序列预览；GIF 在 isolate 解码 |
| `lib/engine/` | 解压 / 发现 / 窗位 / 像素 / ffmpeg 编码 / isolate worker |
| `lib/domain/` | ConvertParams、ProgressEvent、JobRecord、片号换算 |
| `lib/share/` | 系统分享、保存、打开文件夹 |
| `lib/history/` | JobStore / JobsController / 本机路径 / settings.json |

不要在 `ui/` 里写 DICOM 解析；不要在 `engine/` 里依赖 Widget。
