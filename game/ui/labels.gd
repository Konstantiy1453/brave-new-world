extends RefCounted
## English simulation keys to player-facing text. Simulation code never reads this file.

const Keys = preload("res://simulation/keys.gd")

const RESOURCE_NAMES: Dictionary = {
	"ore": "铁矿",
	"copper": "铜矿",
	"crystal": "工业晶体",
	"food": "食品",
	"materials": "建材",
	"parts": "部件",
	"components": "电子元件",
	"alloy": "合金",
	"machinery": "精密机械",
	"pharma": "药品",
}
## Money sinks on the economy page, in display order.
const SINK_NAMES: Dictionary = {
	"buildings": "建设",
	"great_works": "巨型工程",
	"upgrades": "升级",
	"roads": "道路",
	"recruitment": "招募",
	"services": "公共服务",
	"commissions": "委托研究",
	"transfer": "生涯转存",
}
const SITE_KIND_NAMES: Dictionary = {
	Keys.SITE_RESIDENTIAL: "居住据点",
	Keys.SITE_FRONTIER: "边疆据点",
}
const SITE_KIND_TEXT: Dictionary = {
	Keys.SITE_RESIDENTIAL: "人们在这里安家：住房、医疗、学校、研究所和精密工厂都建在这里。自发移民多，有新生儿；只能开轻型矿场。",
	Keys.SITE_FRONTIER: "工程队驻扎的矿区或农区：重型矿场、大田农业只能建在这里，产量 +15%，远征更便宜。很少有人自愿来，要靠道路把人调过来。",
}
const ENTERPRISE_STATUS: Dictionary = {
	Keys.E_FITTING: "装修中",
	Keys.E_OPEN: "营业中",
	Keys.E_RESTRICTED: "经营受限",
	Keys.E_PAUSED: "暂停营业",
	Keys.E_CLOSED: "停业",
}
const ENTERPRISE_REASON: Dictionary = {
	Keys.ER_FITTING: "自主租用社区商业场地；装修需要 4 天",
	Keys.ER_PAUSED: "玩家暂停了服务设施",
	Keys.ER_NO_WORKERS: "可雇用工程队不足",
	Keys.ER_NO_CASH: "企业现金不足以支付工资与租金",
	Keys.ER_RUNNING: "自主经营，无需逐日操作；利润税只对正利润征收",
	Keys.ER_RECOVERING: "有偿重组或迁址，3 日后重新营业",
}
const LEDGER: Dictionary = {
	"capital.initial": "公司初始资本",
	"savings.settlers": "开拓居民自带积蓄",
	"savings.immigrants": "新移民携带积蓄",
	"invest.outpost": "前哨部署投资",
	"invest.build": "建设投资",
	"invest.road": "运输网络投资",
	"enterprise.capital": "民营投资人实缴资本",
	"enterprise.inputs": "企业购买建设材料",
	"enterprise.fitout": "企业店面设备投资",
	"enterprise.wages": "民营企业工资",
	"enterprise.rent": "商业场地租金",
	"enterprise.upkeep": "企业设备维护",
	"enterprise.sales": "居民购买生活服务",
	"enterprise.tax": "本地企业利润税",
	"enterprise.recovery": "企业复业重组投资",
	"admin": "殖民行政费",
	"services.budget": "公共服务预算",
	"governor.share": "公司总督分成",
	"wages.public": "公共工资",
	"upkeep.facility": "设施维护",
	"food_order.income": "轨道补给局食品订单",
	"food_order.port_fee": "食品订单港务费",
	"export": "出口",
	"export.port_fee": "出口港务费",
	"import.food": "食品进口及港务",
	"import.stock": "建设库存采购",
	"food.sales": "居民购买基本食品",
	"transport.fee": "陆路运输费",
	"arrears": "清偿欠款",
	"company.health": "污染地区公共健康支出",
	"company.cleanup": "地区污染治理",
	"aid.cash": "公司援助资金",
	"aid.surcharge": "援助追加经营分成",
	"aid.repay": "援助本金偿还",
	"research.funding": "科研经费",
	"research.wages": "科研及调查人员工资",
	"event.pay": "事件支出",
	"event.reward": "事件一次性收入",
	"event.order_income": "加工订单到货",
	"event.order_fee": "订单装船港务",
	"event.upkeep": "事件设施维护",
	"career.invest": "生涯资金注资",
	"contract.reward": "合同阶段发展资金",
	"road.upkeep": "道路养护",
	"recruit": "招募移民",
	"commerce.income": "商业街区营业收入",
	"service.income": "数据服务收入",
	"research.reshuffle": "重新调研",
	"invest.upgrade": "设施升级",
	"invest.survey": "地面勘察",
	"research.contract": "科研委托收入",
	"legacy.event": "旧版事件",
}

const BUILD_CATEGORIES: Dictionary = {
	"extraction": "矿业",
	"food": "食品",
	"industry": "加工",
	"utilities": "水电与货运",
	"people": "住房与服务",
	"research": "科研",
	"great": "巨型工程",
}
const ROLE_HINTS: Dictionary = {
	"mining_basin": "矿藏丰富、地势平缓，适合作为首府和出口基地。",
	"fertile_valley": "土地肥沃，适合作为粮食据点，矿藏很少。",
	"highland_mining": "铜和晶体多，但建设费高、耕地少，需要外来粮食。",
	"grassland": "地形开阔、地块多，各方面都不差，适合扩张人口。",
	"coastal_plain": "靠海、地块平整，可以开辟航线。",
	"island": "晶体往往集中在这里，地块少一些，靠海运和外界相连。",
	"lake_basin": "水源充足，矿和地都还可以。",
	"arid": "矿藏丰富但水少，要留意供水和尘暴。",
	"cold": "矿藏不错，但耕作困难、建设费高。",
}
const SITE_FILTERS: Array = [
	["all", "全部地点"],
	["ore", "铁矿丰富"],
	["copper", "铜矿丰富"],
	["crystal", "晶体丰富"],
	["farm", "适合耕作"],
	["coast", "沿海"],
	["mining_basin", "矿产盆地"],
	["fertile_valley", "肥沃河谷"],
	["highland_mining", "高山矿区"],
	["grassland", "温带草原"],
	["coastal_plain", "滨海平原"],
	["island", "海岛"],
	["lake_basin", "湖盆"],
	["arid", "干旱荒原"],
	["cold", "寒地"],
]
const STAGE_NAMES: Dictionary = {
	"foothold": "第一阶段 · 立足",
	"division": "第二阶段 · 分工",
	"network": "第三阶段 · 网络",
	"self_reliance": "第四阶段 · 自立",
	"capital": "第五阶段 · 首府",
}
const LICENCE_NAMES: Dictionary = {
	"expedition": "第二据点远征许可",
	"third_settlement": "第三据点许可",
	"network": "第四、第五据点许可",
	"self_reliance": "第六、第七据点许可",
}
const ATTRACTIVENESS_PARTS: Dictionary = {
	"beds": "住房",
	"food": "食品保障",
	"jobs": "工作机会",
	"wage": "工资政策",
	"services": "生活服务",
	"budget": "公共服务预算",
	"district": "首府新区",
	"pollution": "污染",
	"shortages": "水电短缺",
	"company": "公司审查",
	"events": "近期事件",
	"frontier": "边疆条件艰苦",
	"tech": "技术与制度",
}


## Text of one contract goal, with what it needs and the page that moves it.
static func goal(row: Dictionary) -> Dictionary:
	var value: float = float(row.value)
	var target: float = float(row.target)
	match str(row.key):
		"settlements":
			return {"text": "建立据点 %d / %d" % [value, target], "hint": "在地图上选址并建立首府", "page": ""}
		"exports_total":
			return {
				"text": "累计出口 ¥ %.0f / %.0f" % [value, target],
				"hint": "建设矿场并保持货运站运转",
				"page": "build"
			}
		"food_days":
			return {
				"text": "各据点食品 %.1f / %.0f 天" % [value, target],
				"hint": "货运站会自动进口；农场更省钱",
				"page": "build"
			}
		"stage_streak":
			return {
				"text": "一周平均不亏损，连续 %d / %d 天" % [value, target],
				"hint": "近 7 日经营结余合计不为负且没有欠款",
				"page": "economy"
			}
		"research_staffed":
			return {
				"text": "在研项目 %d / %d" % [value, target], "hint": "建研究所并分配研究团队", "page": "research"
			}
		"connected":
			return {
				"text": "相互连通的据点 %d / %d" % [value, target],
				"hint": "建立第二据点并修路",
				"page": "transport"
			}
		"local_food_share":
			return {
				"text": "本地食品自给 %.0f%% / %.0f%%（近 30 日）" % [value * 100.0, target * 100.0],
				"hint": "在肥沃地块建农场；农田不够就研究水培技术，建水培温室",
				"page": "build"
			}
		"processing_days":
			return {
				"text": "加工运行 %d / %d 天" % [value, target],
				"hint": "建复合加工厂，并保证铁矿和铜矿供应",
				"page": "build"
			}
		"population":
			return {
				"text": "人口 %d / %d" % [value, target],
				"hint": "增加住房、提高工资或招募移民",
				"page": "population"
			}
		"technologies":
			return {
				"text": "完成技术 %d / %d" % [value, target], "hint": "分配更多研究团队", "page": "research"
			}
		"employment":
			return {
				"text": "就业率 %.0f%% / %.0f%%" % [value * 100.0, target * 100.0],
				"hint": "新建设施创造岗位",
				"page": "build"
			}
		"housed":
			return {
				"text": "全部居民有住房" if value >= target else "仍有居民缺少住房",
				"hint": "建设模块住区",
				"page": "build"
			}
		"enterprise_profit_days":
			return {
				"text": "民营企业连续盈利 %d / %d 天" % [value, target],
				"hint": "批准服务社，居民越多需求越大",
				"page": "enterprise"
			}
		"non_mining_share":
			return {
				"text": "非矿业收入占比 %.0f%% / %.0f%%（近 30 日）" % [value * 100.0, target * 100.0],
				"hint": "出口加工品、食品订单或扩大本地服务",
				"page": "economy"
			}
		"no_review":
			return {
				"text": "没有进行中的公司审查" if value >= target else "公司审查尚未结束",
				"hint": "解决公司关系页列出的原因",
				"page": "company"
			}
		"frontiers":
			return {"text": "边疆据点 %d / %d" % [value, target], "hint": "派远征队时选择边疆据点", "page": ""}
		"capital_population":
			return {
				"text": "首府人口 %d / %d" % [value, target],
				"hint": "在首府盖更高的住宅，招募更多人",
				"page": "population"
			}
		"capital_hall":
			return {
				"text": "行星议会大厦已建成" if value >= target else "建成行星议会大厦",
				"hint": "需要技术：首府规划。可以建在任何居住据点",
				"page": "build"
			}
	return {"text": str(row.key), "hint": "", "page": ""}


## 第 3 年 4 月 12 日, counted from the landing. Months have 30 days, years 360.
static func date(day: int) -> String:
	return "第 %d 年 %d 月 %d 日" % [day / 360 + 1, (day % 360) / 30 + 1, day % 30 + 1]


## The same in the little space a list row has.
static func short_date(day: int) -> String:
	return "%d年%d月%d日" % [day / 360 + 1, (day % 360) / 30 + 1, day % 30 + 1]


## Whole numbers up to five digits, then 万: what fits in a cell of the resource table.
static func compact(value: float) -> String:
	var size: float = absf(value)
	if size >= 100000.0:
		return "%.1f万" % (value / 10000.0)
	return "%d" % roundi(value)


## The icon file for a building: its own, or that of what it is modelled on.
static func icon_key(config: Dictionary, kind: String) -> String:
	var spec: Dictionary = config.buildings.get(kind, {})
	if spec.has("output"):
		return str(spec.output)
	return str(spec.get("model", kind)).trim_prefix("mine_")


static func building_name(config: Dictionary, kind: String) -> String:
	if kind == "service":
		return "民营生活服务社"
	return str(config.buildings.get(kind, {}).get("name", kind))


static func building_status(building: Dictionary) -> String:
	var days: int = int(building.get("upgrade_days", 0))
	if days > 0:
		return "%s · 升级中 余 %d 天" % [_base_status(building), days]
	return _base_status(building)


static func _base_status(building: Dictionary) -> String:
	match str(building.get("status", "")):
		Keys.B_BUILDING:
			return "建设中 · 余 %d 天" % int(building.get("remaining", 0))
		Keys.B_PENDING:
			return "待结算"
		Keys.B_DISABLED:
			return "手动停工"
		Keys.B_RUNNING:
			return "运行 %.0f%%" % (float(building.get("efficiency", 0.0)) * 100.0)
		Keys.B_IDLE:
			return "停工 · 岗位或供应不足"
		Keys.B_DEPLETED:
			return "已探明储量耗尽"
		Keys.B_TARGET_FULL:
			return "目标库存已满 · 自动停产"
		Keys.B_NO_INPUT:
			return "停工 · 缺少配方原料"
		Keys.B_PRIVATE_OPEN:
			return "民营营业"
		Keys.B_RESTRICTED:
			return "经营受限"
	return ""


static func enterprise_status(key: String) -> String:
	return str(ENTERPRISE_STATUS.get(key, key))


static func enterprise_reason(key: String) -> String:
	return str(ENTERPRISE_REASON.get(key, key))


static func shortage(config: Dictionary, entry: Dictionary) -> String:
	var detail: String = str(entry.get("detail", ""))
	match str(entry.get("key", "")):
		Keys.SH_JOBS_WORKERS:
			return "岗位缺员：%s（需要工程队）" % building_name(config, detail)
		Keys.SH_JOBS_SPECIALISTS:
			return "岗位缺员：%s（需要研究团队）" % building_name(config, detail)
		Keys.SH_POWER:
			return "电力不足：生产按供需比例减产"
		Keys.SH_WATER:
			return "供水不足：生产按供需比例减产"
		Keys.SH_DEPLETED:
			return "%s矿床耗尽" % building_name(config, detail)
		Keys.SH_PROCESSOR_INPUT:
			return "加工缺少本地铁矿或铜矿"
		Keys.SH_NO_PORT:
			return "无本地货运站；依赖陆路补给"
		Keys.SH_PORT_FULL:
			return "港口吞吐不足：货物运不出去，补给也进不来"
		Keys.SH_STARVING:
			return "食品供给不足 · 已持续 %s 天" % detail
		Keys.SH_HOUSING:
			return "住房不足"
		Keys.SH_POLLUTION:
			return "星球污染开始影响健康与生产：可建净化塔、研究清洁技术或出资治理"
	return str(entry.get("key", ""))


static func ledger(config: Dictionary, entry: Dictionary) -> String:
	var key: String = str(entry.get("key", ""))
	var name: String = str(LEDGER.get(key, key))
	var detail: String = str(entry.get("detail", ""))
	if detail == "":
		return name
	if key in ["export", "import.stock"]:
		return "%s · %s" % [name, str(config.resources.get(detail, detail))]
	if key in ["invest.build", "invest.upgrade", "wages.public", "upkeep.facility"]:
		return "%s · %s" % [name, building_name(config, detail)]
	if key == "invest.road":
		return "%s · 铺装" % name
	if key == "research.funding":
		return "%s · %s" % [name, str(config.techs.get(detail, {}).get("name", detail))]
	return "%s · %s" % [name, detail]


## The shortcut beside a shortage: what to do about it and where.
static func fix(entry: Dictionary) -> Dictionary:
	match str(entry.get("key", "")):
		Keys.SH_POWER:
			return {"text": "处理", "page": "build", "category": "utilities"}
		Keys.SH_WATER:
			return {"text": "处理", "page": "build", "category": "utilities"}
		Keys.SH_HOUSING:
			return {"text": "处理", "page": "build", "category": "people"}
		Keys.SH_STARVING:
			return {"text": "处理", "page": "build", "category": "food"}
		Keys.SH_DEPLETED, Keys.SH_PROCESSOR_INPUT:
			return {"text": "处理", "page": "build", "category": "extraction"}
		Keys.SH_NO_PORT, Keys.SH_PORT_FULL:
			return {"text": "处理", "page": "build", "category": "utilities"}
		Keys.SH_JOBS_WORKERS, Keys.SH_JOBS_SPECIALISTS:
			return {"text": "处理", "page": "population"}
		Keys.SH_POLLUTION:
			return {"text": "处理", "page": "company"}
	return {}


## Text for one row of the top resource table's tooltip: where the month's change came from.
static func flow_text(name: String, stock: float, flows: Array) -> String:
	return (
		"%s：全部据点合计 %.0f t\n近 30 日：产出 %.0f · 进口 %.0f · 消耗 %.0f · 出口 %.0f"
		% [name, stock, float(flows[0]), float(flows[3]), float(flows[1]), float(flows[2])]
	)


## Text for one plot in the build dialog's plot list.
static func plot(row: Dictionary) -> String:
	if str(row.kind) == "deposit":
		var depth: String = "深层 · " if bool(row.deep) else ""
		return "%s品位 %.2f · 储量 %.0f t" % [depth, float(row.grade), float(row.reserves)]
	if str(row.kind) == "farm":
		return "肥力 %.0f%%" % (float(row.fertility) * 100.0)
	return "建设用地"


## A site in lists: a settlement's name, or a number and what kind of place it is.
static func site_label(reg: Dictionary) -> String:
	if bool(reg.get("named", true)):
		return str(reg.name)
	return "%s · %s" % [str(reg.name), str(reg.terrain)]


## "A cold archipelago world, rugged." Empty for worlds from before planets had a character.
static func planet_type(types: Dictionary, character: Dictionary) -> String:
	if character.is_empty():
		return ""
	var text: String = (
		"%s的%s"
		% [str(types.climates[character.climate].name), str(types.layouts[character.layout].name)]
	)
	var relief: String = str(types.reliefs[character.relief].name)
	return text if relief == "" else "%s，%s" % [text, relief]


## 「现金可支撑 N 天」 for the top bar and the economy page; empty while nothing has been spent.
static func cover_text(cover: Dictionary) -> String:
	if float(cover.expense) < 1.0:
		return ""
	return (
		"现金可支撑 %.0f 天（按近 %d 日平均经营支出 ¥ %.0f/日）"
		% [float(cover.cover), int(cover.days), float(cover.expense)]
	)


## Where money with nothing to do could go, for the economy page and the advisor.
static func idle_money(sim: RefCounted) -> String:
	var services: Dictionary = sim.pop_rules.get("services", {})
	if not services.is_empty() and int(sim.state.policy.get("services", 0)) < int(services.levels):
		return "钱闲着：可以升级、扩建设施，或在人口移民里提高公共服务预算"
	return "钱闲着：可以升级、扩建设施，或开辟新据点"


## The share of export income that depends on mines running out, with advice once it is too much.
static func mine_warning(outlook: Dictionary, warn: bool) -> String:
	return (
		"近 30 日出口收入中约 %.0f%% 依赖 %d 天内将采空的矿（含用其矿石加工的产品）%s"
		% [float(outlook.share) * 100.0, int(outlook.days), "，收入会下滑：提前开新矿或发展加工" if warn else ""]
	)
