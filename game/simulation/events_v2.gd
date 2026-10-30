extends RefCounted
## Local-day, independently seeded, original event definitions. All payouts are receipts.
static var _definitions: Dictionary = {}


static func definitions() -> Dictionary:
	if _definitions.is_empty():
		_definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/events_v2.json"))
	return _definitions


static func ensure(sim) -> void:
	if sim.state.has("events_v2"):
		return
	var seed_value: int = int(sim.state.world.seed)
	sim.state.events_v2 = {
		"version": 2,
		"rng_state": (absi(seed_value) % 2147483646) + 1,
		"next_id": 1,
		"next_draw": 6,
		"last_negative": -100,
		"instances": [],
		"history": [],
		"effects": [],
		"seen": [],
		"last_tick": -1
	}


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
	if c.get("mine", false):
		var mined: bool = false
		for kind in ["mine_ore", "mine_copper", "mine_crystal"]:
			if _has_building(s, kind):
				mined = true
		if not mined:
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
		var found: bool = false
		for inst in sim.state.events_v2.instances:
			if str(inst.definition_id) + ":" + str(inst.ending) == str(c.previous):
				found = true
		if not found:
			return false
	return true


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
	e.seen.append(definition_id)
	_enter(sim, inst, "start")
	if d.category == "incident":
		e.last_negative = int(sim.state.day)
	return inst


static func _enter(sim, inst: Dictionary, node_id: String) -> void:
	inst.node = node_id
	inst.status = "pending"
	inst.pause_required = true
	inst.scheduled = {}
	inst.deadline = int(sim.state.day) + int(_node(inst).get("deadline_days", 6))
	inst.variables.erase("deferred_node")
	sim._log("事件 · " + str(_node(inst).title))


static func _end(sim, inst: Dictionary, ending: String) -> void:
	if inst.status in ["resolved", "cancelled"]:
		return
	if sim.has_method("research_release"):
		sim.research_release(inst.instance_id)
	inst.status = "resolved"
	inst.pause_required = false
	inst.ending = ending
	inst.scheduled = {}
	inst.variables.erase("investigation")
	sim.state.events_v2.history.append(
		{
			"instance_id": inst.instance_id,
			"definition_id": inst.definition_id,
			"day": int(sim.state.day),
			"ending": ending,
			"target_region": inst.target_region
		}
	)
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
	if float(sim.state.cash) < float(option.get("pay", 0)):
		return "公共资金不足"
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
			return "可派遣研究员不足 %d 人" % int(option.investigate)
	if option.has("build"):
		var b: Dictionary = sim.build_preview(int(inst.target_region), str(option.build))
		if int(s.arrival) > 0 or s.buildings.size() >= 24:
			return "据点未到达或开发地块已满"
		if float(sim.state.cash) < float(b.cost) + float(option.get("pay", 0)):
			return "建设资金不足"
		if float(s.stock.materials) < float(b.materials) or float(s.stock.parts) < float(b.parts):
			return "本地建设材料不足"
		var free: int = sim.free_workers(s)
		if free < int(b.jobs):
			return "需要 %d 名工人，目前空闲 %d 名" % [int(b.jobs), free]
		var free_specialists: int = sim.free_specialists(s)
		if free_specialists < int(b.get("specialists", 0)):
			return "需要 %d 名专家，目前空闲 %d 名" % [int(b.get("specialists", 0)), free_specialists]
	if option.has("order"):
		if not _has_building(s, "processor") or not _has_building(s, "port"):
			return "需要已启用的加工厂和货站"
	return ""


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
		"public", "external", float(option.get("pay", 0)), "事件支出 · " + inst.instance_id, false
	)
	for key in option.get("goods_cost", {}):
		sim._consume(s, str(key), float(option.goods_cost[key]))
	if option.has("reward"):
		sim._transfer(
			"external", "public", float(option.reward), "事件一次性收入 · " + inst.instance_id, false
		)
	for key in option.get("goods_reward", {}):
		sim._produce(s, str(key), float(option.goods_reward[key]), "事件外部交付 · " + inst.instance_id)
	if option.get("sell_rights", false):
		inst.variables.rights_sold = true
	for effect in option.get("effects", []):
		var n: int = int(effect.duration_days)
		sim.state.events_v2.effects.append(
			{
				"source": inst.instance_id,
				"region": int(inst.target_region),
				"kind": str(effect.kind),
				"factor": float(effect.factor),
				"start": int(sim.state.day) + 1,
				"until": int(sim.state.day) + 1 + n if n > 0 else -1,
				"duration_days": n,
				"maintenance": float(effect.get("maintenance", 0))
			}
		)
	inst.history.append(
		{"day": int(sim.state.day), "node": inst.node, "choice": option.id, "automatic": automatic}
	)
	if option.has("ending"):
		_end(sim, inst, str(option.ending))
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
			"next": str(option.get("next", "")),
			"due": int(sim.state.day) + int(option.get("delay", 1))
		}
	_sync_legacy(sim)
	return ""


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
				"加工订单到货 · " + inst.instance_id,
				true
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
		"订单装船港务 · " + inst.instance_id,
		"external"
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
				float(effect.maintenance), "事件设施维护 · " + str(effect.source), "external"
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
		if inst.status == "deferred" and day >= int(inst.deadline):
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
		e.next_draw = day + int(definitions().sampling.interval_days)
		var candidates: Array = []
		var total: float = 0
		for id in definitions().definitions:
			var d: Dictionary = definitions().definitions[id]
			if e.seen.has(id):
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
	for effect in sim.state.get("events_v2", {}).get("effects", []):
		if (
			int(effect.region) == region
			and effect.kind == kind
			and _active_effect(effect, int(sim.state.day))
		):
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


static func _description(sim, inst: Dictionary, option: Dictionary) -> String:
	var parts: Array = []
	if option.has("pay"):
		parts.append("支出 %.0f" % float(option.pay))
	if option.has("reward"):
		parts.append("一次性收入 %.0f" % float(option.reward))
	for key in option.get("goods_cost", {}):
		parts.append(
			"消耗 %.0f %s" % [float(option.goods_cost[key]), str(sim.config.resources.get(key, key))]
		)
	for key in option.get("goods_reward", {}):
		parts.append(
			(
				"取得 %.0f %s"
				% [float(option.goods_reward[key]), str(sim.config.resources.get(key, key))]
			)
		)
	if option.has("investigate"):
		parts.append("占用 %d 名研究员，标准 %d 日" % [int(option.investigate), int(option.work)])
	if option.has("build"):
		var b: Dictionary = sim.build_preview(int(inst.target_region), str(option.build))
		parts.append(
			(
				"建设 %.0f 资金 / %.0f 建材 / %.0f 部件，%d 日"
				% [float(b.cost), float(b.materials), float(b.parts), int(b.days)]
			)
		)
		var place: Dictionary = sim.settlement(int(inst.target_region))
		if not place.is_empty():
			parts.append("需要 %d 名工人，目前空闲 %d 名" % [int(b.jobs), sim.free_workers(place)])
	if option.has("order"):
		parts.append(
			(
				"本地加工 %.0f 部件 × %.0f，到货付款，%d 日截止，航程 3 日"
				% [float(option.order.amount), float(option.order.price), int(option.order.days)]
			)
		)
	for effect in option.get("effects", []):
		var names: Dictionary = {
			"water": "供水", "farm": "农产", "mine": "采矿", "processor": "加工", "port": "货站吞吐"
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
	return "；".join(parts)


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
						"cost": float(option.get("pay", 0)),
						"duration_days": int(option.get("effects", [{}])[0].get("duration_days", 0))
					}
				)
			var can_defer: bool = inst.variables.get("deferred_node", "") != inst.node
			item.choices.append(
				{
					"id": "defer",
					"label":
					(
						"稍后处理 · 第 %d 日到期执行「%s」"
						% [
							int(inst.deadline),
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
					"label": "撤回研究员并封存现场 · 已付调查费不退",
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
		row.text = "第 %d 日 · %s" % [int(row.day), str(row.ending)]
		result.history.append(row)
	for effect in sim.state.events_v2.effects:
		if int(effect.until) < 0 or int(effect.until) > int(sim.state.day):
			var row: Dictionary = effect.duplicate(true)
			var names: Dictionary = {
				"water": "供水能力", "farm": "农业产出", "mine": "采矿效率", "processor": "加工效率", "port": "货站吞吐"
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
		if (
			ids.has(inst.instance_id)
			or def_ids.has(inst.definition_id)
			or not definitions().definitions.has(inst.definition_id)
		):
			return "事件重复实例或未知定义"
		ids[inst.instance_id] = true
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
		if bool(inst.pause_required) != (inst.status == "pending"):
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
	if seen.size() != def_ids.size():
		return "事件出现记录缺少实例"
	for h in e.history:
		if (
			not h is Dictionary
			or not ids.has(h.get("instance_id"))
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
	for effect in e.effects:
		if (
			not effect is Dictionary
			or not ids.has(effect.get("source"))
			or not effect.get("kind") in ["water", "farm", "mine", "processor", "port"]
		):
			return "事件效果来源无效"
		for key in ["region", "factor", "start", "until", "duration_days", "maintenance"]:
			if not _number(effect.get(key)):
				return "事件效果数值无效"
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
