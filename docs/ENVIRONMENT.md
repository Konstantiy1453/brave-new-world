# 本机环境与工具链

记录日期：2026-10-29。工作目录 `D:/勇敢新世界`，Windows PowerShell。初始检查 `D:/Tools`（仅 ffmpeg）与 `D:/Binaries` 未发现 Godot，因此为本工程下载官方标准版，不采用 .NET 或浏览器壳。

## 引擎与模板

- 固定稳定版本：Godot **4.5.1.stable.official.f62fdbde1**。这是官方已发布稳定维护版本；本项目固定此版本，不声称它是最新版本。
- 实际执行：`tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe --headless --version`，退出码 0，输出如上。
- 编辑器：`tools/godot-4.5.1/Godot_v4.5.1-stable_win64.exe`。
- 自动测试/导出使用同目录 `_console.exe`。渲染配置采用 Compatibility/OpenGL，实际驱动与性能以运行报告为准。
- 下载入口：[Godot 官方 4.5.1 archive](https://godotengine.org/download/archive/4.5.1-stable/)。官方链接重定向至 `godot-releases.nbg1.your-objectstorage.com/4.5.1-stable/`，下载 `Godot_v4.5.1-stable_win64.exe.zip`（76,685,794 字节）及 `Godot_v4.5.1-stable_export_templates.tpz`（1,355,592,535 字节）。原始压缩包保留于 `tools/`。
- 官方校验清单：[godotengine/godot-builds 4.5.1-stable SHA512-SUMS.txt](https://github.com/godotengine/godot-builds/releases/download/4.5.1-stable/SHA512-SUMS.txt)，本地 `tools/godot-SHA512-SUMS.txt`。**两个完整下载包的 SHA512 均与官方清单逐字一致**。
- 仅解出本任务需要的 Windows x64 debug/release 及 version.txt 到 `C:/Users/ASUS/AppData/Roaming/Godot/export_templates/4.5.1.stable/`。完整标准模板压缩包仍保留，可补提取其他平台。
- 编辑器、模板包、单独可执行文件的 SHA256/SHA512、字节数和匹配结果见 `docs/evidence/toolchain_hashes.json`。

| 文件 | SHA256 |
| --- | --- |
| Godot Windows ZIP | `defccc78669e644861b4247626b01ae362cd9f23975edf19c8bfd2eb1f6a1783` |
| Godot 标准模板 TPZ | `1998af37f1387684e2c211cdb483daf492fc64dc6b12096bddcdca25b6910c86` |
| Windows release 模板 | `78ccc576e8f8bffd7ef6ad6f36ebd72a41e609a1052225a55b3407c96ea84065` |

对应版本文档：[Windows 导出](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_windows.html)、[渲染器](https://docs.godotengine.org/en/4.5/tutorials/rendering/renderers.html)。模板安装和 --version 成功仅证明工具链可用，不代表游戏导出或交互验收通过。

## 本机硬件（Win32 CIM 查询）

- Microsoft Windows 11 家庭版 中文版，10.0.26300。
- Intel Core i9-14900HX，24 核 / 32 逻辑处理器。
- 可见内存 33,160,832 KiB，约 31.6 GiB。
- 显示设备：NVIDIA GeForce RTX 4070 Laptop GPU，驱动 32.0.16.1047；Intel UHD Graphics，驱动 32.0.101.6790；GameViewer Virtual Display Adapter。
- CIM AdapterRAM 对独显返回接近 4 GiB 的值，存在 Win32 字段上限，不将其作为真实显存容量结论。
- Python 3.12：`C:/Users/ASUS/AppData/Local/Programs/Python/Python312/python.exe`；用于文件清单、字体元数据和原创 SVG 构建。

## 离线与分发

游戏运行只依赖导出 EXE/PCK 与已打包资源，字体和肖像位于工程内。工具下载、参考浏览、图像生成属于制作阶段。工具链压缩包不应混入玩家运行包。字体和 Godot 授权文件应随发行目录附带。
