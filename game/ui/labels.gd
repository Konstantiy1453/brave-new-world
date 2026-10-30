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
	Keys.ER_NO_WORKERS: "可雇用工人不足",
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
	"legacy.event": "旧版事件",
}

const STAGE_NAMES: Dictionary = {
	"foothold": "第一阶段 · 立足",
	"division": "第二阶段 · 分工",
	"self_reliance": "第三阶段 · 自立",
}
const LICENCE_NAMES: Dictionary = {
	"expedition": "第二据点远征许可",
	"third_settlement": "第三据点许可",
}
const ATTRACTIVENESS_PARTS: Dictionary = {
	"beds": "住房",
	"food": "食品保障",
	"jobs": "工作机会",
	"wage": "工资政策",
	"services": "生活服务",
	"pollution": "污染",
	"shortages": "水电短缺",
	"company": "公司审查",
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
				"text": "连续经营结余非负 %d / %d 天" % [value, target],
				"hint": "收入不低于支出且没有欠款",
				"page": "economy"
			}
		"research_staffed":
			return {
				"text": "在研项目 %d / %d" % [value, target], "hint": "建研究所并分配研究员", "page": "research"
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
				"hint": "在肥沃地块建农场",
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
			return {"text": "完成技术 %d / %d" % [value, target], "hint": "分配更多研究员", "page": "research"}
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
	return {"text": str(row.key), "hint": "", "page": ""}


static func building_name(config: Dictionary, kind: String) -> String:
	if kind == "service":
		return "民营生活服务社"
	return str(config.buildings.get(kind, {}).get("name", kind))


static func building_status(building: Dictionary) -> String:
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
			return "岗位缺员：%s（需要工人）" % building_name(config, detail)
		Keys.SH_JOBS_SPECIALISTS:
			return "岗位缺员：%s（需要研究员）" % building_name(config, detail)
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
			return "港口吞吐不足：存在尚未满足的补给需求"
		Keys.SH_STARVING:
			return "食品供给不足 · 已持续 %s 天" % detail
		Keys.SH_HOUSING:
			return "住房不足"
		Keys.SH_POLLUTION:
			return "污染影响健康与生产；可治理或停用高污染设施"
	return str(entry.get("key", ""))


static func ledger(config: Dictionary, entry: Dictionary) -> String:
	var key: String = str(entry.get("key", ""))
	var name: String = str(LEDGER.get(key, key))
	var detail: String = str(entry.get("detail", ""))
	if detail == "":
		return name
	if key in ["export", "import.stock"]:
		return "%s · %s" % [name, str(config.resources.get(detail, detail))]
	if key == "invest.build":
		return "%s · %s" % [name, building_name(config, detail)]
	if key == "research.funding":
		return "%s · %s" % [name, str(config.techs.get(detail, {}).get("name", detail))]
	return "%s · %s" % [name, detail]
