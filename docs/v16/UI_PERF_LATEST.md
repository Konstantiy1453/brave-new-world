# v1.6 最新正式验收档 UI 响应复测

2026-10-30 16:51，源工程真实主场景运行，Godot 4.5.1.stable.official.f62fdbde1 / Compatibility，Intel Core i9-14900HX / NVIDIA GeForce RTX 4070 Laptop GPU，1920×1080，UI 比例 1.0，60 FPS 上限。此次等待 EXE 的69张截图任务退出后才开始；没有与另一项渲染或矩阵测试并行。沿用首轮的信号触发和逐帧呈现取样方法。

**结果：30个功能样本全部通过，进程退出码0，日志无 ERROR；100ms 可见反馈目标仍为 PARTIAL。** 首次页面首帧156.98—340.14ms；热页首帧16.21—39.56ms。读档首帧414.54—553.68ms，交接首帧887.85—992.41ms，当前版本尚无这些同步步骤的独立忙碌首帧。

地区首次进入首帧18.42—31.94ms，完整地形1.567—1.600s，生产UI显示进度并允许切回球面取消；重复地区完成33.06—34.08ms，从球面返回缓存地区完成20.93—25.06ms。完整新世界图集在线程中继续生成，冷交接完成细化约7.53—8.79秒。三个交接目标依次为260130、260130、文本“殖民契约”，保留冷与热图集条件。

此次加载 `res://data/v16/acceptance_governor.json`（本地第38日正式总督档），代替首轮的v1.5成功档；页面仍使用实际生产按钮，交接使用实际确认对话框。打开事件页前通过生产事件API加入seed_crate节点作为明确的UI夹具。每次页面打开都断言状态字节不变、暂停与页面可见；每次交接都断言active_id=2、当地day=0、地图与UI选区归零、合同页面打开且暂停。

原始JSON的首个读档样本条件标签继承了旧脚本的 `cold_protocol_atlas`，但其 `atlas_source=memory`、`atlas_cached=true`：新验收档与启动世界同为260129，因此该样本是第一次读取该存档，图集已热，不能宣称冷图集。下面表格纠正文字标签；原始JSON/log保留不改。脚本后续已将标签改为 `first_load_startup_seed_atlas_warm`。

| 操作 | 条件 | handler ms | 首帧 ms | 完成 ms | 完整图集 ms |
|---|---|---:|---:|---:|---:|
| load_success | first_load_atlas_memory (label corrected) | 535.330 | 553.681 | 568.223 | 584.286 |
| load_success | warm_same_save | 405.836 | 419.093 | 433.792 | 450.313 |
| load_success | warm_same_save_repeat | 401.202 | 414.544 | 417.053 | 433.757 |
| page_economy | first_open | 291.168 | 306.335 | 313.563 | 313.563 |
| page_research | first_open | 321.400 | 340.144 | 355.440 | 355.440 |
| page_company | first_open | 195.937 | 205.112 | 206.705 | 206.705 |
| page_events | first_open | 230.187 | 240.144 | 252.907 | 252.907 |
| page_career | first_open | 147.895 | 156.980 | 158.149 | 158.149 |
| page_economy | warm_repeat | 29.601 | 35.302 | 39.580 | 39.580 |
| page_research | warm_repeat | 33.605 | 39.452 | 41.175 | 41.175 |
| page_company | warm_repeat | 13.587 | 18.630 | 20.470 | 20.470 |
| page_events | warm_repeat | 15.523 | 18.856 | 25.047 | 25.047 |
| page_career | warm_repeat | 14.953 | 24.714 | 43.338 | 43.338 |
| page_economy | warm_repeat_2 | 28.318 | 38.790 | 42.387 | 42.387 |
| page_research | warm_repeat_2 | 33.499 | 39.563 | 41.652 | 41.652 |
| page_company | warm_repeat_2 | 12.750 | 16.215 | 23.549 | 23.549 |
| page_events | warm_repeat_2 | 15.901 | 30.186 | 43.087 | 43.087 |
| page_career | warm_repeat_2 | 14.425 | 17.816 | 25.450 | 25.450 |
| region_cold | new_region_0 | 7.548 | 18.416 | 1593.679 | 1593.679 |
| region_repeat | cached_region_0 | 7.554 | 16.315 | 34.075 | 34.075 |
| region_return | cached_region_0 | 6.886 | 9.641 | 20.932 | 20.932 |
| region_cold | new_region_1 | 21.739 | 31.942 | 1599.555 | 1599.555 |
| region_repeat | cached_region_1 | 6.813 | 16.338 | 33.056 | 33.056 |
| region_return | cached_region_1 | 6.119 | 9.731 | 21.840 | 21.840 |
| region_cold | new_region_2 | 12.242 | 21.512 | 1566.593 | 1566.593 |
| region_repeat | cached_region_2 | 3.826 | 16.628 | 33.261 | 33.261 |
| region_return | cached_region_2 | 3.508 | 8.192 | 25.060 | 25.060 |
| handover_next_world | cold_new_seed | 971.986 | 992.406 | 1008.425 | 7530.495 |
| handover_next_world | warm_same_seed | 869.324 | 887.846 | 889.089 | 905.972 |
| handover_next_world | cold_text_seed | 950.490 | 968.437 | 969.627 | 8792.813 |

handler为信号回调返回时间；首帧为触发后的首次 `frame_post_draw`；完成为回调/地区完成后的第二个呈现帧；图集细化单独等待。不是操作系统鼠标延迟，也不是人工完整游玩。每操作仅3个样本，不报告稳定P95。

命令（工作目录 `D:\勇敢新世界`）：

```powershell
$env:APPDATA='D:\勇敢新世界\evidence\v16\userdata_perf_latest'
& .\tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe --path game --rendering-method gl_compatibility --script res://tests/v16_interaction_probe.gd -- --report=res://../evidence/v16/ui_perf_latest.json
```

原始结果为 `evidence/v16/ui_perf_latest.json` 和 `.log`；JSON记录实际缓存Script的source_code哈希，能够区分本次进程所加载代码与之后的工作区变化。首轮旧存档结果 `ui_perf.json/.log` 和 `docs/v16/UI_PERF.md` 保留为历史测量，不覆盖。

最新独立审查：`career_review_latest_green.json/.log` 实际重跑7项通过、exit0、无ERROR；`research_company_review_final_green.json/.log` 17项通过，包含后续发现的人口就业重建保留已支付科研岗位。原始红记录继续保留。前者为受控财务/快照变异回归，后者含明确注入的科研人员和实验所建造资源，均不当作自然玩家通关证据。
