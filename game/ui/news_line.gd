extends PanelContainer
## The news line (1.11 I): one line of news at the bottom edge of the screen. Interface only: it
## reads the state and never writes it, it is not saved, and its randomness comes from its own
## generator seeded by the seed and the day, so the simulation is the same with it on or off.
## - Lines come from `news.json` templates, by kind: weather warnings for systems in the state, stage
##   milestones, filed annual reports with the company's share index, towns passing a size, echoes
##   of resolved events, market prices, Annex VII rumours before stage four, flavour about other
##   colonies and the company. Each kind has a priority, a cooldown in game days and a voice.
## - It never asks for a decision, says nothing about an event still waiting for one, and forecasts
##   only from the state. It stops while an event panel is open.
## Its final place comes with the interface pass.

const D = preload("res://ui/design.gd")
const Rules = preload("res://simulation/rules.gd")
const Names = preload("res://simulation/names.gd")
const Weather = preload("res://simulation/weather.gd")
const Market = preload("res://simulation/market.gd")
const Events = preload("res://simulation/events_v2.gd")
const Labels = preload("res://ui/labels.gd")
const SETTINGS: String = "user://settings.cfg"
const WAITING: Array[String] = ["pending", "deferred"]
## Templates used lately are not drawn again while another of the kind is free.
const RECENT_TEMPLATES: int = 10

var tag_label: Label
var text_label: Label
var memory: Dictionary = {}
var watched: Dictionary = {}
var line: Dictionary = {}
var left: float = 0.0
var on: bool = true


static func rules() -> Dictionary:
	return Rules.read("news")


func _ready() -> void:
	name = "NewsLine"
	anchor_top = 1
	anchor_bottom = 1
	anchor_right = 1
	offset_left = 20
	offset_right = -20
	offset_top = -20
	offset_bottom = -1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The chip's look, thinner: the strip under the task bar is 20 pixels high.
	var box: StyleBoxFlat = (D.style("chip") as StyleBoxFlat).duplicate()
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	add_theme_stylebox_override("panel", box)
	var row: HBoxContainer = D.row(self)
	tag_label = D.label(row, "", 13, D.TEAL, false)
	text_label = D.label(row, "", 13, D.MUTED, false)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.clip_text = true
	var settings := ConfigFile.new()
	settings.load(SETTINGS)
	on = bool(settings.get_value("display", "news", true))
	visible = false


## Called every frame by the game: a new or loaded game starts a fresh memory (what is already true
## is not news); the line turns over while the clock runs, and holds while an event panel is open.
func step(g: Node, delta: float) -> void:
	if not is_inside_tree():
		return
	var ui: Variant = g.get("ui")
	if ui is Control and (ui as Control).has_node("Timelapse"):
		visible = false
		return
	var sim: RefCounted = g.sim
	if not is_same(sim.state, watched):
		watched = sim.state
		memory = fresh_memory(sim)
		line = {}
		left = 0.0
	var playing: bool = (
		on
		and not bool(g.menu_open)
		and not str(sim.state.get("status", "")) in ["planning", "failed"]
	)
	visible = playing and not line.is_empty()
	if not playing or held(g):
		return
	if not bool(g.paused):
		left -= delta
	if left > 0.0 and not line.is_empty():
		return
	var next: Dictionary = pick(sim, memory)
	if next.is_empty():
		return
	line = next
	left = float(rules().get("seconds_per_line", 14.0))
	tag_label.text = "【%s】" % str(line.tag)
	text_label.text = str(line.text)
	text_label.add_theme_color_override(
		"font_color", D.GOLD if str(line.voice) == "company" else D.MUTED
	)
	visible = true


## Whether an event panel is open (or a decision waits): the line stays as it is.
static func held(g: Node) -> bool:
	var panel: bool = is_instance_valid(g.overlay) and str(g.current_page) == "events"
	return panel or Events.pause_required(g.sim)


func shown() -> bool:
	return on


func toggle(g: Node) -> void:
	on = not on
	var settings := ConfigFile.new()
	settings.load(SETTINGS)
	settings.set_value("display", "news", on)
	settings.save(SETTINGS)
	visible = on and not line.is_empty()
	g.open_page("save")


## What is already true when a game starts or loads is not news: towns past a size, reports and
## stages already filed, events already closed.
static func fresh_memory(sim: RefCounted) -> Dictionary:
	var memory: Dictionary = {"last_day": {}, "shown": {}, "recent": []}
	for candidate: Dictionary in candidates(sim):
		if str(candidate.kind) in ["population", "report", "stage", "echo"]:
			memory.shown[str(candidate.key)] = true
	return memory


## The next line, or {}: the highest priority among the candidates not cooling down, not shown
## before and not about an event that waits for a decision; ties and templates drawn from a
## generator seeded by the seed and the day. Updates `memory`.
static func pick(sim: RefCounted, memory: Dictionary) -> Dictionary:
	var day: int = int(sim.state.day)
	var busy: Dictionary = waiting_subjects(sim)
	var kinds: Dictionary = rules().kinds
	var best: Array = []
	var top: int = -1
	for candidate: Dictionary in candidates(sim):
		var kind: Dictionary = kinds[candidate.kind]
		if busy.has(str(candidate.subject)) or memory.shown.has(str(candidate.key)):
			continue
		var last: int = int(memory.last_day.get(candidate.kind, -100000))
		if day - last < int(kind.cooldown_days):
			continue
		var priority: int = int(kind.priority)
		if priority > top:
			top = priority
			best = []
		if priority == top:
			best.append(candidate)
	if best.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:news:%d" % [str(sim.state.world.seed), day])
	var chosen: Dictionary = best[rng.randi_range(0, best.size() - 1)]
	var templates: Array = rules().templates[str(chosen.template)]
	var recent: Array = memory.get("recent", [])
	var fresh: Array = templates.filter(func(t: Variant) -> bool: return not str(t) in recent)
	var pool: Array = fresh if not fresh.is_empty() else templates
	var template: String = str(pool[rng.randi_range(0, pool.size() - 1)])
	var text: String = fill(sim, template, chosen)
	recent.append(template)
	while recent.size() > RECENT_TEMPLATES:
		recent.pop_front()
	memory.recent = recent
	memory.last_day[chosen.kind] = day
	if str(chosen.key) != "":
		memory.shown[str(chosen.key)] = true
	var kind_rule: Dictionary = kinds[chosen.kind]
	var out: Dictionary = chosen.duplicate(true)
	out.text = text
	out.tag = str(kind_rule.tag)
	out.voice = str(kind_rule.voice)
	return out


static func fill(sim: RefCounted, template: String, candidate: Dictionary) -> String:
	var text: String = template
	for key: String in candidate.facts:
		text = text.replace("{%s}" % key, str(candidate.facts[key]))
	return Names.fill(sim, text)


## The subjects of events that wait for the player's decision: their story ids.
static func waiting_subjects(sim: RefCounted) -> Dictionary:
	var out: Dictionary = {}
	for inst: Dictionary in sim.state.get("events_v2", {}).get("instances", []):
		if str(inst.status) in WAITING:
			out[str(inst.definition_id)] = true
	return out


## Everything the line could say today, each with its kind, template, facts from the state, the
## subject it is about (a story id, "" for none) and a key that marks it once shown ("" repeats).
static func candidates(sim: RefCounted) -> Array:
	var out: Array = []
	out.append_array(_weather(sim))
	out.append_array(_milestones(sim))
	out.append_array(_echoes(sim))
	out.append_array(_market(sim))
	var r: Dictionary = rules()
	var annex: Dictionary = sim.state.get("annex", {})
	var stage: int = int(sim.state.get("contract", {}).get("stage", 1))
	if stage < int(r.get("rumour_before_stage", 4)) and int(annex.get("opened_day", -1)) < 0:
		for index: int in range(r.templates.rumour.size()):
			out.append(_candidate("rumour", "rumour", {}, "", "rumour:%d" % index))
	var codes: Array = r.get("other_codes", [11, 98])
	var other: int = _other_code(sim, int(codes[0]), int(codes[1]))
	out.append(_candidate("company_flavour", "company_flavour", {"other": "%02d" % other}, "", ""))
	out.append(_candidate("colony_flavour", "colony_flavour", {}, "", ""))
	return out


static func _candidate(
	kind: String, template: String, facts: Dictionary, subject: String, key: String
) -> Dictionary:
	return {"kind": kind, "template": template, "facts": facts, "subject": subject, "key": key}


## A system warned for a town and still on its way, with the days until it arrives (none if it
## would die out first).
static func _weather(sim: RefCounted) -> Array:
	var out: Array = []
	for system: Dictionary in sim.state.get("weather", {}).get("systems", []):
		var kind: Dictionary = Weather.rules().get("kinds", {}).get(str(system.kind), {})
		for key: Variant in system.get("warned", {}):
			var town: Dictionary = sim.settlement(int(str(key)))
			if town.is_empty() or system.struck.has(str(key)) or kind.is_empty():
				continue
			var days: int = arrival_in(sim, system, town)
			if days < 1:
				continue
			var facts: Dictionary = {
				"kind_name": str(kind.name),
				"town": str(town.name),
				"days": days,
				"system": system.id
			}
			out.append(
				_candidate(
					"weather",
					"weather_covered" if Weather.covered(sim, town) else "weather",
					facts,
					str(kind.event),
					"weather:%d:%s:%d" % [int(system.id), str(key), days]
				)
			)
	return out


## Days until a system's centre comes within its radius of the town along its heading, within the
## forecast horizon and the system's remaining life; -1 when it does not.
static func arrival_in(sim: RefCounted, system: Dictionary, town: Dictionary) -> int:
	var here: Vector2 = Weather.town_point(sim, town)
	var life: int = int(system.life) - int(system.age)
	for step: int in range(1, mini(int(rules().get("weather_horizon", 30)), life) + 1):
		var at: Vector2 = Weather.ahead(system, float(step))
		if Weather.arc(at.x, at.y, here.x, here.y) <= float(system.radius):
			return step
	return -1


## Stages accepted lately, the latest annual report filed lately, and each town's size.
static func _milestones(sim: RefCounted) -> Array:
	var out: Array = []
	var r: Dictionary = rules()
	var day: int = int(sim.state.day)
	var completed: Dictionary = sim.state.get("contract", {}).get("completed", {})
	for stage: Variant in completed:
		if day - int(completed[stage]) <= int(r.get("milestone_days", 30)):
			out.append(_candidate("stage", "stage", {"stage": str(stage)}, "", "stage:%s" % stage))
	var history: Array = sim.state.get("annual", {}).get("history", [])
	if not history.is_empty():
		var entry: Dictionary = history.back()
		if day - int(entry.day) <= int(r.get("report_days", 45)):
			var words: Dictionary = {"missed": "未达标", "waived": "免责", "met": "达标", "exceed": "超额"}
			var facts: Dictionary = {
				"year": int(entry.year),
				"mining": str(words.get(str(entry.outcomes.get("mining", "")), "")),
				"farming": str(words.get(str(entry.outcomes.get("farming", "")), "")),
				"index": "%.1f" % share_index(sim),
			}
			out.append(_candidate("report", "report", facts, "", "report:%d" % int(entry.year)))
	for town: Dictionary in sim.state.get("settlements", []):
		var passed: int = 0
		for count: Variant in r.get("populations", []):
			if int(town.population) >= int(count):
				passed = int(count)
		if passed > 0:
			var facts: Dictionary = {"town": str(town.name), "count": passed}
			out.append(
				_candidate(
					"population",
					"population",
					facts,
					"",
					"population:%d:%d" % [int(town.region), passed]
				)
			)
	return out


## The company's share index: the start, moved by every line of every filed annual report.
static func share_index(sim: RefCounted) -> float:
	var r: Dictionary = rules().get("share_index", {})
	var index: float = float(r.get("start", 100.0))
	for entry: Dictionary in sim.state.get("annual", {}).get("history", []):
		for line_id: Variant in entry.get("outcomes", {}):
			index += float(r.get("points", {}).get(str(entry.outcomes[line_id]), 0.0))
	return index


## Events closed lately, each echoed once with its ending.
static func _echoes(sim: RefCounted) -> Array:
	var out: Array = []
	var day: int = int(sim.state.day)
	var definitions: Dictionary = Events.definitions().get("definitions", {})
	for row: Dictionary in sim.state.get("events_v2", {}).get("history", []):
		if day - int(row.day) > int(rules().get("echo_days", 20)) or str(row.ending) == "":
			continue
		var definition: Dictionary = definitions.get(str(row.definition_id), {})
		var title: String = str(definition.get("nodes", {}).get("start", {}).get("title", ""))
		if title == "":
			continue
		var town: Dictionary = sim.settlement(int(row.get("target_region", -1)))
		var facts: Dictionary = {
			"town": str(town.get("name", Names.capital(sim))),
			"title": Names.fill(sim, title),
			"ending": str(row.ending),
		}
		var key: String = "echo:%s" % str(row.instance_id)
		out.append(_candidate("echo", "echo", facts, str(row.definition_id), key))
	return out


## Goods sold below the reference price by at least `price_move`, in steps of `price_step`.
static func _market(sim: RefCounted) -> Array:
	var out: Array = []
	var move: float = float(rules().get("price_move", 0.15))
	var step: float = maxf(0.01, float(rules().get("price_step", 0.05)))
	for good: Variant in sim.market_rules.get("scale", {}):
		if not Labels.RESOURCE_NAMES.has(str(good)):
			continue
		var fall: float = 1.0 - Market.factor(sim, str(good))
		if fall < move:
			continue
		var pct: int = int(floor(fall / step) * step * 100.0 + 0.5)
		var facts: Dictionary = {"good": Labels.RESOURCE_NAMES[str(good)], "pct": pct}
		out.append(_candidate("market", "market", facts, "", "market:%s:%d" % [str(good), pct]))
	return out


## Another project's code number for flavour lines, never the colony's own.
static func _other_code(sim: RefCounted, low: int, high: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:news-code:%d" % [str(sim.state.world.seed), int(sim.state.day)])
	var own: String = Names.code(sim)
	var other: int = rng.randi_range(low, high)
	if own.ends_with("%02d" % other):
		other = low + posmod(other - low + 1, high - low + 1)
	return other
