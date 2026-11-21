extends RefCounted
## Per-town stock controls (1.11) and what a town's warehouse holds for whom.
##
## Each town keeps, per good, two controls (`s.stock_rules[good]`, units of 100 t; -1 is automatic):
## - `reserve`: the least kept in the town. Ordinary exports, supply orders and road dispatch stop at
##   it; the town's own building, food and factories still draw on it.
## - `slowdown`: the stock at which the town's production of that good stops (farms, factories,
##   and mines and harvesters once the player sets one). A reserve above it lifts it: a warehouse
##   filling its reserve keeps its output.
## A planned project can hold back what it will need in one action (`reserve_for`): its materials
## and parts stay in the warehouse until it is ordered there or released.
## `availability` is the one breakdown of a warehouse (total, held back by kind, free to sell): the
## trade that sells, the pages that quote and the tests all read it.

const Keys = preload("res://simulation/keys.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")

const AUTO: float = -1.0
const HOLD_NAMES: Dictionary = {
	"keep": "本地保留",
	"food": "居民口粮储备",
	"planned": "计划工程预留",
	"roads": "承诺发往相邻据点",
	"orders": "事件订单待发",
	"imported": "进口物资不转卖",
}


static func ensure_state(state: Dictionary) -> void:
	for s: Dictionary in state.get("settlements", []):
		if not s.has("stock_rules"):
			s.stock_rules = {}
			# 1.10's production targets become the slowdown levels.
			for good: Variant in s.get("targets", {}):
				s.stock_rules[str(good)] = {"reserve": AUTO, "slowdown": float(s.targets[good])}
		if not s.has("reservations"):
			s.reservations = []
		if not s.has("auto_shifts"):
			s.auto_shifts = true


static func rules(sim: RefCounted) -> Dictionary:
	return sim.config.get("stock_rules", {})


static func _rule(s: Dictionary, good: String) -> Dictionary:
	return s.get("stock_rules", {}).get(good, {})


## The player's reserve for a good, or -1 when it is automatic.
static func set_reserve(s: Dictionary, good: String) -> float:
	return float(_rule(s, good).get("reserve", AUTO))


## The player's slowdown level for a good, or -1 when it is automatic.
static func set_slowdown(s: Dictionary, good: String) -> float:
	return float(_rule(s, good).get("slowdown", AUTO))


## What the town keeps of a good before anything is sold or sent away: the player's reserve, else
## the automatic one (economy.json `export_reserve`; food: the residents' reserve).
static func keep(sim: RefCounted, s: Dictionary, good: String) -> float:
	var chosen: float = set_reserve(s, good)
	if good == "food":
		return maxf(chosen, food_keep(sim, s))
	if chosen >= 0.0:
		return chosen
	return float(sim.config.economy.export_reserve.get(good, 0.0))


## The residents' food reserve: the trade reserve's days of food (policy `food_reserve` + 1, what the
## port keeps topped up), plus economy.json `supply.keep_extra_days`.
static func food_keep(sim: RefCounted, s: Dictionary) -> float:
	var extra: float = float(sim.config.get("supply", {}).get("keep_extra_days", 0.0))
	return (
		float(s.population)
		* float(sim.config.economy.food_per_person)
		* (float(sim.state.policy.food_reserve) + 1.0 + extra)
	)


## What planned projects hold back of a good.
static func planned(s: Dictionary, good: String) -> float:
	var total: float = 0.0
	for entry: Dictionary in s.get("reservations", []):
		total += float(entry.get(good, 0.0))
	return total


## The stock at which production of a good stops in this town: the player's level, else the
## automatic target (`Production.default_target`), raised to the reserve and planned projects.
static func slowdown(_sim: RefCounted, s: Dictionary, good: String, automatic: float) -> float:
	var chosen: float = set_slowdown(s, good)
	var level: float = chosen if chosen >= 0.0 else automatic
	var held: float = planned(s, good)
	var reserve: float = set_reserve(s, good)
	if reserve >= 0.0:
		held += reserve
	return maxf(level, held)


## What a warehouse holds and for whom, and what is free to sell: {total, held: [{key, name,
## amount}], held_total, sellable}. The trade sells `sellable` (port room permitting), the pages
## quote it, the tests check it: one number everywhere.
static func availability(
	sim: RefCounted, s: Dictionary, good: String, promises: Dictionary = {}
) -> Dictionary:
	var total: float = float(s.get("stock", {}).get(good, 0.0))
	var held: Array = []
	var kept: float = keep(sim, s, good)
	held.append({"key": "food" if good == "food" else "keep", "amount": kept})
	var plan: float = planned(s, good)
	if plan > 0.0:
		held.append({"key": "planned", "amount": plan})
	var orders: float = EventsV2.reserved(sim, int(s.region), good)
	if promises.is_empty():
		promises = sim.Logistics.reserved(sim, s)
	var promised: float = maxf(0.0, float(promises.get(good, 0.0)) - orders)
	if promised > 0.0:
		held.append({"key": "roads", "amount": promised})
	if orders > 0.0:
		held.append({"key": "orders", "amount": orders})
	var held_total: float = 0.0
	for entry: Dictionary in held:
		held_total += float(entry.amount)
	var sellable: float = maxf(0.0, total - held_total)
	# Building stock is sold only as far as the town made it: what came in by port stays.
	if good in ["materials", "parts"]:
		var made: float = maxf(0.0, float(s.get("exportable", {}).get(good, 0.0)) - orders)
		if made < sellable:
			held.append({"key": "imported", "amount": sellable - made})
			held_total += sellable - made
			sellable = made
	for entry: Dictionary in held:
		entry.name = str(HOLD_NAMES.get(str(entry.key), str(entry.key)))
	return {
		"good": good,
		"total": total,
		"held": held,
		"held_total": minf(held_total, total),
		"sellable": sellable,
		"keep": kept,
		"keep_set": set_reserve(s, good) >= 0.0,
		"slowdown_set": set_slowdown(s, good) >= 0.0,
	}


## Sets a town's controls for a good: {region, resource, reserve?, slowdown?} in units; a negative
## value (or "auto": true) returns that control to automatic.
static func set_rule(sim: RefCounted, args: Dictionary) -> String:
	var s: Dictionary = sim.settlement(int(args.get("region", args.get("site", -1))))
	var good: String = str(args.get("resource", ""))
	if s.is_empty() or not good in Keys.RESOURCES:
		return "请选择有效据点与物资"
	ensure_state(sim.state)
	var limit: float = float(rules(sim).get("max_units", 10000.0))
	var rule: Dictionary = s.stock_rules.get(good, {"reserve": AUTO, "slowdown": AUTO}).duplicate()
	for key: String in ["reserve", "slowdown"]:
		if not args.has(key):
			continue
		var value: float = float(args[key])
		if not is_finite(value) or value > limit:
			return "数量应在 0—%.0f t 之间" % sim.tonnes(limit)
		rule[key] = AUTO if value < 0.0 else value
	if bool(args.get("auto", false)):
		rule = {"reserve": AUTO, "slowdown": AUTO}
	s.stock_rules[good] = rule
	if float(rule.reserve) < 0.0 and float(rule.slowdown) < 0.0:
		s.stock_rules.erase(good)
	sim._log(_rule_words(sim, s, good))
	return ""


static func _rule_words(sim: RefCounted, s: Dictionary, good: String) -> String:
	var name: String = str(sim.config.resources.get(good, good))
	var reserve: float = set_reserve(s, good)
	var slow: float = set_slowdown(s, good)
	return (
		"%s · %s：本地保留%s，库存达到%s时减产。"
		% [
			s.name,
			name,
			"自动" if reserve < 0.0 else " %.0f t" % sim.tonnes(reserve),
			"自动目标" if slow < 0.0 else " %.0f t" % sim.tonnes(slow),
		]
	)


## Holds back in one action what a planned project will need here: its materials and parts stay
## in the warehouse (no export, no road dispatch) until it is ordered here or released.
static func reserve_for(sim: RefCounted, args: Dictionary) -> String:
	var region: int = int(args.get("region", args.get("site", -1)))
	var s: Dictionary = sim.settlement(region)
	var kind: String = str(args.get("kind", ""))
	if s.is_empty():
		return "请选择已建立的据点"
	if not sim.config.buildings.has(kind):
		return "无此设施"
	ensure_state(sim.state)
	for entry: Dictionary in s.reservations:
		if str(entry.kind) == kind:
			return "已经为这项工程预留了物资"
	var spec: Dictionary = sim.build_preview(region, kind)
	var entry: Dictionary = {
		"kind": kind,
		"materials": float(spec.get("materials", 0.0)),
		"parts": float(spec.get("parts", 0.0)),
		"day": int(sim.state.day),
	}
	s.reservations.append(entry)
	sim._log(
		(
			"%s · 为%s预留建材 %.0f t、部件 %.0f t：这些物资不再出口或外调，直到下令建设或取消预留。"
			% [
				s.name,
				str(spec.get("name", kind)),
				sim.tonnes(float(entry.materials)),
				sim.tonnes(float(entry.parts))
			]
		)
	)
	return ""


static func release(sim: RefCounted, args: Dictionary) -> String:
	var s: Dictionary = sim.settlement(int(args.get("region", args.get("site", -1))))
	if s.is_empty():
		return "请选择已建立的据点"
	var kind: String = str(args.get("kind", ""))
	for index: int in range(s.get("reservations", []).size()):
		if str(s.reservations[index].kind) == kind:
			s.reservations.remove_at(index)
			return ""
	return "没有这项预留"


## An order placed for a project that had its stock held back uses the hold: it ends.
static func on_build(s: Dictionary, kind: String) -> void:
	for index: int in range(s.get("reservations", []).size()):
		if str(s.reservations[index].kind) == kind:
			s.reservations.remove_at(index)
			return


static func set_shifts(sim: RefCounted, args: Dictionary) -> String:
	var s: Dictionary = sim.settlement(int(args.get("region", args.get("site", -1))))
	if s.is_empty():
		return "请选择已建立的据点"
	s.auto_shifts = bool(args.get("enabled", true))
	sim._log("%s · 自动减班%s。" % [s.name, "开启" if bool(s.auto_shifts) else "关闭"])
	return ""


## Checks for the audit: controls within their bounds, reservations well formed.
static func audit(state: Dictionary) -> Array:
	var errors: Array = []
	for s: Dictionary in state.get("settlements", []):
		for good: Variant in s.get("stock_rules", {}):
			if not str(good) in Keys.RESOURCES:
				errors.append("stock rule for an unknown good")
		for entry: Variant in s.get("reservations", []):
			if not entry is Dictionary or float(entry.get("materials", 0.0)) < 0.0:
				errors.append("planned project reservation invalid")
	return errors
