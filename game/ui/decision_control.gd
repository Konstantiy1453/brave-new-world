extends RefCounted
## The colony-wide decision controls (1.11), for the main scene `g`: the clock row with "advance to
## the next decision", the run it starts (the normal simulation, a few days a frame, until the chosen
## milestone or a decision the player could otherwise miss: simulation/advance.gd), the live refresh
## of an open page, and a contract goal's action opening a town that can carry it out.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
const Advance = preload("res://simulation/advance.gd")

const DAYS_PER_FRAME: int = 8
const AUTOSAVE_FALLBACK_DAYS: int = 90
const OWN_PAGES: Array[String] = [
	"research", "transport", "economy", "contract", "population", "company"
]


## The speed buttons, then "advance to the next decision" with where it should stop.
static func build_clock_controls(g, controls: Control) -> void:
	var time_rules: Dictionary = g.sim.progression.time
	for item: Array in [
		["暂停", 0],
		["1×", 1],
		["%d×" % int(time_rules.fast_multiplier), int(time_rules.fast_multiplier)],
		["%d×" % int(time_rules.very_fast_multiplier), int(time_rules.very_fast_multiplier)],
	]:
		var val: int = int(item[1])
		var b: Button = D.button(
			controls,
			str(item[0]),
			func(): g.set_speed(val),
			"空格暂停 / 恢复；每天固定步进",
			"Speed_" + str(val)
		)
		b.custom_minimum_size = Vector2(54, 32)
		b.add_theme_font_size_override("font_size", 15)
	var ahead: Button = D.button(
		controls,
		"⏩ 下一个决定",
		func(): start(g),
		"照常运行模拟，到选定的时刻，或在你可能错过一个决定之前停下；途中的日常消息汇总给你看",
		"AdvanceNext"
	)
	ahead.custom_minimum_size = Vector2(118, 32)
	ahead.add_theme_font_size_override("font_size", 15)
	var names: Array = []
	for key: String in Advance.MILESTONES:
		names.append(str(Advance.NAMES[key]))
	var pick: OptionButton = D.option(
		controls,
		"AdvanceMilestone",
		names,
		Advance.MILESTONES.find(g.advance_milestone),
		func(index: int): g.advance_milestone = Advance.MILESTONES[index]
	)
	pick.add_theme_font_size_override("font_size", 14)
	pick.tooltip_text = "停在哪里：无论选哪项，遇到需要你决定的事都会先停"


## Starts a run towards `milestone` (the chosen one when empty).
static func start(g, milestone: String = "") -> void:
	var sim: RefCounted = g.sim
	if sim.state.is_empty() or sim.state.status in ["planning", "failed"]:
		g.toast("先建立首府")
		return
	if g.event_pause_required():
		g.open_page("events")
		g.toast("先答复等待中的通讯")
		return
	if is_instance_valid(g.overlay):
		g.close_modal()
	g.paused = true
	g.resume_on_close = false
	g.advance_run = Advance.begin(sim, milestone if milestone != "" else g.advance_milestone)
	g.advance_run.lines = []
	g.date_label.text = "%s · 正在推进…" % Labels.date(int(sim.state.day))


## A few days of the run each frame; stops with a summary when the run says so.
static func step(g) -> void:
	var sim: RefCounted = g.sim
	var reason: String = ""
	for _i: int in range(DAYS_PER_FRAME):
		var before: int = sim.state.log.size()
		sim.tick()
		for entry: Dictionary in sim.state.log.slice(maxi(0, before - 1)):
			if int(entry.day) == int(sim.state.day):
				g.advance_run.lines.append("%d · %s" % [int(entry.day), str(entry.text)])
		var every: int = int(sim.progression.time.get("autosave_days", AUTOSAVE_FALLBACK_DAYS))
		if int(sim.state.day) % maxi(1, every) == 0 and int(sim.state.day) != int(g.autosave_day):
			g._begin_autosave()
			g.autosave_day = sim.state.day
		g.coach.on_day()
		reason = Advance.stop_reason(sim, g.advance_run)
		if reason != "":
			break
	g.map.sync_state(sim.state)
	g.refresh()
	if reason != "":
		finish(g, reason)


static func finish(g, reason: String) -> void:
	var lines: Array = g.advance_run.get("lines", [])
	g.advance_summary = Advance.summary(g.sim, g.advance_run, reason)
	g.advance_summary.lines = lines
	g.advance_run = {}
	g.paused = true
	g.last_status = g.sim.state.status
	g._announce_new_event()
	g.open_page("advance")


## With panels not pausing the game (a setting), an open page follows the days as they pass:
## deadlines, research progress and which actions are open. Not while the player types in it.
static func refresh_open_page(g) -> void:
	if not is_instance_valid(g.overlay) or g.current_page.is_empty() or g.panel_pause:
		return
	var focus: Control = g.get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	g.populate_current_page()


## A contract goal's action: opens a town that can carry it out, on the page and part that do it.
## One town that qualifies is opened at once (the capital when it is the only one, even after
## inspecting empty ground); several give a short choice with why each qualifies.
static func goal_action(g, action: Dictionary) -> void:
	var sim: RefCounted = g.sim
	var need: String = str(action.get("need", ""))
	var page: String = str(action.get("page", ""))
	if page in OWN_PAGES and need == "":
		g.open_page(page)
		return
	if need == "settlement":
		g.close_modal()
		g.toast("在地图上点一块地，看地点卡；推荐地点也可以")
		return
	var towns: Array = sim.Outlook.candidates(sim, need if need != "" else "any")
	if towns.is_empty() and sim.state.settlements.size() == 1:
		towns = [{"region": int(sim.state.settlements[0].region), "category": ""}]
	if towns.is_empty():
		g.toast("现在没有能做这件事的据点：" + str(action.get("text", "")))
		return
	if towns.size() == 1:
		open_for(g, int(towns[0].region), action, str(towns[0].get("category", "")))
		return
	g.goal_choice = {"action": action, "towns": towns}
	g.open_page("goal_choice")


## Opens a town for an action: the ground selection gives way to the town, then the page, on the
## part of it that fits this town's way of doing it.
static func open_for(g, region: int, action: Dictionary, category: String = "") -> void:
	if not g.ground.is_empty():
		g.ground = {}
		g.map.set_ground({})
	g.selected = region
	g.map.selected_region = region
	g.map.focus_region(region)
	g.refresh_sidebar()
	if category != "":
		g.build_category = category
	elif action.has("category"):
		g.build_category = str(action.category)
	if action.has("kind"):
		g.build_selected = str(action.kind)
	var page: String = str(action.get("page", "build"))
	g.open_page(page if page != "" else "build")
