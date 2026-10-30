# 1.6 交付验证记录

2026-10-30，工作目录 `D:\勇敢新世界`，Godot 4.5.1.stable.official.f62fdbde1，Windows x64 Compatibility。硬件 Intel Core i9-14900HX / NVIDIA GeForce RTX 4070 Laptop GPU。源工程、自动经营、图形主场景、导出程序和OS点击分开记录。旧版证据保留；本报告不把历史1.5结果算成本轮通过。

## 自动规则与整合

|执行|实际结果|主要证据|
|---|---|---|
|F01/F02/F07/F08、批量/目标库存|9项0失败|economy_green3.log|
|科研/公司独立负变异与就业审查|17项0失败|research_company_review_final_green.json|
|科研曲线/集中分散/公司三路线/后矿业|35项0失败|rules_final.log / rules_results.json|
|完整经营旧套件适配新机制|96项0失败|sim_regression_budget_final.log|
|原创事件全分支/调查/真实订单/存读/幂等|431项0失败|events_verified.log / events_manifest.json|
|道路截止日真运输函数|22项0失败|f12_transport.json|
|生涯原子移交/分红/重开|21项0失败|career_streams.log|
|全球/当地日历、难度重开、矿床衰竭|19项0失败|career_boundary_final.log|
|代管税费/旧星完整快照独立审查|7项0失败|career_review_latest_green.json|
|嵌套旧档与损坏类型拒绝|21项0失败|save_nested_final.json|
|生产UI模态/等时/长帧/强制决策/任命/接管|20项0失败|ui_release.log|
|原UI契约适配强制暂停|通过，退出0|ui_contract_updated.log|
|固定27组180日经营|全部任命，逐日审计空，研究48/126日|flow_matrix_final.json + flow_matrix_budget.log|
|新局→B→第二星→分红注资→存读续算|通过|acceptance_flow.json / flow_fixtures_release.log|

这些套件有重叠，不将检查数机械相加当作独立覆盖率。受控夹具和正式动作区别见 ECONOMY、EVENTS、CAREER、BALANCE。世界16种子一致性、7569格点缓存、真实地形字节一致、道路标签/材质、旧档拒绝等见 WORLD.md 及 world_manifest.json。

旧40秒/10秒UI对照在新版第6日强制事件时不再表示等模拟日；更新为事件前4日的20秒/5秒对照，并由20项新版UI测试另验强制中断。原科研开局固定45日投资失败保留为策略反例；预算试验不是修改规则强迫全开局同日成功。

## 最终Windows构建

`tools/build_v16.ps1` 重新导入并导出，退出0。最后构建日志 **build_verified.log**，EXE SHA256 `78CCC576E8F8BFFD7EF6AD6F36EBD72A41E609A1052225A55B3407C96EA84065`，PCK SHA256 **`EDDB8C151C78DE9947D0DF456300B806098F971F366F7C9BE943661A64DBADAA`**。引擎EXE可与旧版相同，游戏内容身份以PCK和完整源清单确定。

发行前OS操作发现导出专属问题：脚本编译后源码`.gd`不存在，旧的FileAccess存在检查误判事件模块缺失；已用preload资源入口修复。前一候选PCK `CEA1314A...` 不作为交付版。最终EXE截图过程逐个存档比较生产事件暂停入口与实际事件状态，另做OS按键/点击确认。所有先前红日志保留。

最终69张导出截图在 `evidence/v16/screenshots_verified`，3种分辨率×3种字档覆盖科研、公司、事件、代管、存读，并涵盖其他经营与地图页面。科研使用真实science第30日在研档。视觉记录见 VISUAL.md 及最终复核补充；截图不是完整人类通关。

## 实际窗口与持久化

OS操作使用Windows computer-use技能。隔离用户目录 `evidence/v16/userdata_manual/ColonyCharter/v16`，没有操作玩家原存档。已实际点击保存、Alt+F4正常退出、启动新进程、主菜单“继续上次存档”、Ctrl+S和F12；第36日完整状态重读后保存SHA256仍为 `EB233E729EDA3AD16EC6248FF8EB67C6DD1D6886A221CCB164A1EEF6355AFDE8`。随后实际继续经营，第二星38日取得资格并保存。

最终EDDB构建读取该真实38日档；按空格即打开待决事件并保持日历38日/生涯76日。实际点击“签收入库”使事件结案，食品按配置入账；保存记录见 manual_verified_event.json。关闭窗口后仍暂停，实际点击快进继续日结。最终过程状态、日期、存档哈希和退出码见 manual_verified_report.json；截图由游戏F12落盘。

该验证是实际OS操作的针对性试玩，**不是20—40分钟全程人类盲玩**。自动跨星流程、OS针对性验证、截图观察分别成立，不互相替代。

## 性能与已知问题

真实主场景30交互样本、96断言通过；热页首次呈现16.21—39.56ms，首次打开156.98—340.14ms；读档414.54—553.68ms；交接887.85—992.41ms。首次地区18.42—31.94ms提供反馈，约1.57—1.60秒完成；缓存返回20.93—25.06ms。见 UI_PERF_LATEST.md。样本不构成稳定P95；静止画面60FPS不代表按钮响应。

**100ms首次反馈目标PARTIAL**：管理页、读档和交接仍含同步等待；地区已有进度、取消和缓存。长期非最优策略平衡、人类首次阅读节奏及千万级人口真实性能未验证。地区地形保留既有表现，部分边界标签可能重叠、河道仍有阶梯/切边感。B是明确汇总代管模型，没有完整后台旧星物流或可返回旧星操作。

## 复现与回退

PowerShell下先为每套测试设独立APPDATA，再使用本地引擎：

```powershell
$env:APPDATA='D:\勇敢新世界\evidence\v16\userdata_reproduce'
& './tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe' --headless --path game --script res://tests/v16_events_tests.gd
& './tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe' --headless --path game --script res://tests/v16_flow.gd
```

其他脚本同目录，对应日志和专项文档记录入口；不要将测试APPDATA环境带到另一个终端的发行导出模板查找中。重新生成交付档是单独显式命令 `v16_flow.gd -- --fixtures`，正常对照不会覆盖它们。构建用独立 `build/v16`，打包 `python tools/package_v16.py`。源码ZIP不含Godot编辑器和导出模板，重建需4.5.1标准版与Windows模板；当前工作目录已具备。

原版可执行基线、源码、用户存档及SHA在 `versions/v1_5_before_v1_6_20261030_125059/BASELINE.json`。1.6正式档独立位于 `%APPDATA%/ColonyCharter/v16`；原1.5目录不改写。旧档兼容和越界历史种子恢复方法见README。最终关键文件SHA、包内字节核对与ZIP CRC结果见release_identity.json和delivery/v16/PACKAGE_MANIFEST.json。

最终源/构建清单包含159项；冻结基线212文件均逐SHA校验一致，原用户目录16个保存/设置文件与开工快照逐SHA一致。最终EDDB构建第42日存档在退出0、重启读取、再次保存后SHA仍为E81ABECFC02931604C0B2BBBDCFE03A959A172A35FE4D47B6885F7EC9041CA16。最终渲染进程exit0，capture_report.failures=[]，构建/最终截图/两次最终窗口日志无ERROR或SCRIPT ERROR。源码ZIP不打包历史v1.5快照及Godot工具；引用旧地形例程的历史比较需当前工作目录versions快照。

## 最后库存控件校正与发行身份

最终构建日志build_delivery.log（exit0），PCK **5D907101B22EC43C379E5AD1BE08835500F1F92F498F862FAB9250784E275016**。与此前EDDB构建相比，只校正库存目标编辑框实际默认值、上限与微吨显示精度，并扩展开发截图门禁；main、sim、公司、科研、事件、生涯、地理规则未改变。独立实际控件45断言0失败，默认201.6/160/40、超过5000的合法目标、小数与上下界均在1e-6吨误差内保持，详见manage_target_precision_green.json。最终9张管理页3分辨率×3字号来自screenshots_targets_delivery，capture exit0/failures=[]；先前69张全页面保留其EDDB构建身份，最终两处说明按像素/源差异继承，不改写历史哈希。

最终5D907构建已另实际启动，OS点击继续第42日档，Ctrl+S后SHA仍为E81ABECFC02931604C0B2BBBDCFE03A959A172A35FE4D47B6885F7EC9041CA16，空格正确打开强制事件、日期不变，退出码0。见manual_delivery_report.json。最终文件身份以release_identity.json为准，旧EDDB清单另存release_identity_EDDB.json。
