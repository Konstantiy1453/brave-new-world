# 模型接入交接说明

本包收录 **20 项建筑与组件资产：12 项旧包正式白名单资产、8 项续建候选资产**。打开 [MODEL_GALLERY.html](MODEL_GALLERY.html) 浏览包内实图；程序读取 [HANDOFF_ASSET_INDEX.json](HANDOFF_ASSET_INDEX.json) 获取相对路径、单位、尺寸、面数、游戏建筑 ID 原注释、位图依赖和历史检查状态。

## 从哪里开始

1. 在 `project` 目录继续代码与玩法工作；模型储备位于 `project/art_reserve/` 的两个原包目录。以本交接索引中的 20 项为实际包含范围。
2. 选一个小建筑作为首次接入试件，优先从旧包 `CC_HOUSING_HP_v002` 或 `CC_COMMAND_HP_v001` 开始。对应 MAX 可继续编辑，FBX 用于目标引擎导入。
3. 在游戏的资源目录建立加工后的运行时资产，记录对应源 `asset_id`。先检查米制比例、轴向、入口朝向、落地基点、包围盒和材质，再接入建筑 ID、建造预览、放置、存档与升级逻辑。
4. 根据目标相机与同屏数量制作 LOD、合并/实例策略和碰撞体；在游戏内验证显示、选取、放置、拆除、保存读取与性能。源 FBX 均为高模交换文件。

## 当前资产与验收状态

| 资产 | ID | 交接分类 | 原记录视觉状态 |
|---|---|---|---|
| 工业设施 | `CC_INDUSTRY_HP_v005` | 旧包正式白名单 | LEGACY_ALLOWLIST_ACTUAL_WITH_REPORTED_LIMITATIONS |
| 指挥设施 | `CC_COMMAND_HP_v001` | 旧包正式白名单 | LEGACY_ALLOWLIST_ACTUAL_WITH_REPORTED_LIMITATIONS |
| 居住建筑 | `CC_HOUSING_HP_v002` | 旧包正式白名单 | LEGACY_ALLOWLIST_ACTUAL_WITH_REPORTED_LIMITATIONS |
| 能源设施 | `CC_POWER_HP_v002` | 旧包正式白名单 | LEGACY_ALLOWLIST_ACTUAL_WITH_REPORTED_LIMITATIONS |
| 净水设施 | `CC_WATER_HP_v003` | 旧包正式白名单 | LEGACY_ALLOWLIST_ACTUAL_WITH_REPORTED_LIMITATIONS |
| 矿业设施 | `CC_MINING_HP_v002` | 旧包正式白名单 | LEGACY_ALLOWLIST_ACTUAL_WITH_REPORTED_LIMITATIONS |
| 温室 | `CC_GREENHOUSE_HP_v003` | 旧包正式白名单 | LEGACY_ALLOWLIST_ACTUAL_WITH_REPORTED_LIMITATIONS |
| 科研设施 | `CC_RESEARCH_HP_v002` | 旧包正式白名单 | LEGACY_ALLOWLIST_ACTUAL_WITH_REPORTED_LIMITATIONS |
| 物流设施 | `CC_LOGISTICS_HP_v002` | 旧包正式白名单 | LEGACY_ALLOWLIST_ACTUAL_WITH_REPORTED_LIMITATIONS |
| 公共建筑 | `CC_CIVIC_HP_v001` | 旧包正式白名单 | LEGACY_ALLOWLIST_ACTUAL_WITH_REPORTED_LIMITATIONS |
| 基础设施源库 | `CC_INFRASTRUCTURE_HP_v002` | 旧包正式白名单 | LEGACY_ALLOWLIST_ACTUAL_WITH_REPORTED_LIMITATIONS |
| 环境源库 | `CC_ENVIRONMENT_HP_v002` | 旧包正式白名单 | LEGACY_ALLOWLIST_ACTUAL_WITH_REPORTED_LIMITATIONS |
| 公寓 | `CC_APARTMENT_HP_v002` | 续建候选 | PASS |
| 生态综合体 | `CC_ARCOLOGY_HP_v002` | 续建候选 | NOT_RUN |
| 首府大厅 | `CC_CAPITAL_HALL_HP_v002` | 续建候选 | PASS |
| 民用货船 | `CC_CIVIL_CARGO_SHIP_HP_v001` | 续建候选 | PASS |
| 施工组件 | `CC_CONSTRUCTION_KIT_HP_v001` | 续建候选 | PASS |
| 人员宿舍 | `CC_CREW_QUARTERS_HP_v001` | 续建候选 | PASS |
| 港口码头组件 | `CC_HARBOR_QUAY_KIT_HP_v002` | 续建候选 | PASS |
| 升降港 | `CC_LIFT_PORT_HP_v001` | 续建候选 | PASS |

续建目录没有正式 `DELIVERY_TARGET_IDS.json`；其 `CURRENT_SELECTION.json` 是 68 项规划的候选选择。上表 8 项已有 MAX、FBX 与保存的重开/重导入报告，继续按候选处理。`CC_ARCOLOGY_HP_v002` 的材质/经营视图检查为 **NOT_RUN**，`business_100px.png` 为 **NATIVE_PROJECTION_READY_IMAGE_NOT_RUN** 且文件缺失；其他 7 项有原视觉 PASS 记录。画廊展示已有图，不将展示本身算作视觉验收。

`CC_SCRUBBER_HP_v003` 原进度为 **FINALIZING**，仅有灰模阶段 MAX，本次未选入交接资产。余下规划项见续建 `00_brief/ASSET_TASKS.json` 和 `MODELING_INSTRUCTIONS.md`。

## 文件、证据与本轮检查

原 MAX、FBX、metadata、预览与检查报告逐字节复制；[SOURCE_RECEIPTS_ART.json](SOURCE_RECEIPTS_ART.json) 记录源路径、目标相对路径、大小、复制前后与批次结束时 SHA-256。原目录的文件清单与大小/修改时间也在复制前后比较，以检测建模进程活动。本轮执行本地文件与依赖检查；Max 重开、渲染、FBX 导入和游戏接入均为 **NOT_RUN**。

旧 metadata 的部分 `checks` 保留制作阶段的 `not yet run`；实际旧包保存的执行结果在各 `*_reopen.json`、`*_delivery004_library_exchange.json` 和 `*_delivery004_library_fbx_import.json`。后续请保留这些原始状态。部分旧建筑的 FBX 精确三角数比较为 false，源报告以独立几何等价检查记录 `equivalent_cylinder_caps_verified`；接入索引分别保留两种结果。

原说明文档可能描述完整旧 21 项或续建 68 项，引用的星球、地形、据点、失败试作和历史版本未全部随此子集交付。当前交接的浏览入口是本包新画廊与新索引；原文档供溯源使用。

## 在另一台电脑打开 MAX

源场景按 Autodesk 3ds Max 2024 制作，旧包说明记录 MAXtoA 5.6.0.100 / Arnold 7.2.0.0。打开前先保存自己的现有场景。源 metadata 与场景中的位图路径保留原电脑的绝对路径。

每个包内保留相同的 10 张表面贴图，位于各自 `07_materials_textures/surfaces/`，以及 `11_max_scripts/relink_textures.py`。打开该包的目标 MAX 后，在 Max Python 中执行位于**该包新位置**的重链接脚本。脚本按文件名重设位图路径、输出未找到项，不自动保存；确认结果后另存工作版本。续建包的重链接脚本从旧包原脚本原样复用，来源见逐文件收据。

两组贴图同名文件的 SHA-256 一致，保留两份用于各包独立重链接。10 张为混凝土、金属、涂装、岩石、土壤各自的 basecolor 与 roughness。完整星球纹理目录未打入。

## 单位、轴向和材质约定

建筑及组件以米为单位，Z 向上；建筑入口通常朝 -Y，接口、门和基点以单资产 metadata 为准。新 metadata 含 `pivot`、`doors`、`interfaces`、`protected_parts` 与语义分组，可用于调整目标引擎的锚点与碰撞设计。环境与基础设施文件是源库陈列，应拆分或实例化合适构件再接入。

FBX 的 `EmbedTextures=False`，外部位图需在引擎中重建绑定。basecolor 使用 sRGB，roughness 使用线性/Raw；金属度、玻璃透射、水面反射等还需依据 Max 材质参数重建。Physical/程序材质与 Arnold 效果以 MAX 为编辑参考。UV1 具备覆盖，部分为投影 UV；唯一无重叠烘焙图集、游戏轻量 LOD 和碰撞体需在后续接入时制作。

源图像展示的是保存的 Arnold/Max 结果。它们适合识别外形与材质意图；目标引擎效果和性能以实际游戏运行结果验收。
