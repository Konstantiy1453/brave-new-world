# 殖民契约：美术资产与来源

记录日期：2026-10-29。工程资源根为 `game/assets/`。本表记录资产制作与检查；是否在最终画面实际使用以游戏源码与最终实机截图为准。

## 视觉规范

克制工业科幻；深空 `#09121C`、面板 `#132333`、正文 `#E7EEF2`、次文 `#A6BAC8`、交互 `#62C7C5`、合同/资金 `#D8B16A`、警报 `#E46F68`。主要操作保持明亮边缘和文字，告警同时显示三角图标及原因。地图是视觉中心，常驻面板保持边缘分布，详细账本按需打开。肖像采用相同的半身构图、暗蓝背景、左侧青绿轮廓光和右侧暖黄铜主光。

## 已实际查看的参考

- [TerraGenesis 官方入口](https://terragenesisgame.com/) 本次网络请求超时；[App Store](https://apps.apple.com/us/app/terragenesis-space-settlers/id1039841501) 内容可读。另通过浏览器实际打开并观察了开发者在 IndieDB 的 [Gameplay Main Screen 图](https://media.indiedb.com/images/games/1/62/61309/Gameplay---Main-Screen.jpg)。观察到右侧占据大幅画面的球体、有明暗面的海岸与陆块、金色点状聚落灯、左侧稀疏的状态和功能。采用：球体与地貌先于面板成为主体；城市灯仅对应真实聚落；功能入口有限、区分总览与局部详情。没有复制其六边形按钮、纹理、商标或付费项目。
- [Stellaris 官方 Steam 商店](https://store.steampowered.com/app/281990/Stellaris/) 已在浏览器实际查看，所见游戏画面含顶部资源条、左侧工具列、中央行星星系画面与右侧 Advisor Online 人物通讯窗。采用：经济总览常驻顶部、上下文信息靠右、人物用于解释合同与事件、告警可逐步展开。Demo 降低密度并提高中文字号；没有提取游戏贴图、肖像、图标、声音或界面图作为游戏素材。

参考图片只在外部浏览器查看，未打包进游戏。所有最终游戏肖像和图标均在本次新建。

## 资产清单

| 文件 | 用途 | 来源与制作 | 状态/许可 |
| --- | --- | --- | --- |
| `fonts/main.ttf` | 保留的字体来源 | 从本机 `C:/Windows/Fonts/NotoSansSC-VF.ttf` 原样复制；字体内部名称 Noto Sans SC，Version 2.04;241114210130;non-release；cmap 30,890 字符 | 源变量字体；SIL OFL 1.1，保留 `fonts/OFL.txt`；源文件未改 |
| `fonts/main_medium.ttf` | 全中文 UI/地图标签生产字体 | 上述字体通过 fontTools.varLib.instancer 固定 wght=500；去除 fvar，OS/2 weight=500，保留全部 30,890 字符；内部家族改为 Colony Sans SC Medium | 最终静态字体；同一 SIL OFL 1.1，衍生版名称无保留名称 Source |
| `portraits/liaison.png` | 公司联络人，合同/结算 | 内置 `image_gen.imagegen` 本次独立生成；1024×1536 PNG；成熟女性、整洁深蓝职业制服 | Demo 最终肖像；AI 生成原创角色，无外部 IP 参考图输入 |
| `portraits/engineer.png` | 工程负责人，建设/警报 | 同工具本次独立生成；1024×1536 PNG；年长男性、耐磨工装与工具背带 | Demo 最终肖像；AI 生成原创角色 |
| `portraits/scientist.png` | 科研负责人，科研/人才 | 同工具本次独立生成；1024×1536 PNG；女性科研人员、灰蓝实验外套与平板 | Demo 最终肖像；AI 生成原创角色 |
| `icons/ore.svg`、`copper.svg`、`crystal.svg` | 三种矿产 | 本次原创几何路径 | Demo 最终图标；项目原创 |
| `icons/food.svg`、`materials.svg`、`parts.svg` | 食品、材料、部件 | 本次原创几何路径 | Demo 最终图标；项目原创 |
| `icons/habitat.svg`、`power.svg`、`water.svg`、`farm.svg` | 生活、发电、供水、农业 | 本次原创几何路径 | Demo 最终图标；项目原创 |
| `icons/processor.svg`、`lab.svg`、`port.svg`、`warning.svg` | 加工、科研、港口、警报 | 本次原创几何路径 | Demo 最终图标；项目原创 |

图标为 64×64 SVG、2.5 px 圆角细线，底色透明；主体白色供 UI 调制选中色，warning 使用红色及感叹号。矿场可复用相应矿产图标。可重建源为 `tools/create_icons.py`。PNG 是独立人物绘画，没有烘焙游戏按钮或文字。

肖像原始生成文件保留于 `C:/Users/ASUS/.codex/generated_images/01a185fa-8591-7201-95e0-d7261709e1cf/`，分别为 `exec-4f75ec00-f7ba-4a7d-9184-27eb525612da.png`、`exec-a768ad9b-9450-4d12-ac1e-19072f1009a4.png`、`exec-d32881f5-77c6-4194-b74c-d5edd42a493a.png`；工程使用的是自身副本，不依赖生成目录。

## 许可与证据

字体版权：Copyright 2014-2021 Adobe，Reserved Font Name 'Source'。其内嵌授权与 [Google Fonts 的 OFL](https://github.com/google/fonts/blob/main/ofl/notosanssc/OFL.txt) 一致；完整许可随工程保存，发行构建旁也应保留。OFL 首次 raw.githubusercontent 请求连接重置，后从同一官方仓库的 jsDelivr 镜像成功获取；无内容改写。字体的文件名变为 main.ttf，内部家族名和二进制保持不变。

实机发现 Godot 直接加载原始变量字体会采用其默认 wght=100（Thin），正文过细。已按集成负责人要求额外制作 main_medium.ttf 静态 500 字重，生产 UI 可直接加载，避免依赖字体轴默认行为。fontTools 的自动实例化遗留部分语言 name17=Thin，故将衍生版所有语言的 family/subfamily/PostScript 名称统一为 Colony Sans SC Medium / Regular / ColonySansSC-Medium；版权、OFL 授权和源文件均保留。完整轴范围、源/结果哈希及变更见 `docs/evidence/static_font_instance.json`。

Godot 使用 MIT 许可，`docs/GODOT_LICENSE.txt` 保存 4.5.1-stable 官方完整许可，`docs/GODOT_COPYRIGHT.txt` 保存同一版本第三方版权与许可清单（97,253 字节），发行包应附带二者；说明详见 [Godot 许可证页面](https://godotengine.org/license/)。二者从官方 godotengine/godot 的 4.5.1-stable 标签经 jsDelivr 获取。

肖像使用内置工具，不使用 API key/CLI；完整最终提示词保存于 `docs/evidence/portrait_prompts.json`。三图均已实际目视检查：构图、完整头部、服装身份、照明与色彩一致；科研人员眼镜和手持平板正常，工程人员手套未与身体混合，公司人物没有错误标识。原始肖像无需占位替换。

项目原创 SVG 与 AI 图像作为本 Demo 原创资源提供，不冒称来源于第三方开放素材库。文件哈希见 `docs/evidence/asset_manifest.json`；字体内嵌名称/授权见 `docs/evidence/font_metadata.json`。程序化行星/地区/建筑由 world 模块在运行时创建，具体生成方法及世界状态一致性由该模块文档和运行验证记录说明。

## 本次资产校验

- PNG：三张均通过 Pillow 完整图像解码/校验，尺寸均为 1024×1536；已目视检查三张实际生成结果。
- SVG：14 张 XML 可解析，并由真实 Godot 4.5.1 `Image.load` 解码、合成 `docs/evidence/icon_atlas.png`。工具 `tools/verify_asset_render.gd` 实际退出码 0，日志 `docs/evidence/asset_render.log`。已打开图集检查，线宽、留白、边界及警报辨识正常。
- 字体：二进制 SHA256 与本机源字体一致；中文界面代表字串全部存在于 cmap。此项为字形覆盖抽样，最终界面排版与三个分辨率的检查仍以实机 QA 为准。
- 未将资产文件存在、图像解码或图集检查宣称为游戏 UI 接入验收；最终集成由实机截图与交互记录确认。

## CC-GEO-1.5 程序化地理、河系与共用图集

新局程序资产的权威来源为 `game/world/world_gen.gd`、`seed_geography.gd`、`hydrology.gd` 与 `map_view.gd`，均为本项目代码生成；没有下载第三方大陆纹理、地形模型、海底图或河流贴图。旧1.4原采样函数保留以显示旧存档，不能将旧版固定地图的画面标为本次新seed生成结果。

- 大陆与海洋：由已保存版本/种子派生的省区参数、球面旋转、海岸域扭曲、多尺度噪声、海深与海拔场采样生成；森林/草原/荒漠等颜色读取实际气候/高度分类。
- 河流与湖泊：由保存世界的自然高程与降水汇流生成，`world.rivers`/`river_metadata`/`lakes`是真实数据路径；球面、平铺和地区投影读取同一组数据，不分别绘制随机河道。
- 全球图集：1536×768 RGBA程序纹理，RGB存地理色彩，alpha编码高程用于轻量起伏阴影；它是生成器输出的缓存，不是外部美术素材。球面球体和等经纬平铺网格共享该图集，同一世界不会因切换模式改变大陆。
- 缓存：缓存身份包括图集协议、世界生成器版本、seed、尺寸档和generation参数摘要；运行期用户目录缓存不等于源资产。新增后台生成通过只读采样context工作，各线程噪声实例独立，避免共享可变参数缓存。
- 地区与建筑：地表由同一个世界采样及实际水道投影细化，开发台地属于有限工程整平；设施仍为项目原创模块几何，未使用外部3D素材包。

`sample_with_context` 仅从原采样函数抽取只读计算，7个固定种子的完整world SHA256在抽取前后逐一相同，证据 `docs/evidence/seed_context_extract_comparison.json`。这项比较验证生成数据未变，不验证后台线程实际执行、贴图渲染速度或最终画面质量；对应结论由场景与发行实测记录承担。

推荐种子的预生成图集已经实际接入：`game/assets/generated/world_atlas_d0139459574cf5351f59c4a47e4409eef99bd1bd7481d8dc7eae051297abbe9d.png`，1536×768，SHA256 `CF7D8ED9B7A7C9488EC30D9C78B09B0C327E4B0E718EF0FAB6EA7CE29FD16826`。生成key为 `atlas-1536-r3:CC-GEO-1.5:260129:1:ade5af9348d84bcbf330d1cc78b14b4d23ffdfcb1df9fb9d4515c62c06ff79fc`；引擎从res://assets/generated读取，探针明确记录bundled来源。它用于推荐种子的首次显示；其他新种子先生成预览再后台细化，均使用同一采样规则。来源、冷/热/随包耗时及范围见FLAT_MAP_V15_QA。本次新地图的准确地理来源与范围见WORLD_REPORT、SEED_DIVERSITY、HYDROLOGY_REPORT，实际采用的图集与画面由最终清单和视觉报告确认。
