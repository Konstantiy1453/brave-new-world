# 2026-11-06 交接资料：Git 仓库与 ZIP 目录映射

本目录保存 2026-11-06 交接文档与清单的原始副本。原文件内的相对路径以两个 ZIP 合并后的 `BraveNewWorld_Handoff_20261106/` 为基准。当前目录是文档存档位置，文中 `project/`、`playable/`、`history/` 和模型预览链接应到解压目录中使用。

## 推荐阅读顺序

1. [START_HERE.md](START_HERE.md)：项目方向、开发入口、规则、模型接入和原包恢复步骤。
2. [VALIDATION_20261106.md](VALIDATION_20261106.md)：当日实际执行的结果、失败记录与未执行范围。
3. [MODEL_INTEGRATION.md](MODEL_INTEGRATION.md)：12 项原正式资产和 8 项续建候选的来源、状态与接入要求。
4. [HANDOFF_ASSET_INDEX.json](HANDOFF_ASSET_INDEX.json)：20 项资产的文件、状态和依赖索引；MAX/FBX、纹理和预览从模型 ZIP 获取。
5. [SHA256SUMS.txt](SHA256SUMS.txt)：两个原 ZIP 的校验值。

## 目录差别

| 合并后的 ZIP 目录 | Git clone 对应位置或用途 |
|---|---|
| `project/game/` | 仓库根目录下 `game/`，直接导入 `game/project.godot` |
| `project/docs/`、`project/tools/` 中脚本 | 仓库根目录下 `docs/`、`tools/` |
| `project/tools/godot-4.5.1/` | 从主包复制到仓库 `tools/godot-4.5.1/`，补齐引擎 |
| `project/build/godot_home/` | 从主包复制到仓库 `build/godot_home/`，补齐 Windows 模板 |
| `project/saves/`、指定 `project/evidence/` 和历史源码 | 仓库已明确纳入四个被测试引用的外部 fixture；其他证据在原 ZIP 中查看 |
| `project/art_reserve/` | clone 保留原少量已跟踪参考资料；完整 MAX/FBX、纹理和预览在模型 ZIP 中 |
| `playable/` | 原 1.8.0 EXE/PCK 试玩入口，保留在主 ZIP 中 |
| `history/ColonyCharter.bundle`、`history/lfs_objects/` | 离线历史恢复材料；正常 GitHub clone 使用仓库历史及 LFS 下载 |
| 顶层 `START_HERE.*`、`MODEL_INTEGRATION.*`、清单 | 本文档目录保存原件；包内路径仍按合并解压根解释 |
| 顶层 `MODEL_GALLERY.html` | 在解压后的合并包内浏览，依赖随包预览，未复制空图库到源码仓库 |

完整交接包可在仓库 Release 中下载。正常 clone 无须再次克隆 bundle；补入工具和模板后按仓库根 README 开发即可。离线 bundle 恢复流程用于没有 GitHub clone 的场景。

## 清单和校验脚本的适用范围

- `MANIFEST_MAIN.json`、`MANIFEST_ART.json` 描述原 ZIP 的内容；它们不是本 Git 仓库的文件清单。
- `SOURCE_RECEIPTS_MAIN.json`、`SOURCE_RECEIPTS_ART.json` 保存原始来源路径和哈希，属于当日来源记录。
- `VERIFY_PACKAGE.py` 应在两 ZIP 合并后的顶层运行：`python VERIFY_PACKAGE.py --require-art`。本目录副本用于审阅脚本；在 clone 文档目录运行会因缺少包内文件而失败。
- 原始 `START_HERE.html` 与 `MODEL_INTEGRATION.html` 保留随包版本；HTML 中预览、源码和报告的相对链接在解压布局下使用。
- `交接包校验结果.json` 保存当日最终交付校验结果；发布准备的来源对比与 LFS 检查属于另一轮静态检查。

## 需要保留的状态

当前游戏仍是 1.8.0，20 项高模尚未接入游戏。12 项旧资产属于原正式白名单，8 项续建资产为候选。`CC_ARCOLOGY_HP_v002` 材质/经营视图检查保留 `NOT_RUN`，100px 预览缺失。默认全套中的七个旧 helper 仍有原 D 盘输出路径，不能把选定四套测试结果扩展为全套迁机通过。

原根 README 另存于 [HISTORICAL_README_1.8.md](../../HISTORICAL_README_1.8.md)。本仓库当前操作步骤以 [根 README](../../../README.md) 为入口。
