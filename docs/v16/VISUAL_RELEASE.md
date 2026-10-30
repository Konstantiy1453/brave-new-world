# v1.6 最终导出视觉复核

**交付版窄修追加：最终资源包现为5D907101…275016。前版EDDB的69张完整视觉范围保留；交付版另新增9张批量管理截图，三分辨率×三字号全部直接查看，目标值201.6 / 160.0 / 40.0与模拟一致。详见文末追加记录。未在交付版重跑完整69张。**

最终资源包对应的69张截图已完成可见区域审查：**55张最终截图由两名审查代理直接逐张打开查看；14张与已直接查看过的上一轮截图在文件字节和RGB像素上完全一致，明确继承该视觉结论。未发现阻断使用的布局缺陷。** 这覆盖69张所记录的页面视口，不代表所有滚动位置、事件分支或完整人工游玩。

最终图像在 `evidence/v16/screenshots_verified`，2026-10-30 17:22导出、17:25:56完成截图。`capture_report.json` 为69项、failures为空；主代理记录capture进程14912退出码0，本次独立扫描 `capture_verified.log` 无ERROR或SCRIPT ERROR。硬件记录为i9-14900HX、RTX 4070 Laptop GPU。最终文件身份经SHA256重新核对：

| 文件 | 字节数 | SHA256 |
|---|---:|---|
| build/v16/ColonyCharter.exe | 96,725,504 | 78CCC576E8F8BFFD7EF6AD6F36EBD72A41E609A1052225A55B3407C96EA84065 |
| build/v16/ColonyCharter.pck | 77,502,572 | EDDB8C151C78DE9947D0DF456300B806098F971F366F7C9BE943661A64DBADAA |

实际观察到的截图进程命令为：

```text
"D:\勇敢新世界\build\v16\ColonyCharter.exe" --log-file D:/勇敢新世界/evidence/v16/capture_verified.log -- --qa-v16=D:/勇敢新世界/evidence/v16/screenshots_verified
```

用户数据隔离在 `evidence/v16/userdata_capture_verified/ColonyCharter/v16`。本轮图片均为Godot实际导出程序渲染，未绘制概念图或改动像素。

| 页面范围 | 分辨率 | 字号档 | 最终覆盖 |
|---|---|---|---:|
| research、company、events、career、save | 1280×720 / 1920×1080 / 2560×1440 | 16 / 18 / 20 | 45张 |
| planet、flat、region、economy、contract、enterprise、transport、manage | 同上三种 | 18 | 24张 |

字号为产品的16/18、1、20/18内容缩放档位。最终69张的实际PNG尺寸均与文件名一致。每张PNG哈希、比较基准、差异像素数量、是否最终直接查看、审查代理、夹具和游戏日期都在 `evidence/v16/visual_verified_inventory.json`。其中world代理直接查看31张、economy代理直接查看24张；两份逐图记录分别为 `visual_verified_world_review.json` 和 `visual_verified_economy_review.json`。

比较方法与证据继承：先直接查看上一轮release的45张（科研/设置18张、基础页24张、company/events/career在1280×720大字号3张），保留 `release_visual_direct_view.json`。再将最终69张分别与该45张或首轮已查看的剩余24张核心页比较。结果有14张文件字节完全相同，也逐RGB像素确认相同；其余55张即便只差1个背景像素也全部重新打开查看。对比及证据覆盖校验命令 `python evidence/v16/compare_verified_visual.py` 实际退出0。14张继承图为：

- 三分辨率的flat与region，共6张；1280×720的manage。
- 1280×720 20px的events；三分辨率20px的save。
- 1920×1080和2560×1440的18px research；2560×1440 18px enterprise。

关键观察和已修复问题：

- **批量管理已修复。** 首轮三个分辨率出现标签被挤成单字竖列的问题，主代理增加标签最小宽度并允许横向扩张。最终三个分辨率均是左侧完整横排标签、右侧启停或数值控件，五行全部可见。首轮问题截图仍在 `screenshots/manage_*`，修复后的图在 `screenshots_verified/manage_*`；1280图严格相同继承，其余两张最终直接查看。
- **科研九组可读。** 改用正式 `acceptance_research.json` 第30日活动科研档：总研究员12、可用3、实验室容量10，精细勘探分配9/实投9、速度1.249、剩余22.3、预计18日。项目经费、工资另计、前置要求、分配输入和暂停按钮可辨。介绍文案结尾句号孤行已消失。
- **设置九组可读。** 保存/读取和四个v1.6验收档按钮未横向截断；下方兼容读档与显示选项属于可滚动区域。此轮顶端PNG不承担下方控件的可达性结论。
- **基础页已补齐。** 球面、平铺和地区三种地图的地形、标记、道路、建筑和选区侧栏可见；经营账本各账户、本地库存、外部流入分类清楚；企业卡片、运输方案与当前线路信息可辨。契约文案在“240/日”与“¥/5090”之间换行稍生硬，但数字与句子可读，属润色项。
- **公司/事件/生涯完整覆盖九组。** 公司风险、整改期限、援助条款与按钮未发生互相遮挡。第二援助卡延伸到滚动区下方，固定页脚独立。事件截图为第25日调查中段；生涯截图为第二星球登陆36日、生涯74日及分红余额443.18。关闭按钮、输入框、检查点恢复按钮和主要文本均可辨。

截图与交互分别记录。首轮源工程滚动补验有39按钮、51断言和5张页底图片，详见 `VISUAL.md` 与 `evidence/v16/scroll_source/report.json`；未在本次最终EXE中重跑该自动滚动探针。主代理另用真实Windows点击/按键验证最终EXE的事件选项、待决停时、快进遇第42日事件停止、保存退出/新进程继续后字节一致，记录在 `manual_verified_report.json`，其证据范围独立于本视觉审查。

历史轮次保留：`screenshots` 为首轮45核心页审查；`screenshots_release` 对应CEA1314A…资源包，视觉可用，但主代理随后发现该导出包的待决事件暂停门控错误，因此它不是最终行为验收版本。最终以EDDB8C15…及 `screenshots_verified` 为准；本报告仅在逐字节/像素一致的14张上继承先前视觉观察，未将旧程序运行算作新程序运行。

暂停温缓存球面每种分辨率120帧P95分别16.67、16.67、16.75ms；这只描述静止场景。真实交互的30样本在 `UI_PERF_LATEST.md` / `ui_perf_latest.json`，首次页面、读档及交接超过100ms且缺少统一立即反馈的状态继续记为 **PARTIAL**，不因截图成功而改为通过。

**2026-10-30 17:48交付版批量管理目标窄修。** 主代理在此前布局复核后发现三个输入初值统一显示100，没有取实际库存目标。改为调用 `sim._target()` 后，验证又发现SpinBox步长5把食品201.6量化为200；步长0.1仍会把合法自定义201.65等值四舍五入。最终使用微吨（0.000001吨）输入精度、0.1吨箭头步长，输入上限至少10000以覆盖模拟允许范围；界面初始化读取当地实际目标。

新增9张实际EXE截图在 `evidence/v16/screenshots_targets_delivery`：1280×720、1920×1080、2560×1440各16/18/20字号。9张均已用view_image逐张直接查看，标签、数值、按钮、关闭控件和页脚没有遮挡或截断，所有截图均显示食品201.6、建材160.0、部件40.0。所选据点是人口42的铁岬盆地，食品计算为 `max(180, 42 × 0.16 × 30) = 201.6`；总人口60不用于单个据点的目标。导出capture同时将三个SpinBox值与实际 `_target()` 比较，capture_report的9项全部完成且failures为空，日志无ERROR。

| 交付版文件 | 字节数 | SHA256 |
|---|---:|---|
| build/v16/ColonyCharter.exe | 96,725,504 | 78CCC576E8F8BFFD7EF6AD6F36EBD72A41E609A1052225A55B3407C96EA84065 |
| build/v16/ColonyCharter.pck | 77,503,196 | 5D907101B22EC43C379E5AD1BE08835500F1F92F498F862FAB9250784E275016 |

生产控件的独立探针 `game/tests/v16_manage_target_review.gd` 在Godot4.5.1无头模式中实例化真实manage页面、调用真实sim和三个“设置目标”按钮回调。最终 `manage_target_precision_green.json/.log` 为**45断言通过、exit0、无ERROR**：覆盖默认201.6/160/40、超过5000的7012.3/8021.7/9999.9、自定义201.65/160.25/40.125、端点0与10000及201.6501234微吨边界；四种场景打开页面均保持模拟字节不变，提交误差均不超过1e-6吨。该行为验证使用最小页面上下文，不冒充主场景OS点击。

交付新增图逐图尺寸、SHA256、实际观察数值及PCK身份在 `visual_targets_delivery_review.json`，本次文档/测试/日志/9张截图哈希在 `visual_targets_delivery_manifest.json`。精度修正前的截图目录 `screenshots_targets`（930530CC…候选）、`manage_targets_candidate_red_review.json`、实际6项失败的 `manage_target_precision_red.json/.log` 均保留。最终交付证据应写为“前版69张已查＋交付窄修9张新查”；不把不同PCK下的78张描述为同一次全套运行。
