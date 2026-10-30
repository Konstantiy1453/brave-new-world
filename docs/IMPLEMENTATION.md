# 殖民契约 Demo 实施计划
Spec: ../DEMO_AGENT_PROMPT.txt（唯一验收依据）
技术：Godot 4.x 稳定版标准 GDScript，Compatibility 原生渲染，Windows x64。工具负责人核定准确版本及匹配模板。无浏览器壳，无联网游戏依赖。
方向已由用户批准，常规技术决策自主执行。空目录直接创建工程，不另建工作树。

## 接口（并行开发必须遵守）
所有模拟状态为 JSON 兼容 Dictionary/Array，资源固定 ore/copper/crystal/food/materials/parts 六种。
world/world_gen.gd: extends RefCounted；generate(seed_value:int, size_id:int=1)->Dictionary。
world 含 seed, version, size, regions:Array。region: id:int,name:String,lat:float,lon:float,elevation:float,fertility:float,water:float,temperature:float,deposits:{ore,copper,crystal},neighbors:Array[int],terrain:String。可以增加 grid 等字段。前两个候选为可通达矿区与肥沃河谷，地理位置必须在大陆上。route(world,a:int,b:int,mountain:bool=false)->Dictionary 返回 reachable,distance,days,cost,path:Array[int]。海洋不能通过。
world/map_view.gd: extends Node3D；signal region_selected(id)；setup(world:Dictionary)；sync_state(state:Dictionary)；show_planet()；show_region(id:int)；orbit(dx:float,dy:float)；zoom(amount:float)。三维可旋转球体和地区模块化建筑读取同一世界。镜头自管，UI 根 overlay；map 交互只通过 root _unhandled_input。可实现 pick_region(screen_pos:Vector2)。
simulation/sim.gd: extends RefCounted；var state:Dictionary；var config:Dictionary；new_game(seed:int, advantage:String,size:int=1)；act(action:String,args:Dictionary={})->String（空串成功，否则中文失败原因）；tick() 每调用一天；save_game(path:String)->String；load_game(path:String)->String；summary()->Dictionary 可选。
优势 capital/workers/science。act: settle {region:int}, build {region:int,kind:String}, connect {a:int,b:int,mountain:bool}, research {tech:String}, enterprise {region:int}, policy {tax:float,food_reserve:float}, event {choice:String}。
建筑 kind habitat,power,water,mine_ore,mine_copper,mine_crystal,farm,processor,lab,port。
state 至少 world,day,cash,resident_cash,enterprise_cash,settlements:Array,route:Dictionary,shipments:Array,research:Dictionary,events:Array,log:Array,ledger:Array,status:String,streak:int。
settlement: region:int,name:String,population:int,children:int,workers:int,scientists:int,stock:Dictionary,buildings:Array[Dictionary {kind, active, ...}],jobs:int,housing:int,food_days:float, shortages:Array[String]。
ledger 行含 day,category,amount,from,to，amount 正数；公共账户经营净值 state.operating_net；status planning/active/success/failed。
research 含 current,progress,completed:Array[String]；企业详情 state.enterprise:Dictionary；事件当前 state.event:Dictionary（title,text,choices:Array[{id,label}] 等）。
config 包含 buildings 字典（name,cost,materials,days,jobs,power,water,maintenance,...）与 techs 字典（name,cost,description,...）；合同 config.contract。

## 工作分工与验证
- [ ] A 模拟与配置：账本、各产业与人口、物流、事件、企业、存档、合同；实现并运行 headless 单元/场景测试。
- [ ] B 世界与视觉：种子、地理、路径、真实球体、地表建筑；自测生成和路径。
- [ ] C 工具与资产：引擎模板、中文可分发字体与许可、三肖像、图标与来源。
- [ ] Root：中文 UI、新局/选址/建设/信息/保存流程、集成与试玩、导出/截图/报告。
- [ ] 交叉审查、修复、三尺寸布局、实际构建运行、交付。

## 美术规范
深空 #09121C、面板 #132333、文字 #E7EEF2、次文 #A6BAC8、青绿 #62C7C5、合同金 #D8B16A、危险 #E46F68。地图居中，顶部经济，左功能，右上下文，底部任务。中等密度、留白、细边线、正文18px设计基准。3张半身写实科幻职业肖像。建筑采用组合几何精制轮廓与统一金属/光带，不以立方体代替整座建筑。所有按钮为真实控件。

## 审查重点
资金守恒；本地库存与在途不瞬移；存档恢复；UI 阻止穿透；海洋不能陆路直达；亏损宽限与成功后税基；所有验收证据区分自动脚本与真实 UI 操作。
