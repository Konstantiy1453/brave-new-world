# 三维资产交接入口 · 2026-11-07

**独立保存，尚未接入游戏。建模已按用户要求暂停。**

[下载全部模型与附件](https://github.com/Konstantiy1453/brave-new-world/releases/tag/art-assets-20261107) · [自动下载与合并](DOWNLOAD_AND_ASSEMBLE.md) · [还原后的使用说明](START_HERE.md) · [当前资产表](ASSET_INDEX.csv) · [按任务浏览状态](INDEX.md)

本次完成最后正在制作的文化中心，并保存两套资产库的全部现存模型、贴图、预览、来源和历史版本。GitHub Release 用 51 个传输附件保存 9 个独立 ZIP：5 个整包与 4 个大包的 46 个分片，自动接收工具会还原原始 ZIP。完整压缩数据合计 **5,783,326,573 bytes（约 5.78 GB）**；解压载荷 **10,035,936,473 bytes**，共 **2,627 个文件**。仓库本身保存本目录中的交接资料，MAX/FBX 等大文件由该仓库的 Release 附件分发。

归档含 **217 个 MAX、110 个 FBX、128 个材质与贴图文件、708 个预览文件**。这些数字包括历史版本与制作阶段文件；当前可选入口是 **77 项**，不能将历史文件数量当成独立完成资产数。

|当前入口|数量|状态|
|---|---:|---|
|旧库原正式清单|21|保留原证据，本次没有全量重新验收|
|续建正式资产|32|已有真实 MAX 重开、隔离 FBX 导入、视觉验收，并与当前文件哈希匹配|
|续建最终命名文件|7|待最终视觉检查|
|续建灰模|15|尚未完成最终交付流程|
|环境/海岸旧版|2|v003 保持 PARTIAL；v004 候选尚未生成|

续建原计划为 68 项主任务 + 3 个组合样景，当前正式完成 32 项、未完成 39 项。文件归档不会将未完成任务升级为已完成。完整三组组合样景仍未制作完成；复用任务的旧库来源保留在包内。

## 下载与恢复

推荐下载 [RECEIVE_ASSETS.py](https://github.com/Konstantiy1453/brave-new-world/releases/download/art-assets-20261107/RECEIVE_ASSETS.py)，在该文件所在目录运行：

```powershell
python .\RECEIVE_ASSETS.py --download
```

需要 Python 3，无需第三方库。工具会取得本发布的 [传输清单](TRANSPORT_MANIFEST.json)，下载51个附件、校验每片并合并成原始9个ZIP；中断后运行同一命令继续。全部成功后，ZIP 位于 `received_assets/archives`。把9个ZIP全部解压到同一个空目录，再读包内 START_HERE.md。详细说明见 [DOWNLOAD_AND_ASSEMBLE.md](DOWNLOAD_AND_ASSEMBLE.md)。

[SHA256SUMS.txt](https://github.com/Konstantiy1453/brave-new-world/releases/download/art-assets-20261107/SHA256SUMS.txt) 对应还原后的9个原包。传输分片大小与SHA在TRANSPORT_MANIFEST.json中。自动下载和合并保留两份压缩数据，约需12GB空间；再解压约10GB，建议预留至少25GB。GitHub自动生成的Source code ZIP不含大模型。

|分卷|内容|
|---|---|
|part01|当前原生 MAX 入口，包括明确标注的灰模|
|part02|当前实存高模 FBX|
|part03|全部版本材质与贴图|
|part04|全部版本预览|
|part05|文档、来源、检查证据、索引与贴图重定位工具|
|part06、part07|历史原生模型|
|part08、part09|历史 FBX|

使用 3ds Max 2024 打开对应 MAX。换目录后如缺贴图，在 Max 运行解压根目录的 `tools/Relink_Textures.ms`，按 Listener 结果检查后另存工作副本。文化中心已在同机不同中文目录完成 8 张贴图重定位、另存及重开测试；这是同机搬迁检查，不是第二台机器的全库验收。

## 接手与检查记录

- [完整资产索引 JSON](https://github.com/Konstantiy1453/brave-new-world/releases/download/art-assets-20261107/ASSET_INDEX.json) 包含当前路径、哈希、原验收状态和未生成候选。
- [全部文件清单](https://github.com/Konstantiy1453/brave-new-world/releases/download/art-assets-20261107/MANIFEST.json) 列出每个文件、分卷与 SHA-256。
- [压缩包验证](ARCHIVE_VERIFICATION.json)：所有 ZIP 逐文件实际解压读取，CRC、SHA-256、路径、数量与大小通过，打包前后源文件未变。
- [全量还原验证](TRANSPORT_REASSEMBLY_CHECK.json)：正式接收脚本实际写出9个新ZIP，每个大小和SHA与原始已验证包一致。
- [上传验证](https://github.com/Konstantiy1453/brave-new-world/releases/download/art-assets-20261107/UPLOAD_VERIFICATION.json)：附件上传后与 GitHub 服务器报告的大小和 SHA-256 比对。
- [同机贴图搬迁记录](PORTABILITY_CHECK.json) 与 [暂停状态](HANDOFF_STATUS.json) 保留实际执行范围和失败修复记录。

解压后打开续建库的 `ASSET_GALLERY.html` 浏览成品预览；游戏建筑对应表位于 `00_brief/ASSET_MAPPING.json`，完成/未完成详情位于 `01_progress/COMPLETION_REPORT.md`。原始冻结星球资料沿用 CC-GEO-1.6 / seed 260129，不代表已适配所有程序化世界。

本次仅新增独立资产归档和交接文档，未修改游戏代码、配置、资源映射或存档，未实现经济调整。接手者可另行制作游戏运行资产及接入方案；保留当前高模原件、可编辑分件、UV、材质和尺度作为来源。
