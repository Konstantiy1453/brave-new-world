# 殖民契约 1.12.0：新的地形与定居点

新远征用新的地形生成器 CC-GEO-2.3（山地和高原有积雪），区域图里的定居点按定稿第 06、07 版重做。规则和 1.11 相同，存档通用。

**下载**：`ColonyCharter-1.12.0-Windows-x64.zip`（64 位 Windows 10/11，OpenGL 3.3）。解压后 `ColonyCharter.exe` 和 `ColonyCharter.pck` 放在一起，双击运行。

SHA-256：`3465FDDC82A48A0C695A0D88E1CBBF43EA301FE3BA05B8FFD024FF5ECCB1F357`

## 更新内容

- **新地形**：大陆、山地、高原和水系由新的生成器生成；球面和卫星地图上，雪线随海拔、气温、湿度和坡向变化。
- **定居点按真实尺寸**：建筑之间约 60 米空地，主路 8.6 米、支路 6.2 米、工业路 7.0 米，街道随地形轻轻弯曲。
- **街道跟着你的建筑**：连着的建筑才有支路，远处的矿场单独修路接到最近的路上。
- **地面、植物和岩石**：风化壤土和稀疏草皮、路边压实的土和碎石、树、灌木、细草和风化巨石，跟着落脚点的气候。
- **水**：只有真正的海岸、河流和湖泊处才有水；河流顺着地势弯曲，颜色更沉稳。
- **傍晚的光线、天空和远处的雾**照定稿调整：远处的山野隐入雾中，镜头对着的城镇保持清晰。
- **修正**：在没有推荐地点的岛屿或大陆上，落脚点面板显示可以建首府，确认后却被拒绝；现在面板说可以的地方都能建。
- 旧存档保持原来的地形和定居点位置；存档格式不变（和 1.11 共用存档文件夹）。

完整说明见压缩包里的 `中文说明.md` 和 `CHANGELOG.md`；素材署名见 `CREDITS-terrain.txt`、`CREDITS-district.txt`。

## 已知情况

- 这一版在云端 Linux 上测试（软件渲染）：75 项无窗口自动测试中 67 项通过（未通过的是回本测试 `v19_payback`，以及 7 个需要原 D: 盘路径的 review 工具）；需要窗口的 4 项中 3 项通过（`v16_interaction_probe` 在它的 1.6 存档上失败，自 1.8 起如此）。打包后的 PCK 用 Linux 版引擎走过：启动到菜单；在球面和平面地图上选点建首府，存档、退出、从菜单继续后首府仍在原处；种子 3 的回归（六次点选后建首府）；海面、极地、陡坡的拒绝；1.10 存档沿用；旧存档的区域图；地形导出检查；37 座建筑的殖民地区域图（58 个素材文件全部可读，冷进入 4.6 秒）。从首府远征到内陆新据点（在球面上选点）和海岸新据点（在平面地图上选点）：路线、天数和费用照面板所示，抵达后在建造页下令建农场，存档、退出、读档后两座城镇和首府都在原处，各 21 项检查全部通过。
- Windows 上的 EXE 还没有在真实电脑上打开过；帧率只在软件渲染下量过（不代表显卡上的表现）。
- 回本测试 `v19_payback` 在新地形上有两项略低于目标区间（矿场 56 天，目标 70-150；加工厂 113 天，目标 120-300），本版没有重新平衡经济。
- 和定稿相比：路面在傍晚的暖光下比定稿的灰色沥青偏暖；近处的大石头在正面的夕阳下偏亮；远处是雾，看不到定稿里的远山。

---

**English summary.** 1.12.0 integrates the approved terrain and settlement handoff: the CC-GEO-2.3 generator with mountain and plateau snow for new expeditions (globe, satellite map, landing selection), and a district rebuilt from revision 06 (metric building scale, spacing and streets driven by the player's buildings) and revision 07 (paved roads, compacted shoulders, gravel, soil, sparse grass, weathered boulders with embedded fragments, layered rock on distant slopes), with haze tied to the camera, water only at real coasts, rivers and lakes, and a fix for capitals placed on landmasses without a recommended site. Old saves keep their generator and settlement places.

Implementation: branch `v17-terrain`, commit `379f02a` (game files as exported from `e4dbab7`). Evidence and comparison frames: `docs/v17/terrain/`, `docs/v17/PROGRESS.md`.

Tested on Linux in the cloud (no Windows host): 67 of 75 headless suites pass (`v19_payback` and the seven `review_*` tools that need their original `D:` paths fail, as before); window suites 3 of 4 (`v16_interaction_probe` on its 1.6 fixture, as since 1.8). The exported PCK on the Linux 4.5.1 runtime: boot to the menu; a capital on picked ground from the globe and from the flat map, saved, quit, continued from the menu and found where it was clicked (14/14 each); the seed-3 regression (16/16); refusals at sea, at the pole and on steep ground (7/7); a 1.10 save carried over (13/13); a 1.10 save's district (15/15); the terrain export check; the 37-building coastal district from cold (15/15; all 58 raw district and terrain files open). Frame times on llvmpipe software rendering (Xeon 2.30 GHz, 4 threads, GL Compatibility, 1600x900, populated save): cold region entry 4.6 s; 684 / 506 / 352 ms mean per frame at the default, settlement and verge cameras; no GPU was available, so these say nothing about frame rates on a graphics card. The two outpost cases, from a licence-day save: an expedition through the interface from the capital to inland ground picked on the globe and to coastal ground picked on the flat map, the quoted days and cost, arrival, a farm ordered through the build page, and a save, quit and reload keeping both towns and the capital (21/21 each). Not run: the Windows EXE itself (no Windows host).
