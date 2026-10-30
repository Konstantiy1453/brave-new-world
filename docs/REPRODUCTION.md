# 复现与交付包构建说明

本文依据当前 `README.md`、`tools/build.ps1`、`game/tests/sim_tests.gd`、`game/tests/ui_contract.gd`、世界测试及现有报告编写。它提供复跑入口，不把命令说明视为本次已经重新执行全部验收。最终执行结果和限制以 `docs/VALIDATION.md`、相应原始日志为准。

## 固定工具链与目录

本机工程根为 `D:\勇敢新世界`，源工程为 `D:\勇敢新世界\game`。Godot 标准版固定为 **4.5.1.stable.official.f62fdbde1**，Compatibility/OpenGL；不用 .NET。世界生成器为 **CC-GEO-1.5**（完整旧档兼容1.4）。生产界面使用工程内 `game/assets/fonts/main_medium.ttf`，字体许可为同目录 OFL。

以下 PowerShell 命令使用任务专属变量，不修改系统 HOME/CODEX_HOME：

```powershell
$projectRoot = 'D:\勇敢新世界'
$engineExe = Join-Path $projectRoot 'tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe'
$gameRoot = Join-Path $projectRoot 'game'
& $engineExe --headless --version
& $engineExe --headless --path $gameRoot --editor --import --quit
```

导入应先于首次 UI/贴图加载。首次解压源码没有 `.godot` 缓存，Godot 会重新生成。源码包不携带引擎和 1.35 GB 导出模板下载包；另一台机器需从 [Godot 4.5.1 官方归档](https://godotengine.org/download/archive/4.5.1-stable/) 安装同版本标准版，将 `_console.exe` 放到上述相对目录，或者自行修改命令中的 `$engineExe`。匹配模板应位于当前用户 `%APPDATA%\Godot\export_templates\4.5.1.stable\`，包括 Windows x64 release/debug 和 `version.txt`。原下载文件、官方 SHA512 比对、准确来源在 `docs/ENVIRONMENT.md` 和 `docs/evidence/toolchain_hashes.json`。

## 三个主要逻辑验证入口

每条命令结束后检查 `$LASTEXITCODE` 和完整输出；Godot 某些脚本错误可能伴随进程返回 0，因此同时检查 `SCRIPT ERROR`、`FAIL`、汇总行。不要把导入成功代替这些测试。

| 入口 | 命令（已定义上面的变量） | 覆盖与边界 |
|---|---|---|
| 模拟闭环 | `& $engineExe --headless --path $gameRoot --script res://tests/sim_tests.gd` | 三种优势、真实 act 成功路径、守恒、生产与物流限制、完整存读、继续结算、有限矿藏和失败宽限。输出 `SIM_TEST_RESULT checks=... failures=0` 才是当前测试通过；`SIM_REPORT.md` 记载的本次结果为 95 项通过。 |
| 世界生成/寻路 | `& $engineExe --headless --path $gameRoot --script res://world/self_test.gd` | 七个固定种子重复生成一致、陆地候选、矿区与河谷连接、路线不穿海、孤岛不可达、尺寸改变实际距离。输出 `WORLD_SELF_TEST: PASS []`，写 `docs/world_self_test.json`。不代表穷举全种子。 |
| UI 固定步进契约 | `& $engineExe --headless --path $gameRoot --script res://tests/ui_contract.gd` | 实例化实际主场景；暂停不推进、1×/4×相同模拟时长状态精确相等、九类管理页面可以创建。输出末行 PASS。不是人工点击、视觉排版或所有速度档的完整覆盖。 |

补充地图支持测试：

```powershell
& $engineExe --headless --path $gameRoot --script res://world/support_test.gd
```

此项检查初始 80/40 人住房模型、地区镜头平移及边界、行星忽略地区平移、建设倒计时不重复重建聚落、地区视图即时路线刷新。输出 `WORLD_SUPPORT_TEST: PASS []`。

**测试会写文件。** `sim_tests.gd` 会重建 `game/data/acceptance_midgame.json` 与 `acceptance_success.json`，并在 Godot 用户数据目录写测试档；已有档可能保留 `.bak`。世界自测写 `docs/world_self_test.json`。若要保留交付物原始哈希，请在解压后的工作副本中运行，保留原 ZIP 和包内 `PACKAGE_MANIFEST.json`。

## 推荐种子 260129 的正式 act 成功路径

权威实现位于 `game/tests/sim_tests.gd::_scenario(advantage)`。这里的完整成功回放使用 `new_game(260129, advantage, 1)`；测试里较早的 `make()` 冒烟/边界部分使用的是 **20261029**，两者不要混写。

所有普通成功路径通过正式 `act()` 下达指令，没有直接增加现金、库存或人口。`act` 成功返回空字符串，非空是中文失败原因。每次 `tick()` 恰好推进一个模拟日。

**日期约定必须注意：** `_scenario` 在 `for day in range(1,181)` 中先处理当日动作，再调用 `tick()`。因此循环 `day=16` 的企业指令发生时，`state.day` 尚为 **15**。UI 复现时按“动作前游戏日期”暂停执行，避免一天偏差。

| 动作前 `state.day` | 测试循环标号 | 正式调用，按列内顺序执行 |
|---:|---:|---|
| 0 | 循环前 | `new_game(260129,"capital",1)`；`act("settle",{"region":0})`；`act("build",{"region":0,"kind":"mine_ore"})`；`act("build",{"region":0,"kind":"mine_copper"})`。首府的电力、供水、贸易港和 80 人基础住房由首次登陆规则提供，无需额外手工注入。 |
| 15 | 16 | `act("enterprise",{"region":0})`，随后当日 tick。 |
| 23 | 24 | `act("settle",{"region":1})`，再 `act("connect",{"a":0,"b":1,"mountain":false})`，随后 tick。前哨队伍与补给有在途时间，常设普通道路另计行程。 |
| 27 | 28 | `act("build",{"region":1,"kind":"farm"})`，随后 tick。 |
| 44 | 45 | `act("build",{"region":0,"kind":"processor"})`，随后 tick。这是履约后继续经营的一部分，不能写成首次履约前的必需步骤。 |
| 59 | 60 | 资本/工人路线：`act("build",{"region":0,"kind":"lab"})`；`act("research",{"tech":"survey"})`，随后 tick。 |

工人路线仅将 advantage 改为 `"workers"`。科研路线改为 `"science"`，并在循环开始前、初始双矿之后追加 `act("build",{"region":0,"kind":"lab"})`、`act("research",{"tech":"survey","priority":2.0})`；不重复执行第 59 日的研究所步骤。

每个循环在 tick 之前检查 `state.event`：若有事件，先尝试 `state.event.choices[0].id`，失败才尝试第二项。当前三个事件的优先选择分别是缺水预警 `protect`、铜价窗口 `accept`、人才 `invite`；第二选择分别为 `ration`、`decline`、`decline`。事件的实际效果和可用条件由 config 和 state 决定，不能绕过 act 直接改事件状态。

每个 tick 后调用 audit，原测试要求每日无违规。当前 `SIM_REPORT.md` 记录的首次履约日为资本 38、工人 36、科研 38；三条均继续运行到第 180 日并产生总督阶段公司税。这是自动回放结果，不是三条人工完整试玩，也没有据此证明目标体验时长 20–40 分钟。任何未来数值修改均应重新执行测试，以当次输出为准。

地图中 0=铁岬盆地、1=青溪河谷；推荐中型普通道路 **1124 km / 9 日 / 1570**，跨山道路 **635 km / 3 日 / 1638**。上述回放选择普通路线。

## 存档来源与用途

| 源文件 | 本次读取到的元数据 | 来源与用途 |
|---|---|---|
| `game/data/acceptance_midgame.json` | seed260129、CC-GEO-1.5、capital、day29、active | `_scenario("capital")` 在第29次 tick 后通过 `save_game` 生成。两个据点、陆路、在途货物、民营企业及施工中河谷农场。完整正式 act 路径，非人工 UI 存档。 |
| `game/data/acceptance_success.json` | seed260129、CC-GEO-1.5、capital、day38、success | 同一自动资本回放首次达到 success 后保存。用于验证履约后继续，不是人工从头通关证据。 |
| `saves/ui_day50.json` | seed260129、CC-GEO-1.4、capital、day50、active | 集成实操保留档。其生成流程和跨进程读取证据由最终 VALIDATION 记录；本说明只读取了 JSON 元数据，没有用读取元数据冒充成功加载。 |

当前两个 acceptance 档封装含 `binary/binary_checksum/checksum/payload/version`；ui_day50 为较早的 `checksum/payload/version` 封装。保留它们的真实来源，不把旧格式重新描述成精确 Variant 快照。正常 UI 手动/自动档位于 Godot `user://`，以游戏设置页显示的本机路径为准。

打包脚本会把当前 `game/data/acceptance_*.json` 的规范副本复制到 **临时 staging 的 `saves/`**，与已有 ui_day50 一同进入两个交付 ZIP；不会修改工作区原始存档。游戏主菜单中的验收读取入口使用资源包内 `res://data/acceptance_midgame.json`。

## 构建与真实运行入口

构建只做导入、Windows release 导出和复制许可；它不自动证明可玩性。

```powershell
& (Join-Path $projectRoot 'tools\build.ps1')
# 等价的主要导出步骤：
& $engineExe --headless --path $gameRoot --export-release 'Windows Desktop' (Join-Path $projectRoot 'build\ColonyCharter.exe')
```

匹配预设在 `game/export_presets.cfg`；输出是独立 `ColonyCharter.exe` 与 `ColonyCharter.pck`，PCK 未嵌入 EXE。必须一起分发，并带 `GODOT_LICENSE.txt`、`GODOT_COPYRIGHT.txt`、`OFL.txt`。

```powershell
# 源工程的真实图形运行：
& $engineExe --path $gameRoot --rendering-method gl_compatibility --resolution 1600x900
# 发行程序的真实启动，不要求编辑器：
& (Join-Path $projectRoot 'build\ColonyCharter.exe')
```

自动导出程序截图入口是显式开发参数，普通双击不启用。使用新目录保留既有证据：

```powershell
$captureOutput = Join-Path $projectRoot ('evidence\screenshots_replay_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
& (Join-Path $projectRoot 'build\ColonyCharter.exe') -- --load=res://data/acceptance_midgame.json ('--qa-capture=' + $captureOutput)
```

该工具逐档生成实际原生画面并记录性能样本，属于自动渲染 harness，不是人工游玩。`world/render_test.gd` 则使用人工建筑状态进行独立场景渲染，两者不能混为同一证据。详情见 VISUAL_QA/WORLD_REPORT/VALIDATION。

## 交付 ZIP 内容和排除规则

`tools/package.ps1` 在 `delivery/.staging-<随机ID>/` 分别准备源码与 Windows 目录，然后从目录内容生成 ZIP，避免把临时目录名包进根路径。执行入口：

```powershell
& (Join-Path $projectRoot 'tools\package.ps1')
```

此脚本要求最终 `docs/VALIDATION.md` 已存在，以及当前 EXE/PCK、许可、规范验收档完整；如果缺失会立即报错。**历史记录：脚本编写时曾做 PowerShell 语法检查，结果为 `PACKAGE_SCRIPT_PARSE_OK; SCRIPT_NOT_EXECUTED`。该行仅描述编写阶段，不是当前包状态。** 当前包结果独立记录在 `delivery/PACKAGE_HASHES.json`；解压原件启动及最终外部复核见 `delivery/FINAL_VERIFICATION.json`，EXE/PCK应与release_identity一致。打包核对只判定字节完整性，不代替运行或产品验收。

| 文件 | 内容 |
|---|---|
| `delivery/ColonyCharter_Source.zip` | `game/` 全部源码、真实资产、配置、验收档、正式 tests 及 world 自测；`docs/` 全部文档和其中的证据；`README.md`、`DEMO_AGENT_PROMPT.txt`；`tools/` 顶层小型 ps1/py/gd/md/json/txt（小于2 MiB）；`saves/`；各轮截图、实际UI截图与大小受限的集成日志/记录；原始失败证据保留并区分来源。 |
| `delivery/ColonyCharter_Windows.zip` | `build/` 当前可执行目录及许可；`saves/`；README；VALIDATION、REPRODUCTION、ASSETS、ENVIRONMENT、SIM_REPORT、WORLD_REPORT、VISUAL_QA、VISUAL_RELEASE_QA、REVIEW、REQUIREMENT_MATRIX 等关键报告；小型文本/JSON审查证据、各轮截图、实际UI截图和集成日志/记录。保留 `build/` 层级使 README 的启动路径正确。 |

两个包都排除任意层 `.git`、`.godot`、`__pycache__` 和 `.bak/.tmp/.pyc`。tools 下引擎目录、下载 ZIP、TPZ、大型二进制不进入源码包；Windows 包不需要制作工具。项目资源的 `.uid` 和 `.import` 配置保留，`.godot` 编译缓存可重建。历史审查小脚本有部分固定本机绝对路径；跨机器首先使用上面三个正式相对资源入口，若使用历史探针应先检查其中的路径。

每个 ZIP 根含 `PACKAGE_MANIFEST.json`，列出除清单本身以外的文件路径、字节数、SHA256。脚本在发布前逐条打开 ZIP、检查必需路径并比较每个非清单条目的 SHA256；随后写 `delivery/PACKAGE_HASHES.json`。已有同名 ZIP 会改名保留为 `.previous-时间-随机后缀`，不会删除原工程、构建或存档。成功后只清理经绝对路径检查的本次 staging；失败保留 staging 便于定位。

包内字节核对成功只可称 **PACKAGING_VERIFIED**，不能称可玩性、所有性能场景或完整需求验收通过。应继续保留最终 VALIDATION 中的 PARTIAL/NOT_RUN 范围。

交付收尾新增的存档容错回归入口：

```powershell
& $engineExe --headless --path $gameRoot --script res://../tools/review_save_nested_regressions.gd
```

该探针21项，包括18类内部类型/数值损坏，以及当前中期、旧UI50日档、待处理事件档的兼容验证；完整经营95项另行执行。旧失败证据在 docs/evidence/save_nested_type_review_before_fix.*。

新地理复现入口：`res://world/diversity_report.gd` 输出固定7种子的统计与重复世界SHA256；`res://world/coast_review.gd` 读取 evidence/v1_4/acceptance_midgame.json 检查旧版10368格采样精确一致。水系说明见HYDROLOGY_REPORT.md；新局气候与地理参数及边界见SEED_DIVERSITY.md。
