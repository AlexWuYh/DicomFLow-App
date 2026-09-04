**1.0.2**

手机勾选「合并成一个文件」时，不再因为内存不足失败。各序列先单独编码，再拼成一个文件。

Merging series into one file no longer runs out of memory on phones.

全程离线，不作诊断依据。 Offline. Not for diagnosis.

| File | Notes |
| --- | --- |
| `*-android.apk` | Debug-signed; not for Play Store |
| `*-macos.zip` | Ad-hoc `.app`; not notarized |
| `*-windows.zip` | Portable folder, includes ffmpeg and 7-Zip |
