# 模拟实现与验证报告

2026-10-29，Godot 4.5.1.stable.official.f62fdbde1。权威模拟：`game/simulation/sim.gd`；数值、配方、三种开局、六项科研、三次事件和合同：`game/data/economy.json`。世界生成器由 world 模块提供，新局版本 CC-GEO-1.5，兼容完整 CC-GEO-1.4 旧档。

## 可用接口

- `new_game(seed_value:int, advantage:String, size:int=1)`；优势 `capital/workers/science`。
- `act(action,args)->String`：成功空串，失败中文原因。支持 settle/build/connect/research/enterprise/policy/event；额外支持 toggle `{region,index}` 关闭/开启具体设施。
- `tick()`：固定一天；planning/failed 不推进；成功后继续经营。暂停与速度由 UI 控制调用次数。
- `save_game(path)`、`load_game(path)`：空串成功。带版本、SHA-256、可读 JSON 和精确 Variant 快照的 JSON 封装；对象反序列化关闭。临时同目录写入、回读检查、原文件 .bak 备份后 rename 发布。旧的 payload-only 版本1存档仍接受，前提是世界生成器版本匹配。
- `settlement(region)`、`build_preview(region,kind)`、`contract_progress()`、`summary()`、`audit()` 为 UI/验证辅助。contract_progress 返回 connected/food/housing/employment/industry/enterprise/solvent/streak/required_streak。

## 核心状态

state.cash/resident_cash/enterprise_cash 对应公共、居民、民营账户；external_in/out 是累计外部现金流，initial_money=0，所有初始资金都由外部注资交易明确记账。ledger 行含 day/category/amount/from/to/operating，amount 为正；日志最多120行、账本1800行、经营趋势90天，累计外部现金和物资守恒量一直保存。

经营净值采用当日应计公共经营口径：工资、维护、食品进口、运输和行政费用计入，建设与融资排除。未付经营款形成按收款方保存的 arrears；后日偿还不重复进入经营支出。民营初始资本来自外部投资人，自行购买本地材料、外部设备、租场、雇工、支付维护、向居民售生活服务、仅对正利润缴本地税。公司分成从履约次日起，以正的公共账户税前经营结余乘15%，亏损不缴。

建筑字段 remaining/active/enabled/status/reason/employed/specialists/efficiency/owner。据点字段 stock/stock_delta/jobs/employed/employed_workers/employed_scientists/housing/food_days/shortages/power_supply/power_demand/water_supply/water_demand/port_capacity/port_used/arrival。shipments 是 from/to/resource/amount/remaining/total_days/expedition；装车即从起点扣除，到达才增加终点。首个前哨远征可在尚未常设道路时携带一次性队伍物资，经已验证陆路且有实际行程；以后自动补给须道路。物资总量包含在途。

食品政策单位是“天”，默认12天。初始物资不会被自动当作经营产品出售；建材/部件出口额度须来自本地加工。矿储量有限，勘探增加产率而不创造矿储量。公共与民营不重复占用同一工人；迁移、职业培训后立即重排岗位快照，存档不依赖额外tick修复。

## 实际 headless 结果

命令（cwd `D:\勇敢新世界`）：

```powershell
& '.\tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe' --headless --path '.\game' --script res://tests/sim_tests.gd
```

首次测试在 API 尚不存在时实际失败；随后逐步实现。当前95项PASS、0FAIL，退出码0。包括第一笔外销、建设失败不扣款、海洋无法陆路拓展、在途物流、企业实际营业/付薪/缴税、资金和物资守恒、三种90天生存开局、三种180天完整履约路径、付款与供应失败宽限、无效存档不覆盖运行状态、精确存读和15天相同后续结算。

保存浮点回归：Godot JSON 小数解析会产生约1 ULP差异；单纯full_precision JSON并非位精确。存档因此保留无对象Variant精确快照，测试比较完整状态规范序列化结果及继续15天后的完整状态，均PASS。JSON字段仍保留供审查。

推荐种子260129，以下为自动调用正式act接口的回放，未修改资金/库存/人口：day0登陆铁岬并建铁矿+铜矿；科研优势另建学院并以2倍科研投入研究精细勘探；day16引入服务社；day24建立青溪河谷前哨、连接普通绕山道路；day28建河谷农场；day45建加工厂；资本/工人路线day60建学院并研究精细勘探；事件优先选择付费方案，条件不足时选第二方案。

|路线|首次履约日|第180天资金|累计公司税|每日守恒|
|---|---:|---:|---:|---|
|资本|38|14018.57|1836.65|PASS|
|工人|36|15360.38|2230.76|PASS|
|科研|38|7425.16|1121.53|PASS|

`game/data/acceptance_midgame.json` 是上述资本路径第29天完整真实模拟状态：两据点、陆路和在途货物、民营企业、施工中河谷农场。`game/data/acceptance_success.json` 是同路径第38天履约状态。重新运行测试会按确定性路径生成这两个文件；不属于人工UI试玩存档。

## 范围与限制

这些是实际Godot无界面逻辑执行，不能替代编辑器/导出程序运行、真实UI操作、画面观察或目标20–40分钟体验验证。当前最快自动履约36–38模拟天，按UI每5秒1天仅约3分钟等待，合同偏容易；20–40分钟目标未凭这些测试得到验证。三次事件在35/85/135天出现，后两次可发生于履约后沙盒。UI实操与性能、三分辨率、导出验收由主报告另列。

人口为地区职业/年龄汇总，生育每360游戏日、出生者5760天成年、初始儿童2880天成年；短局主增长来自有空岗且供给充足时的工人移民。只有商业服务这一类民营企业，不含个体寻路、市场竞价、海运或第三据点。私营经营可能因购买力不足连续亏损或缺人15天而停业，原因可见。

补充边界测试：无电/无水/无工人停产；没有配方输入不产出；晶体储量0.25只产0.25；远征到达前库存为0；不足人员扩张完全不扣款；孤岛首府拒绝；亏损日无总督税；第11天仍在付款宽限、第12天失败；合同整改期最后一天结束。边界夹具会直接设置状态，明确与三条仅act正常游玩回放分开。原始最终运行输出：evidence/sim_v15_final.log。


本表为CC-GEO-1.5随机地理与实际水系接入后的重新执行结果。旧1.4数值见evidence/v1_4/SIM_REPORT.md，未用旧结果覆盖新数值。损坏存档21项在1.5中期档上复跑通过，日志docs/evidence/save_nested_regressions_v15.log；旧UI50日档仍完整可读。
