extends SceneTree
## 1.11 phase I: the news line.
## - every line in scripted scenarios agrees with the state it was drawn from (weather systems,
##   stages, reports and the share index, town sizes, closed events, prices, the sealed annex);
## - no line about an event that waits for a decision; none asks for one; each kind keeps its
##   cooldown and its voice; what is already true when a game loads is not news;
## - the simulation is byte-identical with the news line on or off;
## - the line on screen holds while an event panel is open.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Rules = preload("res://simulation/rules.gd")
const Sim = preload("res://simulation/sim.gd")
const Weather = preload("res://simulation/weather.gd")
const Market = preload("res://simulation/market.gd")
const Names = preload("res://simulation/names.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const NewsLine = preload("res://ui/news_line.gd")
const Labels = preload("res://ui/labels.gd")
const SEED: int = 20261123

var checks: int = 0
var failures: Array[String] = []


class FakeGame:
	extends Node
	var sim: RefCounted
	var menu_open: bool = false
	var paused: bool = false
	var overlay: Node
	var current_page: String = ""


func _initialize() -> void:
	Watchdog.arm(self, 900.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_data()
	_scenario()
	_waiting()
	_cooldowns()
	_fresh()
	_unchanged()
	_held()
	print("V111_NEWS_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _colony(seed_value: int = SEED) -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, "capital", 1)
	for reg: Dictionary in sim.state.world.regions:
		if sim.settle_refusal(int(reg.id)) == "":
			sim.act("settle", {"region": int(reg.id)})
			break
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 200000.0, "TEST funds", false)
	return sim


func _tick(sim: RefCounted) -> void:
	for town: Dictionary in sim.state.settlements:
		sim._produce(town, "food", maxf(0.0, 400.0 - float(town.stock.food)), "TEST food")
	sim.state.company.distrust = 0.0
	sim.state.company.stage = "normal"
	sim.tick()


## A system set on a straight course for the capital, arriving in `days`.
func _aimed(sim: RefCounted, kind: String, days: float) -> Dictionary:
	var here: Vector2 = Weather.town_point(sim, sim.state.settlements[0])
	var system: Dictionary = {
		"id": int(sim.state.weather.next_id),
		"kind": kind,
		"lat": here.x - 2.0 * days,
		"lon": here.y,
		"heading": 0.0,
		"speed": 2.0,
		"radius": 1.0,
		"age": 0,
		"life": 40,
		"warned": {},
		"struck": {},
		"prepared": {},
	}
	sim.state.weather.next_id = int(sim.state.weather.next_id) + 1
	sim.state.weather.systems.append(system)
	return system


func _data() -> void:
	var r: Dictionary = NewsLine.rules()
	var complete: bool = true
	var asks: bool = false
	for kind: String in r.kinds:
		complete = complete and r.templates.has(kind)
		complete = complete and str(r.kinds[kind].voice) in ["company", "colony"]
	for name: String in r.templates:
		for text: Variant in r.templates[name]:
			asks = asks or str(text).contains("？") or str(text).contains("?")
	check(complete and r.templates.has("weather_covered"), "every kind has templates and a voice")
	check(not asks, "no template asks a question")


## Lines drawn day by day while the colony lives: every candidate, in every template, checked
## against the state it came from, and the picked lines too.
func _scenario() -> void:
	var sim: RefCounted = _colony()
	var town: Dictionary = sim.state.settlements[0]
	var memory: Dictionary = NewsLine.fresh_memory(sim)
	var lines: Array = []
	var wrong: Array = []
	var offered: Dictionary = {}
	_aimed(sim, "heavy_rain", 6.0)
	for day: int in range(120):
		if day == 10:
			sim.state.contract.completed["1"] = int(sim.state.day)
		if day == 20:
			sim.Population._admit(sim, town, 260, 0)
		if day == 30:
			sim.state.market.saturation["ore"] = 4500.0
		if day == 40:
			sim.state.annual.next_ship = int(sim.state.day) + 1
		if day == 45 and not sim.state.annual.pending.is_empty():
			sim.act("annual_report", {})
		if day == 50:
			_aimed(sim, "cold_wave", 5.0)
		_tick(sim)
		for candidate: Dictionary in NewsLine.candidates(sim):
			offered[str(candidate.kind)] = true
			for template: Variant in NewsLine.rules().templates[str(candidate.template)]:
				var filled: Dictionary = candidate.duplicate(true)
				filled.text = NewsLine.fill(sim, str(template), candidate)
				var problem: String = _verify(sim, filled)
				if problem != "":
					wrong.append("%s: %s" % [str(filled.text), problem])
		var news: Dictionary = NewsLine.pick(sim, memory)
		if news.is_empty():
			continue
		lines.append(news)
		var error: String = _verify(sim, news)
		if error != "":
			wrong.append("%s: %s" % [str(news.text), error])
	var kinds: Dictionary = {}
	for news: Dictionary in lines:
		kinds[str(news.kind)] = true
	print("  lines: %d, kinds shown %s" % [lines.size(), str(kinds.keys())])
	for sample: Dictionary in lines.slice(0, 14):
		print("  [%s] %s" % [str(sample.tag), str(sample.text)])
	check(wrong.is_empty(), "no line contradicts the state: %s" % str(wrong.slice(0, 4)))
	for kind: String in ["weather", "stage", "report", "population", "market", "rumour"]:
		check(offered.has(kind), "the scenario offers %s lines" % kind)
	check(kinds.size() >= 5, "and shows %d kinds of line" % kinds.size())
	var voices: bool = true
	for news: Dictionary in lines:
		var text: String = str(news.text)
		if str(news.voice) == "company":
			voices = voices and (text.contains("本公司") or text.contains("部") or text.contains("CC-"))
		else:
			voices = voices and not (text.contains("贵方") or text.contains("本公司"))
	check(voices, "company lines in the company's voice, colony lines in the colony's")


## Checks a line's facts against the state, apart from the code that drew it.
func _verify(sim: RefCounted, news: Dictionary) -> String:
	var text: String = str(news.text)
	var facts: Dictionary = news.facts
	if text.contains("{") or text.contains("？") or text.contains("?"):
		return "placeholder or question"
	match str(news.kind):
		"weather":
			for system: Dictionary in sim.state.weather.systems:
				if int(system.id) != int(facts.system):
					continue
				var town: Dictionary = {}
				for s: Dictionary in sim.state.settlements:
					if str(s.name) == str(facts.town):
						town = s
				if town.is_empty() or not system.warned.has(str(town.region)):
					return "no warning for that town"
				if system.struck.has(str(town.region)):
					return "already struck"
				var here: Vector2 = Weather.town_point(sim, town)
				for step: int in range(1, 31):
					var at: Vector2 = Weather.ahead(system, float(step))
					if Weather.arc(at.x, at.y, here.x, here.y) <= float(system.radius):
						return "" if step == int(facts.days) else "arrives in %d days" % step
				return "never arrives"
			return "no such system"
		"stage":
			return "" if sim.state.contract.completed.has(str(facts.stage)) else "stage not passed"
		"report":
			var history: Array = sim.state.annual.history
			if history.is_empty() or int(history.back().year) != int(facts.year):
				return "no such report"
			return "" if "%.1f" % NewsLine.share_index(sim) == str(facts.index) else "index"
		"population":
			for s: Dictionary in sim.state.settlements:
				if str(s.name) == str(facts.town) and int(s.population) >= int(facts.count):
					return ""
			return "town smaller"
		"echo":
			for row: Dictionary in sim.state.events_v2.history:
				if str(row.ending) == str(facts.ending):
					return ""
			return "no such ending"
		"market":
			var good: String = ""
			for key: String in Labels.RESOURCE_NAMES:
				if str(Labels.RESOURCE_NAMES[key]) == str(facts.good):
					good = key
			var fall: float = 1.0 - Market.factor(sim, good)
			return "" if good != "" and fall + 0.0001 >= float(facts.pct) / 100.0 else "price"
		"rumour":
			var sealed: bool = int(sim.state.annex.get("opened_day", -1)) < 0
			return "" if int(sim.state.contract.stage) < 4 and sealed else "annex"
		"company_flavour":
			return "" if not Names.code(sim).ends_with(str(facts.other)) else "own code"
	return ""


## While a story waits for the player, nothing is said about it: not the weather that opened it,
## not an echo of the same story.
func _waiting() -> void:
	var sim: RefCounted = _colony()
	var town: Dictionary = sim.state.settlements[0]
	_aimed(sim, "heavy_rain", 4.0)
	_tick(sim)
	check(
		EventsV2.trigger(sim, "flood_season", int(town.region)),
		"a flood story opens and waits for a decision"
	)
	var about: bool = false
	var said: int = 0
	var memory: Dictionary = NewsLine.fresh_memory(sim)
	for _try: int in range(30):
		memory.last_day = {}
		for candidate: Dictionary in NewsLine.candidates(sim):
			if str(candidate.kind) == "weather":
				said += 1
		var news: Dictionary = NewsLine.pick(sim, memory)
		about = about or str(news.get("subject", "")) == "flood_season"
	check(said > 0, "the heavy rain is in the candidates (%d times)" % said)
	check(not about, "but no line about it while the flood story waits")
	var inst: Dictionary = sim.state.events_v2.instances.back()
	sim._produce(town, "materials", 50.0, "TEST materials")
	var refusal: String = sim.act(
		"event_v2", {"instance_id": str(inst.instance_id), "choice": "levee"}
	)
	check(refusal == "", "the flood story is decided: " + refusal)
	var echoed: bool = false
	for _try: int in range(30):
		memory.last_day = {}
		var news: Dictionary = NewsLine.pick(sim, memory)
		echoed = echoed or (str(news.get("kind", "")) == "echo" and str(news.text).contains("堤坝保住"))
	check(echoed, "once decided, it is echoed with its ending")


func _cooldowns() -> void:
	var sim: RefCounted = _colony()
	var memory: Dictionary = NewsLine.fresh_memory(sim)
	var seen: Dictionary = {}
	var early: Array = []
	for _day: int in range(90):
		_tick(sim)
		var news: Dictionary = NewsLine.pick(sim, memory)
		if news.is_empty():
			continue
		var kind: String = str(news.kind)
		var gap: int = int(NewsLine.rules().kinds[kind].cooldown_days)
		if seen.has(kind) and int(sim.state.day) - int(seen[kind]) < gap:
			early.append(kind)
		seen[kind] = int(sim.state.day)
	check(early.is_empty(), "each kind waits its cooldown: %s" % str(early))


## A loaded game does not announce what was already true.
func _fresh() -> void:
	var sim: RefCounted = _colony()
	sim.state.settlements[0].population = 600
	sim.state.contract.completed["1"] = int(sim.state.day)
	var memory: Dictionary = NewsLine.fresh_memory(sim)
	var old: bool = false
	for _try: int in range(20):
		memory.last_day = {}
		var news: Dictionary = NewsLine.pick(sim, memory)
		old = old or str(news.get("kind", "")) in ["population", "stage"]
	check(not old, "a loaded game's old milestones are not news")
	sim.state.settlements[0].population = 1200
	memory.last_day = {}
	var grown: bool = false
	for _try: int in range(5):
		memory.last_day = {}
		grown = grown or str(NewsLine.pick(sim, memory).get("kind", "")) == "population"
	check(grown, "a town that grows past the next size is")


## The same colony, one with the news line drawing every day and one without: the same bytes.
func _unchanged() -> void:
	var quiet: RefCounted = _colony()
	var loud: RefCounted = _colony()
	var memory: Dictionary = NewsLine.fresh_memory(loud)
	_aimed(quiet, "heavy_rain", 5.0)
	_aimed(loud, "heavy_rain", 5.0)
	for _day: int in range(150):
		_tick(quiet)
		_tick(loud)
		NewsLine.pick(loud, memory)
		NewsLine.candidates(loud)
	check(
		var_to_bytes(quiet.state) == var_to_bytes(loud.state),
		"the simulation is byte-identical with the news line on or off"
	)


func _held() -> void:
	var fake := FakeGame.new()
	fake.sim = _colony()
	root.add_child(fake)
	var line := NewsLine.new()
	line.on = true
	fake.add_child(line)
	line.step(fake, 0.1)
	var first: String = line.text_label.text
	check(first != "" and line.visible, "the line shows: " + first)
	fake.overlay = Node.new()
	fake.add_child(fake.overlay)
	fake.current_page = "events"
	for _frame: int in range(20):
		line.step(fake, 5.0)
	var kept: float = line.left
	check(line.text_label.text == first and kept > 0.0, "and holds while an event panel is open")
	fake.current_page = ""
	fake.overlay.queue_free()
	fake.overlay = null
	line.step(fake, 5.0)
	check(is_equal_approx(line.left, kept - 5.0), "then its time runs again")
	fake.queue_free()
