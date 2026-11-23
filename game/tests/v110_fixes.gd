extends SceneTree
## 1.10 fixes for the feedback verified against the November 13 preview
## (docs/v17/REVIEW_20261119.md).
## - Building identity: every building keeps a uid; a story that built something follows it, so
##   pulling down an unrelated older building leaves the story going and pulling down the target
##   ends it; saves from before uids get them on load, and so do stories that followed a position.
## - Research: assigned, blocked and progressing are told apart, and the tutorial waits for work
##   that progresses; a commission's points shorten the days left.
## - A farm's forecast counts the food its town can use, not its nominal capacity.
## - The water lesson tells waiting from investing; the menu shows the tutorial's real planet.
## - The clock keeps its part of a day across panels and pauses.
## - An event's town is chosen after the event, by its kind of work and how lately it had one;
##   options that send a team say when it reports back.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Rules = preload("res://simulation/rules.gd")
const Sim = preload("res://simulation/sim.gd")
const Events = preload("res://simulation/events_v2.gd")
const Production = preload("res://simulation/production.gd")
const SaveIo = preload("res://simulation/save_io.gd")
const Research = preload("res://simulation/research.gd")
const Tutorial = preload("res://simulation/tutorial.gd")
const PeopleLines = preload("res://ui/people_lines.gd")
const PROBE_ID: String = "v110_pump_probe"
const SAVE_PATH: String = "user://v110_fixes.save"

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, 600.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	# Commissions are frozen in 1.11 (features.gd); this suite keeps their code tested.
	Rules.read("progression").features.research_commissions = true
	Events.definitions().definitions[PROBE_ID] = _pump_probe()
	_identity()
	_unrelated_demolition()
	_target_demolition()
	_old_story()
	_research_states()
	_commission_pace()
	_usable_farm()
	_water_lesson()
	_event_towns()
	_growth_limits()
	Events.definitions().definitions.erase(PROBE_ID)
	await _interface()
	print("V110_FIXES_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


## Never drawn: a story that builds a pump and checks it once it runs.
func _pump_probe() -> Dictionary:
	return {
		"version": 1,
		"type": "chain",
		"category": "opportunity",
		"kind": "decision",
		"critical": false,
		"cooldown_days": 999,
		"weight": 0,
		"chance": 0.0,
		"conditions": {"trigger_only": true},
		"nodes":
		{
			"start":
			{
				"title": "泵站探针",
				"text": "只供测试的事件：建一座泵站，泵站运转后进入验收节点。",
				"deadline_days": 10,
				"default": "skip",
				"choices":
				[
					{"id": "pump", "label": "建泵站", "build": "water", "next": "check"},
					{"id": "skip", "label": "不建", "ending": "未建"}
				]
			},
			"check":
			{
				"title": "泵站验收",
				"text": "泵站已经运转，这一步只用来确认故事走到了这里。",
				"deadline_days": 10,
				"default": "done",
				"choices": [{"id": "done", "label": "验收", "ending": "验收完成"}]
			}
		}
	}


func _colony() -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(20261029, "science", 1)
	sim.act("settle", {"region": 0})
	Events.ensure(sim)
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 50000.0, "TEST funds", false)
	for good: String in ["materials", "parts", "food"]:
		sim._produce(sim.settlement(0), good, 400.0, "TEST stock")
	return sim


func _identity() -> void:
	var sim: RefCounted = _colony()
	var home: Dictionary = sim.settlement(0)
	var seen: Dictionary = {}
	var unique: bool = true
	for b: Dictionary in home.buildings:
		unique = unique and int(b.get("uid", 0)) > 0 and not seen.has(int(b.uid))
		seen[int(b.uid)] = true
	check(unique and not home.buildings.is_empty(), "every building has its own uid")
	var before: int = int(sim.state.next_building_uid)
	check(sim.act("build", {"site": 0, "kind": "habitat"}) == "", "a new building is ordered")
	check(
		int(home.buildings.back().uid) == before and int(sim.state.next_building_uid) == before + 1,
		"it takes the next uid"
	)
	check(sim.audit().is_empty(), "the audit accepts the uids")
	# A save from before uids: they are given in list order, after the largest one left.
	var old: Dictionary = sim.state.duplicate(true)
	for b: Dictionary in old.settlements[0].buildings:
		b.erase("uid")
	old.erase("next_building_uid")
	Sim.ensure_systems(old)
	var ordered: bool = true
	for index: int in range(old.settlements[0].buildings.size()):
		ordered = ordered and int(old.settlements[0].buildings[index].uid) == index + 1
	check(ordered, "an old save's buildings get uids in list order")
	check(
		int(old.next_building_uid) == old.settlements[0].buildings.size() + 1,
		"and the counter continues after them"
	)
	check(sim.save_game(SAVE_PATH) == "", "a game with uids saves")
	var copy: RefCounted = Sim.new()
	check(copy.load_game(SAVE_PATH) == "", "and loads")
	check(
		JSON.stringify(copy.settlement(0).buildings) == JSON.stringify(home.buildings),
		"with the same uids"
	)
	check(int(copy.state.schema) == SaveIo.SCHEMA and SaveIo.SCHEMA == 6, "as schema 6")


## The preview's case: a story's pump finishes on time while an older mine is pulled down.
func _unrelated_demolition() -> void:
	var sim: RefCounted = _colony()
	var home: Dictionary = sim.settlement(0)
	check(sim.act("build", {"site": 0, "kind": "mine_ore"}) == "", "an older mine is ordered")
	for _day: int in range(int(sim.config.buildings.mine_ore.days) + 1):
		sim.tick()
	var mine: int = home.buildings.size() - 1
	var inst: Dictionary = Events._open(sim, PROBE_ID, 0)
	check(
		Events.act(sim, {"instance_id": inst.instance_id, "choice": "pump"}) == "",
		"the story orders a pump"
	)
	var pump_uid: int = int(inst.variables.get("building_uid", -1))
	check(pump_uid == int(home.buildings.back().uid), "and follows it by uid")
	check(
		sim.act("demolish", {"region": 0, "index": mine}) == "", "the unrelated mine is pulled down"
	)
	sim.tick()
	check(inst.status == "waiting", "the story still waits for its pump: " + str(inst.ending))
	for _day: int in range(int(sim.config.buildings.water.days) + 2):
		if inst.node == "check":
			break
		sim.tick()
	check(inst.node == "check", "and goes on when the pump runs (%s)" % str(inst.ending))


## Pulling down the story's own pump still ends it.
func _target_demolition() -> void:
	var sim: RefCounted = _colony()
	var home: Dictionary = sim.settlement(0)
	var inst: Dictionary = Events._open(sim, PROBE_ID, 0)
	Events.act(sim, {"instance_id": inst.instance_id, "choice": "pump"})
	var index: int = Production.index_of(home, int(inst.variables.building_uid))
	check(index == home.buildings.size() - 1, "the pump is found by its uid")
	# The newest building is not protected as a settlement's last pump: older ones stand.
	check(
		sim.act("demolish", {"region": 0, "index": index}) == "", "the pump itself is pulled down"
	)
	sim.tick()
	check(
		inst.status == "resolved" and inst.ending == "工程目标失效",
		"the story ends without its target: " + str(inst.ending)
	)


## A story saved before uids followed a list position; on load it follows that building's uid.
func _old_story() -> void:
	var sim: RefCounted = _colony()
	var home: Dictionary = sim.settlement(0)
	var inst: Dictionary = Events._open(sim, PROBE_ID, 0)
	Events.act(sim, {"instance_id": inst.instance_id, "choice": "pump"})
	var old: Dictionary = sim.state.duplicate(true)
	var target: int = home.buildings.size() - 1
	for b: Dictionary in old.settlements[0].buildings:
		b.erase("uid")
	old.erase("next_building_uid")
	var story: Dictionary = old.events_v2.instances.back()
	story.variables.erase("building_uid")
	story.variables.building_index = target
	Sim.ensure_systems(old)
	check(
		(
			not story.variables.has("building_index")
			and int(story.variables.building_uid) == int(old.settlements[0].buildings[target].uid)
		),
		"an old story follows the uid of the building at its saved position"
	)
	check(Events.validate(old) == "", "and passes the save check")


## A topic with a team but no laboratory is blocked, not under way; with one running it progresses.
func _research_states() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(20261029, "capital", 1)
	sim.act("settle", {"region": 0})
	sim._transfer("external", "public", 50000.0, "TEST funds", false)
	var home: Dictionary = sim.settlement(0)
	home.scientists = int(home.scientists) + 4
	home.workers = int(home.workers) - 4
	var tech: String = _open_topic(sim)
	check(sim.act("research_allocate", {"tech": tech, "staff": 3}) == "", "a team is assigned")
	sim.tick()
	var row: Dictionary = _row(sim, tech)
	check(str(row.state) == "blocked", "with no laboratory the topic is blocked: " + str(row.state))
	check(str(row.reason) != "" and int(row.days_left) == -1, "with a reason, and no days left")
	var context: Dictionary = Tutorial.new_context()
	check(
		not Tutorial.check(sim, {"name": "project_staffed"}, context),
		"the tutorial does not count a blocked team as research"
	)
	check(
		Tutorial.note(sim, {"name": "project_staffed"}, context).contains(str(row.reason)),
		"and says why it waits"
	)
	check(sim.act("build", {"site": 0, "kind": "lab"}) == "", "a laboratory is ordered")
	for _day: int in range(int(sim.config.buildings.lab.days) + 2):
		sim.tick()
	row = _row(sim, tech)
	check(str(row.state) == "progressing", "once it runs, the topic progresses: " + str(row.reason))
	check(int(row.days_left) > 0, "with days left (%d)" % int(row.days_left))
	check(Tutorial.check(sim, {"name": "project_staffed"}, context), "and the tutorial counts it")


## A commission's extra points bring the finish closer, on the card's own count.
func _commission_pace() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(20261029, "science", 1)
	sim.act("settle", {"region": 0})
	sim._transfer("external", "public", 200000.0, "TEST funds", false)
	var tech: String = _open_topic(sim)
	sim.act("research_allocate", {"tech": tech, "staff": 6})
	sim.tick()
	var alone: int = Research.days_left(sim, tech)
	check(alone > 0, "a working team has days left (%d)" % alone)
	check(sim.act("research_commission", {"tech": tech, "level": 1}) == "", "a commission is set")
	var helped: int = Research.days_left(sim, tech)
	check(helped > 0 and helped < alone, "and the days left fall: %d -> %d" % [alone, helped])


## A second farm where the first already feeds the town: most of it would stand idle.
func _usable_farm() -> void:
	var sim: RefCounted = _colony()
	var home: Dictionary = sim.settlement(0)
	var first: Dictionary = sim.build_forecast(0, "farm")
	var nominal: float = float(first.outputs.get("food", 0.0))
	check(nominal > 0.0, "a farm has a capacity (%.2f)" % nominal)
	for _farm: int in range(6):
		if sim.act("build", {"site": 0, "kind": "farm"}) != "":
			break
	for b: Dictionary in home.buildings:
		if b.kind == "farm":
			b.remaining = 0
			b.efficiency = 1.0
	var grown: float = 0.0
	for b: Dictionary in home.buildings:
		if b.kind == "farm":
			grown += Production.farm_rate(sim, home, b)
	# Fewer mouths than the farms feed: the town is fed by what stands.
	var people: int = int(home.population)
	home.population = floori(grown / float(sim.config.economy.food_per_person)) - 1
	var need: float = float(home.population) * float(sim.config.economy.food_per_person)
	var next: Dictionary = sim.build_forecast(0, "farm")
	home.population = people
	var usable: float = float(next.usable.get("food", 0.0))
	check(
		grown >= need and usable < float(next.outputs.food) * 0.5,
		(
			"with the town fed (%.1f grown, %.1f eaten) a further farm can use little: %.2f of %.2f"
			% [grown, need, usable, float(next.outputs.food)]
		)
	)
	check(
		is_equal_approx(
			float(next.revenue_per_day),
			usable * float(sim.config.prices.food) * (1.0 + float(sim.config.economy.port_fee))
		),
		"its money counts only the usable part"
	)
	check(
		is_equal_approx(float(next.import_savings_per_day), float(next.revenue_per_day)),
		"as the imports it replaces"
	)
	check(
		float(first.usable.get("food", 0.0)) > float(next.usable.get("food", 0.0)),
		"a first farm in a hungry town can use more"
	)


## The water lesson: waiting for the fault to pass is not fixing it; a new pump that ends the
## shortage is (v110_audit plays the lesson's own fault both ways).
func _water_lesson() -> void:
	for invest: bool in [false, true]:
		var sim: RefCounted = _colony()
		var context: Dictionary = Tutorial.new_context()
		context.shortage_day = int(sim.state.day)
		context.water_built = Tutorial.water_count(sim, 0)
		# This town has water to spare: a harsher fault makes it go short, as the lesson's does.
		var rules: Dictionary = Tutorial.data().shortage
		var factor: float = float(rules.factor)
		rules.factor = 0.01
		sim.act("tutorial_shortage", {"site": 0})
		rules.factor = factor
		if invest:
			sim.act("build", {"site": 0, "kind": "water"})
		for _day: int in range(int(Tutorial.data().shortage.days) + 4):
			sim.tick()
			Tutorial.count_shortage(sim, context)
		var done: bool = Tutorial.check(
			sim, {"name": "shortage_cleared", "shortage": "water"}, context
		)
		var note: String = Tutorial.note(sim, {"name": "shortage_cleared"}, context)
		if invest:
			# This fault is far harsher than the lesson's: the new pump runs at 1% too, so the
			# shortage lasts until the fault passes. That is the filter recovering, not the pump.
			check(
				not done and Tutorial.waited(sim, context) and note.contains("泵站"),
				(
					"a pump that could not end the shortage is not credited, and the note names it: "
					+ note
				)
			)
		else:
			check(not done and Tutorial.waited(sim, context), "waiting it out does not complete it")
			check(
				note.contains("自己恢复") and note.contains("¥") and int(context.short_days) > 0,
				(
					"and the note says what waiting cost (%d days): %s"
					% [int(context.short_days), note]
				)
			)


## Events with several towns that qualify: drawn first, then spread by kind of work and recency.
func _event_towns() -> void:
	var sim: RefCounted = _colony()
	# People enough at the capital for two expeditions.
	sim.settlement(0).workers = int(sim.settlement(0).workers) + 30
	sim.settlement(0).population = int(sim.settlement(0).population) + 30
	var places: Array = [0]
	for region: int in range(1, sim.state.world.regions.size()):
		if places.size() >= 3:
			break
		sim.state.contract.licences.append("expedition")
		sim.state.contract.licences.append("third_settlement")
		if sim.act("settle", {"site": region, "from": 0}) == "":
			places.append(region)
	check(places.size() == 3, "three towns stand (%s)" % str(places))
	var counts: Dictionary = {}
	for _draw: int in range(300):
		var town: int = Events._choose_town(sim, PROBE_ID, places)
		counts[town] = int(counts.get(town, 0)) + 1
	check(
		int(counts.get(places[0], 0)) < 200 and counts.size() == 3,
		"the oldest town no longer gets them all: %s" % str(counts)
	)
	Events._open(sim, PROBE_ID, places[1])
	var after: Dictionary = {}
	for _draw: int in range(300):
		var town: int = Events._choose_town(sim, PROBE_ID, places)
		after[town] = int(after.get(town, 0)) + 1
	check(
		int(after.get(places[1], 0)) < int(counts.get(places[1], 0)),
		"a town that just had one is drawn less: %s" % str(after)
	)
	var option: Dictionary = {"next": "check", "investigate": 3, "work": 12.0}
	var inst: Dictionary = Events._open(sim, PROBE_ID, 0)
	check(
		Events._course(inst, option).contains("12 日后回报"),
		"a team sent out says when it reports back: " + Events._course(inst, option)
	)


## The interface: the menu shows the tutorial's own planet, and a panel keeps the part of a day.
func _interface() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var lesson: Dictionary = Tutorial.data()
	scene.tutorial_on = true
	scene.show_menu()
	await process_frame
	check(scene.seed_edit.text == str(int(lesson.seed)), "the menu shows the tutorial's seed")
	check(
		(
			scene.difficulty_option.selected == scene.DIFFICULTIES.find(str(lesson.difficulty))
			and is_equal_approx(
				scene.radius_slider.value, scene.RadiusSlider.of_size(int(lesson.size))
			)
		),
		"and its size and difficulty"
	)
	scene.tutorial_on = false
	scene.seed_edit.text = "260129"
	scene.start_game()
	await process_frame
	scene.close_modal()
	scene.menu_open = false
	scene.sim.act("settle", {"site": int(scene.sim.geo.playability.pairs[0][0])})
	scene.sim.state.events_v2.next_draw = 99999
	scene.paused = false
	scene.speed = 1
	var per_day: float = float(scene.sim.progression.time.seconds_per_day)
	var day: int = int(scene.sim.state.day)
	scene.advance_time(per_day * 0.8)
	check(int(scene.sim.state.day) == day, "most of a day has run")
	scene.open_page("economy")
	check(is_equal_approx(scene.accumulator, per_day * 0.8), "opening a panel keeps it")
	scene.close_modal()
	scene.set_speed(1)
	scene.advance_time(per_day * 0.25)
	check(int(scene.sim.state.day) == day + 1, "and the day ends a quarter of a day later")
	root.remove_child(scene)
	scene.free()


func _open_topic(sim: RefCounted) -> String:
	for category: String in sim.state.research.offers:
		for tech: String in sim.state.research.offers[category]:
			if sim.config.techs[tech].requires.is_empty():
				return tech
	return ""


func _row(sim: RefCounted, tech: String) -> Dictionary:
	for row: Dictionary in Research.tree(sim):
		if str(row.id) == tech:
			return row
	return {}


## The town says what holds its growth back: no free beds, then too many out of work.
func _growth_limits() -> void:
	var sim: RefCounted = _colony()
	var home: Dictionary = sim.settlement(0)
	home.population = int(home.housing)
	var full: Dictionary = PeopleLines.limit(sim, home, sim.population_view(0))
	check(
		str(full.key) == "housing" and str(full.remedy).contains("床"), "a full town names housing"
	)
	home.population = int(home.housing) - 20
	home.employed = 0
	var idle: Dictionary = PeopleLines.limit(sim, home, sim.population_view(0))
	check(str(idle.key) == "jobs", "a town with beds but no jobs names jobs: " + str(idle.text))
