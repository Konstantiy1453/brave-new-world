# 勇敢新世界 · Colony Charter

单颗行星殖民经营游戏，当前可玩原型 **1.8.0**，使用 Godot **4.5.1** / GDScript / GL Compatibility，面向 Windows x64。项目按离线单机、免费、无内购的方向开发。

本仓库提供可继续编辑的源码、玩法配置、测试与指定历史输入。完整离线工具、可运行版和 20 项模型资产通过 **[Releases](https://github.com/Konstantiy1453/brave-new-world/releases)** 提供。游戏基线为 `af752d255c49bff477a5e884237d99f887cfad0c`，交接资料日期为 **2026-11-06**。

## 从 Git clone 开始开发

安装 Git、Git LFS，以及用于部分打包/校验工具的 Python 3。在仓库页面复制 Clone URL，然后运行：

```powershell
git lfs install
git clone https://github.com/Konstantiy1453/brave-new-world.git ColonyCharter
cd ColonyCharter
git lfs pull
git lfs fsck
```

字体、PNG 和 `acceptance_*.json` 使用 LFS。正常 clone 后，它们应是实际资源文件。完整恢复需要 Git 内容与 LFS 实体都下载成功。

从 [Release Assets](https://github.com/Konstantiy1453/brave-new-world/releases) 下载 `01_Code_Gameplay_1.8.0_20261106.zip` 并解压。将包内以下目录复制到 clone 根目录的对应位置：

| 主包解压目录内的来源 | clone 根目录内的目标 | 用途 |
|---|---|---|
| `project/tools/godot-4.5.1/` | `tools/godot-4.5.1/` | Godot 编辑器和控制台启动器 |
| `project/build/godot_home/` | `build/godot_home/` | Windows x64 导出模板 |

运行 `tools/godot-4.5.1/Godot_v4.5.1-stable_win64.exe`，导入 **`game/project.godot`**，等待资源导入完成后按 **F5** 运行。也可在仓库根目录启动编辑器：

```powershell
& .\tools\godot-4.5.1\Godot_v4.5.1-stable_win64.exe --editor --path .\game
```

**clone 的根目录就是工程仓库根；ZIP 中的工程则位于 `project/`。** 只按上表补入工具和模板，避免用整个 `project/` 覆盖正在开发的 clone。完整目录映射见 [交接资料入口](docs/handoff/20261106/README.md)。

## 测试与 Windows 构建

在 clone 根目录的新 PowerShell 窗口执行以下选定回归：

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Only v17_bugs,v17_saves,v18_systems,ui_contract
```

测试脚本会在本仓库 `evidence/v17/` 下创建隔离用户目录和日志。四套测试之外，默认全套中七个旧审查辅助脚本仍写死原 D 盘输出路径；跨目录工作时先修复对应辅助脚本，再安排默认全套。详细范围见 [原交接说明](docs/handoff/20261106/START_HERE.md)。

构建前确认上表的模板目录已经复制完整，然后另开一个 PowerShell 窗口运行：

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_v17.ps1
```

输出为 `build/v17/ColonyCharter.exe` 与 `ColonyCharter.pck`，两者运行时保持同目录。脚本名保留 v17，实际构建当前 **1.8.0** 工程。模板位于 `build/godot_home/Godot/export_templates/4.5.1.stable/`。从 Python 启动 Windows PowerShell 5.1 时，模块环境要求见交接验证记录中的首次失败与 r2 处理。

## 源码与接手入口

| 路径 | 内容 |
|---|---|
| `game/simulation/` | 模拟规则、经营系统、保存与迁移 |
| `game/ui/`、`game/world/` | 页面、地图和当前程序化建筑 |
| `game/data/v17/` | 当前玩法配置与验收存档 |
| `game/tests/`、`tools/` | 测试、导出与打包脚本 |
| `docs/v17/` | 当前规则、设计、进度和验收记录 |
| `docs/reviews/2026-11-02-content-readiness-audit.md` | 内容与接手优先级审查 |
| `docs/superpowers/plans/` | 后续 v18/v19 玩法和模型接入计划 |
| `docs/handoff/20261106/` | 原交接说明、资产状态、清单与来源证据 |

开发测试还使用仓库中的 `saves/ui_day50.json`、`evidence/v16/world_seed_red.json`、`evidence/v1_4/acceptance_midgame.json`、`versions/v1_5_before_v1_6_20261030_125059/game/world/map_view.gd`。它们是明确纳入的历史输入，需保留路径。其他运行输出继续由 `.gitignore` 排除。

原根目录说明保存在 [HISTORICAL_README_1.8.md](docs/HISTORICAL_README_1.8.md)，其中旧版本路径按历史语境阅读。后续 v18/v19 文档是开发计划，当前运行版本仍为 1.8.0。

## 下载完整交接包与模型

| Release 附件 | 内容 |
|---|---|
| `01_Code_Gameplay_1.8.0_20261106.zip` | 完整开发快照、Godot、Windows 模板、可玩发行版、证据、Git bundle 与离线 LFS 对象 |
| `02_Model_Integration_20Assets_20261106.zip` | 20 项 MAX/FBX 资产、实际依赖贴图、预览及检查记录 |

两 ZIP 解压到同一个父目录，合并成 `BraveNewWorld_Handoff_20261106/`，打开其中的 `START_HERE.html`。试玩使用 `playable/ColonyCharter.exe`；模型浏览使用 `MODEL_GALLERY.html`。在合并后的顶层运行 `python VERIFY_PACKAGE.py --require-art` 复核两份包。

模型状态为 **12 项原正式白名单资产 + 8 项续建候选**。20 项高模尚未接入当前游戏。`CC_ARCOLOGY_HP_v002` 的材质/经营视图检查保持 `NOT_RUN`，100px 预览缺失；状态见 [模型接入说明](docs/handoff/20261106/MODEL_INTEGRATION.md) 和 [资产索引](docs/handoff/20261106/HANDOFF_ASSET_INDEX.json)。制作运行资产、游戏接入、视觉和性能验收是后续工作。

GitHub 自动生成的 Source code ZIP/tar.gz 覆盖源码快照；完整离线工具和模型使用上述两个具名附件。

## 验证记录与文件身份

[2026-11-06 验证记录](docs/handoff/20261106/VALIDATION_20261106.md) 保存了同机换目录导入、三套合计 **238 项检查**、另列 UI 断言、Windows 导出、headless 启动以及 Git/LFS 离线恢复的执行结果。新导出 EXE/PCK 当时与原 1.8.0 发行版哈希一致。本次源码发布准备做来源哈希、Git 差异和 LFS 完整性检查，未重新运行这些游戏测试。

朋友电脑运行、完整真人试玩、窗口图形帧时间与新模型接入效果仍待相应验收。历史报告与本次静态发布检查分别保留其证据日期和范围。

```text
c7d6f93d5346bcd1d178ce8d98daea07ed5beef891b91a28be7971010960ce03  01_Code_Gameplay_1.8.0_20261106.zip
894c1b547c4db2e5f9ab47faa8e460e9b4cc96ff9a0a67b98d95df60a42da1fd  02_Model_Integration_20Assets_20261106.zip
```

第三方引擎许可见 [GODOT_LICENSE.txt](docs/GODOT_LICENSE.txt) 与 [GODOT_COPYRIGHT.txt](docs/GODOT_COPYRIGHT.txt)，字体许可见 [OFL.txt](game/assets/fonts/OFL.txt)，素材说明见 [ASSETS.md](docs/ASSETS.md)。项目源码及原创资产的后续授权由项目所有者决定。
