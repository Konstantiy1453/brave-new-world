extends RefCounted
## The shape a save's `events_v2` state must have (split from events_v2.gd in 1.11): every field,
## instance, history row, effect and landmark checked before a save is loaded. Pure: it reads the
## candidate and the event definitions and changes nothing.


static func validate(
	candidate: Dictionary,
	definitions: Dictionary,
	effect_kinds: Array[String],
	landmark_kinds: Array[String]
) -> String:
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
		if not id is String or not definitions.definitions.has(id) or seen.has(id):
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
		if ids.has(inst.instance_id) or not definitions.definitions.has(inst.definition_id):
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
		var d: Dictionary = definitions.definitions[inst.definition_id]
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
			inst.variables.has("building_uid")
			and (
				not _number(inst.variables.building_uid)
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
			if inst.scheduled.kind == "construction" and not inst.variables.has("building_uid"):
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
		if not h.get("definition_id") is String or not definitions.definitions.has(h.definition_id):
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
			or not effect.get("kind") in effect_kinds
		):
			return "事件效果来源无效"
		for key in ["region", "factor", "start", "until", "duration_days", "maintenance"]:
			if not _number(effect.get(key)):
				return "事件效果数值无效"
		if effect.has("label") and not effect.label is String:
			return "事件效果名称无效"
		if effect.has("event") and not effect.event is String:
			return "事件效果来源事件无效"
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
	if e.has("landmarks"):
		if not e.landmarks is Array:
			return "地标列表无效"
		var standing: Dictionary = {}
		for mark in e.landmarks:
			if (
				not mark is Dictionary
				or not mark.get("id") is String
				or not mark.get("name") is String
				or not mark.get("text") is String
				or not mark.get("kind") in landmark_kinds
				or not _number(mark.get("region"))
				or not _number(mark.get("day"))
				or standing.has(mark.id)
			):
				return "地标无效"
			if (
				int(mark.region) < 0
				or int(mark.region) >= candidate.world.regions.size()
				or int(mark.day) > int(candidate.day)
			):
				return "地标位置或日期无效"
			standing[mark.id] = true
	return ""


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
