extends RefCounted
## Local-day, independently seeded, original event definitions. All payouts are receipts.
## Each run deals itself a deck: some definitions are simply not in it. A definition can open again
## after its cooldown. Notices never pause; decisions pause when they are critical or the player
## asks for every decision to pause. Money scales with recent income.
const PRODUCTION_KINDS: Array[String] = ["mine", "farm", "processor"]
const EFFECT_KINDS: Array[String] = [
	"water",
	"farm",
	"mine",
	"processor",
	"port",
	"power",
	"all",
	"appeal",
	"research",
	"export_price",
	"road_capacity"
]
const PAUSE_ALL: String = "all"
const PAUSE_CRITICAL: String = "critical"
## How a gift technology's effects read on an event card: the name, and -1 where a bonus makes the
## number smaller (trips get shorter).
const GIFT_EFFECTS: Dictionary = {
	"road_speed": ["陆路单程时间", -1.0],
	"road_capacity": ["道路运力", 1.0],
	"sea_speed": ["航程时间", -1.0],
	"sea_capacity": ["航线运力", 1.0],
}

static var _definitions: Dictionary = {}


static func definitions() -> Dictionary:
	if _definitions.is_empty():
		_definitions = load("res://simulation/rules.gd").read("events")
	return _definitions


## Saves from before cooldowns: what has been seen counts as last opened when it was created.
static func ensure_state(state: Dictionary) -> void:
	if not state.policy.has("event_pause"):
		state.policy.event_pause = PAUSE_CRITICAL
	if not state.has("events_v2"):
		return
	var e: Dictionary = state.events_v2
	if not e.has("last_opened"):
		e.last_opened = {}
		e.endings = {}
		for inst: Dictionary in e.instances:
			e.last_opened[inst.definition_id] = int(inst.created_day)
			if str(inst.ending) != "":
				e.endings[inst.definition_id] = str(inst.ending)
	if not e.has("off"):
		e.off = _deal_deck(e)


## Which definitions this run will never draw. Not every story happens on every planet.
static func _deal_deck(e: Dictionary) -> Array:
	var rules: Dictionary = definitions()
	var seen: Array = e.get("seen", [])
	var off: Array = []
	for id: String in rules.definitions:
		var d: Dictionary = rules.definitions[id]
		var chance: float = float(d.get("chance", rules.sampling.availability))
		if _rng(e) >= chance and not seen.has(id):
			off.append(id)
	return off


static func ensure(sim) -> void:
	if sim.state.has("events_v2"):
		ensure_state(sim.state)
		return
	var seed_value: int = int(sim.state.world.seed)
	sim.state.events_v2 = {
		"version": 2,
		"rng_state": (absi(seed_value) % 2147483646) + 1,
		"next_id": 1,
		"next_draw": int(definitions().sampling.first_draw_day),
		"last_negative": -100,
		"instances": [],
		"history": [],
		"effects": [],
		"seen": [],
		"last_tick": -1,
		"last_opened": {},
		"endings": {},
	}
	ensure_state(sim.state)


static func _rng(e: Dictionary) -> float:
	e.rng_state = (int(e.rng_state) * 48271) % 2147483647
	return float(e.rng_state) / 2147483647.0


static func _instance(sim, id: String) -> Dictionary:
	for inst in sim.state.events_v2.instances:
		if inst.instance_id == id:
			return inst
	return {}


static func _node(inst: Dictionary) -> Dictionary:
	return definitions().definitions.get(inst.definition_id, {}).get("nodes", {}).get(inst.node, {})


static func _has_building(s: Dictionary, kind: String) -> bool:
	for b in s.get("buildings", []):
		if b.kind == kind and int(b.remaining) <= 0 and bool(b.get("enabled", true)):
			return true
	return false


static func _matches(sim, s: Dictionary, c: Dictionary) -> bool:
	if int(sim.state.day) < int(c.get("min_day", 0)) or int(s.arrival) > 0:
		return false
	if c.has("building") and not _has_building(s, c.building):
		return false
	if c.get("mine", false) and not _has_mine(s):
		return false
	if int(s.scientists) < int(c.get("scientists", 0)):
		return false
	if sim.state.settlements.size() < int(c.get("settlements", 1)):
		return false
	if float(sim.state.exports_total) < float(c.get("exports", 0)):
		return false
	if c.has("status") and sim.state.status != c.status:
		return false
	if c.has("previous"):
		var parts: PackedStringArray = str(c.previous).split(":")
		if str(sim.state.events_v2.endings.get(parts[0], "")) != parts[1]:
			return false
	return _matches_colony(sim, s, c)


static func _has_mine(s: Dictionary) -> bool:
	for b: Dictionary in s.get("buildings", []):
		if str(b.kind).begins_with("mine_") and int(b.remaining) <= 0:
			return true
	return false


## Conditions on the systems added since 1.6.
static func _matches_colony(sim, s: Dictionary, c: Dictionary) -> bool:
	if bool(c.get("trigger_only", false)):
		return false
	var site: Dictionary = sim.state.world.regions[int(s.region)]
	if bool(c.get("frontier", false)) and str(s.kind) != "frontier":
		return false
	if bool(c.get("residential", false)) and str(s.kind) != "residential":
		return false
	if bool(c.get("coast", false)) and not bool(site.get("coast", false)):
		return false
	if sim.Pollution.stage(sim) < int(c.get("pollution_stage", 0)):
		return false
	if int(s.population) < int(c.get("population", 0)):
		return false
	if int(s.children) < int(c.get("children", 0)):
		return false
	if float(s.get("attractiveness", 1.0)) < float(c.get("attractiveness", 0.0)):
		return false
	if float(sim.state.imports_total) < float(c.get("imports", 0.0)):
		return false
	if int(sim.state.contract.stage) < int(c.get("contract_stage", 0)):
		return false
	if c.has("wage_below") and float(sim.state.policy.wage) >= float(c.wage_below):
		return false
	if c.has("employment"):
		var adults: int = maxi(1, int(s.workers) + int(s.scientists))
		if float(s.employed) / adults < float(c.employment):
			return false
	if bool(c.get("river", false)) and not bool(site.get("river", false)):
		return false
	if bool(c.get("arid", false)) and float(site.get("rainfall", 0.5)) >= 0.32:
		return false
	if bool(c.get("cold", false)) and float(site.get("temperature", 20.0)) >= 6.0:
		return false
	if bool(c.get("wet", false)) and float(site.get("rainfall", 0.5)) < 0.55:
		return false
	if bool(c.get("no_enterprise", false)) and not sim.state.enterprise.is_empty():
		return false
	if bool(c.get("research_active", false)) and not _project_running(sim):
		return false
	if bool(c.get("road", false)) and not _has_road_at(sim, int(s.region)):
		return false
	if bool(c.get("land_road", false)) and not _has_road_at(sim, int(s.region), "land"):
		return false
	if bool(c.get("sea_link", false)) and not _has_road_at(sim, int(s.region), "sea"):
		return false
	if c.has("lacks_tech") and sim.state.research.completed.has(str(c.lacks_tech)):
		return false
	if bool(c.get("hidden_deposit", false)) and not _has_hidden(site):
		return false
	return true


static func _project_running(sim) -> bool:
	for project: Dictionary in sim.state.research.get("projects", {}).values():
		if int(project.effective) > 0:
			return true
	return false


## A finished link at this place; `kind` "land" counts only roads, "sea" only cargo docks.
static func _has_road_at(sim, region: int, kind: String = "") -> bool:
	for road: Dictionary in sim.state.roads:
		var ready: bool = int(road.get("ready_day", 0)) < int(sim.state.day)
		if not ready or (int(road.a) != region and int(road.b) != region):
			continue
		var variant: String = str(road.get("variant", "valley"))
		if kind == "sea" and variant != "sea":
			continue
		if kind == "land" and variant in ["sea", "shuttle"]:
			continue
		return true
	return false


static func _has_hidden(site: Dictionary) -> bool:
	for plot: Dictionary in site.get("plots", []):
		if plot.kind == "deposit" and bool(plot.hidden):
			return true
	return false


static func _date(day: int) -> String:
	return "%d年%d月%d日" % [day / 360 + 1, (day % 360) / 30 + 1, day % 30 + 1]


## Whether this definition makes the game stop and wait, under the player's setting.
static func _pauses(sim, definition: Dictionary) -> bool:
	if str(definition.get("kind", "decision")) == "notice":
		return false
	if bool(definition.get("critical", true)):
		return true
	return str(sim.state.policy.get("event_pause", PAUSE_CRITICAL)) == PAUSE_ALL


static func _cooled(sim, id: String) -> bool:
	var e: Dictionary = sim.state.events_v2
	if not e.last_opened.has(id):
		return true
	var d: Dictionary = definitions().definitions[id]
	var cooldown: int = int(d.get("cooldown_days", definitions().sampling.default_cooldown_days))
	return int(sim.state.day) - int(e.last_opened[id]) >= cooldown


static func _open_now(sim, id: String) -> bool:
	for inst: Dictionary in sim.state.events_v2.instances:
		if inst.definition_id == id and not inst.status in ["resolved", "cancelled"]:
			return true
	return false


## Money in events keeps pace with the colony: at most a few days of recent income.
static func money_scale(sim) -> float:
	var rules: Dictionary = definitions().sampling
	var history: Array = sim.state.get("operating_history", [])
	var window: int = mini(int(rules.income_window_days), history.size())
	if window <= 0:
		return 1.0
	var total: float = 0.0
	for i: int in range(history.size() - window, history.size()):
		total += float(history[i].income)
	return maxf(1.0, total / window / float(rules.reference_income))


static func _pay(sim, option: Dictionary) -> float:
	return float(option.get("pay", 0.0)) * money_scale(sim)


static func _reward(sim, option: Dictionary) -> float:
	return float(option.get("reward", 0.0)) * money_scale(sim)


## Opens a definition because something just happened, if its cooldown allows.
static func trigger(sim, id: String, region: int) -> void:
	if not sim.state.has("events_v2") or sim.settlement(region).is_empty():
		return
	if not definitions().definitions.has(id):
		return
	if _open_now(sim, id) or not _cooled(sim, id):
		return
	_open(sim, id, region)
	_sync_legacy(sim)


static func _open(sim, definition_id: String, region: int) -> Dictionary:
	var e: Dictionary = sim.state.events_v2
	var d: Dictionary = definitions().definitions[definition_id]
	var id: String = "%s:e%d" % [str(sim.state.world.seed), int(e.next_id)]
	e.next_id += 1
	var inst: Dictionary = {
		"instance_id": id,
		"definition_id": definition_id,
		"definition_version": int(d.version),
		"target_region": region,
		"node": "start",
		"status": "pending",
		"created_day": int(sim.state.day),
		"deadline": 0,
		"pause_required": true,
		"ending": "",
		"variables": {},
		"history": [],
		"scheduled": {},
		"order": {}
	}
	e.instances.append(inst)
	if not e.seen.has(definition_id):
		e.seen.append(definition_id)
	e.last_opened[definition_id] = int(sim.state.day)
	_prune(e)
	_enter(sim, inst, "start")
	if d.category == "incident":
		e.last_negative = int(sim.state.day)
	return inst


## Finished instances beyond a short memory go; what chains need lives in `endings`.
static func _prune(e: Dictionary) -> void:
	var keep: int = int(definitions().sampling.keep_resolved_instances)
	var resolved: int = 0
	for index: int in range(e.instances.size() - 1, -1, -1):
		if e.instances[index].status in ["resolved", "cancelled"]:
			resolved += 1
			if resolved > keep:
				e.instances.remove_at(index)


static func _enter(sim, inst: Dictionary, node_id: String) -> void:
	inst.node = node_id
	inst.status = "pending"
	# A node marked critical (a chain's deciding step) waits for the player whatever its event's
	# own setting: a finale is never settled by a default the player did not see.
	inst.pause_required = (
		_pauses(sim, definitions().definitions[inst.definition_id])
		or bool(_node(inst).get("critical", false))
	)
	inst.scheduled = {}
	inst.deadline = int(sim.state.day) + int(_node(inst).get("deadline_days", 6))
	inst.variables.erase("deferred_node")
	sim._log("事件 · " + str(_node(inst).title))


## `closing` carries the ending scene when a choice ends the event: its `outcome` text, what
## changed in words (`changes`), and whether the default applied at the deadline (`automatic`).
static func _end(sim, inst: Dictionary, ending: String, closing: Dictionary = {}) -> void:
	if inst.status in ["resolved", "cancelled"]:
		return
	if sim.has_method("research_release"):
		sim.research_release(inst.instance_id)
	inst.status = "resolved"
	inst.pause_required = false
	inst.ending = ending
	inst.scheduled = {}
	inst.variables.erase("investigation")
	sim.state.events_v2.endings[inst.definition_id] = ending
	var row: Dictionary = {
		"instance_id": inst.instance_id,
		"definition_id": inst.definition_id,
		"day": int(sim.state.day),
		"ending": ending,
		"target_region": inst.target_region
	}
	for key: String in ["outcome", "changes"]:
		if str(closing.get(key, "")) != "":
			row[key] = str(closing[key])
	if closing.has("automatic"):
		row.automatic = bool(closing.automatic)
	sim.state.events_v2.history.append(row)
	while sim.state.events_v2.history.size() > 80:
		sim.state.events_v2.history.pop_front()
	sim._log("事件结案 · " + ending)


static func _choice(inst: Dictionary, id: String) -> Dictionary:
	for choice in _node(inst).get("choices", []):
		if choice.id == id:
			return choice
	return {}


static func _reason(sim, inst: Dictionary, option: Dictionary) -> String:
	var s: Dictionary = sim.settlement(int(inst.target_region))
	if s.is_empty():
		return "目标据点已不存在"
	if option.is_empty():
		return "未知选项"
	if float(sim.state.cash) < _pay(sim, option):
		return "公共资金不足：需要 %.0f" % _pay(sim, option)
	var colony_reason: String = _colony_reason(sim, s, option)
	if colony_reason != "":
		return colony_reason
	for resource in option.get("goods_cost", {}):
		if float(s.stock.get(resource, 0)) < float(option.goods_cost[resource]):
			return "本地库存不足：" + str(resource)
	if option.get("requires_survey", false) and not bool(inst.variables.get("surveyed", false)):
		return "需要完成水线实测"
	if option.get("sell_rights", false) and bool(inst.variables.get("rights_sold", false)):
		return "调查权已经转让"
	if option.has("investigate"):
		var count: int = 0
		for place in sim.state.settlements:
			count += int(place.scientists)
		for key in sim.state.research.get("investigations", {}):
			if key != inst.instance_id:
				count -= int(sim.state.research.investigations[key].staff)
		if count < int(option.investigate):
			return "可派遣研究团队不足 %d 支" % int(option.investigate)
	if option.has("build"):
		var b: Dictionary = sim.build_preview(int(inst.target_region), str(option.build))
		var refusal: String = sim.Production.build_refusal(
			sim, int(inst.target_region), str(option.build)
		)
		if int(s.arrival) > 0 or refusal != "":
			return refusal if refusal != "" else "据点未到达"
		if float(sim.state.cash) < float(b.cost) + _pay(sim, option):
			return "建设资金不足"
		if float(s.stock.materials) < float(b.materials) or float(s.stock.parts) < float(b.parts):
			return "本地建设材料不足"
		var free: int = sim.free_workers(s)
		if free < int(b.jobs):
			return "需要 %d 支工程队，目前空闲 %d 支" % [int(b.jobs), free]
		var free_specialists: int = sim.free_specialists(s)
		if free_specialists < int(b.get("specialists", 0)):
			return "需要 %d 支研究团队，目前空闲 %d 支" % [int(b.get("specialists", 0)), free_specialists]
	if option.has("order"):
		if not _has_building(s, "processor") or not _has_building(s, "port"):
			return "需要已启用的加工厂和货站"
	return ""


## Beds, hands, specialists and what else an option needs before it may be chosen.
static func _colony_reason(sim, s: Dictionary, option: Dictionary) -> String:
	var beds: int = int(option.get("beds", 0))
	if beds > 0 and sim.Population.free_beds(sim, s) < beds:
		return "需要 %d 张空床位，目前 %d 张" % [beds, maxi(0, sim.Population.free_beds(sim, s))]
	var hands: int = int(option.get("workers", 0))
	if hands > 0 and sim.free_workers(s) < hands:
		return "需要 %d 支空闲工程队，目前 %d 支" % [hands, sim.free_workers(s)]
	var trained: int = int(option.get("train_scientists", 0))
	if trained > 0 and int(s.workers) < trained + 8:
		return "工程队太少，无法抽调培训"
	if float(option.get("research_points", 0.0)) > 0.0 and not _project_running(sim):
		return "目前没有进行中的科研项目"
	if bool(option.get("found_enterprise", false)):
		if not sim.state.enterprise.is_empty():
			return "已有一家民营企业"
		if float(sim.enterprise_preview(int(s.region)).get("estimated_profit", -1.0)) < 0.0:
			return "当地需求还撑不起服务社"
		if float(s.stock.materials) < 8.0 or float(s.stock.parts) < 2.0:
			return "企业要向本地仓库购买 8 建材和 2 部件"
	if bool(option.get("clear_closure", false)) or int(option.get("shorten_closure", 0)) > 0:
		if _closed_road(sim, int(s.region)).is_empty():
			return "这里没有封闭中的道路"
	return ""


static func _closed_road(sim, region: int) -> Dictionary:
	for road: Dictionary in sim.state.roads:
		if int(road.a) != region and int(road.b) != region:
			continue
		if int(road.get("ready_day", 0)) >= int(sim.state.day):
			continue
		if int(road.get("blocked_until", 0)) >= int(sim.state.day):
			return road
	return {}


static func act(sim, args: Dictionary) -> String:
	# Reject before ensure, so malformed commands cannot mutate even migration state.
	if not sim.state.has("events_v2"):
		return "没有待处理的新事件"
	if not args.get("instance_id", "") is String or not args.get("choice", "") is String:
		return "事件操作参数类型无效"
	var inst: Dictionary = _instance(sim, str(args.get("instance_id", "")))
	if inst.is_empty():
		return "事件实例不存在"
	var key: String = str(args.get("choice", ""))
	if (
		key == "cancel"
		and inst.status == "waiting"
		and inst.scheduled.get("kind", "") == "research"
	):
		_end(sim, inst, "主动撤回调查，现场封存")
		_sync_legacy(sim)
		return ""
	if not inst.status in ["pending", "deferred"]:
		return "事件节点已处理或正在等待实际进展"
	if sim.settlement(int(inst.target_region)).is_empty():
		return "目标据点已不存在，下一日将取消事件"
	if key == "defer":
		if inst.variables.get("deferred_node", "") == inst.node:
			return "本节点已经稍后处理；截止日不会延长"
		inst.status = "deferred"
		inst.pause_required = false
		inst.variables.deferred_node = inst.node
		inst.history.append(
			{"day": int(sim.state.day), "node": inst.node, "choice": "defer", "automatic": false}
		)
		_sync_legacy(sim)
		return ""
	var option: Dictionary = _choice(inst, key)
	var reason: String = _reason(sim, inst, option)
	if reason != "":
		return reason
	return _apply(sim, inst, option, false)


static func _apply(sim, inst: Dictionary, option: Dictionary, automatic: bool) -> String:
	var s: Dictionary = sim.settlement(int(inst.target_region))
	# Reserve first: a failed reservation has no economic side effects.
	if option.has("investigate"):
		var error: String = sim.research_reserve(inst.instance_id, int(option.investigate))
		if error != "":
			return error
	if option.has("build"):
		var error: String = sim.act(
			"build", {"region": int(inst.target_region), "kind": str(option.build)}
		)
		if error != "":
			return error
		inst.variables.building_index = s.buildings.size() - 1
		inst.variables.building_kind = str(option.build)
	sim._transfer(
		"public", "external", _pay(sim, option), "event.pay", false, str(inst.instance_id)
	)
	for key in option.get("goods_cost", {}):
		sim._consume(s, str(key), float(option.goods_cost[key]))
	if option.has("reward"):
		sim._transfer(
			"external", "public", _reward(sim, option), "event.reward", false, str(inst.instance_id)
		)
	for key in option.get("goods_reward", {}):
		sim._produce(s, str(key), float(option.goods_reward[key]), "事件外部交付 · " + inst.instance_id)
	if option.get("sell_rights", false):
		inst.variables.rights_sold = true
	_apply_colony(sim, s, option)
	_forget_old_effects(sim)
	for effect in option.get("effects", []):
		var n: int = int(effect.duration_days)
		var factor: float = float(effect.factor)
		if effect.has("clinic") and sim.Population.has_clinic(s):
			factor = float(effect.clinic)
		sim.state.events_v2.effects.append(
			{
				"source": inst.instance_id,
				"region": int(inst.target_region),
				"kind": str(effect.kind),
				"factor": factor,
				"start": int(sim.state.day) + 1,
				"until": int(sim.state.day) + 1 + n if n > 0 else -1,
				"duration_days": n,
				"maintenance": float(effect.get("maintenance", 0)),
				"label": str(effect.get("label", ""))
			}
		)
	var step: Dictionary = {
		"day": int(sim.state.day), "node": inst.node, "choice": option.id, "automatic": automatic
	}
	if str(option.get("outcome", "")) != "":
		step.outcome = str(option.outcome)
	inst.history.append(step)
	if option.has("ending"):
		_end(
			sim,
			inst,
			str(option.ending),
			{
				"outcome": str(option.get("outcome", "")),
				"changes": _description(sim, inst, option, false),
				"automatic": automatic
			}
		)
	elif option.has("investigate"):
		inst.status = "waiting"
		inst.pause_required = false
		inst.variables.investigation = {
			"staff": int(option.investigate), "work": float(option.work), "progress": 0.0
		}
		inst.scheduled = {
			"kind": "research", "next": option.next, "deadline": int(sim.state.day) + 45
		}
	elif option.has("build"):
		inst.status = "waiting"
		inst.pause_required = false
		inst.scheduled = {
			"kind": "construction", "next": option.next, "deadline": int(sim.state.day) + 30
		}
	elif option.has("order"):
		var o: Dictionary = option.order
		inst.order = {
			"resource": "parts",
			"required": float(o.amount),
			"price": float(o.price),
			"dispatched": 0.0,
			"delivered": 0.0,
			"paid": 0.0,
			"deadline": int(sim.state.day) + int(o.days),
			"cargo": [],
			"reviewed": false,
			"extended": false,
			"reduced": false,
			"cancelled": false,
			"created_day": int(sim.state.day)
		}
		inst.status = "waiting"
		inst.pause_required = false
		inst.scheduled = {"kind": "order_review", "next": "review", "due": int(sim.state.day) + 3}
	elif option.has("order_action"):
		inst.order.reviewed = true
		if option.order_action == "extend" and not inst.order.extended:
			inst.order.deadline += 10
			inst.order.extended = true
		if option.order_action == "reduce":
			inst.order.required = float(inst.order.dispatched)
			inst.order.reduced = true
		inst.status = "waiting"
		inst.pause_required = false
		inst.scheduled = {"kind": "order", "next": "delivered"}
	else:
		inst.status = "waiting"
		inst.pause_required = false
		inst.scheduled = {
			"kind": "date",
			"next": _next_node(sim, option),
			"due": int(sim.state.day) + int(option.get("delay", 1))
		}
	_sync_legacy(sim)
	return ""


## An option may lead to one of two nodes by chance; the roll comes from the events' own RNG.
static func _next_node(sim, option: Dictionary) -> String:
	if not option.has("alt"):
		return str(option.get("next", ""))
	var roll: float = _rng(sim.state.events_v2)
	return str(option.next) if roll < float(option.chance) else str(option.alt)


static func _forget_old_effects(sim) -> void:
	var keep: Array = []
	for effect: Dictionary in sim.state.events_v2.effects:
		if int(effect.until) < 0 or int(effect.until) >= int(sim.state.day):
			keep.append(effect)
	sim.state.events_v2.effects = keep


## What an option does to people, places and roads. Ledgers stay with _transfer and _produce.
static func _apply_colony(sim, s: Dictionary, option: Dictionary) -> void:
	var workers: int = int(option.get("admit_workers", 0))
	var scientists: int = int(option.get("admit_scientists", 0))
	if workers + scientists > 0:
		sim.Population._admit(sim, s, workers, scientists)
	var trained: int = int(option.get("train_scientists", 0))
	if trained > 0:
		s.workers = int(s.workers) - trained
		s.scientists = int(s.scientists) + trained
		sim._reconcile_jobs(s)
	# The planetary emergency network (1.9) cuts what an event takes and how long it closes roads.
	var kept: float = maxf(0.0, 1.0 + sim.Research.bonus(sim, "event_losses"))
	for good: String in option.get("lose_goods", {}):
		var lost: float = float(option.lose_goods[good]) * kept
		sim._consume(s, good, minf(lost, float(s.stock[good])))
	if option.has("set_wage"):
		sim.state.policy.wage = float(option.set_wage)
	if option.has("distrust"):
		sim.state.company.distrust = clampf(
			float(sim.state.company.distrust) + float(option.distrust), 0.0, 100.0
		)
	if option.has("pollution"):
		sim.Pollution.add_points(sim, float(option.pollution))
	if option.has("research_lead"):
		sim.Research.add_lead(sim, str(option.research_lead))
	if option.has("tech_gift"):
		sim.Research.grant(sim, str(option.tech_gift))
	if float(option.get("research_points", 0.0)) > 0.0:
		sim.Research.add_progress(sim, float(option.research_points))
	if bool(option.get("found_enterprise", false)):
		sim.act("enterprise", {"region": int(s.region)})
	if bool(option.get("clear_closure", false)):
		_closed_road(sim, int(s.region)).blocked_until = int(sim.state.day) - 1
	if int(option.get("shorten_closure", 0)) > 0:
		var road: Dictionary = _closed_road(sim, int(s.region))
		road.blocked_until = mini(
			int(road.blocked_until), int(sim.state.day) + int(option.shorten_closure)
		)
	if int(option.get("close_roads", 0)) > 0:
		var closed: int = ceili(
			int(option.close_roads) * maxf(0.0, 1.0 + sim.Research.bonus(sim, "event_closures"))
		)
		for road: Dictionary in sim.state.roads:
			if int(road.a) == int(s.region) or int(road.b) == int(s.region):
				road.blocked_until = maxi(
					int(road.get("blocked_until", 0)), int(sim.state.day) + closed
				)
	if option.has("revise_deposits"):
		_revise_deposits(sim, s, option.revise_deposits)
	if bool(option.get("reveal_hidden", false)):
		var site: Dictionary = sim.state.world.regions[int(s.region)]
		for plot: Dictionary in site.plots:
			if plot.kind == "deposit":
				plot.hidden = false
		sim.Sites.SiteGen.refresh_deposits(site)


static func _revise_deposits(sim, s: Dictionary, band: Array) -> void:
	var site: Dictionary = sim.state.world.regions[int(s.region)]
	var factor: float = lerpf(float(band[0]), float(band[1]), _rng(sim.state.events_v2))
	for plot: Dictionary in site.plots:
		if plot.kind == "deposit" and not bool(plot.hidden):
			plot.reserves = float(plot.reserves) * factor
	sim.Sites.SiteGen.refresh_deposits(site)


static func _advance_order(sim, inst: Dictionary) -> void:
	var order: Dictionary = inst.order
	if order.is_empty() or bool(order.cancelled):
		return
	if inst.node == "delivered":
		return  # A signed delivery cannot become overdue while its closing card is deferred.
	var day: int = int(sim.state.day)
	var s: Dictionary = sim.settlement(int(inst.target_region))
	var keep: Array = []
	for cargo in order.cargo:
		if day >= int(cargo.arrival):
			order.delivered += float(cargo.amount)
			var paid: float = sim._transfer(
				"external",
				"public",
				float(cargo.amount) * float(order.price),
				"event.order_income",
				true,
				str(inst.instance_id)
			)
			order.paid += paid
		else:
			keep.append(cargo)
	order.cargo = keep
	if day > int(order.deadline):
		# Committed cargo is still delivered and paid, but no new dispatch after deadline.
		if order.cargo.is_empty():
			_end(sim, inst, "逾期按实结清")
		return
	if float(order.delivered) >= float(order.required) - 0.000001 and bool(order.reviewed):
		if bool(order.reduced):
			_end(sim, inst, "协商减量")
		elif inst.node != "delivered":
			_enter(sim, inst, "delivered")
		return
	if s.is_empty() or not _has_building(s, "port") or not _has_building(s, "processor"):
		return
	var amount: float = minf(
		float(order.required) - float(order.dispatched),
		minf(
			float(s.get("exportable", {}).get("parts", 0)),
			maxf(0, float(s.port_capacity) - float(s.port_used))
		)
	)
	amount = minf(amount, float(s.stock.parts))
	if amount <= 0:
		return
	sim._consume(s, "parts", amount)
	s.port_used += amount
	order.dispatched += amount
	order.cargo.append({"amount": amount, "departure": day, "arrival": day + 3})
	# _consume records irrevocably exported goods; this separate receipt models the voyage.
	sim._public_expense(
		amount * float(order.price) * float(sim.config.economy.port_fee),
		"event.order_fee",
		"external",
		str(inst.instance_id)
	)


static func tick(sim) -> void:
	ensure(sim)
	var e: Dictionary = sim.state.events_v2
	var day: int = int(sim.state.day)
	if day <= int(e.last_tick):
		return
	e.last_tick = day
	for effect in e.effects:
		if (
			_active_effect(effect, day)
			and float(effect.maintenance) > 0
			and not sim.settlement(int(effect.region)).is_empty()
		):
			sim._public_expense(
				float(effect.maintenance), "event.upkeep", "external", str(effect.source)
			)
	for inst in e.instances:
		if inst.status in ["resolved", "cancelled"]:
			continue
		var s: Dictionary = sim.settlement(int(inst.target_region))
		if s.is_empty():
			_end(sim, inst, "目标失效，现场工作取消")
			inst.status = "cancelled"
			continue
		_advance_order(sim, inst)
		if inst.status in ["resolved", "cancelled"]:
			continue
		var unanswered: bool = inst.status == "pending" and not bool(inst.pause_required)
		if (inst.status == "deferred" or unanswered) and day >= int(inst.deadline):
			var option: Dictionary = _choice(inst, str(_node(inst).default))
			if _reason(sim, inst, option) == "":
				_apply(sim, inst, option, true)
			else:
				_end(sim, inst, "到期无法执行默认选项，结案")
		elif inst.status == "waiting":
			var scheduled: Dictionary = inst.scheduled
			match str(scheduled.get("kind", "")):
				"date", "order_review":
					if day >= int(scheduled.due):
						_enter(sim, inst, str(scheduled.next))
				"construction":
					var idx: int = int(inst.variables.get("building_index", -1))
					if (
						idx < 0
						or idx >= s.buildings.size()
						or s.buildings[idx].kind != inst.variables.building_kind
					):
						_end(sim, inst, "工程目标失效")
					elif s.buildings[idx].remaining <= 0 and s.buildings[idx].active:
						_enter(sim, inst, str(scheduled.next))
					elif day >= int(scheduled.deadline):
						_end(sim, inst, "工程未能投入运行")
				"research":
					var staff: int = int(
						sim.state.research.get("investigations", {}).get(inst.instance_id, {}).get(
							"staff", 0
						)
					)
					var inv: Dictionary = inst.variables.investigation
					inv.progress += (
						pow(float(staff) / 3.0, log(0.6) / log(0.5)) if staff > 0 else 0.0
					)
					if float(inv.progress) >= float(inv.work):
						inst.variables.surveyed = true
						sim.research_release(inst.instance_id)
						inst.variables.erase("investigation")
						_enter(sim, inst, str(scheduled.next))
					elif day >= int(scheduled.deadline):
						_end(sim, inst, "调查人员不足，现场封存")
	var pending: bool = false
	var waiting: int = 0
	for inst in e.instances:
		if inst.status in ["pending", "deferred"]:
			pending = true
		if not inst.status in ["resolved", "cancelled"]:
			waiting += 1
	if (
		not pending
		and waiting < int(definitions().sampling.max_waiting)
		and day >= int(e.next_draw)
	):
		e.next_draw = day + _draw_interval(sim)
		var candidates: Array = []
		var total: float = 0
		# Plenty of days nothing happens at all.
		var quiet: bool = _rng(e) >= float(definitions().sampling.fire_chance)
		for id in definitions().definitions:
			if quiet:
				break
			var d: Dictionary = definitions().definitions[id]
			if e.off.has(id) or _open_now(sim, id) or not _cooled(sim, id):
				continue
			if (
				d.category == "incident"
				and day - int(e.last_negative) < int(definitions().sampling.negative_cooldown_days)
			):
				continue
			for s in sim.state.settlements:
				if _matches(sim, s, d.conditions):
					candidates.append(
						{"id": id, "region": int(s.region), "weight": float(d.weight)}
					)
					total += float(d.weight)
					break
		if total > 0:
			var roll: float = _rng(e) * total
			for c in candidates:
				roll -= float(c.weight)
				if roll <= 0:
					_open(sim, str(c.id), int(c.region))
					break
	_sync_legacy(sim)


static func _active_effect(effect: Dictionary, day: int) -> bool:
	return day >= int(effect.start) and (int(effect.until) < 0 or day < int(effect.until))


static func modifier(sim, region: int, kind: String) -> float:
	var value: float = 1.0
	var general: bool = kind in PRODUCTION_KINDS
	for effect in sim.state.get("events_v2", {}).get("effects", []):
		if (
			int(effect.region) == region
			and (effect.kind == kind or (general and effect.kind == "all"))
			and _active_effect(effect, int(sim.state.day))
		):
			value *= float(effect.factor)
	return value


## Harder levels draw events more often; the pool and their rules stay the same.
static func _draw_interval(sim) -> int:
	var level: Dictionary = sim.progression.difficulty[sim.state.get("difficulty", "normal")]
	return roundi(float(definitions().sampling.interval_days) * float(level.event_interval_factor))


## Effects that reach the whole colony, whichever settlement they began in.
static func colony_modifier(sim, kind: String) -> float:
	var value: float = 1.0
	for effect in sim.state.get("events_v2", {}).get("effects", []):
		if effect.kind == kind and _active_effect(effect, int(sim.state.day)):
			value *= float(effect.factor)
	return value


static func reserved(sim, region: int, resource: String) -> float:
	var amount: float = 0.0
	for inst in sim.state.get("events_v2", {}).get("instances", []):
		if (
			int(inst.target_region) != region
			or inst.status in ["resolved", "cancelled"]
			or inst.order.is_empty()
		):
			continue
		if inst.order.resource == resource and int(sim.state.day) <= int(inst.order.deadline):
			amount += maxf(0.0, float(inst.order.required) - float(inst.order.dispatched))
	return amount


## What an option costs and does, in words; with `with_course`, also where it leads.
static func _description(
	sim, inst: Dictionary, option: Dictionary, with_course: bool = true
) -> String:
	var parts: Array = []
	if option.has("pay"):
		parts.append("支出 %.0f" % _pay(sim, option))
	if option.has("reward"):
		parts.append("一次性收入 %.0f" % _reward(sim, option))
	if int(option.get("admit_workers", 0)) + int(option.get("admit_scientists", 0)) > 0:
		parts.append(
			(
				"迁入工程队 %d、研究团队 %d"
				% [int(option.get("admit_workers", 0)), int(option.get("admit_scientists", 0))]
			)
		)
	if float(option.get("research_points", 0.0)) > 0.0:
		parts.append("当前项目 +%.0f 研究量" % float(option.research_points))
	if int(option.get("train_scientists", 0)) > 0:
		parts.append("%d 支工程队转为研究团队" % int(option.train_scientists))
	if option.has("distrust"):
		parts.append("公司不信任 %+.1f" % float(option.distrust))
	if option.has("pollution"):
		parts.append("星球污染 %+.0f" % float(option.pollution))
	if option.has("research_lead"):
		var lead: Dictionary = sim.config.techs.get(str(option.research_lead), {})
		parts.append("科研候选增加「%s」" % str(lead.get("name", "")))
	if option.has("tech_gift"):
		var gift: Dictionary = sim.config.techs.get(str(option.tech_gift), {})
		parts.append("获得技术「%s」（无法研究，只能由事件获得）：%s" % [str(gift.get("name", "")), _effect_text(gift)])
	if option.has("set_wage"):
		parts.append("工资恢复到 %.1f 倍" % float(option.set_wage))
	if int(option.get("close_roads", 0)) > 0:
		parts.append("线路封闭 %d 日" % int(option.close_roads))
	if bool(option.get("clear_closure", false)):
		parts.append("当天恢复通车")
	for good: String in option.get("lose_goods", {}):
		parts.append(
			(
				"损失至多 %.0f t %s"
				% [
					sim.tonnes(float(option.lose_goods[good])),
					str(sim.config.resources.get(good, good))
				]
			)
		)
	for key in option.get("goods_cost", {}):
		parts.append(
			(
				"消耗 %.0f t %s"
				% [
					sim.tonnes(float(option.goods_cost[key])),
					str(sim.config.resources.get(key, key))
				]
			)
		)
	for key in option.get("goods_reward", {}):
		parts.append(
			(
				"取得 %.0f t %s"
				% [
					sim.tonnes(float(option.goods_reward[key])),
					str(sim.config.resources.get(key, key))
				]
			)
		)
	if option.has("investigate"):
		parts.append("占用 %d 支研究团队，标准 %d 日" % [int(option.investigate), int(option.work)])
	if option.has("build"):
		var b: Dictionary = sim.build_preview(int(inst.target_region), str(option.build))
		parts.append(
			(
				"建设 %.0f 资金 / %.0f t 建材 / %.0f t 部件，%d 日"
				% [
					float(b.cost),
					sim.tonnes(float(b.materials)),
					sim.tonnes(float(b.parts)),
					int(b.days)
				]
			)
		)
		var place: Dictionary = sim.settlement(int(inst.target_region))
		if not place.is_empty():
			parts.append("需要 %d 支工程队，目前空闲 %d 支" % [int(b.jobs), sim.free_workers(place)])
	if option.has("order"):
		parts.append(
			(
				"本地加工 %.0f t 部件 × ¥%.0f/百吨，到货付款，%d 日截止，航程 3 日"
				% [
					sim.tonnes(float(option.order.amount)),
					float(option.order.price),
					int(option.order.days)
				]
			)
		)
	for effect in option.get("effects", []):
		var names: Dictionary = {
			"water": "供水",
			"farm": "农产",
			"mine": "采矿",
			"processor": "加工",
			"port": "货站吞吐",
			"power": "发电",
			"all": "全部生产",
			"appeal": "吸引力",
			"research": "科研速度",
			"export_price": "出口价格",
			"road_capacity": "道路运力",
		}
		parts.append(
			(
				"%s × %.2f，%s"
				% [
					str(names.get(effect.kind, effect.kind)),
					float(effect.factor),
					(
						"持续生效"
						if int(effect.duration_days) == 0
						else "次日起 %d 日" % int(effect.duration_days)
					)
				]
			)
		)
		if float(effect.get("maintenance", 0)) > 0:
			parts.append("维护 %.1f / 日" % float(effect.maintenance))
	if option.get("sell_rights", false):
		parts.append("独家后续调查权转让，放弃该现场后续研究成果")
	var course: String = _course(inst, option) if with_course else ""
	if course != "":
		parts.append(course)
	return "；".join(parts)


## Where an option leads, in words: the ending it closes on, the next step and when, or for a
## gamble both outcomes with their odds. Players weigh a choice by this as much as by its price.
static func _course(inst: Dictionary, option: Dictionary) -> String:
	if option.has("ending"):
		return "结局「%s」" % str(option.ending)
	if not option.has("next"):
		return ""
	var nodes: Dictionary = definitions().definitions[inst.definition_id].nodes
	var ahead: String = str(nodes.get(str(option.next), {}).get("title", option.next))
	var wait: int = int(option.get("delay", 0))
	if option.has("alt"):
		var share: int = roundi(float(option.chance) * 100.0)
		var other: String = str(nodes.get(str(option.alt), {}).get("title", option.alt))
		return (
			"两种可能：约 %d%%「%s」，约 %d%%「%s」%s"
			% [share, ahead, 100 - share, other, ("，%d 日后揭晓" % wait) if wait > 0 else ""]
		)
	if option.has("investigate"):
		return "调查完成后进入「%s」" % ahead
	if wait > 0:
		return "%d 日后进入「%s」" % [wait, ahead]
	return "随即进入「%s」" % ahead


## What a gift technology's effects do, in words: 「陆路单程时间 -20%，道路运力 +10%」.
static func _effect_text(tech: Dictionary) -> String:
	var words: PackedStringArray = []
	for key: String in tech.get("effects", {}):
		var named: Array = GIFT_EFFECTS.get(key, [key, 1.0])
		var value: float = float(tech.effects[key]) * float(named[1]) * 100.0
		words.append("%s %+.0f%%" % [str(named[0]), value])
	return "，".join(words)


## Cheap per-frame query: builds no view and allocates nothing.
static func pause_required(sim) -> bool:
	for inst: Dictionary in sim.state.get("events_v2", {}).get("instances", []):
		if inst.status == "pending" and inst.pause_required:
			return true
	return false


static func view(sim) -> Dictionary:
	var result: Dictionary = {
		"pause_required": false, "pending": [], "active": [], "history": [], "effects": []
	}
	if not sim.state.has("events_v2"):
		return result
	for inst in sim.state.events_v2.instances:
		if inst.status in ["resolved", "cancelled"]:
			continue
		var n: Dictionary = _node(inst)
		var item: Dictionary = {
			"instance_id": inst.instance_id,
			"id": inst.definition_id,
			"title": n.get("title", "事件"),
			"text": n.get("text", ""),
			"node": inst.node,
			"status": inst.status,
			"deadline": inst.deadline,
			"remaining_days": maxi(0, int(inst.deadline) - int(sim.state.day)),
			"pause_required": inst.pause_required,
			"kind": str(definitions().definitions[inst.definition_id].get("kind", "decision")),
			"target_region": inst.target_region,
			"choices": [],
			"scheduled": inst.scheduled.duplicate(true),
			"variables": inst.variables.duplicate(true),
			"order": inst.order.duplicate(true),
			"history": inst.history.duplicate(true)
		}
		if inst.status in ["pending", "deferred"]:
			for option in n.get("choices", []):
				var reason: String = _reason(sim, inst, option)
				var desc: String = _description(sim, inst, option)
				item.choices.append(
					{
						"id": option.id,
						"label": str(option.label) + (" · " + desc if desc != "" else ""),
						"enabled": reason == "",
						"reason": reason,
						"cost": _pay(sim, option),
						"duration_days": int(option.get("effects", [{}])[0].get("duration_days", 0))
					}
				)
			var can_defer: bool = inst.variables.get("deferred_node", "") != inst.node
			item.choices.append(
				{
					"id": "defer",
					"label":
					(
						"稍后处理 · %s 到期执行「%s」"
						% [
							_date(int(inst.deadline)),
							str(_choice(inst, str(n.default)).get("label", "默认处理"))
						]
					),
					"enabled": can_defer,
					"reason": "本节点已经延期，期限不再延长" if not can_defer else "",
					"cost": 0.0,
					"duration_days": 0
				}
			)
			result.pending.append(item)
			if inst.pause_required:
				result.pause_required = true
		elif inst.status == "waiting" and inst.scheduled.get("kind", "") == "research":
			item.choices.append(
				{
					"id": "cancel",
					"label": "撤回研究团队并封存现场 · 已付调查费不退",
					"enabled": true,
					"reason": "",
					"cost": 0.0,
					"duration_days": 0
				}
			)
		result.active.append(item)
	for entry in sim.state.events_v2.history:
		var row: Dictionary = entry.duplicate(true)
		row.title = str(
			(
				definitions()
				. definitions
				. get(row.definition_id, {})
				. get("nodes", {})
				. get("start", {})
				. get("title", "事件")
			)
		)
		row.text = "%s · %s" % [_date(int(row.day)), str(row.ending)]
		result.history.append(row)
	for effect in sim.state.events_v2.effects:
		if int(effect.until) < 0 or int(effect.until) > int(sim.state.day):
			var row: Dictionary = effect.duplicate(true)
			var names: Dictionary = {
				"water": "供水能力",
				"farm": "农业产出",
				"mine": "采矿效率",
				"processor": "加工效率",
				"port": "货站吞吐",
				"power": "发电能力",
				"all": "全部生产",
				"appeal": "吸引力",
				"research": "科研速度",
				"export_price": "出口价格",
				"road_capacity": "道路运力",
			}
			row.title = str(names.get(effect.kind, effect.kind))
			row.text = (
				"%s × %.2f · %s"
				% [
					row.title,
					float(effect.factor),
					(
						"持续生效"
						if int(effect.until) < 0
						else "第 %d 至 %d 日" % [int(effect.start), int(effect.until) - 1]
					)
				]
			)
			if float(effect.maintenance) > 0:
				row.text += " · 维护 %.1f / 日" % float(effect.maintenance)
			result.effects.append(row)
	return result


static func _sync_legacy(sim) -> void:
	var v: Dictionary = view(sim)
	sim.state.event = {}
	if not v.pending.is_empty():
		var p: Dictionary = v.pending[0]
		for candidate in v.pending:
			if candidate.pause_required:
				p = candidate
				break
		sim.state.event = {
			"id": p.id,
			"instance_id": p.instance_id,
			"day": int(sim.state.day),
			"title": p.title,
			"text": p.text,
			"duration": 0,
			"expires": p.deadline,
			"choices": p.choices.duplicate(true),
			"pause_required": p.pause_required
		}


static func validate(candidate: Dictionary) -> String:
	if not candidate.has("events_v2"):
		return ""
	var e: Variant = candidate.events_v2
	if not e is Dictionary:
		return "事件状态类型无效"
	for key in ["version", "rng_state", "next_id", "next_draw", "last_negative", "last_tick"]:
		if not e.get(key) is int and not e.get(key) is float:
			return "事件数值字段无效：" + key
		if not is_finite(float(e[key])) or float(e[key]) != floor(float(e[key])):
			return "事件整数无效：" + key
	if (
		e.version != 2
		or int(e.rng_state) <= 0
		or int(e.rng_state) >= 2147483647
		or int(e.next_id) < 1
	):
		return "事件版本或随机状态无效"
	for key in ["instances", "history", "effects", "seen"]:
		if not e.get(key) is Array:
			return "事件列表无效：" + key
	if e.instances.size() > 32 or e.effects.size() > 128 or e.history.size() > 80:
		return "事件记录超过上限"
	if int(e.last_tick) > int(candidate.day) or int(e.next_draw) < 0:
		return "事件调度日期无效"
	if not e.get("last_opened", {}) is Dictionary or not e.get("endings", {}) is Dictionary:
		return "事件冷却记录无效"
	if not e.get("off", []) is Array:
		return "事件牌堆记录无效"
	var seen: Dictionary = {}
	for id in e.seen:
		if not id is String or not definitions().definitions.has(id) or seen.has(id):
			return "事件已出现列表无效"
		seen[id] = true
	var ids: Dictionary = {}
	var def_ids: Dictionary = {}
	for inst in e.instances:
		if not inst is Dictionary:
			return "事件实例类型无效"
		for key in ["instance_id", "definition_id", "node", "status", "ending"]:
			if not inst.get(key) is String:
				return "事件标识类型无效"
		for key in ["target_region", "definition_version", "created_day", "deadline"]:
			if not _number(inst.get(key)) or float(inst[key]) != floor(float(inst[key])):
				return "事件实例数字无效"
		for key in ["variables", "scheduled", "order"]:
			if not inst.get(key) is Dictionary:
				return "事件实例容器无效"
		if not inst.get("history") is Array or not inst.get("pause_required") is bool:
			return "事件历史或暂停状态无效"
		if ids.has(inst.instance_id) or not definitions().definitions.has(inst.definition_id):
			return "事件重复实例或未知定义"
		var finished: bool = inst.status in ["resolved", "cancelled"]
		if not finished and def_ids.has(inst.definition_id):
			return "同一事件不能同时开启两次"
		ids[inst.instance_id] = true
		if not finished:
			def_ids[inst.definition_id] = true
		if not seen.has(inst.definition_id):
			return "事件实例缺少出现记录"
		var serial: int = str(inst.instance_id).get_slice(":e", 1).to_int()
		if (
			serial < 1
			or serial >= int(e.next_id)
			or inst.instance_id != "%s:e%d" % [str(candidate.world.seed), serial]
		):
			return "事件唯一标识无效"
		var d: Dictionary = definitions().definitions[inst.definition_id]
		if int(inst.definition_version) != int(d.version) or not d.nodes.has(inst.node):
			return "事件定义版本或节点无效"
		if not inst.status in ["pending", "deferred", "waiting", "resolved", "cancelled"]:
			return "事件生命周期无效"
		if bool(inst.pause_required) and inst.status != "pending":
			return "事件暂停状态不一致"
		if int(inst.target_region) < 0 or int(inst.target_region) >= candidate.world.regions.size():
			return "事件目标越界"
		if (
			int(inst.created_day) < 0
			or int(inst.created_day) > int(candidate.day)
			or int(inst.deadline) < int(inst.created_day)
		):
			return "事件实例日期无效"
		if inst.history.size() > 32:
			return "单事件历史过长"
		for h in inst.history:
			if (
				not h is Dictionary
				or not h.get("node") is String
				or not h.get("choice") is String
				or not h.get("automatic") is bool
				or not _number(h.get("day"))
			):
				return "事件选择历史无效"
			if not d.nodes.has(h.node) or int(h.day) > int(candidate.day):
				return "事件历史节点或日期无效"
			if h.has("outcome") and not h.outcome is String:
				return "事件选择结果文字无效"
		for key in ["surveyed", "rights_sold"]:
			if inst.variables.has(key) and not inst.variables[key] is bool:
				return "事件权利标志无效"
		if (
			inst.variables.has("building_index")
			and (
				not _number(inst.variables.building_index)
				or not inst.variables.get("building_kind") is String
			)
		):
			return "事件工程目标无效"
		if (
			inst.variables.has("deferred_node")
			and (
				not inst.variables.deferred_node is String
				or not d.nodes.has(inst.variables.deferred_node)
			)
		):
			return "延期节点无效"
		if inst.status == "deferred" and inst.variables.get("deferred_node", "") != inst.node:
			return "延期未经明确选择"
		if inst.variables.has("investigation"):
			var inv: Variant = inst.variables.investigation
			if not inv is Dictionary:
				return "调查数据无效"
			for key in ["staff", "work", "progress"]:
				if not _number(inv.get(key)) or float(inv[key]) < 0:
					return "调查工作量无效"
			if inst.status != "waiting" or inst.scheduled.get("kind", "") != "research":
				return "调查与节点不一致"
			if not candidate.research.get("investigations", {}).has(inst.instance_id):
				return "调查人员预留丢失"
		if inst.status == "waiting" and inst.scheduled.is_empty():
			return "等待节点缺少后继"
		if (
			inst.status in ["resolved", "cancelled"]
			and (not inst.scheduled.is_empty() or inst.ending == "")
		):
			return "事件结案状态无效"
		if not inst.scheduled.is_empty():
			if (
				not (
					inst.scheduled.get("kind")
					in ["date", "order_review", "construction", "research", "order"]
				)
				or not inst.scheduled.get("next") is String
				or not d.nodes.has(inst.scheduled.next)
			):
				return "事件后继无效"
			var timekey: String = (
				"due" if inst.scheduled.kind in ["date", "order_review"] else "deadline"
			)
			if inst.scheduled.kind != "order" and not _number(inst.scheduled.get(timekey)):
				return "事件后继时刻无效"
			if inst.scheduled.kind == "construction" and not inst.variables.has("building_index"):
				return "工程后继缺少目标"
			if inst.scheduled.kind == "research" and not inst.variables.has("investigation"):
				return "调查后继缺少工作量"
		if not inst.order.is_empty():
			var o: Dictionary = inst.order
			if o.get("resource") != "parts" or not o.get("cargo") is Array:
				return "事件订单货物无效"
			for key in [
				"required", "price", "dispatched", "delivered", "paid", "deadline", "created_day"
			]:
				if not _number(o.get(key)) or float(o[key]) < 0:
					return "事件订单数量无效"
			for key in ["reviewed", "extended", "reduced", "cancelled"]:
				if not o.get(key) is bool:
					return "事件订单标志无效"
			var cargo_sum: float = 0
			for cargo in o.cargo:
				if not cargo is Dictionary:
					return "事件在途货单无效"
				for key in ["amount", "departure", "arrival"]:
					if not _number(cargo.get(key)) or float(cargo[key]) < 0:
						return "事件在途数值无效"
				if int(cargo.arrival) != int(cargo.departure) + 3:
					return "事件航程无效"
				cargo_sum += float(cargo.amount)
			if (
				absf(float(o.dispatched) - float(o.delivered) - cargo_sum) > 0.00001
				or absf(float(o.paid) - float(o.delivered) * float(o.price)) > 0.00001
			):
				return "事件交付账不平"
			if float(o.dispatched) > float(o.required) + 0.00001 or float(o.price) <= 0:
				return "事件交付超出承诺"
	for h in e.history:
		if (
			not h is Dictionary
			or not h.get("instance_id") is String
			or not h.get("ending") is String
			or not _number(h.get("day"))
			or not _number(h.get("target_region"))
		):
			return "事件结案历史无效"
		if (
			not h.get("definition_id") is String
			or not definitions().definitions.has(h.definition_id)
		):
			return "事件结案历史缺少定义"
		if (
			int(h.day) > int(candidate.day)
			or int(h.target_region) < 0
			or int(h.target_region) >= candidate.world.regions.size()
		):
			return "事件结案历史日期或地区无效"
		for key: String in ["outcome", "changes"]:
			if h.has(key) and not h[key] is String:
				return "事件结局文字无效"
		if h.has("automatic") and not h.automatic is bool:
			return "事件结局方式无效"
	for effect in e.effects:
		if (
			not effect is Dictionary
			or not effect.get("source") is String
			or not effect.get("kind") in EFFECT_KINDS
		):
			return "事件效果来源无效"
		for key in ["region", "factor", "start", "until", "duration_days", "maintenance"]:
			if not _number(effect.get(key)):
				return "事件效果数值无效"
		if effect.has("label") and not effect.label is String:
			return "事件效果名称无效"
		if (
			float(effect.factor) <= 0
			or float(effect.maintenance) < 0
			or int(effect.region) < 0
			or int(effect.region) >= candidate.world.regions.size()
		):
			return "事件效果范围无效"
		if (
			(int(effect.duration_days) == 0 and int(effect.until) != -1)
			or (
				int(effect.duration_days) > 0
				and int(effect.until) - int(effect.start) != int(effect.duration_days)
			)
		):
			return "事件持续时间不一致"
	return ""


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
