# 勇敢新世界／殖民契约 1.8：三维模型补建指令与清单

核对日期：2026-11-01。依据当前源工程 1.8.0、git HEAD af752d2，以及 max_highpoly_20261031 现有资产包。

本文件交给建模 Agent 执行。继续使用真实 3ds Max 制作高模母版，新增资产独立保存，不修改游戏代码、不覆盖原高模包、不自动接入游戏。

## 1. 结论与证据范围

- 当前 economy.json 有 56 个公共可建建筑 ID；相对 v1.7.1 的 17 项，新增 39 项。
- 41 项含 model 字段，其中 habitat 是自映射；真正借用其他外观的是 40 项，包括新增 39 项和旧水培温室。
- 当前地区显示仍调用 building_models.gd 的程序几何。存在绘制分支不代表存在独立高模，也不代表该分支经过配置映射后实际使用。
- 旧高模包正式白名单包含 21 个主体场景：1 星球、6 地形、10 类建筑、基础设施和环境库各 1、2 套据点。该包独立保存，尚未接入当前游戏。
- 本次查看了代码、资产入口、文件清单和部分保存画面；未运行游戏、未重新打开 Max、未重验旧包全部几何和渲染。旧包重开/导出结果属于已有报告证据。

56 种建筑需要完整资产对应关系，但不等于从零制作 56 套。按“复用母版、改型组件、专用新建”组织任务。

另有 2026-11-01-v19-money-and-models-instructions.md 集成草案。当前仍是 1.8.0，草案中的转换器、运行时约 4500/9000 面预算及拟新增巨型工程不能写成已实现。此次不制作尚未进入当前目录的新增设施，不把运行时预算当作高模面数上限。

## 2. 文件与边界

旧包只读：

    D:\勇敢新世界\art_reserve\max_highpoly_20261031

新资产统一输出到：

    D:\勇敢新世界\art_reserve\max_highpoly_v18_supplement_20261101

新目录由建模 Agent 开始制作时创建。需要利用旧模型时另存副本，保留来源 ID 和哈希；不得覆盖旧场景、FBX、白名单和检查记录。

先读取本文件、同目录 2026-11-01-v18-model-coverage.json，以及旧包：

- 00_brief/DELIVERY_TARGET_IDS.json
- OPEN_AND_REVIEW.md、QA_REPORT.md、ASSET_GALLERY.html
- 相关 10_validation/<ID>.json；优先小文件，不必解析约 92 MB 的总清单。

再核对当前 game/data/v17/economy.json 中目标 ID 的用途和限制。所有建模、地形构件、散布和组合在真实 3ds Max 中完成，可以使用 Max 内 MAXScript/pymxs。交付高模源、分件、UV、材质和高模 FBX。游戏转换、减面、着色器、地图接入、图标与资源映射属于后续集成任务。

## 3. 已有资产：优先复用

| 正式源资产 ID | 合理用途 |
|---|---|
| CC_COMMAND_HP_v001 | 登陆指挥、行政建筑构件 |
| CC_HOUSING_HP_v002 | 模块住区及宿舍/公寓的结构与立面模块 |
| CC_POWER_HP_v002 | 光伏与储能，不直接充当风电、裂变或聚变 |
| CC_WATER_HP_v003 | 净水泵站、储水与管路 |
| CC_MINING_HP_v002 | 轻型井架和输送构件 |
| CC_GREENHOUSE_HP_v003 | 温室与水培改型基础 |
| CC_INDUSTRY_HP_v005 | 加工厂外壳、装卸与工业配件 |
| CC_RESEARCH_HP_v002 | 教学研究所、研究院/校园构件 |
| CC_LOGISTICS_HP_v002 | 仓库、龙门吊、货柜与物流中心；起降坪/码头需另核对补齐 |
| CC_CIVIC_HP_v001 | 小型民营服务、商业和公共建筑，不直接作为议会成品 |
| CC_INFRASTRUCTURE_HP_v002 | 道路、平台、管件、栏杆；检查具体组件后补缺 |
| CC_ENVIRONMENT_HP_v002 | 既有树木、岩石和环境源件 |

旧两套据点是审阅和组装参考，不应作为所有新版居住/边疆据点的固定城市。

## 4. 首批 P0：主要进度与用途要能看出来

优先级是本次美术工作建议，不改变游戏解锁顺序。

| 资产组 | 对应 ID／机制 | 必须具备的轮廓和内容 |
|---|---|---|
| 行星议会大厦 | capital_hall | 议事主体、行政翼楼、正式入口和公共前场，形成首府地标，区别于大学和普通服务楼 |
| 轨道升降港 | lift_port | 锚定基座、垂直运输核心、转运层和独立系缆接口；不要求把完整轨道长度缆索塞进一个场景 |
| 海运岸端套件与货船 | port 的海运端点附属；没有独立 harbour ID | 码头、岸壁、装卸平台、泊位、堆场及一款民用货船；保留轨道货运站原本用途 |
| 居住发展套件 | apartment、arcology | 公寓有多层体量；穹顶城有内部建筑层次、绿地与支撑，不是住区等比放大 |
| 边疆工棚营地 | crew_quarters | 简易生活单元、集中服务与作业场地，区别于长期居住区 |
| 污染净化塔 | scrubber | 大型进气/过滤/吸附、检修平台与排气路径，区别于普通加工厂 |
| 通用施工组件 | 当前建造中状态 | 小/中/大围挡、脚手架、基础施工段、材料堆和吊装设备 |

海港/货船是“海运玩法已存在，独立三维显示入口尚未接入”的备用资产，不新增舰队、造船或运输玩法。

施工目前是完整建筑外套架子。不要求 56 个建筑各做三套全新施工模型；新地标保留基础/骨架/表皮分组，用通用组件做示范。多阶段显示由后续接入处理。

## 5. 第二批 P1：真正不同的功能要有不同形体

| 资产组 | ID | 制作重点 |
|---|---|---|
| 行星大学 | university | 教学、研究、图书/公共核心与步行院落，区别于议会 |
| 气候调节站 | climate_regulator | 大型气体处理/换热/调节阵列，区别于净化塔；地图作用圈不属于建模 |
| 专用能源 | wind_farm、geothermal、fission、fusion | 分别体现风机、井口与热交换、反应堆围护与冷却、聚变核心厂房 |
| 海水淡化 | desalination | 海水取水、处理模块、清水输出与沿海连接 |
| 重型露天开采 | mine_ore_heavy、mine_copper_heavy | 分层采场、大型装载/破碎、输送和矿料堆，共用机械并区分附件 |
| 重型晶体井 | mine_crystal_heavy | 深井/提升与晶体处理，保持竖井特征 |
| 自动钻场 | mine_ore_auto、mine_copper_auto、mine_crystal_auto | 钻机阵列、封闭控制单元、自动搬运；共享母版但有可辨改型 |
| 大田、牧场、垂直农场 | field_station、ranch、vertical_farm | 田块/农机棚/粮仓，围栏/畜舍/饲料，高层种植设施，不能全用温室 |
| 近海养殖 | aquafarm | 网箱、浮台、服务栈桥，独立水线基准 |
| 医疗与教育 | clinic、hospital、school | 诊所可改型公共楼；医院有门急诊/住院层次；学校有教学和活动空间 |
| 市政与数据服务 | civic_center、data_center | 行政服务与公共前场；模块机房、冷却与供电设备 |
| 边疆宿舍升级 | frontier_lodge | 从工棚到常驻宿舍的明显改善，保留作业气质 |
| 洁净工业母版 | component_plant | 洁净厂房、设备区和物流分流，供其他精密产业改型 |

配套补件先查旧库，只补缺少的桥跨/桥墩、路口/坡道、封路围挡、矿化露头、封井和废矿整理组件。道路做可拼接模块，不建数千公里固定公路。废矿样件表现状态，不开发动态挖坑或塌陷；隐藏矿床不能因美术摆放提前泄露。

## 6. 第三批 P2：改型完善产业与生活

| 类别 | ID | 方向 |
|---|---|---|
| 深井与集水 | deep_well、atmospheric_water | 管件＋井口/泵房；集水站补冷凝阵列 |
| 回收与新资源 | tailings_plant、sea_copper、crystal_vat | 尾矿处理、海水提取、结晶槽有专用设备；厂房可复用 |
| 食品 | hydroponic_farm、protein_plant、foodworks | 循环水培、反应/发酵、清洁加工/包装/出货各有识别点 |
| 工业 | smelter、machine_works、pharma_plant | 冶炼炉与冷却、机械装配、无菌设备形成差异 |
| 研究提升 | institute | 扩展实验楼、仪器和院落，不只放大 |
| 公共生活 | park、culture_center、commerce、service | 生态绿地、文化活动、商业街区、小型民营服务中心 |
| 升级附件 | progression.json 中实际可升级类型 | 增补模块、设备与扩建翼，不给不存在的升级虚构等级 |

容易遗漏的边界：

- foodworks 当前走通用 fallback，是旧建筑遗留的独立外观缺口。
- hydroponic_farm 有程序水培分支，但配置映射为 farm；高模改型与显示映射是两件事。
- commerce 有程序商业分支，但配置映射为 habitat；新街区应按功能重组 CIVIC。
- service 是实际使用的民营附属建筑，不在 56 项公共目录中，单列映射，可复用 CIVIC。
- 工程队/研究团队是人员名称变化，不因此强加角色、骨骼或人物动画。

## 7. 星球与地形：新版本适配不等于重做固定世界

旧高模基于 CC-GEO-1.6 / seed 260129 / 半径 1000 km。当前新世界为 CC-GEO-2.2，配置半径 3823、6371、8282 km，候选点、地貌与气候也已改变。相同种子不等于相同世界。

- 保留旧整球、三地区和两据点作为艺术样板；不能按旧经纬度和旧地区 0/1/5 套入新版。
- 此轮建筑、海港、道路、环境件不绑定旧地名、固定种子或地形。
- 旧自然源库继续复用；必要时补积雪岩石、寒地灌丛、干旱裸岩、海岸岩石等变体。
- 云、大气、地表色、河流、冰盖需要与程序世界一致，属于后续地图表现接入；不要求再建几颗固定大陆球体。
- 新整体审阅场景标明世界版本、坐标和范围，不宣称适配所有随机星球。
- 当前污染是全星球指标，没有完整地方烟雾/污水扩散三维系统。先做净化塔，不把污染特效与治理车队列为强制资产。

## 8. 制作、检查和交付

延续旧包深蓝灰金属、冷灰面板、少量暖黄工业标识及可靠基础，同时用体量和空间组织区分新用途。医院、学校、大学和议会不能仅是同一楼块换牌。

要求：

1. 真实 3ds Max 高模，主结构、厚度、倒角、设备有几何；不靠简单盒子细分或换色充数。
2. 米制、Z-up，建议入口朝 -Y；轴心为占地中心的地面基准。记录真实尺寸、门/道路/管线接口；海洋件记录水线与岸向。
3. 大型建筑群分件；提供便于展示缩尺的组合，但不能把真实门高和设备比例压坏。
4. 俯视 40—60°、主体约 60—120 像素宽的缩略图仍能辨识，另有高分辨率近景；缩略检查不削减高模标准。
5. 屋顶、结构、玻璃、设备、管线、基础和状态灯分件命名，沿用 roof、wall、glass、tank、foundation、pipe、status_light 等语义便于后续处理。
6. 运营/停用通过独立灯或部件表达；施工使用公共套件与可显隐结构组。
7. 交付 .max、高模 FBX、材质贴图、灰模/材质/细节预览。
8. 实际重开源文件、隔离重导入 FBX，核查单位/尺寸/轴向/UV及图片比例、穿插、落地、轮廓；执行和视觉检查分别记录。旧包报告不能替代新资产检查。

建议目录：

    00_brief/DELIVERY_TARGET_IDS.json
    05_buildings/
    06_showcases/
    07_materials_textures/
    08_exports/highpoly_fbx/
    09_previews/
    10_validation/<ASSET_ID>.json
    11_max_scripts/

每项小 JSON 至少含：ID、game_building_ids、来源/版本、MAX/FBX路径、单位、measured_size、bounds、axis、pivot、doors、geometry.nodes（名称和边界）、接口、预览、哈希和检查状态。港口/船舶等没有独立游戏 ID 的项目写关联机制，不伪造 ID。

提供 ASSET_MAPPING.json，将下方覆盖表的游戏 ID 对应到真实母版、改型与版本。允许共享母版，说明变体的零件及轮廓差异。

按 P0→P1→P2 分批完成并保存。用首府居住与边疆工业/海运两张总览审阅资产组合，不将其当成固定游戏地图。未完成项如实保留；“可以复用”不能写成“改型已完成”。

## 9. 证据入口

| 事实 | 当前文件 |
|---|---|
| 当前版本 | game/project.godot:5、README.md |
| 建筑 ID、功能与类型限制 | game/data/v17/economy.json |
| 别名决定显示模型 | game/world/region_view.gd:630 |
| 程序模型与占位 | game/world/building_models.gd:128、345 |
| 施工架 | game/world/building_models.gd:353、region_view.gd:737 |
| 海运依赖 port | game/simulation/logistics.gd:112 |
| 区域出口、道路和桥 | game/world/region_view.gd:831、856 |
| 民营 service | game/simulation/enterprise.gd:50 |
| 新世界版本/尺度 | game/world/geo2/world_gen2.gd:12、game/data/v17/geography.json:653 |
| 旧包入口 | art_reserve/max_highpoly_20261031/00_brief/DELIVERY_TARGET_IDS.json |
| 旧包限制 | art_reserve/max_highpoly_20261031/QA_REPORT.md |

下附逐项表的 ID、名称和类型从当前配置核对；制作建议不是已完成状态。其他 Agent 更新代码后，先检查新增/删除 ID，再扩表，不重复重建已有模型。


## 10. 全部 56 项公共建筑对应表

“复用候选”指已有主体可用；“改型/新建”均为待制作。具体零件来源与用途见同名 coverage.json。

| 游戏 ID | 中文名 | 据点 | 当前模型键 | 优先级／制作方式 | 改动要点 |
|---|---|---|---|---|---|
| habitat | 模块住区 | 居住 | habitat | 保留／复用候选 | 保留模块住宅主体，接入另行处理 |
| apartment | 公寓楼 | 居住 | habitat | P0／改型 | 增加中高层体量与楼层秩序 |
| arcology | 生态穹顶城 | 居住 | habitat | P0／新建 | 穹顶结构与内部高密度建筑绿地 |
| crew_quarters | 工棚营地 | 边疆 | habitat | P0／改型 | 单层简易工棚与集中生活服务 |
| frontier_lodge | 边疆宿舍楼 | 边疆 | habitat | P1／改型 | 常驻宿舍和作业配套 |
| power | 光伏储能站 | 居住/边疆 | power | 保留／复用候选 | 现有光伏储能主体 |
| wind_farm | 风电场 | 居住/边疆 | power | P1／新建 | 风机叶片塔架和变电组件 |
| geothermal | 地热电站 | 居住/边疆 | power | P1／新建 | 井口热交换和汽轮设备 |
| fission | 裂变电站 | 居住/边疆 | power | P1／新建 | 围护厂房冷却和受控作业区 |
| fusion | 聚变电站 | 居住/边疆 | power | P1／新建 | 独立聚变核心厂房与配套 |
| water | 净水泵站 | 居住/边疆 | water | 保留／复用候选 | 现有净水主体 |
| deep_well | 深层水井 | 居住/边疆 | water | P2／改型 | 井口泵房与输水接口 |
| desalination | 海水淡化厂 | 居住/边疆 | water | P1／新建 | 海水取水端与淡化处理列 |
| atmospheric_water | 大气集水站 | 居住/边疆 | water | P2／新建 | 冷凝集水阵列 |
| port | 轨道货运站 | 居住/边疆 | port | P1／改型 | 保留仓储补独立起降与货运接口 |
| depot | 区域物流中心 | 居住/边疆 | port | 保留／复用候选 | 现有仓库吊机堆场适配 |
| scrubber | 污染净化塔 | 居住/边疆 | processor | P0／新建 | 净化过滤吸附塔独立轮廓 |
| mine_ore | 轻型铁矿场 | 居住/边疆 | mine_ore | 保留／复用候选 | 轻型井架与铁矿料件 |
| mine_copper | 轻型铜矿场 | 居住/边疆 | mine_copper | P2／改型 | 铜矿料及处理附件差异 |
| mine_crystal | 晶体采掘站 | 居住/边疆 | mine_crystal | P2／改型 | 晶体料及处理附件差异 |
| mine_ore_heavy | 重型铁矿场 | 边疆 | mine_ore | P1／新建 | 台阶采场大型装载和破碎 |
| mine_copper_heavy | 重型铜矿场 | 边疆 | mine_copper | P1／改型 | 复用重型母版补铜矿处理 |
| mine_crystal_heavy | 重型晶体矿井 | 边疆 | mine_crystal | P1／改型 | 深井提升和晶体分选 |
| mine_ore_auto | 自动铁矿钻场 | 边疆 | mine_ore | P1／新建 | 钻机阵列封闭控制单元 |
| mine_copper_auto | 自动铜矿钻场 | 边疆 | mine_copper | P1／改型 | 自动母版加铜矿附件 |
| mine_crystal_auto | 自动晶体钻场 | 边疆 | mine_crystal | P1／改型 | 自动母版加晶体附件 |
| tailings_plant | 尾矿回收站 | 居住/边疆 | processor | P2／改型 | 回收处理线与尾矿料堆 |
| sea_copper | 海水提铜站 | 边疆 | water | P2／新建 | 海水提取设备与岸端接口 |
| crystal_vat | 晶体培育槽 | 居住/边疆 | lab | P2／改型 | 可见晶体培养槽和控制设备 |
| farm | 温室农场 | 居住/边疆 | farm | 保留／复用候选 | 普通温室主体 |
| field_station | 大田农业站 | 边疆 | farm | P1／新建 | 田块粮仓农机棚 |
| ranch | 牧场 | 边疆 | farm | P1／新建 | 围栏畜舍饲料设施，不强加动物动画 |
| hydroponic_farm | 水培温室 | 居住/边疆 | farm | P2／改型 | 循环供液与种植架，现映射绕过专用分支 |
| aquafarm | 近海养殖场 | 边疆 | farm | P1／新建 | 网箱浮台服务栈桥 |
| vertical_farm | 垂直农场 | 居住 | farm | P1／新建 | 高层种植设施与服务核心 |
| protein_plant | 合成蛋白厂 | 居住 | processor | P2／改型 | 反应发酵与卫生处理设备 |
| foodworks | 食品出口加工坊 | 居住/边疆 | foodworks（通用占位） | P2／改型 | 包装出货；当前程序通用fallback |
| processor | 复合加工厂 | 居住/边疆 | processor | 保留／复用候选 | 现有加工主体 |
| smelter | 合金冶炼厂 | 居住/边疆 | processor | P2／改型 | 冶炼炉冷却与原料处理 |
| component_plant | 电子元件厂 | 居住 | component_plant | P1／新建 | 洁净厂房设备与物流分流母版 |
| machine_works | 精密机械厂 | 居住 | component_plant | P2／改型 | 机械装配加工和成品出货 |
| pharma_plant | 生物制药厂 | 居住 | component_plant | P2／改型 | 无菌生产与封闭处理设备 |
| lab | 教学研究所 | 居住 | lab | 保留／复用候选 | 现有教学研究所 |
| institute | 研究院 | 居住 | lab | P2／改型 | 扩展实验楼仪器院落 |
| clinic | 社区诊所 | 居住 | clinic | P1／改型 | 小型诊疗入口服务区 |
| park | 生态公园 | 居住 | habitat | P2／改型 | 步道绿地和景观设施 |
| school | 中等学校 | 居住 | lab | P1／改型 | 教学与活动空间 |
| culture_center | 文化中心 | 居住 | habitat | P2／改型 | 活动厅与公共前场 |
| hospital | 综合医院 | 居住 | habitat | P1／新建 | 门急诊与住院层次 |
| civic_center | 市政中心 | 居住 | habitat | P1／改型 | 市政服务入口与公共前场 |
| commerce | 商业街区 | 居住 | habitat | P2／改型 | 可组合街区；当前别名绕过商业分支 |
| data_center | 数据中心 | 居住 | lab | P1／新建 | 模块机房冷却与配电 |
| university | 行星大学 | 居住 | university | P1／新建 | 多楼校园与公共核心 |
| lift_port | 轨道升降港 | 居住/边疆 | lift_port | P0／新建 | 锚定基座运输核心与系缆接口 |
| climate_regulator | 气候调节站 | 居住/边疆 | climate_regulator | P1／新建 | 调节阵列并与净化塔区分 |
| capital_hall | 行星议会大厦 | 居住 | university | P0／新建 | 议事主体行政翼和公共前场 |
