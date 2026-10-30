extends RefCounted
## Reads schema 1 and 2 saves (JSON envelope) and converts them to schema 3.
## The original validation runs first, so a malformed old save is refused as it was in 1.6.

const WorldGen = preload("res://world/world_gen.gd")
const Keys = preload("res://simulation/keys.gd")
const Research = preload("res://simulation/research.gd")
const Company = preload("res://simulation/company.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const Career = preload("res://simulation/career.gd")
const LEGACY_SCHEMAS: Array[int] = [1, 2]
const WORLD_RECORD_FIELDS: Array[String] = [
	"seed",
	"seed_input",
	"seed_protocol",
	"version",
	"size",
	"radius_km",
	"grid_width",
	"grid_height",
	"regions",
	"candidates",
]
const BUILDING_STATUS: Dictionary = {
	"建设中": Keys.B_BUILDING,
	"待结算": Keys.B_PENDING,
	"手动停工": Keys.B_DISABLED,
	"已探明储量耗尽": Keys.B_DEPLETED,
	"目标库存已满 · 自动停产": Keys.B_TARGET_FULL,
	"停工 · 缺少配方原料": Keys.B_NO_INPUT,
	"停工 · 岗位或供应不足": Keys.B_IDLE,
	"民营营业": Keys.B_PRIVATE_OPEN,
}
const ENTERPRISE_STATUS: Dictionary = {
	"装修中": Keys.E_FITTING,
	"营业中": Keys.E_OPEN,
	"经营受限": Keys.E_RESTRICTED,
	"暂停营业": Keys.E_PAUSED,
	"停业": Keys.E_CLOSED,
}
const ENTERPRISE_REASON: Dictionary = {
	"玩家暂停了服务设施": Keys.ER_PAUSED,
	"可雇用工人不足": Keys.ER_NO_WORKERS,
	"企业现金不足以支付工资与租金": Keys.ER_NO_CASH,
	"自主经营，无需逐日操作；利润税只对正利润征收": Keys.ER_RUNNING,
	"有偿重组或迁址，3 日后重新营业": Keys.ER_RECOVERING,
}
const LEDGER_KEYS: Dictionary = {
	"公司初始资本": "capital.initial",
	"开拓居民自带积蓄": "savings.settlers",
	"前哨部署投资": "invest.outpost",
	"运输网络投资": "invest.road",
	"民营投资人实缴资本": "enterprise.capital",
	"企业购买建设材料": "enterprise.inputs",
	"企业店面设备投资": "enterprise.fitout",
	"殖民行政费": "admin",
	"公司总督分成": "governor.share",
	"公共工资": "wages.public",
	"设施维护": "upkeep.facility",
	"轨道补给局可再生食品订单": "food_order.income",
	"食品订单港务费": "food_order.port_fee",
	"出口港务费": "export.port_fee",
	"食品进口及港务": "import.food",
	"居民购买基本食品": "food.sales",
	"民营企业工资": "enterprise.wages",
	"商业场地租金": "enterprise.rent",
	"企业设备维护": "enterprise.upkeep",
	"居民购买生活服务": "enterprise.sales",
	"本地企业利润税": "enterprise.tax",
	"陆路运输费": "transport.fee",
	"新移民携带积蓄": "savings.immigrants",
	"企业复业重组投资": "enterprise.recovery",
	"污染地区公共健康支出": "company.health",
	"地区污染治理": "company.cleanup",
	"科研及调查人员工资": "research.wages",
	"生涯资金注资（不计当地经营利润）": "career.invest",
	"人才移民自带积蓄": "savings.immigrants",
}
const LEDGER_PREFIXES: Dictionary = {
	"建设投资 · ": "invest.build",
	"出口 · ": "export",
	"建设库存采购 · ": "import.stock",
	"清偿欠款 · ": "arrears",
	"公司援助融资 · ": "aid.cash",
	"援助追加经营分成 · ": "aid.surcharge",
	"援助本金偿还 · ": "aid.repay",
	"科研经费 · ": "research.funding",
	"事件支出 · ": "event.pay",
	"事件一次性收入 · ": "event.reward",
	"加工订单到货 · ": "event.order_income",
	"订单装船港务 · ": "event.order_fee",
	"事件设施维护 · ": "event.upkeep",
}


static func load_legacy(sim: RefCounted, bytes: PackedByteArray) -> String:
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return "存档格式或版本不兼容"
	if not (parsed.get("version") is int or parsed.get("version") is float):
		return "存档格式或版本不兼容"
	if (
		float(parsed.version) != float(int(parsed.version))
		or not int(parsed.version) in LEGACY_SCHEMAS
	):
		return "存档格式或版本不兼容"
	if not parsed.has("payload") or not parsed.payload is String:
		return "存档缺少有效负载"
	if parsed.payload.sha256_text() != parsed.get("checksum", ""):
		return "存档校验失败"
	var candidate: Variant = JSON.parse_string(parsed.payload)
	if parsed.has("binary"):
		if (
			not parsed.binary is String
			or parsed.binary.sha256_text() != parsed.get("binary_checksum", "")
		):
			return "精确状态校验失败"
		candidate = bytes_to_var(Marshalls.base64_to_raw(parsed.binary))
	var schema_one: bool = candidate is Dictionary and candidate.get("schema", 0) == 1
	var error: String = validate_old(sim, candidate, schema_one)
	if error != "":
		return error
	var old_state: Dictionary = sim.state
	var old_geo: Dictionary = sim.geo
	if schema_one:
		candidate.schema = 2
		candidate.difficulty = "normal"
		# ensure() only reads and fills sim.state, so it runs on the candidate here.
		sim.state = candidate
		Research.ensure(sim)
		Company.ensure(sim)
		Career.ensure(sim)
		EventsV2.ensure(sim)
		sim.state = old_state
		sim.geo = old_geo
	var converted: Dictionary = convert_v2(candidate)
	if converted.has("error"):
		return str(converted.error)
	return load("res://simulation/save_io.gd").adopt(sim, converted.state, converted.blobs)


## Converts one schema 2 state in place. Returns {state, blobs} or {error}.
static func convert_v2(old: Dictionary) -> Dictionary:
	var world: Dictionary = old.world
	var record: Dictionary = {}
	for field: String in WORLD_RECORD_FIELDS:
		if world.has(field):
			record[field] = world[field]
	var world_hash: String = WorldGen.geo_hash(world)
	record.hash = world_hash
	if not WorldGen.regenerates(world, world_hash):
		record.stored_geo = WorldGen.pack_geo(world)
	old.world = record
	for s: Dictionary in old.settlements:
		s.shortages = []
		for b: Dictionary in s.buildings:
			b.status = _building_status(b)
			b.erase("reason")
	if not old.enterprise.is_empty():
		var enterprise: Dictionary = old.enterprise
		enterprise.status = ENTERPRISE_STATUS.get(enterprise.status, Keys.E_OPEN)
		enterprise.reason = ENTERPRISE_REASON.get(enterprise.reason, Keys.ER_FITTING)
	for entry: Dictionary in old.ledger:
		_convert_entry(entry)
	for bill: Dictionary in old.arrears:
		bill.key = _ledger_key(str(bill.category)).key
		bill.erase("category")
	var blobs: Dictionary = {"checkpoint": PackedByteArray(), "archives": {}}
	var career: Dictionary = old.get("career", {})
	var encoded: String = str(career.get("checkpoint", ""))
	career.checkpoint = ""
	if encoded != "":
		var checkpoint: Variant = Career.decode_legacy(encoded)
		if not checkpoint is Dictionary:
			return {"error": "登陆检查点损坏"}
		var converted: Dictionary = convert_v2(checkpoint)
		if converted.has("error"):
			return converted
		blobs.checkpoint = Career.encode_blob(converted.state)
		career.checkpoint = Career.blob_hash(blobs.checkpoint)
	for archive: Dictionary in career.get("archives", []):
		var snapshot: Variant = Career.decode_legacy(str(archive.get("snapshot", "")))
		if snapshot is Dictionary:
			blobs.archives[archive.id] = Career.encode_blob(snapshot)
			archive.hash = Career.blob_hash(blobs.archives[archive.id])
		else:
			archive.hash = ""
		archive.erase("snapshot")
	old.schema = 3
	return {"state": old, "blobs": blobs}


static func _building_status(b: Dictionary) -> String:
	if int(b.get("remaining", 0)) > 0:
		return Keys.B_BUILDING
	if not bool(b.get("enabled", true)):
		return Keys.B_DISABLED
	var old_status: String = str(b.get("status", ""))
	if old_status.begins_with("运行"):
		return Keys.B_RUNNING
	return BUILDING_STATUS.get(old_status, Keys.B_PENDING)


static func _convert_entry(entry: Dictionary) -> void:
	var converted: Dictionary = _ledger_key(str(entry.get("category", "")))
	entry.key = converted.key
	entry.detail = converted.detail
	entry.erase("category")


static func _ledger_key(category: String) -> Dictionary:
	if LEDGER_KEYS.has(category):
		return {"key": LEDGER_KEYS[category], "detail": ""}
	for prefix: String in LEDGER_PREFIXES:
		if category.begins_with(prefix):
			return {"key": LEDGER_PREFIXES[prefix], "detail": category.trim_prefix(prefix)}
	return {"key": "legacy.event", "detail": category}


## The 1.6 validator, unchanged in what it accepts and refuses.
static func validate_old(sim: RefCounted, candidate: Variant, schema_one: bool) -> String:
	if not candidate is Dictionary:
		return "存档状态无效"
	# Validate nested containers before any property access or audit. GDScript
	# runtime errors do not throw to the caller; a validator error must never be
	# mistaken for an empty success result and replace the current state.
	var shape_error: String = sim._save_shape(candidate, _old_shape(sim), "state")
	if shape_error != "":
		return shape_error
	if (
		candidate.world.grid_width != WorldGen.GW
		or candidate.world.grid_height != WorldGen.GH
		or candidate.world.grid.size() != WorldGen.GW * WorldGen.GH
		or candidate.world.regions.size() != 6
	):
		return "世界网格或地区数量不合法"
	if (
		float(candidate.schema) != float(int(candidate.schema))
		or not int(candidate.schema) in ([1] if schema_one else [2])
		or not candidate.status in ["planning", "active", "success", "failed"]
		or not sim.config.openings.has(candidate.advantage)
	):
		return "存档版本或阶段无效"
	if not candidate.route.is_empty():
		shape_error = sim._save_shape(
			candidate.route,
			{
				"reachable": false,
				"distance": 0,
				"days": 0,
				"cost": 0,
				"path": [0],
				"coordinates": [[0]],
				"mountain": false,
				"a": 0,
				"b": 0,
				"capacity": 0,
				"blocked_until": 0,
				"sent_today": 0
			},
			"route"
		)
		if shape_error != "":
			return shape_error
		if (
			candidate.route.days < 1
			or candidate.route.a < 0
			or candidate.route.a >= 6
			or candidate.route.b < 0
			or candidate.route.b >= 6
		):
			return "运输线路无效"
		for pair: Array in candidate.route.coordinates:
			if pair.size() != 2:
				return "运输坐标无效"
	if not candidate.enterprise.is_empty():
		shape_error = sim._save_shape(
			candidate.enterprise,
			{
				"name": "",
				"region": 0,
				"industry": "",
				"status": "",
				"remaining": 0,
				"employees": 0,
				"profit": 0,
				"sales_total": 0,
				"wages_total": 0,
				"tax_total": 0,
				"loss_days": 0,
				"reason": "",
				"rent": 0
			},
			"enterprise"
		)
		if shape_error != "":
			return shape_error
	if not candidate.event.is_empty():
		shape_error = sim._save_shape(
			candidate.event,
			{
				"id": "",
				"day": 0,
				"title": "",
				"text": "",
				"duration": 0,
				"expires": 0,
				"choices": [{"id": "", "label": ""}]
			},
			"event"
		)
		if shape_error != "":
			return shape_error
	for key: Variant in candidate.effects:
		shape_error = sim._save_shape(
			candidate.effects[key], "" if key == "drought_choice" else 0, "effects." + str(key)
		)
		if shape_error != "":
			return shape_error
	if not candidate.world.version in WorldGen.SUPPORTED_VERSIONS:
		return "世界生成器版本不同"
	if candidate.settlements.size() > 2:
		return "据点数据不合法"
	shape_error = _validate_old_settlements(sim, candidate, schema_one)
	if shape_error != "":
		return shape_error
	for cargo: Dictionary in candidate.shipments:
		if (
			not cargo.resource in Keys.RESOURCES
			or cargo.amount < 0
			or cargo.total_days < 1
			or cargo.remaining < 0
		):
			return "在途货物数据无效"
		if cargo.from < 0 or cargo.from >= 6 or cargo.to < 0 or cargo.to >= 6:
			return "货物目的地无效"
	shape_error = WorldGen.world_compatibility_error(candidate.world)
	if shape_error != "":
		return shape_error
	if schema_one:
		return ""
	shape_error = EventsV2.validate(candidate)
	if shape_error != "":
		return shape_error
	if (
		not candidate.get("difficulty") is String
		or not sim.progression.difficulty.has(candidate.difficulty)
	):
		return "难度配置无效"
	for validator: Variant in [Research, Company]:
		shape_error = validator.validate(sim, candidate)
		if shape_error != "":
			return shape_error
	return Career.validate_old(candidate)


static func _old_building_shape() -> Dictionary:
	return {
		"kind": "",
		"remaining": 0,
		"active": false,
		"enabled": true,
		"status": "",
		"reason": "",
		"employed": 0,
		"specialists": 0,
		"efficiency": 0.0,
		"owner": ""
	}


static func _validate_old_settlements(
	sim: RefCounted, candidate: Dictionary, schema_one: bool
) -> String:
	for s: Variant in candidate.settlements:
		if not s is Dictionary:
			return "据点数据不合法"
		var error: String = sim._save_shape(
			s,
			{
				"region": 0,
				"name": "",
				"population": 0,
				"children": 0,
				"workers": 0,
				"scientists": 0,
				"stock": sim._stock(),
				"stock_delta": sim._stock(),
				"buildings": [_old_building_shape()],
				"jobs": 0,
				"housing": 0,
				"base_housing": 0,
				"food_days": 0,
				"shortages": [""],
				"employed": 0,
				"employed_workers": 0,
				"employed_scientists": 0,
				"power_supply": 0,
				"power_demand": 0,
				"water_supply": 0,
				"water_demand": 0,
				"starvation": 0,
				"arrival": 0,
				"cohorts": [{"count": 0, "mature_day": 0}],
				"port_used": 0,
				"port_capacity": 0,
				"food_consumed": 0
			},
			"settlement"
		)
		if error != "":
			return error
		if s.has("exportable"):
			error = sim._save_shape(
				s.exportable, {"materials": 0, "parts": 0}, "settlement.exportable"
			)
			if error != "":
				return error
		for key: String in [
			"population",
			"children",
			"workers",
			"scientists",
			"employed_workers",
			"employed_scientists"
		]:
			if s[key] < 0:
				return "人口与岗位不能为负数"
		if int(s.region) < 0 or int(s.region) >= candidate.world.regions.size():
			return "据点位置无效"
		for b: Variant in s.buildings:
			if (
				not b is Dictionary
				or not b.has("kind")
				or not b.has("remaining")
				or (b.kind != "service" and not sim.config.buildings.has(b.kind))
			):
				return "建筑数据无效"
		if schema_one:
			continue
		if s.has("targets"):
			if not s.targets is Dictionary:
				return "库存目标类型无效"
			for resource: Variant in s.targets:
				if not resource in Keys.RESOURCES:
					return "库存目标资源无效"
				error = sim._save_shape(s.targets[resource], 0, "stock_target")
				if error != "":
					return error
		for field: String in ["pollution", "social_days"]:
			error = sim._save_shape(s.get(field, 0), 0, "settlement." + field)
			if error != "":
				return error
	return ""


static func _old_shape(sim: RefCounted) -> Dictionary:
	return {
		"schema": 0,
		"world":
		{
			"seed": 0,
			"version": "",
			"size": 0,
			"radius_km": 0,
			"grid_width": 0,
			"grid_height": 0,
			"grid":
			[
				{
					"height": 0,
					"temperature": 0,
					"rainfall": 0,
					"land": false,
					"river": false,
					"lake": false
				}
			],
			"regions":
			[
				{
					"id": 0,
					"name": "",
					"lat": 0,
					"lon": 0,
					"elevation": 0,
					"fertility": 0,
					"water": 0,
					"temperature": 0,
					"rainfall": 0,
					"deposits": {"ore": 0, "copper": 0, "crystal": 0},
					"grade": {"ore": 0, "copper": 0, "crystal": 0},
					"neighbors": [0],
					"terrain": "",
					"land_fraction": 0,
					"river": false,
					"grid_index": 0,
					"development_multiplier": 0
				}
			],
			"candidates": [0],
			"rivers": [[[0]]],
			"lakes": [{"lat": 0, "lon": 0, "name": "", "elevation": 0}]
		},
		"day": 0,
		"advantage": "",
		"cash": 0,
		"resident_cash": 0,
		"enterprise_cash": 0,
		"initial_money": 0,
		"external_in": 0,
		"external_out": 0,
		"settlements": [],
		"shipments":
		[
			{
				"from": 0,
				"to": 0,
				"resource": "",
				"amount": 0,
				"remaining": 0,
				"total_days": 0,
				"expedition": false
			}
		],
		"research": {"current": "", "progress": 0, "completed": [""], "priority": 0},
		"route": {},
		"enterprise": {},
		"events": [""],
		"event": {},
		"effects": {},
		"ledger":
		[{"day": 0, "category": "", "amount": 0, "from": "", "to": "", "operating": false}],
		"log": [{"day": 0, "text": ""}],
		"status": "",
		"streak": 0,
		"operating_net": 0,
		"operating_history": [{"day": 0, "net": 0, "income": 0, "expense": 0}],
		"income_daily": 0,
		"expense_daily": 0,
		"debt": 0,
		"arrears": [{"to": "", "amount": 0, "category": ""}],
		"grace_days": 0,
		"policy": {"tax": 0, "food_reserve": 0, "private_allowed": false},
		"exports_total": 0,
		"imports_total": 0,
		"transported_total": 0,
		"company_tax_total": 0,
		"success_day": 0,
		"failure_reason": "",
		"resource_sources": sim._stock(),
		"resource_sinks": sim._stock(),
		"rng_state": 0,
		"births_total": 0,
		"immigrants_total": 0
	}
