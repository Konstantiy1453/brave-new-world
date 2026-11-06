# 殖民契约／勇敢新世界：开发交接

交接日期：2026-11-06  
游戏：Colony Charter 1.8.0  
接手范围：代码维护、玩法与内容深化、3ds Max 模型接入  
两个 ZIP 的共同顶层目录：BraveNewWorld_Handoff_20261106

这是一款已经接通核心循环的单机殖民经营原型。接手后最有价值的工作，是把登陆、分工、危机、首府、总督移交这一整段经历做得有选择、有反馈、能理解，并把准备好的美术资产逐步接入实际地图。现有架构能够承接这轮工作；没有发现必须推倒重写才能继续制作内容的依据。

先运行 playable 里的既有版本，再阅读当前规则和审查记录，最后在 project 里开发。模型包提供制作源与候选资产，游戏目前仍以程序几何显示建筑。完成高模、完成运行资产转换、完成游戏接入、完成视觉与性能验收，是四项不同的工作。

本轮交接检查的实际结果集中记录在同目录 [VALIDATION_20261106.md](VALIDATION_20261106.md)。本文不把旧报告改写成本轮结果，也不预填朋友机器上的运行结果。

## 1. 收到的是什么

两个 ZIP 解压到同一个父目录，让它们合并成同一个 BraveNewWorld_Handoff_20261106。保留 ZIP 作为收到时的原件，日常修改放在解压目录或从其建立的开发目录。

~~~text
BraveNewWorld_Handoff_20261106/
  START_HERE.md                       本交接说明
  VALIDATION_20261106.md              本轮检查与实际运行记录
  MODEL_INTEGRATION.md                模型来源、状态和接入要求
  HANDOFF_ASSET_INDEX.json            随包资产索引
  MODEL_GALLERY.html                 模型浏览入口
  project/
    game/                            可编辑的 Godot 工程
    docs/                            当前规则、历史进度、审查与提案
    tools/                           脚本与 Godot 引擎
    build/godot_home/                 Windows x64 导出模板缓存
    saves/                           被测试引用的指定历史 fixture
    versions/                        被旧地形对照引用的指定历史源码
    evidence/                        选取的历史证据与测试基线
    art_reserve/                     美术 ZIP 解压后补齐
      max_highpoly_20261031/
      max_highpoly_continuation_20261102/
    README.md
    CHANGELOG.md
    CLAUDE.md
    gdlintrc
  playable/                          8 个既有发行文件 + RELEASE_IDENTITY.json，共 9 个
  history/
    ColonyCharter.bundle             Git HEAD、分支与标签历史
    lfs_objects/                     Git LFS 实体对象，保留两层目录
    LFS_OBJECTS.json                  LFS 对象清单与校验信息
~~~

主包提供继续开发所需的工作区内容、离线引擎和 Windows 模板、指定回归输入、选取的历史证据、既有发行版与 Git bundle。美术包提供旧包 12 项可复用库/建筑源、新包 8 项候选源，以及实际依赖纹理、选取的证据和预览。每项的实际文件、来源、哈希和状态以随包清单与 HANDOFF_ASSET_INDEX.json 为准。

这是按开发交接目的整理的快照，不是原电脑整个工作目录的逐文件备份。旧发行物、完整历史运行目录、全部美术迭代和可再生成缓存没有无差别复制。需要复查某条历史结论时，先看清单是否包含其原始输入与输出；未带的历史材料不能靠重建一个相似文件冒充原件。

playable 保留既有发行物的身份。新写的交接说明和文件清单不会让旧 EXE 变成本轮重新编译的 EXE。朋友修改后重新导出的程序应另建版本与记录。

## 2. 项目愿景与继续保持的约束

玩家是公司的殖民外包专员，在一颗随机星球上选址、生产、运输、养活居民，逐步建立能自负盈亏的社会，取得总督资格。之后可以继续经营，或移交旧星、获得代管收益，再开启下一颗星球。

当前优先做深单颗星球的经营。边疆与居住据点应有不同的角色；矿业、农业、加工、科研应形成受地点与资源条件影响的选择；事件应留下规则和生活层面的后果。旧星采用摘要式代管结算。战争、全体居民逐人模拟、同时实时治理多个星球，不属于这轮既定开发范围。

继续保留以下技术与玩法约束：

- 离线单机、免费、无内购；科研经费、课题重抽等支付仅使用游戏内资金，不引入科研资源或数值的真实货币付费。Windows x64、Godot 4.5.1、GDScript、GL Compatibility 是当前运行路径，跨平台目标另立。
- 模拟以固定日步推进。相同种子与行动序列应得到相同状态；1×、3×、6×改变经过时间，不改变经营结果。
- Sim.state 保存可变状态；规则修改经 Sim.act() 与 Sim.tick() 进入。UI 和地图读取状态、提交动作，不自行改账或偷偷推进天数。
- 可调数值集中在 game/data/v17/*.json，规则、预览、UI 和测试读取同一份数据。不要在按钮里再写一套价格、工期或解锁条件。
- 资源与资金的生产、消耗和转账需能审计。新事件和新玩法沿已有账本与模块接口生效，audit() 应持续通过。
- 英文 ID 是数据契约，中文是显示文本。改名字不随意改建筑、科技、事件、节点和选项 ID；结构变化要补迁移。
- 原有玩家存档和美术母版保留。程序运行资产在新目录派生，转换记录指向原始文件及哈希。
- 历史运行、源码检查、窗口运行、导出 EXE、已查看图片、真人整局试玩分别记录。NOT_RUN、MISS、失败和未知原因不因交接而消失。

1.8 的游戏内一年为 360 天。标准难度总督资格目标是 6—8 个游戏年，这不是“真人必须玩多久”的承诺。历史六倍速约 35 分钟只是时钟换算，读说明、暂停、规划和试错会改变真实游玩时间。

## 3. 版本、工作区快照与证据身份

| 项目 | 当前记录 |
|---|---|
| 应用版本 | 1.8.0，见 game/project.godot |
| Git HEAD | af752d255c49bff477a5e884237d99f887cfad0c |
| 原分支 | v17 |
| 指向基线的标签 | v1.8.0 |
| Godot | 4.5.1-stable，Windows x64 |
| 新世界生成器 | CC-GEO-2.2 |
| 当前存档 schema | 4；容器标记仍为 CCS3 |
| 工程目录 | game/ |
| 规则、文档、构建目录 | 仍沿用 v17 命名 |

目录名 v17 不表示游戏仍然是 1.7。docs/v17/PLAN.md 保留早期架构设计，里面的 schema 3、旧科研树和旧数值需要结合 V18_PLAN.md、当前源码阅读。现在 save_io.gd 的 SCHEMA 是 4，科研是分类抽牌。

Git bundle 仅收 HEAD、分支与标签，不包含临时 Codex refs。project 快照本身没有 .git。Git HEAD 只能标识已提交的源码历史。打包时工作区还有未提交材料：docs/reviews/2026-11-02-content-readiness-audit.md、若干模型覆盖/补建/1.9 提案及配图，旧美术目录的 README 也有本地修改。project 快照保留实际选入的工作区文件，bundle 保留已提交历史。两者必须合看，不能只检出 af752d2 就称得到了本次交接的全部资料。

| 时间与范围 | 已有记录 | 使用方式 |
|---|---|---|
| 1.8 开发期验证 | PROGRESS.md、VALIDATION.md、BALANCE.md 记录 46 套无窗口、4 套窗口、480 局平衡等历史结果 | 理解当时通过项、缺口与性能基线；对应源码、机器与输出仍需核对 |
| 2026-11-02 内容审查 | 六套无窗口检查共 858 checks 通过；独立副本执行，保留输入哈希、隔离目录、命令、退出码和日志 | 这是 11 月 2 日真实运行，不是本次打包新跑，也不是第二台机器验证 |
| 2026-11-06 本轮交接 | 见 VALIDATION_20261106.md | 以该文件实际记录为准 |
| 朋友机器接收验证 | 接收前 NOT_RUN | 在朋友电脑导入、启动、执行指定套件并保存新日志后填写 |

11 月 2 日六套分别为 v18_systems 92、v17_saves 103、v17_events 151、v17_research 144、v17_contract_population 136、v17_tutorial 232。第一次审查运行器曾因正则组合错误失败，r2 修正后独立重跑；原失败与修正版有各自证据。

当前没有完成真人整局体验验收。机器人通关、脚本点击 EXE、截图生成和真人试玩承担不同验证任务。

## 4. 先读哪些文件

建议按下面顺序阅读，避免把旧数值和未实施提案混在一起：

1. 本文、VALIDATION_20261106.md 和 project/README.md：知道收到的版本、怎么运行、结论来自哪一轮。
2. project/docs/reviews/2026-11-02-content-readiness-audit.md：理解“核心已接通，下一步做内容与体验”的依据与缺口。
3. project/CLAUDE.md：现有工作边界、目录、证据标签和提交习惯。旧存档、旧版本及美术源的保护要求继续有效。
4. project/docs/v17/PROGRESS.md 顶部 1.8 部分、V18_BRIEF.md、V18_PLAN.md：原需求、验收条目、已做与未达标项。
5. project/docs/v17/PLAN.md、DESIGN.md、DECISIONS.md：架构与取舍。先读模块/数据所有权，再按正在修改的系统深入。
6. project/docs/v17/VALIDATION.md、BALANCE.md、PLAYTEST.md：检查协议、历史结果和真人试玩清单。
7. MODEL_INTEGRATION.md、HANDOFF_ASSET_INDEX.json、MODEL_GALLERY.html，以及模型覆盖与补建文件：决定先接哪些资产。
8. project/docs/superpowers/plans/2026-11-01-v19-money-and-models-instructions.md：作为有测量、有实验、有设想的历史提案阅读，逐项重新决定是否采用。

旧文档可能保留原电脑 D:/勇敢新世界 的绝对链接。迁机后按相同的 project 相对路径寻找即可。本文命令均以解压后的 project 为工作目录，另有说明的 Git 恢复段除外。

## 5. 当前已经做到哪里

经营闭环已经串起生产、贸易、企业、人口、科研、道路与海运、污染、合同、公司介入、生涯移交。成功、失败、审查和恢复有真实规则。

内容规模在 11 月 2 日源码审查中实际解析为 56 种公共建筑、122 项科技、4 个科研类别、83 个事件定义（71 个短事件、12 条多节点链）、14 步新手引导和 5 条后续提示。数量说明已有可用内容池，不能替代体验质量与模型覆盖。

| 系统 | 现状与接手重点 |
|---|---|
| 合同 | 五阶段推进到首府；标准均衡机器人的历史授勋中位日为 2454，约 6.8 年。观察后段是否只剩等人口、科技或稳定期。 |
| 人口与据点 | 居住/边疆已有不同规则、许可和建筑限制；工资、床位、失业、招募影响人口。强化功能差异与反馈。 |
| 科研 | 四类别抽牌、派团队、付费重抽，必需课题有保护；五队速度为十队的 60%。让课题改变路线，而不只是增加倍率。 |
| 经济 | 公共、居民、企业账户及收支审计已存在；矿业、加工、固定收入、物流一起决定现金。后期现金缺少用途，但有些局会在资源衰退时赤字。 |
| 公司与污染 | 不信任有来源、变化和介入阶段；污染是全星球累积的晚期惩罚，不是公司风险来源。新内容遵守这一分工。 |
| 地理与交通 | 随机地貌、气候、候选点、道路与海路；0.6、1.0、1.3 地球半径参与距离。旧固定星球模型不能替代新程序世界。 |
| 事件 | 支持条件、调查、建设、订单、延迟、分支和持续效果；跨事件回响仍少，适合做少量完整事件线。 |
| 生涯 | 旧星归档、代管摘要、分红、新星开局已有；不是实时多星治理。 |
| 地图表现 | 建筑主要仍由 building_models.gd 生成；39 种新增建筑借用现有模型/图标，高模尚需转换与接入。 |
| 性能与保存 | 有历史存读档、窗口和 EXE 性能结果；新模型接入后必须重新测。 |

公开的问题应继续放在进度表里：

- 开局授勋中位数差距约 20%，未达到原 15% 目标；已测策略中科研优先在三种开局下都最快。
- 便宜道路同时更慢的比例约 90%，超过原 30%—70% 条目。真实星球尺度改变了旧条目的适用性，但历史 MISS 原样保留；改验收定义要另记理由和新协议。
- 标准均衡机器人 30 局中有 3 局在授勋前被接管。这是已测机器人策略的结果，需要真人与针对性回放定位。
- 后期现金与投资机会不足并存，不能用统一加税或砍收入覆盖所有种子、开局与难度。
- 开发期间记录过三次未稳定复现的异常，涉及引擎崩溃、无输出分片、fixture 解码。原因尚未确定，不能写成已经修复。
- 真人完整试玩、外部模型实际接入后的观感与性能仍有未完成验收。

## 6. 从哪里改：代码导航

下列路径均相对于 project。先找到数据与负责模块，再追踪 Sim.act()、预览和 UI，避免只修显示。表内省略 game/ 的 simulation、ui、world、data 路径都位于 game/ 内。

| 要做的事 | 主要入口 | 相关检查 |
|---|---|---|
| 启动与配置 | game/project.godot、game/main.tscn、ui/main.gd | 保存目录、引导、时钟、导航 |
| 日循环与动作 | simulation/sim.gd | act、tick、audit、账本；失败动作不改状态 |
| 规则加载 | simulation/rules.gd、data/v17/*.json | 顶层键与部分引用已有检查，完整内容 schema 待补 |
| 建筑、生产、升级 | data/v17/economy.json、simulation/production.gd | build_forecast 与实际成本/产量一致 |
| 地块与选址 | simulation/sites.gd、data/v17/geography.json | 据点种类、沿海限制、隐藏矿床、储量 |
| 物流与交通 | simulation/logistics.gd、world/routes.gd | 运力、工期、食品到货、预留，显示与模拟分离 |
| 人口与工资 | simulation/population.gd、data/v17/population.json | 迁移原因可解释，预算不绕过住房/人员约束 |
| 价格与私营 | simulation/market.gd、enterprise.gd、data/v17/market.json | 饱和、固定收入复制、就业与账户 |
| 合同与公司 | simulation/contract.gd、company.gd、data/v17/contract.json | 目标、期限、审查、恢复、失败、授勋 |
| 科研与大型工程 | simulation/research.gd、megaprojects.gd、data/v17/techs.json | 抽牌可重放；团队、席位、经费、暂停进度 |
| 污染 | simulation/pollution.gd、data/v17/progression.json | 晚期影响；不重新并入公司风险 |
| 事件与叙事 | simulation/events_v2.gd、data/v17/events.json | 稳定 ID，进行中事件旧档，条件与效果 |
| 生涯与移交 | simulation/career.gd、data/v17/career.json | 归档、代管结算、落地检查点 |
| 存档迁移 | simulation/save_io.gd、save_migration.gd | schema 4、旧档、原子写入、附属文件 |
| UI 与文本 | ui/pages.gd、progression_pages.gd、design.gd、labels.gd | 规则键与显示文本分开，小分辨率和大字检查 |
| 引导与统计 | simulation/tutorial.gd、stats.gd、ui/tutorial_coach.gd | 跳过/重播；统计仅展示，不反向驱动规则 |
| 新世界生成 | world/geo2/world_gen2.gd、plates.gd、climate.gd、site_gen.gd | 种子、版本、尺寸、生成哈希、可玩性 |
| 地图与模型 | world/map_view.gd、region_view.gd、building_models.gd、planet_view.gd、flat_view.gd | 缓存、签名、状态变化，先做窄接入接口 |
| 测试与发布 | game/tests/、game/tests/balance/、tools/test_suites.json | run_tests.ps1、build_v17.ps1、package_v17.py |

当前外部资产接入缺口很具体：region_view.gd 的 _baked_model() 先读取 economy 建筑的 model 别名，再生成程序几何；_collect_parts() 只接收带 material_override 的 MeshInstance3D，且只追加 surface 0。直接塞多材质外部模型可能丢 surface、丢材质或变换错误。先补资产映射、完整 surface/material 处理、状态与回退，再推广。

存档 MAGIC 仍是 CCS3，但 SCHEMA 已为 4。不要根据魔数字符串误判格式版本。存档旁的 .ckpt-<hash>、.arch... 文件参与生涯检查点和旧星归档；迁移测试需要带同槽位附属文件。

## 7. 内容优先顺序

先完成一个有代表性的完整流程样例，再扩到不同开局与地理。下面每一步都应能独立评审。

**第一步：接手可运行性。** 确认清单、导入、可运行版和源码版能启动；修复七个辅助脚本的绝对路径；补齐旧输入说明。建立朋友电脑自己的日志，不沿用原机器 PASS。

**第二步：做一次有记录的整局试玩。** 使用 PLAYTEST.md，从登陆到授勋或失败，记录每阶段的困惑、等待、重复操作、危机原因和有记忆的选择。卡点记录种子、开局、难度、日数、操作与可回放存档副本。重点看引导、首次缺粮、第一次外派、科研选择和阶段五。

**第三步：形成有适用条件的经营路线。** 先比较边疆矿业/加工、农业与定居、科研与高附加值三类方向。它们应在现金流、地块、污染、物流、人力和风险上各有代价。解释优势来源后再做小幅调整，不以所有组合完全同速为目的。

**第四步：做少量有后续回应的事件线。** 每条线需要具体地点、经营前提、真实代价、可观察结果与后续回响。叙事若承诺行政分权、行业转型或地方特征，规则和页面也要有对应变化。优先扩展现有条件、效果和结局接口。

**第五步：处理中期重复操作与无效等待。** 已有税率、工资、食品储备、私营许可、据点批量启停和库存目标，先看玩家是否能发现并用好。确需自动化时限定目标、预算和异常汇报；自动支出可预测、可回看、可关闭。

**第六步：让投资服务于转型。** 授勋前增加有用的公共服务、科研条件、产业转型机会；授勋后把移交、回报和新开局做完整。保留抵御矿业衰退与危机的合理储备，不把每年必须花掉多少现金当作唯一乐趣指标。

美术接入可以并行。先挑住宅、议会地标、海运端点等少数用途验证接口和实际画面，再扩大覆盖。内容无需等全部模型完成；模型也不应为了凑覆盖率都变成同一母版的等比缩放。

## 8. 模型包怎么用

先看 MODEL_INTEGRATION.md，再开 MODEL_GALLERY.html，最后按 HANDOFF_ASSET_INDEX.json 取源文件。原 .max、FBX、材质、纹理和验证记录组成资产来源；game 只接收经确认的派生产物。

旧包位于 project/art_reserve/max_highpoly_20261031。本次带的 12 项是 10 类建筑、基础设施和环境库：

~~~text
CC_COMMAND_HP_v001        CC_HOUSING_HP_v002
CC_POWER_HP_v002          CC_WATER_HP_v003
CC_MINING_HP_v002         CC_GREENHOUSE_HP_v003
CC_RESEARCH_HP_v002       CC_INDUSTRY_HP_v005
CC_LOGISTICS_HP_v002      CC_CIVIC_HP_v001
CC_INFRASTRUCTURE_HP_v002  CC_ENVIRONMENT_HP_v002
~~~

它们可作运行模型来源或改型母版。完整旧白名单曾包含 21 个主体场景，不能因为本次选 12 项就改写旧白名单。旧固定整球、地形、城市组合主要是旧 CC-GEO-1.6 世界的艺术与组装参考；当前 CC-GEO-2.2 的随机星球、半径和候选地区不同。同种子不等于同地貌，不按旧 R00/R01/R05 坐标套用新版地图。

新包位于 project/art_reserve/max_highpoly_continuation_20261102，当前随包 8 项候选：

| 资产 ID | 预期用途 | 交接状态 |
|---|---|---|
| CC_APARTMENT_HP_v002 | apartment 公寓楼 | 候选源，以逐项证据为准 |
| CC_ARCOLOGY_HP_v002 | arcology 穹顶城 | 候选源；视觉验收 NOT_RUN |
| CC_CAPITAL_HALL_HP_v002 | capital_hall 行星议会 | 候选源 |
| CC_CIVIL_CARGO_SHIP_HP_v001 | 民用货船、海运表现 | 候选源，不自动新增舰队玩法 |
| CC_CONSTRUCTION_KIT_HP_v001 | 通用施工状态 | 候选源 |
| CC_CREW_QUARTERS_HP_v001 | crew_quarters 边疆工棚 | 候选源 |
| CC_HARBOR_QUAY_KIT_HP_v002 | 海运岸端、码头附属 | 候选源，当前没有独立 harbour 建筑 ID |
| CC_LIFT_PORT_HP_v001 | lift_port 轨道升降港 | 候选源 |

新目录没有已确认的 DELIVERY_TARGET_IDS 白名单，不能因文件存在就称“8 项正式验收完毕”。索引列的是本轮选入文件及状态。正式接入前，完成该资产源/导出一致性、材质纹理依赖、尺寸轴向和视觉确认，记录接受版本与哈希。尤其不要把 arcology 的结构报告升级为已经看过实际效果。

旧 1.9 草案中的统一约 4500 面预算、抛弃 UV/纹理、统一拉高比例等是历史方案，不是本次要求。原高模继续保留材质、UV、纹理和空间比例；运行网格可另做简化、烘焙、LOD 或材质合并，但要以实际视觉和性能比较决定。透明穹顶、细长支撑、地标与普通设施应分别判断。

建议维护映射表：游戏建筑 ID → 运行资源 → 源资产 ID/哈希 → 单位/轴向/地面基准 → 材质贴图 → 运行/停用/施工状态 → 图标 → 回退模型 → 检查结果。原高模不写回，转换脚本可重跑，失败产物和诊断另存。

先检查多材质与多 surface、节点变换、实例、法线、透明玻璃、贴图路径、纹理颜色空间、单位。再在游戏实际俯视角、典型缩放和密集建造场景检查轮廓、落地、入口、遮挡和识别度。美术预览好看仍需经过这一层。

验收至少覆盖居住点与边疆点，以及正常、停用、施工、升级变化；海港核对岸线/水线。冷区域、热切换、密集期、存档后恢复都要测。对应运行资产验收前保留程序模型回退。

## 9. 朋友电脑第一次开工

以下是接收方执行说明，路径替换为实际解压位置。

~~~powershell
Set-Location -LiteralPath 'E:\BraveNewWorld_Handoff_20261106\project'
$engine = Join-Path (Get-Location) 'tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe'

# 初次导入，重建本机缓存和全局脚本类。
& $engine --headless --path game --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }

# 打开编辑器。
& $engine --path game --editor
~~~

关闭编辑器后，需要直接从源码启动时：

~~~powershell
& $engine --path game
~~~

可运行版在同级 playable 中双击 ColonyCharter.exe。EXE 与 PCK 保持同目录。保留这个版本，作为修改前的参照。

第一次接收验证可先跑 11 月 2 日同一组核心套件：

~~~powershell
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 -Only v18_systems,v17_saves,v17_events,v17_research,v17_contract_population,v17_tutorial -Jobs 2
~~~

本命令产生朋友机器的新日志。成功标准是退出码、错误标记、套件成功标记和检查结果都满足运行器条件，不预设仍应恰好 858 项；代码变化可能改变检查数，需解释变化。

run_tests.ps1 给每个套件隔离 APPDATA，写入 evidence/v17/tests 和 evidence/v17/userdata_tests。每次会覆盖同名结果并清理该套件隔离用户目录，因此完成一轮后把日志与 summary.json 复制到带日期/机器/版本的独立证据目录，再开始下一轮。不要把真实玩家存档放在测试目录。

## 10. 全套测试的迁机问题

tools/test_suites.json 有 50 套：默认 46 个无窗口，-Window 增加 4 个窗口。窗口套件需要正常图形桌面与真实渲染环境；运行器让窗口套件独占，避免并发量帧。

以下七个 helper 仍把输出写死为 D:/勇敢新世界/evidence/v17/tests。迁机先做小范围路径修复，再宣称完整测试可移植：

| 套件 | 文件 |
|---|---|
| review_save_nested_type | tools/review_save_nested_type.gd |
| review_save_guards | tools/review_save_guards.gd |
| review_enterprise | tools/review_enterprise_capacity.gd |
| review_outpost_jobs | tools/review_outpost_jobs.gd |
| review_island | tools/review_island.gd |
| review_sim | tools/review_sim.gd |
| review_world | tools/review_world.gd |

修复时按工程根构造输出，例如统一到 res://../evidence/v17/tests，并保证目录存在；原检查条件与报告内容保持不变。在原根目录不存在的另一位置执行，确认没有文件落回旧 D:。tools/verify_asset_render.gd 也有同类硬编码，虽然不在默认套件，使用前同样处理。

| 必须保持布局的历史输入 | 使用者与缺失后果 |
|---|---|
| saves/ui_day50.json | review_save_nested_regressions.gd 的旧档回归；缺失会失败 |
| versions/v1_5_before_v1_6_20261030_125059/game/world/map_view.gd | world_v16_terrain_identity.gd 的旧地形例程；缺失会失败 |
| evidence/v16/world_seed_red.json | world_v16_seed.gd 的冻结哈希对照；缺失会跳过该部分，其余仍可能 PASS |
| game/data/acceptance_*.json、game/data/v16/、game/data/v17/acceptance_* | 多套旧档迁移与系统测试的直接输入，不能按发行包过滤规则删除 |

coast_review.gd 另依赖 evidence/v1_4/acceptance_midgame.json，它不在默认 50 套中。执行前核对随包清单是否带了该文件。新生成的相似存档不能替代冻结输入。

路径修复且输入核对后执行：

~~~powershell
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 -Jobs 2
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 -Window -Jobs 2
~~~

日常只跑与变更对应的套件，合并里程碑前再做完整检查。数值变化需平衡机器人；UI/模型变化需窗口与导出 EXE。更多无窗口重复不能代替适用证据。

平衡测试会改写 docs/v17/BALANCE.md，并输出 evidence/v17/balance。在自己的开发副本执行，结束后恢复 APPDATA：

~~~powershell
$savedAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path (Get-Location) 'evidence\v17\userdata_balance_handoff'
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    & $engine --headless --path game --script res://tests/balance/run_balance.gd -- --quick --label=friend_baseline
    if ($LASTEXITCODE -ne 0) { throw 'Balance harness failed' }
}
finally {
    $env:APPDATA = $savedAppData
}
~~~

完整平衡先固定种子、开局、难度、策略与统计口径，再使用 --full。性能测试不与模型转换、重渲染和其他批量作业同时运行。

## 11. 构建与发布

离线工具链有两份引擎 EXE，console 是包装器，不能只留它。build_v17.ps1 先看系统 APPDATA 下 Godot 模板，没有则使用 project/build/godot_home 下 4.5.1.stable 模板。本包提供 Windows release、debug、version.txt，通常无需再下载全平台 TPZ。

先完成第 12 节的 Git bundle、LFS 和当前快照恢复，再在没有手动隔离 APPDATA 的新 PowerShell 窗口中进入恢复好的 project_git 发布。不要直接在没有 .git 的 project 快照里生成发行身份：

~~~powershell
Set-Location -LiteralPath 'E:\BraveNewWorld_Handoff_20261106\project_git'
powershell -ExecutionPolicy Bypass -File tools\build_v17.ps1
if ($LASTEXITCODE -ne 0) { throw 'Build failed; packaging stopped' }
python tools\package_v17.py
if ($LASTEXITCODE -ne 0) { throw 'Packaging failed' }
~~~

build 输出到 build/v17，package 输出到 delivery/v17。game/export_presets.cfg 的默认导出路径与脚本显式路径不同，发布以 build_v17.ps1 的 build/v17 为准。

Python 脚本使用标准库，至少需要支持 removeprefix 的 Python 3.9；原文档使用 Python 3.12。Git、Git LFS、Python 需要接收方安装。打包脚本会调用 git rev-parse HEAD；project 快照没有 .git，直接在其中打包会得到空 commit，机器没有 Git 时还会报启动错误。因此发布新版包前必须先按下一节恢复 bundle 与 LFS，再叠加当前快照，在恢复好的仓库中构建和打包。gdformat/gdlint 属于另外的开发工具，Godot 并不包含；按项目格式要求配置后再提交代码。

若 Agent/Python 从 PowerShell 7 环境启动 Windows PowerShell 5.1，继承的 PSModulePath 可能导致 Get-FileHash 等模块命令找不到。应在启动该子进程的环境副本中移除键名不区分大小写的 PSModulePath，再让新进程建立自己的模块路径。不要吞掉构建非零退出；保留首次失败和修正重试为不同记录。普通用户从新的 Windows PowerShell 窗口运行可按上面的命令操作，具体本轮复现见 VALIDATION_20261106.md。

修改版本时同步 project.godot、package_v17.py 的 VERSION、README、CHANGELOG 和保存策略，不能只改 ZIP 名。package_v17.py 的源码压缩范围有限，普通 Source.zip 仍不是本次这种完整开发交接。

每次正式交付记录源码 commit、工作区差异、引擎哈希、输入清单、命令/cwd、退出码、日志与产物哈希。检查 PCK 未混入测试专用内容，实际启动 EXE，查看关键页面和场景，再发版本。ZIP 可打开、PCK 可解析、文件存在，只是其中一层。

## 12. 存档、个人资料与 Git 历史衔接

正常游戏使用本机 %APPDATA%\ColonyCharter\v18：manual.save、autosave.save，自动档每 10 个游戏日写入，并有 .bak。1.8 读取旧 v17/v16 存档时保留原件，后续写到新版本目录；旧版本不能据此读取新规则存档。

本次不传原电脑个人 APPDATA、完整个人存档、账号配置或 Codex 会话。project/saves/ui_day50.json 是代码明确引用的历史测试输入，不代表打包了私人游玩目录。复现具体玩家问题时，另取经确认的存档副本及相关 .ckpt/.arch 附属文件，放在隔离目录。

Git bundle 恢复已提交历史，工作区快照补齐实际选入的未提交材料。项目 .gitattributes 启用了 Git LFS，bundle 本身只有 LFS 指针，不包含对应资源实体。本包另带 history/lfs_objects 的 17 个对象（104,014,505 字节），已按对象 ID 校验；清单见 history/LFS_OBJECTS.json。这些对象覆盖交接时 git lfs ls-files --all 列举的对象。project 中当前工程资源已经是实体，直接运行 Godot 无需先恢复 LFS；恢复 Git 历史和发布新版时则应完成下面步骤。

先安装 Git、Git LFS 和 Python。建议在独立目录恢复历史后叠加快照，保留原 project 与 ZIP 作收到时参照。从共同顶层运行：

~~~powershell
Set-Location -LiteralPath 'E:\BraveNewWorld_Handoff_20261106'
git bundle list-heads .\history\ColonyCharter.bundle

# 克隆时先跳过网络下载，随后使用随包的本地 LFS 对象。
$savedLfsSkip = $env:GIT_LFS_SKIP_SMUDGE
try {
    $env:GIT_LFS_SKIP_SMUDGE = '1'
    git clone -b v17 .\history\ColonyCharter.bundle .\project_git
    if ($LASTEXITCODE -ne 0) { throw 'Git clone failed' }
    git -C .\project_git switch -c codex/continue-20261106 af752d255c49bff477a5e884237d99f887cfad0c
    if ($LASTEXITCODE -ne 0) { throw 'Git baseline checkout failed' }

    New-Item -ItemType Directory -Force -Path .\project_git\.git\lfs\objects | Out-Null
    robocopy .\history\lfs_objects .\project_git\.git\lfs\objects /E
    if ($LASTEXITCODE -ge 8) { throw 'LFS object copy failed' }
}
finally {
    $env:GIT_LFS_SKIP_SMUDGE = $savedLfsSkip
}

git -C .\project_git lfs install --local
if ($LASTEXITCODE -ne 0) { throw 'Git LFS setup failed' }
git -C .\project_git lfs checkout
if ($LASTEXITCODE -ne 0) { throw 'Git LFS checkout failed' }

# 最后叠加当前快照；/E 保留子目录，不使用 /MIR 删除文件。
robocopy .\project .\project_git /E /XD .git .godot __pycache__ /XF *.tmp
if ($LASTEXITCODE -ge 8) { throw 'Snapshot copy failed' }

git -C .\project_git status --short --untracked-files=all
~~~

旧 README 提到的 build/v16 与旧 delivery 二进制没有随本次交接发送。bundle 与 LFS 可恢复对应历史源码和资源，不能据此声称同时拿到了旧 EXE 或旧发行 ZIP；需要旧二进制时另取原件。

robocopy 退出码 0—7 不等于复制失败，8 及以上需要处理。复制美术会额外占空间；空间紧张时可只留一个开发目录，但仍保留收到的 ZIP 和清单。

叠加后先核对差异。未跟踪后续文档是本次上下文，不要当杂物清掉。art_reserve、引擎、build、evidence、saves、versions 通常被 .gitignore 排除，git status 看不见不表示磁盘没有或不需要；个别历史已跟踪文件仍可能显示修改。

开始新工作时做清楚的“接收交接资料”提交，显式列出需纳入的文档；再独立提交路径修复、内容与模型接入。不要 git add -A 把大型源、临时输出和无关修改混入。保存快照清单，后续代码与资产引用才能追溯。

## 13. 可验收的待办清单

下表是建议的下一阶段拆分。完成标准让接手者知道怎样结束一项工作，不把“代码写了”直接当作体验完成。

| 待办 | 可评审产物 | 完成标准 |
|---|---|---|
| 可移植基线 | 路径修复、接收说明、本机日志 | 原 D: 工程不存在仍能导入启动；七 helper 写本地；冻结对照未悄悄跳过 |
| 内容数据校验 | 字段类型、引用、未知值检查 | 拼错 ID、未知条件、非法数值明确失败并定位字段；旧有效内容通过 |
| 两种以上经营路线 | 有地理/开局条件和代价的样例 | 多输入下各有长处，同时报告速度、存活率和代价 |
| 完整事件线 | 条件、选择、持久结果、后续回应 | 文本与规则一致，进行中旧档可继续，效果实际可见 |
| 中期体验 | 针对等待和重复操作的改进 | 真人能理解下一步；自动支出有上限/记录/关闭入口 |
| 资金与转型 | 小范围经济变化、可选投资 | 固定协议比较不同难度/开局，记录失败，守住人口/研究/污染等约束 |
| 模型接口样例 | 映射与代表资产接入 | surface/材质/变换正确，状态可辨，缺资源可回退，来源哈希可追踪 |
| 模型观感与性能 | 游戏画面、检查记录、帧时间/内存 | 目标缩放可辨；密集期、冷热切换、状态变化、保存恢复都检查 |
| 总督与移交 | 总结、回报、再开局体验 | 旧星收益可解释，归档可读，检查点完整，新局有挑战 |
| 真人整局 | 当前候选版本完整流程与后续对照 | 记录版本/种子/操作/困惑，区分真人意见与机器人统计 |
| 里程碑发布 | 新说明、程序包、源码与证据 | 适用检查通过，缺口公开，EXE 实跑，关键图片已看，旧版可恢复 |

改规则和加机制前先写预期行为与判断标准。不为追求全绿悄悄放宽目标；确需改目标时，将原结果、新定义和理由并列记录。

## 14. 发给朋友与留在原电脑的内容

发给朋友两个交接 ZIP、哈希与清单，以及 START_HERE、VALIDATION、模型说明、索引和图库。只想先玩可打开主包 playable；改代码用 project；模型接入再合并美术包。

不发送个人 APPDATA/存档、账号与凭据、完整 Codex 会话、Godot 本机缓存，以及无关的大量重复发行物和临时运行目录。留在原电脑的历史材料可在确有复核需要时另取，清单要区分“文档引用了”与“原始文件实际随包”。

接手后的第一份反馈可包含四项：实际解压路径、实际运行版本与机器、最先发现的一个玩法问题、准备先完成的一个小里程碑。代码、体验与美术三条工作由此围绕同一个可验收结果推进。

