# 2026-11-06 交接包验证记录

本轮在原电脑上，把交接包内的工程复制到一个新目录，使用随包引擎和导出模板进行验证。当前工程仍为 **1.8.0**，提交为 `af752d255c49bff477a5e884237d99f887cfad0c`。结果说明当前交接副本可以导入、运行选定测试并导出 Windows 程序。朋友电脑上的实测由接收方完成。

## 实际执行结果

| 项目 | 本轮结果 | 证据范围 |
|---|---|---|
| 原发行 ZIP | PASS | CRC 检查；ZIP、EXE、PCK 与原 RELEASE_IDENTITY 哈希相符 |
| 工程换目录导入 | PASS | 随包 Godot 4.5.1；隔离 APPDATA；退出码 0 |
| `v17_bugs` | PASS | 43 项检查，失败 0 |
| `v17_saves` | PASS | 103 项检查，失败 0 |
| `v18_systems` | PASS | 92 项检查，失败 0 |
| `ui_contract` | PASS | 暂停、速度一致性、地图切换、保存/读取入口及十类页面构建断言通过 |
| Windows x64 导出 | PASS（r2） | 随包 Windows 模板；生成 EXE/PCK 与原 1.8.0 逐字节一致 |
| 原发行 EXE 无窗口启动 | PASS | `--headless --quit-after 120`；退出码 0，无错误标记 |
| 新导出 EXE 无窗口启动 | PASS | 同上；属于启动冒烟检查 |
| Git 与 LFS 离线恢复 | PASS | 本地 bundle 克隆；17 个 LFS 对象恢复；当前快照叠加哈希一致 |
| 原输入保护 | PASS | 485 个复制来源及主包副本复核一致；未改游戏、玩家存档、原建模资产或原发行 |
| 模型文件交接 | PASS | 20 MAX/20 FBX、20 metadata、102 预览及纹理；文件哈希、依赖和图库链接检查 |

三套计数测试合计 **238 项检查**；`ui_contract` 另行报告断言结果，不人为给它补一个检查总数。默认全套中的七个旧辅助脚本仍写死原 D 盘输出路径，本轮选择的四套测试避开了它们，详见 START_HERE。

新导出产物：

```text
ColonyCharter.exe   96,725,504 bytes
SHA256 78ccc576e8f8bffd7ef6ad6f36ebd72a41e609a1052225a55b3407c96ea84065

ColonyCharter.pck   14,222,340 bytes
SHA256 614ff8b9e6bcb57aba18c71a8289e2a4cc11a2748b56c37a003db855ad5d41be
```

## 保留的首次失败及处理

首次 `portable_build` 返回 1。Godot 已导出文件，脚本在最后一步 `Get-FileHash` 报命令不存在。本轮 Python 启动器继承了 PowerShell 7 的 `PSMODULEPATH`，再启动 Windows PowerShell 5.1，导致模块搜索不正确。

最小复现保存在 `verification/powershell_environment_diagnosis_r2.json`：保留继承值时 `Get-Command Get-FileHash` 返回 1；仅移除子进程环境中的该键后返回 0。随后使用相同工程和构建脚本，以正确的子进程环境执行 `portable_build_r2`，退出码 0。

原失败日志、退出码和两次诊断均保留。第一份诊断脚本未处理环境变量键名大小写，因此其第二个试验仍失败；r2 按不区分大小写删除键后得到上述结果。没有为使交接通过而修改游戏或原构建脚本。

普通接手者从 Windows 新开的 PowerShell 窗口执行文档命令即可。自动化代理若经 Python 启动 Windows PowerShell 5，应让该子进程使用正确的模块环境；不要忽略非零退出码。

## 模型检查的边界

模型包内原报告仍保留制作时的验收状态。本轮核对源文件、交换文件、贴图、报告及预览的真实性与完整性，没有重新运行 3ds Max，也没有把模型接入游戏。

- 12 项旧资产属于原正式白名单选集。
- 8 项续建资产为候选，当前没有正式交付白名单。
- `CC_ARCOLOGY_HP_v002` 材质/经营视图检查仍为 `NOT_RUN`，100px 预览缺失，索引已标记。
- 102 张随包 PNG 解码通过；画廊 349 个本地引用存在。此项属于文件和链接检查。

## 本轮没有执行的验收

朋友电脑运行、完整真人通关、窗口图形效果及帧时间、新模型引擎导入/渲染、默认全套测试和完整平衡机器人批次均未运行。2026-11-02 的六套 858 检查与更早 1.8 的平衡报告按历史证据随包保留。

## 如何复核

- `verification/portable_summary.json`：每步命令、工作目录、隔离用户目录、进程、退出码及日志哈希。
- `verification/history_restore_result.json`：Git bundle、LFS 对象和工作区覆盖的恢复记录。
- `verification/art_verification_receipt.json`：模型文件、依赖与预览检查。
- `SOURCE_RECEIPTS_MAIN.json` / `SOURCE_RECEIPTS_ART.json`：原路径和逐文件来源记录。
- `MANIFEST_MAIN.json` / `MANIFEST_ART.json`：最终 ZIP 内文件的相对路径、大小与 SHA-256。
- `VERIFY_PACKAGE.py`：解压后运行，核对实际接收内容；传输后的文件应以本地核验结果为准。

证据 JSON 内的原绝对路径是本轮执行地点，不要求接收者创建相同目录。交接使用路径以顶层文档和相对路径索引为准。
