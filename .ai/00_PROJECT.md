# 项目目标

## 一句话

医院 DICOM 压缩包 → 本机 MP4/GIF，Android / Windows 上可预览（按片定位、局部放大）、分享给医生、管理历史。

## 非目标

- 替代放射科诊断工作站
- 医疗器械认证、PACS / DICOMweb
- 多租户 SaaS、账号、公网上传
- 测量、标注、报告、窗宽窗位交互调节

## 术语

| 词 | 含义 |
|----|------|
| 序列 | 以 `SeriesInstanceUID` 分组的一组切片 |
| 合并 | 本次任务多个输出媒体拼成单个 mp4/gif（序列间黑场） |
| 片 | 预览器里的一帧，对应一层切片（按编码 fps 推算） |
| 历史 | 本机已完成/失败的转换任务记录，替代网页 24h TTL |

## Agent 硬约束

1. 只做当前里程碑（见 `MILESTONES.md`）。
2. 源文件默认不出本机；日志与历史不落 PatientName / PatientID。
3. 品牌色 primary `#2563eb`，accent `#f97316`；布局与交互按原生 App，不照搬网页三步营销长页。不以 DicomFlow `design-system/MASTER.md` 为准。
4. 不提交真实胶片、`.env` 真值、密钥。
5. 产品 P0 发布平台是 Android 与 Windows。开发机可用 macOS 做功能验证与打包；不得用 Chrome 冒充客户端，也不得把 macOS 当成商店发布验收。
6. 真实医院压缩包只放 `testdata/private/`，该目录与 `*.rar` 已 gitignore，禁止提交或 `git add -f`。
