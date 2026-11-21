extends SceneTree
## Seed-3 opening, played as the site card suggests: found the capital at a coordinate, carry out the
## card's best first-sale plan (its facilities, and the supply order when the plan is one), let the
## balanced bot keep the colony running, and as soon as the first genuine delivery is paid and the
## expedition is affordable, found the second town at an unmarked coordinate (no recommended site
## within 0.5°) chosen from the same site card. Records the card, every action with its day, the
## first delivery, the second town, supply orders and their renewals, sales by kind, stage days.
##   godot --headless --path game --script /home/user/probes/opening_play.gd -- --lat=.. --lon=.. --days=420 --out=..

const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")

var options: Dictionary = {
	"lat": "39.9747", "lon": "122.1984", "days": "420", "out": "", "second": "true"
}
var record: Dictionary = {}
var sim: RefCounted
var bot: RefCounted
var mine: Array = []
var pending: Dictionary = {}
var second_plan_day: int = -1


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var timer: SceneTreeTimer = create_timer(1500.0)
	timer.timeout.connect(func(): _finish("watchdog"))
	_run.call_deferred()


func _act(action: String, args: Dictionary) -> String:
	var error: String = sim.act(action, args)
	mine.append({"day": int(sim.state.day), "action": action, "args": args, "error": error})
	return error


func _card(lat: float, lon: float, from: int, kind: String) -> Dictionary:
	var view: Dictionary = sim.Placement.preview(sim, lat, lon, from, kind)
	var plans: Array = []
	for plan: Dictionary in view.get("plans", []):
		var needs: Array = []
		for step: Dictionary in plan.needs:
			needs.append(str(step.kind))
		plans.append(
			{
				"key": plan.key,
				"title": plan.title,
				"cost": snappedf(float(plan.cost), 1.0),
				"first_day": int(plan.first_day),
				"first_amount_t": sim.tonnes(float(plan.first_amount)),
				"per_day": snappedf(float(plan.per_day), 0.1),
				"goal_day": int(plan.goal_day),
				"late": bool(plan.get("late", false)),
				"needs": needs,
				"best": bool(plan.best),
				"note": str(plan.note)
			}
		)
	var minerals: Dictionary = {}
	for good: String in view.get("minerals", {}):
		var m: Dictionary = view.minerals[good]
		minerals[good] = {
			"level": m.get("level"),
			"low_t": sim.tonnes(float(m.get("low", 0.0))),
			"high_t": sim.tonnes(float(m.get("high", 0.0))),
			"plots": [m.get("plots_low"), m.get("plots_high")],
			"none_detected": m.get("none_detected", false)
		}
	return {
		"lat": view.get("lat"),
		"lon": view.get("lon"),
		"refusal": view.get("refusal", ""),
		"elevation": view.get("elevation"),
		"terrain": view.get("terrain"),
		"biome": view.get("biome"),
		"coast": view.get("coast"),
		"plots": view.get("plots", {}),
		"farming": view.get("farming", {}),
		"fishing": view.get("fishing", {}),
		"water": view.get("water_supply", {}),
		"building": {"cost_factor": view.get("building", {}).get("cost_factor")},
		"minerals": minerals,
		"plans": plans
	}


func _run() -> void:
	sim = Sim.new()
	sim.new_game("3", "capital", 1, "normal", 1.0)
	var lat: float = float(options.lat)
	var lon: float = float(options.lon)
	record.options = options
	record.card = _card(lat, lon, -1, "residential")
	if _act("settle_at", {"lat": lat, "lon": lon, "name": "首府"}) != "":
		_finish("capital refused")
		return
	var home: int = int(sim.state.settlements[0].region)
	var best: Dictionary = {}
	for plan: Dictionary in record.card.plans:
		if bool(plan.best):
			best = plan
	record.plan = best
	for kind: String in best.get("needs", []):
		if kind != "port" or not _has(home, "port"):
			_act("build", {"site": home, "kind": kind})
	if str(best.get("key", "")) in ["food", "catch"]:
		_act("supply_sign", {"site": home, "kind": str(best.key)})
	bot = Bot.new()
	bot.begin(sim, 3)
	var first_delivery: Dictionary = {}
	var second: Dictionary = {}
	var stage_days: Dictionary = {}
	var months: Array = []
	var last_exports: float = 0.0
	for _day: int in range(int(options.days)):
		if (
			second.is_empty()
			and not first_delivery.is_empty()
			and options.second == "true"
			and sim.Contract.cap_refusal(sim) == ""
		):
			second = _second_town(home)
		if (
			not pending.is_empty()
			and int(sim.settlement(int(pending.region)).get("arrival", 0)) <= 0
		):
			# The expedition has arrived: the second town's plan, as its card showed it, one step
			# a day as the cash allows (a player waits for the money rather than giving up).
			var region: int = int(pending.region)
			if not pending.has("steps"):
				pending.steps = pending.plan.needs.duplicate()
			while not pending.steps.is_empty():
				var kind: String = str(pending.steps[0])
				if kind == "port" and _has(region, "port"):
					pending.steps.pop_front()
					continue
				if sim.act("build", {"site": region, "kind": kind}) != "":
					break
				mine.append(
					{
						"day": int(sim.state.day),
						"action": "build",
						"args": {"site": region, "kind": kind},
						"error": ""
					}
				)
				pending.steps.pop_front()
			if pending.steps.is_empty():
				if str(pending.plan.key) in ["food", "catch"]:
					_act("supply_sign", {"site": region, "kind": str(pending.plan.key)})
				second_plan_day = int(sim.state.day)
				pending = {}
		bot.on_day()
		sim.tick()
		if first_delivery.is_empty() and float(sim.state.exports_total) > 0.0:
			first_delivery = {
				"day": int(sim.state.day),
				"exports_total": snappedf(float(sim.state.exports_total), 1.0),
				"log": _log_today()
			}
		for stage: String in sim.state.contract.completed:
			stage_days[stage] = int(sim.state.contract.completed[stage])
		if int(sim.state.day) % 30 == 0:
			var window: Dictionary = sim.stats_window(30)
			var sales: Dictionary = {"export": 0.0, "supply": 0.0, "local": 0.0}
			for s: Dictionary in sim.state.settlements:
				var rows: Dictionary = sim.Supply.sales(s, int(sim.state.day), 30)
				for key: String in sales:
					sales[key] = snappedf(float(sales[key]) + float(rows.get(key, 0.0)), 1.0)
			months.append(
				{
					"day": int(sim.state.day),
					"cash": snappedf(float(sim.state.cash), 1.0),
					"exports_total": snappedf(float(sim.state.exports_total), 1.0),
					"exports_month": snappedf(float(sim.state.exports_total) - last_exports, 1.0),
					"sales_30d": sales,
					"towns": sim.state.settlements.size(),
					"stage": int(sim.state.contract.stage),
					"company": str(sim.state.company.stage),
					"pop": int(sim.summary().population),
					"income_30d": window.get("income", {})
				}
			)
			last_exports = float(sim.state.exports_total)
		if sim.state.status == "failed":
			break
	record.first_delivery = first_delivery
	record.second_town = second
	record.second_plan_day = second_plan_day
	record.stage_days = stage_days
	record.months = months
	record.status = str(sim.state.status)
	record.final_day = int(sim.state.day)
	record.failure_reason = str(sim.state.get("failure_reason", ""))
	record.exports_total = snappedf(float(sim.state.exports_total), 1.0)
	record.orders = []
	for order: Dictionary in sim.state.get("supply", {}).get("orders", []):
		record.orders.append(order.duplicate(true))
	var towns: Array = []
	for s: Dictionary in sim.state.settlements:
		var kinds: Dictionary = {}
		for b: Dictionary in s.buildings:
			kinds[str(b.kind)] = int(kinds.get(str(b.kind), 0)) + 1
		var reg: Dictionary = sim.state.world.regions[int(s.region)]
		towns.append(
			{
				"name": s.name,
				"region": int(s.region),
				"lat": reg.lat,
				"lon": reg.lon,
				"placed": reg.get("placed", false),
				"kinds": kinds,
				"pop": int(s.population)
			}
		)
	record.towns = towns
	var rows: Array = []
	var seq: int = 0
	for entry: Dictionary in mine:
		seq += 1
		rows.append(
			[
				int(entry.day),
				0,
				seq,
				(
					"%d · player · %s %s %s"
					% [int(entry.day), entry.action, JSON.stringify(entry.args), entry.error]
				)
			]
		)
	for entry: Dictionary in bot.actions:
		seq += 1
		if str(entry.error) == "" and int(entry.day) <= 200:
			rows.append(
				[
					int(entry.day),
					1,
					seq,
					"%d · bot · %s %s" % [int(entry.day), entry.action, JSON.stringify(entry.args)]
				]
			)
	rows.sort_custom(
		func(a: Array, b: Array) -> bool:
			return a[0] < b[0] or (a[0] == b[0] and (a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])))
	)
	var acts: Array = []
	for row: Array in rows:
		acts.append(row[3])
	record.actions = acts
	_finish("done")


func _log_today() -> Array:
	var lines: Array = []
	for entry: Dictionary in sim.state.log:
		if int(entry.day) == int(sim.state.day):
			lines.append(str(entry.text))
	return lines


func _has(region: int, kind: String) -> bool:
	for b: Dictionary in sim.settlement(region).get("buildings", []):
		if str(b.kind) == kind:
			return true
	return false


## The best unmarked coordinate within 9° of the capital that a town can be founded on today: no
## recommended site within 0.5°, the site card's best plan reaching the export goal soonest.
func _second_town(home: int) -> Dictionary:
	var capital: Dictionary = sim.state.world.regions[home]
	var marks: Array = []
	for reg: Dictionary in sim.state.world.regions:
		if not bool(reg.get("placed", false)):
			marks.append(Vector2(float(reg.lat), float(reg.lon)))
	var found: Dictionary = {}
	var best_day: int = 1 << 30
	var lat0: float = float(capital.lat)
	var lon0: float = float(capital.lon)
	var step: float = 0.75
	var tried: int = 0
	for i: int in range(-12, 13):
		for j: int in range(-12, 13):
			var lat: float = lat0 + i * step + 0.137
			var lon: float = lon0 + j * step + 0.241
			var near_mark: bool = false
			for mark: Vector2 in marks:
				if absf(mark.x - lat) < 0.5 and absf(mark.y - lon) < 0.5:
					near_mark = true
			if near_mark:
				continue
			var view: Dictionary = sim.Placement.view(sim, lat, lon, home, "frontier")
			if str(view.get("refusal", "x")) != "":
				continue
			tried += 1
			var card: Dictionary = _card(lat, lon, home, "frontier")
			if str(card.refusal) != "" or card.plans.is_empty():
				continue
			var day: int = int(card.plans[0].goal_day)
			if day < best_day:
				best_day = day
				found = card
	if found.is_empty():
		return {}
	var before: int = sim.state.settlements.size()
	var error: String = _act(
		"settle_at",
		{
			"lat": float(found.lat),
			"lon": float(found.lon),
			"from": home,
			"name": "二号",
			"kind": "frontier"
		}
	)
	if error != "" or sim.state.settlements.size() == before:
		return {"refused": error, "card": found, "tried": tried}
	var region: int = int(sim.state.settlements[-1].region)
	pending = {"region": region, "plan": found.plans[0]}
	return {
		"day": int(sim.state.day),
		"card": found,
		"tried": tried,
		"stage": int(sim.state.contract.stage),
		"exports_total": snappedf(float(sim.state.exports_total), 1.0),
		"cash_after": snappedf(float(sim.state.cash), 1.0)
	}


func _finish(why: String) -> void:
	record.finish = why
	var text: String = JSON.stringify(record, "  ")
	if str(options.out) != "":
		var file: FileAccess = FileAccess.open(str(options.out), FileAccess.WRITE)
		file.store_string(text)
		file.close()
	printerr(
		(
			"OPENING finish=%s first=%s second=%s stages=%s status=%s exports=%s"
			% [
				why,
				str(record.get("first_delivery", {}).get("day", -1)),
				str(record.get("second_town", {}).get("day", -1)),
				str(record.get("stage_days", {})),
				str(record.get("status", "")),
				str(record.get("exports_total", 0))
			]
		)
	)
	quit(0)
