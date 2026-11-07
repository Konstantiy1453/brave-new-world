# 勇敢新世界 / 殖民契约：3ds Max 资产交接包

2026-11-07。**独立保存，尚未接入游戏。建模已暂停。**

本次按用户要求只完成最后正在制作的文化中心，然后将两套现有资产库完整归档。未继续扩展其他建筑、地形或组合样景。旧库保持只读，游戏代码、配置、资源映射和存档未修改。

GitHub 交付入口：[art-assets-20261107](https://github.com/Konstantiy1453/brave-new-world/releases/tag/art-assets-20261107)。模型二进制存放在该仓库 Release 附件中；仓库内 art-assets/20261107 提供入口、清单和检查记录。

## 下载、解压和选择模型

1. 下载 Release 中全部 `BNW_*.zip`，以及 `SHA256SUMS.txt`、`MANIFEST.json`。不要把 GitHub 自动生成的 Source code ZIP 当成模型包。
2. 用 SHA-256 校验附件。每个 ZIP 都是独立压缩包；全部解压到同一个空目录，不需要拼接分卷。完整解压后得到本文件、tools 和 art_reserve 下两套资产库。
3. 先看 `ASSET_INDEX.csv` 或 `INDEX.md`。表内的 native_path/fbx_path 都相对解压根目录。优先使用 `RECORDED_ACCEPTED_IN_CONTINUATION_MANIFEST` 项；旧库入口保留原清单验收状态。WIP/GRAY/PARTIAL 和缺失候选没有被提升为完成。
4. 用 Autodesk 3ds Max 2024 或支持该版本文件的 Max 打开对应 MAX。保留分件、修改器、UV 和材质。原始材质与灯光主要采用 Physical Material、Arnold。
5. 若换目录导致贴图路径失效，在 Max 的 Scripting → Run Script 运行本包 `tools/Relink_Textures.ms`。它按原库名及完整相对后缀重新定位 Bitmaptexture；缺少任何目标文件时不改路径。查看 Listener 结果，确认没有缺图后另存一个工作副本。工具不自动保存，不改几何、UV 或材质数值。

需要编辑或为游戏另做衍生资产时，从已验收 MAX/FBX 复制到独立工作区。高模不等于已完成游戏性能适配；当前任务没有自动减面、替换现有游戏资产或接入引擎。

## 当前保存状态

|范围|状态|
|---|---|
|旧资产库|原正式清单 21 项；此次保留文件和原证据，没有重新验收全部旧模型|
|续建正式完成|32 项，包含本次完成的文化中心；对应真实 MAX 重开、FBX 隔离重导入和视觉记录|
|续建其他最终命名文件|7 项待最终视觉确认；2 项环境/海岸 v003 保留 PARTIAL，计划中的 v004 尚未生成|
|续建灰模|15 项有原生 MAX 灰模，尚未完成最终材质、交换或最终验收流程|
|续建未生成候选|12 项主任务及 3 个组合样景；其中 9 项复用任务的旧库来源仍在旧库中，但续建版未完成|
|主任务范围|68 项，加 3 个组合样景；归档现存文件不代表全部 71 项完成|

当前文件入口合计为旧库 21 项 + 续建实存 56 个资产族（41 个最终命名 MAX、15 个灰模 MAX）。历史修订、灰模阶段、旧导出和失败记录也一并保存，不应仅凭文件名含 final 或版本号较大就选为成品。

文化中心：`CC_CULTURE_CENTER_HP_v001`，347 个可编辑资产分件，65,008 个三角面。已完成实际 MAX 重开、隔离 FBX 重导入和灰模/特征线/材质近景/经营视角/100px 缩图检查。原生记录为 0 退化三角、0 非流形边；400 条开放边属于有意保留的植物叶片。

文化中心原生入口：
`art_reserve/max_highpoly_continuation_20261102/05_buildings/CC_CULTURE_CENTER_HP_v001.max`

文化中心交换入口：
`art_reserve/max_highpoly_continuation_20261102/08_exports/highpoly_fbx/CC_CULTURE_CENTER_HP_v001.fbx`

## 给后续接手者的文件入口

|用途|相对解压根目录|
|---|---|
|资产入口与文件哈希|`ASSET_INDEX.json`、`ASSET_INDEX.csv`、`INDEX.md`|
|全部 ZIP 文件、路径、大小与 SHA-256|Release 独立附件 `MANIFEST.json` / `MANIFEST.csv`|
|两库原文件清单|`FILES.json` / `FILES.csv`，在文档 ZIP 内|
|续建游戏建筑对应表|`art_reserve/max_highpoly_continuation_20261102/00_brief/ASSET_MAPPING.json`|
|续建正式交付白名单|`art_reserve/max_highpoly_continuation_20261102/00_brief/DELIVERY_TARGET_IDS.json`|
|完成与未完成详情|`art_reserve/max_highpoly_continuation_20261102/01_progress/COMPLETION_REPORT.md`|
|浏览续建成品预览|`art_reserve/max_highpoly_continuation_20261102/ASSET_GALLERY.html`|
|逐项真实检查与来源|两库的 `10_validation` 目录，以及各库 `ASSET_MANIFEST.json`|
|材质与 FBX 边界|`art_reserve/max_highpoly_continuation_20261102/07_materials_textures/MATERIALS_AND_EXCHANGE.md`|
|原始任务与冻结参考|两库 `00_brief`、参考/来源目录，按原组织保留|

整球、地图、地区与据点沿用冻结 CC-GEO-1.6 / seed 260129 来源；这是特定冻结星球的艺术资产参考，不代表已适配当前游戏所有随机世界。完整据点/组合场景按各自已有记录区分，不能把旧库场景或未运行脚本当成续建三个组合样景已经完成。

原生 MAX 保存完整材质、灯光和程序化设置；FBX 保留高模交换所需的网格、分件、单位和 UV，但不保证其他渲染器重现 Arnold、Falloff、玻璃及程序材质效果。PNG/TIFF 来源和 .tx 缓存按原字节保留。后续转换应参考真实预览和材质说明。

## 归档和验证范围

全部 ZIP 逐文件读取到末尾，校验 CRC、字节数、SHA-256、相对路径和文件数，并核对打包前后源文件未变化。详情见 `ARCHIVE_VERIFICATION.json`。上传完成后的服务器附件核对另见 `UPLOAD_VERIFICATION.json`，该记录作为 Release 附件提供。

归档保留历史/失败证据；排除的运行缓存、临时锁、桥接状态等列在 `EXCLUDED_FILES.json`。GitHub 登录信息、CLI 本机安装目录和桥接连接凭据不进入包。历史脚本保留来源用途，可能引用原机器路径；不要批量运行它们恢复制作。

搬迁工具只处理本库 Bitmaptexture 路径；其他插件、渲染器或目标引擎的配置仍按各资产记录处理。文化中心已在同一台机器的不同中文目录中实际执行启动器，成功重定位 8 张贴图、另存副本并重新打开，原始 MAX 哈希未变；详见 `PORTABILITY_CHECK.json`。完整库没有在第二台机器做全量重新验收；本包不会把压缩校验通过表述为跨软件或跨机器外观一致。

最后生产状态及检查边界见 `HANDOFF_STATUS.json`。本交接不实现经济调整、未定稿设施或游戏接入。
