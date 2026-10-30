# 1.5 地图视图与首次加载验证

2026-10-29；Windows / Godot 4.5.1 / OpenGL Compatibility / NVIDIA RTX 4070 Laptop GPU。

## 实现范围

- `map_view.show_flat()` 切换到等距经纬投影，`mode == "flat"`。平铺与球面共用同一张权威地理 atlas，支持缩放、平移、点击地区、据点状态、当前选区、真实陆运路径和在途货运点。
- 所有地图地理采样显式使用存档的 `world.version`。1.4 地区保留旧河道规则；1.5 使用 `world.rivers`、`river_metadata.heights` 和 `world.lakes`。地球旋转后的坐标通过 `project_coordinate` / `unproject_coordinate` 与地区坐标互换。
- 三种视图共用从同一保存河网得到的圆角显示路径。插值水位保持下游不增高；局部河床按该水位降低并向两岸平滑混合。显示插值没有改写权威格网、坡向、路线或存档。
- 河流取消道路式中心亮线，宽度沿程小幅改变；植被避开水体。树木按采样位置的雨量、温度和 biome 门控，荒漠、高山与冻原使用岩石。道路按现有实际服务路径分段贴地及跨水，未增加虚构跨区出口。
- 默认完整 atlas 为 1536×768。未缓存的世界先显示 384×192 预览，再由独立噪声实例与只读地理参数在后台生成完整纹理，结束后同时更新球面和平铺。内存、磁盘缓存各最多 2 张。缓存键包含纹理协议、分辨率、world 版本、seed、size 与 generation 参数 SHA256。
- 推荐 seed 260129 的程序生成 atlas 已作为正式工程资源随包导出。因此推荐世界的新机启动不需要先生成这张图。

## 原生执行与观测

工作目录：`D:\勇敢新世界`。

执行：`tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe --path D:\勇敢新世界\game --script res://world/flat_render_test.gd`；第二个 seed 使用 `-- --seed=260130`。

最后推荐 seed 探针退出码为 0；16 项断言全部通过。覆盖平铺可见性、正交投影、经纬原点、投影点击/信号、6 个据点、真实路线及货运点、缩放平移、返回球面、透视恢复、进入地区、真实水系局部裁剪、旋转坐标往返、显示水位单调、主循环持续运行、同世界缓存复用、缓存容量。

| 场景 | setup 实测 | atlas / 后台实测 | 证据 |
|---|---:|---:|---|
| 原串行 1536 冷生成，修复前 | 32340 ms | 32259 ms 阻塞 | `evidence/flat_render_serial_atlas_v15.*`，保留失败性能基线 |
| 260129 无缓存，预览后后台生成 | 2034 ms | 1965 ms 预览；8582 ms 后台，期间 497 帧 | `evidence/flat_render_cold_260129.*` |
| 260130 无缓存，预览后后台生成 | 1681 ms | 1610 ms 预览；6798 ms 后台，期间 389 帧 | `evidence/flat_render_cold_260130.log`、`evidence/flat_render_test_260130.json` |
| 260129 正式随包 atlas | 131 ms | 57 ms，`initial_atlas_source="bundled"` | `evidence/flat_render_test.json`、`evidence/flat_render_fit_v15.log` |
| 同进程再次载入 260129 | 73 ms | atlas 0 ms，内存复用 | 同上 |

上述 setup 时间不包含窗口创建、整个世界生成或 UI 初始化，不能等同于整程序启动时间。冷生成数据是在打包 atlas 前、且该键没有磁盘/内存缓存时测得。最后随包测试明确记录来源为 bundled，而非开发机磁盘热缓存。冷生成试验后又调整了初始日照与植被门控，后台线程与采样数值未变化。

## 已实际查看的图像

最后推荐种子 4 张 1600×900 原生渲染均已逐张打开：`world_flat_v15_fixture.png`、`world_flat_zoom_v15_fixture.png`、`world_planet_v15_fixture.png`、`world_region_v15_fixture.png`，位于 `docs/evidence/`。地图边框清楚、平铺标签没有左侧越界，主大陆初始位于球面可见受光区域，河道已平滑且没有中心道路白线。

另逐张查看同名带 `_260130` 后缀的 4 张图，确认大陆和候选位置随 seed 变化。这组图来自初始日照与植被门控调整之前，属于第二 seed 冷生成探针记录，不作为最后发布界面的截图。

这些探针使用生成器的真实世界与路线，但人口住宅、两据点和一条在途货运是构造的渲染 fixture，没有执行完整经济生产。最终 UI、验收存档及发布截图另由 `VISUAL_V1_5_QA.md` 和运行验收记录覆盖。

## 哈希与素材来源

- 冻结 `game/world/map_view.gd`：`0CFBEE65341F3E02EA6A08726BCDE03571FC59FFB486661F5E79B51337779FDF`。
- `game/world/flat_render_test.gd`：`CD2BE051EDA3E31E40017C097F4CC5DBFBEC6AA60CF17352AE2A44702326465C`。
- 随包 PNG：`game/assets/generated/world_atlas_d0139459574cf5351f59c4a47e4409eef99bd1bd7481d8dc7eae051297abbe9d.png`；SHA256 `CF7D8ED9B7A7C9488EC30D9C78B09B0C327E4B0E718EF0FAB6EA7CE29FD16826`。
- atlas key：`atlas-1536-r3:CC-GEO-1.5:260129:1:ade5af9348d84bcbf330d1cc78b14b4d23ffdfcb1df9fb9d4515c62c06ff79fc`。
- 由本工程 `sample_with_context` 与 `_geo_color` 确定性程序生成；RGB 为地表颜色，alpha 为编码地表高度；不是外部购买或网络下载素材。

## 范围与限制

本项结论为功能与上述图像采样通过。河网仍是粗格网汇水模型的显示插值，地区为可操作的地形切片，植被和建筑仍采用低多边形图形。细节精修与完整美术品质保持 PARTIAL，不能把几张正确渲染的图升级为商业级美术验收。

