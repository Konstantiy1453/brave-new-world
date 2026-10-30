# v1.6 实际主界面交互性能

本报告来自实际 Godot 主场景的图形运行。以生产导航按钮的 `pressed` 信号、交接确认对话框的 `confirmed` 信号触发动作，完整执行现有 UI 回调；不包含操作系统鼠标送达时间。2026-10-30，Godot 4.5.1.stable.official.f62fdbde1，Compatibility，Intel Core i9-14900HX / NVIDIA GeForce RTX 4070 Laptop GPU，1920×1080，UI比例1.0，60FPS上限。

**状态：功能集成 PASS；首次操作约100ms反馈目标 PARTIAL。** 共30个样本，页面只读、强制暂停、读档/换星球选区同步、真实交接提交等断言全部通过；退出码0，日志未出现ERROR。首次页面、读档和交接仍有同步耗时，不能把温缓存结果当成所有操作达标。

取样口径：handler 为信号回调返回耗时；首帧为动作发出后首次 `frame_post_draw`；完成为回调/地区加载结束后的第二个呈现帧；完整图集细化单独计时。每个页面3次（首次与2次重复），每个地区操作3次（地区0/1/2），每个读档/交接3次。样本不足以给出稳定P95，不报告平均FPS代替交互。

| 操作 | 条件 | handler(ms) | 首帧(ms) | 完成(ms) | 完整图集(ms) |
|---|---|---:|---:|---:|---:|
| load_success | cold_protocol_atlas | 486.872 | 505.241 | 516.899 | 9357.407 |
| load_success | warm_same_save | 322.014 | 335.144 | 349.264 | 365.913 |
| load_success | warm_same_save_repeat | 330.131 | 343.868 | 350.189 | 366.963 |
| page_economy | first_open | 293.038 | 308.470 | 314.818 | 314.818 |
| page_research | first_open | 290.678 | 305.247 | 307.893 | 307.893 |
| page_company | first_open | 196.156 | 205.373 | 208.946 | 208.946 |
| page_events | first_open | 123.865 | 131.072 | 141.787 | 141.787 |
| page_career | first_open | 152.175 | 161.009 | 177.001 | 177.001 |
| page_economy | warm_repeat | 30.195 | 36.272 | 41.288 | 41.288 |
| page_research | warm_repeat | 34.564 | 40.060 | 42.478 | 42.478 |
| page_company | warm_repeat | 13.608 | 19.491 | 24.780 | 24.780 |
| page_events | warm_repeat | 13.011 | 16.168 | 26.023 | 26.023 |
| page_career | warm_repeat | 14.930 | 18.561 | 27.517 | 27.517 |
| page_economy | warm_repeat_2 | 27.532 | 32.529 | 44.961 | 44.961 |
| page_research | warm_repeat_2 | 33.853 | 39.313 | 40.695 | 40.695 |
| page_company | warm_repeat_2 | 13.943 | 17.511 | 26.156 | 26.156 |
| page_events | warm_repeat_2 | 12.059 | 15.131 | 26.795 | 26.795 |
| page_career | warm_repeat_2 | 14.633 | 17.885 | 20.379 | 20.379 |
| region_cold | new_region_0 | 7.384 | 17.137 | 1610.838 | 1610.838 |
| region_repeat | cached_region_0 | 8.199 | 16.241 | 32.940 | 32.940 |
| region_return | cached_region_0 | 7.219 | 10.039 | 21.771 | 21.771 |
| region_cold | new_region_1 | 22.164 | 32.614 | 1599.184 | 1599.184 |
| region_repeat | cached_region_1 | 7.994 | 16.606 | 33.428 | 33.428 |
| region_return | cached_region_1 | 6.167 | 9.482 | 22.805 | 22.805 |
| region_cold | new_region_2 | 14.618 | 23.644 | 1566.035 | 1566.035 |
| region_repeat | cached_region_2 | 4.019 | 16.514 | 33.720 | 33.720 |
| region_return | cached_region_2 | 3.156 | 8.248 | 25.169 | 25.169 |
| handover_next_world | cold_new_seed | 997.496 | 1019.776 | 1033.977 | 7722.809 |
| handover_next_world | warm_same_seed | 877.379 | 893.939 | 906.846 | 924.026 |
| handover_next_world | cold_text_seed | 939.977 | 958.181 | 965.386 | 8971.752 |

首次页面handler为123.865—293.038ms，首帧131.072—308.470ms；温缓存页面handler12.059—34.564ms，首帧15.131—40.060ms。已加载地区重复进入完成32.940—33.720ms，离开后返回21.771—25.169ms；首次地区显示1.566—1.611秒，但首帧17.137—32.614ms，有实时进度和可取消导航。

读档同步handler322.014—486.872ms。交接同步handler877.379—997.496ms，首帧893.939—1019.776ms；后续图集细化独立在线程中完成。此测量版本尚未给读档、交接和首次管理页面提供独立忙碌首帧；这些是剩余响应性限制，不能记作已达成100ms。启动主场景同步耗时1458.771ms（含初次世界和UI构建，不等于完整启动到桌面点击延迟）。

性能夹具：加载原版 `res://data/acceptance_success.json` 后通过当前迁移入口进入v1.6；事件面板加入一个生产事件API打开的seed_crate节点，明确作为UI测试输入。每次交接都重新读取该成功档，目标种子前两次260130，第三次文本“殖民契约”；断言active_id=2、当地day=0、合同面板打开且暂停、主UI与地图选区均0。测试不宣称重复三次从零自然通关。

命令：

```powershell
$env:APPDATA='D:\勇敢新世界\evidence\v16\userdata_perf'
& ./tools/godot-4.5.1/Godot_v4.5.1-stable_win64_console.exe --path game --rendering-method gl_compatibility --script res://tests/v16_interaction_probe.gd
```

测试只在隔离的 `evidence/v16/userdata_perf/ColonyCharter/v16` 写入派生图集、日志和交接存档。结果为 `evidence/v16/ui_perf.json` 与 `.log`。后续若实现UI异步忙碌状态，应保留本次原始报告作为修复前证据，再使用新报告名重测。

独立审查补充：`career_review_green.json/.log` 中7项生涯财务与完整快照门禁断言通过；`research_company_review_green.json/.log` 中14项科研人员归属、即时停用、人员整数/总量和援助字段门禁断言通过。原始red证据均保留。
