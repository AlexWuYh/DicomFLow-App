# testdata

本目录存放**本机验证用**的医院压缩包。真实胶片含患者信息，**禁止提交、禁止 push**。

| 路径 | 是否入库 |
|------|----------|
| [README.md](./README.md)（本文件） | 是 |
| `private/` 下任意文件 | **否**（`.gitignore` 已排除） |

## 本机文件

把验证用压缩包放到 `testdata/private/`。当前预期：

```text
testdata/private/C252708.rar
```

来源是开发者本机的 DicomFlow `input/` 拷贝，不是仓库的一部分。克隆仓库后若该文件不存在，从你自己的胶片备份复制进来即可。

```bash
# 确认不会被 git 跟踪（应打印 testdata/private/）
git check-ignore -v testdata/private/C252708.rar
```

可入库的合成夹具：

```text
testdata/synthetic_5.zip
```

五张未压缩合成切片，供 M1 手动选择转换。真正医院包仍只放 `private/`。
