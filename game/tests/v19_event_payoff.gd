extends SceneTree
## 1.9 event payoffs (docs/v17/EVENTS_DIAGNOSIS.md, steps 1-4), on a probe event added to the
## loaded definitions, since the data that uses the new keys comes later: a node marked critical
## pauses even in a notice; an ending keeps its scene (`outcome`), or else what changed in words,
## and says when the default applied by itself; the interface shows a card for each new ending and
## none for a loaded game's old ones, and the events page keeps the scene; effects keep their label;
## all of it survives a save. An ending can raise a landmark: it stands once, its effects last,
## the town panel and the economy page list what acts where, the maps mark a place while an event
## is open there, and the town view draws it.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Events = preload("res://simulation/events_v2.gd")
const Sim = preload("res://simulation/sim.gd")
const PROBE_ID: String = "v19_payoff_probe"
const SCENE: String = "工程队在孔口浇了最后一圈混凝土，测绘站的墙上从此多了一张星图的复印件。"
const SAVE_PATH: String = "user://v19_event_payoff.save"
const MARK_ID: String = "probe_station"
const MARK_NAME: String = "探针观测站"

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


## Never drawn (code only), a notice whose first node is marked critical.
func _probe() -> Dictionary:
	return {
		"version": 1,
		"type": "short",
		"category": "opportunity",
		"kind": "notice",
		"critical": false,
		"cooldown_days": 999,
		"weight": 0,
		"chance": 0.0,
		"conditions": {"trigger_only": true},
		"nodes":
		{
			"start":
			{
				"title": "终章探针",
				"critical": true,
				"text": "这是一个只供测试使用的事件节点，用来检查结局场景、节点暂停和效果名称。",
				"deadline_days": 10,
				"default": "plain",
				"choices":
				[
					{
						"id": "scene",
						"label": "有结局场景",
						"ending": "封存星图",
						"pay": 300,
						"outcome": SCENE,
						"effects":
						[{"kind": "mine", "factor": 0.9, "duration_days": 30, "label": "测试限速"}]
					},
					{
						"id": "plain",
						"label": "没有结局文字",
						"ending": "朴素结局",
						"effects": [{"kind": "farm", "factor": 1.1, "duration_days": 20}]
					},
					{
						"id": "station",
						"label": "建起观测站",
						"ending": "观测站落成",
						"outcome": "观测站的灯亮起来以后，夜班的人说终于有了一个可以指路的地方。",
						"landmark":
						{
							"id": MARK_ID,
							"name": MARK_NAME,
							"kind": "station",
							"text": "孔口上方的小观测站，夜里那盏灯一直亮着。",
							"effects":
							[{"kind": "mine", "factor": 1.1}, {"kind": "research", "factor": 1.12}]
						}
					}
				]
			},
			"calm":
			{
				"title": "平静节点",
				"text": "这个节点没有标记为关键，作为通知不应暂停世界，只用于对照检查。",
				"deadline_days": 10,
				"default": "close",
				"choices": [{"id": "close", "label": "结束", "ending": "平静结束"}]
			}
		}
	}


func run() -> void:
	Events.definitions().definitions[PROBE_ID] = _probe()
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var sim: RefCounted = scene.sim
	var pairs: Array = sim.geo.get("playability", {}).get("pairs", [[0, 1]])
	var site: int = int(pairs[0][0])
	check(sim.act("settle", {"site": site}) == "", "the colony lands")
	Events.ensure(sim)
	scene._watch_events()
	_pausing(sim, site)
	_gift_words()
	await _scenes(scene, sim, site)
	await _page(scene)
	await _landmarks(scene, sim, site)
	await _loaded_game(scene, sim)
	root.remove_child(scene)
	scene.free()
	Events.definitions().definitions.erase(PROBE_ID)
	print(
		(
			"V19_EVENT_PAYOFF_RESULT checks=%d failures=%d %s"
			% [checks, failures.size(), str(failures)]
		)
	)
	quit(0 if failures.is_empty() else 1)


## A gift whose effects have no short name on a card reads from its own description.
func _gift_words() -> void:
	var text: String = Events._effect_text(
		{
			"effects": {"research_speed": 0.15, "crystal_output": 0.1},
			"description": "事件赠予，无法研究。地层相位学：科研速度 +15%，晶体产量 +10%。"
		}
	)
	check(text == "地层相位学：科研速度 +15%，晶体产量 +10%。", "a new gift's effects read in words: " + text)
	check(
		Events._effect_text({"effects": {"sea_speed": 0.25}}) == "航程时间 -25%",
		"the named ones still read as before"
	)


func _pausing(sim: RefCounted, site: int) -> void:
	var inst: Dictionary = Events._open(sim, PROBE_ID, site)
	check(inst.pause_required, "a node marked critical pauses, even in a notice")
	check(Events.pause_required(sim), "and the game knows it must wait")
	Events._enter(sim, inst, "calm")
	check(not inst.pause_required, "a notice's other nodes do not pause")
	Events.act(sim, {"instance_id": inst.instance_id, "choice": "close"})


func _scenes(scene: Node, sim: RefCounted, site: int) -> void:
	var before: int = scene.notices.get_child_count()
	var inst: Dictionary = Events._open(sim, PROBE_ID, site)
	check(
		Events.act(sim, {"instance_id": inst.instance_id, "choice": "scene"}) == "",
		"the ending with a scene can be chosen"
	)
	var row: Dictionary = sim.state.events_v2.history.back()
	check(str(row.get("outcome", "")) == SCENE, "the ending keeps its scene")
	check(str(row.get("changes", "")).contains("支出"), "and what changed, in words")
	check(row.get("automatic", true) == false, "chosen by the player, not by the deadline")
	check(str(inst.history.back().get("outcome", "")) == SCENE, "the event's own record has it too")
	var effect: Dictionary = sim.state.events_v2.effects.back()
	check(str(effect.get("label", "")) == "测试限速", "the effect keeps its label")
	scene._watch_events()
	await process_frame
	check(scene.notices.get_child_count() == before + 1, "a new ending raises a card")
	var card: Node = scene.notices.get_child(scene.notices.get_child_count() - 1)
	var text: String = ""
	for label: Label in card.find_children("*", "Label", true, false):
		text += label.text
	check(text.contains(SCENE) and text.contains("封存星图"), "the card tells the ending and its scene")
	check(text.contains("终章探针"), "under the event's title")
	scene._watch_events()
	check(scene.notices.get_child_count() == before + 1, "only once")
	var timed: Dictionary = Events._open(sim, PROBE_ID, site)
	Events.act(sim, {"instance_id": timed.instance_id, "choice": "defer"})
	for _day: int in range(12):
		sim.tick()
	var late: Dictionary = sim.state.events_v2.history.back()
	check(
		str(late.get("ending", "")) == "朴素结局" and late.get("automatic", false) == true,
		"a default applied at the deadline says so"
	)
	check(
		not late.has("outcome") and str(late.get("changes", "")).contains("农产"),
		"an ending without a scene keeps what changed"
	)
	scene._watch_events()
	await process_frame
	var newest: Node = scene.notices.get_child(scene.notices.get_child_count() - 1)
	var words: String = ""
	for label: Label in newest.find_children("*", "Label", true, false):
		words += label.text
	check(
		words.contains("到期按默认处理") and words.contains("农产"),
		"its card says the default applied, and what changed"
	)
	check(Events.validate(sim.state) == "", "the new fields pass the save check")
	check(sim.save_game(SAVE_PATH) == "", "a game with scenes saves")
	var copy: RefCounted = Sim.new()
	check(copy.load_game(SAVE_PATH) == "", "and loads")
	var restored: Array = copy.state.events_v2.history
	var labelled: bool = false
	for kept: Dictionary in copy.state.events_v2.effects:
		labelled = labelled or str(kept.get("label", "")) == "测试限速"
	check(
		(
			restored.size() >= 2
			and str(restored[restored.size() - 2].get("outcome", "")) == SCENE
			and labelled
		),
		"with the scenes and labels it had"
	)


func _page(scene: Node) -> void:
	scene.open_page("events")
	await process_frame
	var found: bool = false
	for label: Label in scene.modal_box.find_children("*", "Label", true, false):
		if label.text.contains(SCENE):
			found = true
	check(found, "the events page keeps the scene under its ending")
	scene.close_modal()


func _landmarks(scene: Node, sim: RefCounted, site: int) -> void:
	var inst: Dictionary = Events._open(sim, PROBE_ID, site)
	scene.map.sync_state(sim.state)
	scene.map._update_markers()
	check(
		_names(scene.map).contains(scene.map.EVENT_MARK), "the map marks a place with an open event"
	)
	var before: float = Events.modifier(sim, site, "mine")
	check(
		Events.act(sim, {"instance_id": inst.instance_id, "choice": "station"}) == "",
		"an ending can raise a landmark"
	)
	# Effects begin the day after the choice.
	sim.tick()
	var marks: Array[Dictionary] = Events.landmarks_at(sim, site)
	check(marks.size() == 1 and str(marks[0].name) == MARK_NAME, "the landmark stands at its place")
	var lasting: int = 0
	for effect: Dictionary in sim.state.events_v2.effects:
		if str(effect.source) == "landmark:" + MARK_ID and int(effect.until) == -1:
			lasting += 1
	check(lasting == 2, "its effects last (%d)" % lasting)
	check(
		is_equal_approx(Events.modifier(sim, site, "mine"), before * 1.1),
		"and act there: mining ×%.2f, was ×%.2f" % [Events.modifier(sim, site, "mine"), before]
	)
	check(
		str(sim.state.events_v2.history.back().get("changes", "")).contains(MARK_NAME),
		"the ending says what it left"
	)
	var again: Dictionary = Events._open(sim, PROBE_ID, site)
	Events.act(sim, {"instance_id": again.instance_id, "choice": "station"})
	check(Events.landmarks_at(sim, site).size() == 1, "a landmark stands only once")
	var here: Array[Dictionary] = Events.place_effects(sim, site)
	var named: bool = false
	var colony: bool = false
	for effect: Dictionary in here:
		named = named or (str(effect.name) == MARK_NAME and int(effect.days_left) == -1)
		colony = colony or (bool(effect.colony) and str(effect.what) == "科研速度")
	check(named and colony, "the place lists its own effects and the colony-wide ones")
	var everywhere: Array[Dictionary] = Events.colony_effects(sim)
	check(not everywhere.is_empty() and str(everywhere[0].get("place", "")) != "", "with places")
	scene.map.sync_state(sim.state)
	scene.map._update_markers()
	check(not _names(scene.map).contains(scene.map.EVENT_MARK), "the mark goes when the event ends")
	scene.selected = site
	scene.refresh_sidebar()
	await process_frame
	var panel: String = _texts(scene.sidebar)
	check(panel.contains("地标") and panel.contains(MARK_NAME), "the town panel lists the landmark")
	check(
		panel.contains("事件影响") and panel.contains(MARK_NAME + " · 采矿 ×1.10 · 长期"),
		"and the effects acting there"
	)
	scene.open_page("economy")
	await process_frame
	check(_texts(scene.modal_box).contains("仍生效的事件影响"), "the economy page lists them too")
	scene.close_modal()
	scene.map.show_region(site)
	while scene.map.region_busy:
		await process_frame
	scene.map.sync_state(sim.state)
	var drawn: Node = scene.map.buildings_root.find_child("Landmark_" + MARK_ID, true, false)
	check(drawn != null, "the town view draws the landmark")
	check(Events.validate(sim.state) == "", "landmarks pass the save check")
	check(sim.save_game(SAVE_PATH) == "", "a game with a landmark saves")
	var copy: RefCounted = Sim.new()
	check(
		copy.load_game(SAVE_PATH) == "" and Events.landmarks_at(copy, site).size() == 1,
		"and loads with it"
	)


func _names(map: Node3D) -> String:
	var text: String = ""
	for label: Label3D in map.marker_root.find_children("*", "Label3D", true, false):
		text += label.text + "|"
	return text


func _texts(root: Node) -> String:
	var text: String = ""
	for label: Label in root.find_children("*", "Label", true, false):
		text += label.text + "|"
	return text


func _loaded_game(scene: Node, sim: RefCounted) -> void:
	var before: int = scene.notices.get_child_count()
	var state: Dictionary = sim.state.duplicate(true)
	sim.state = state
	scene._watch_events()
	await process_frame
	check(
		scene.notices.get_child_count() == before, "a loaded game raises no cards for old endings"
	)
