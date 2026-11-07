extends RefCounted
## Developer capture of the 1.9 money interface: the public services budget on the population page,
## the copy surcharge in the build list and the cash cover, administration and market floor lines
## on the economy page, after a balanced colony has grown for two years.
##   godot --path game -- --dev --dev-script=res://tests/art/capture_pages_v19.gd

const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const OUT: String = "res://../evidence/v17/art/pages"
const SEED: int = 260129
const DAYS: int = 700


static func run(g) -> void:
	g.sim.new_game(SEED, "capital", 1, "normal")
	var bot: RefCounted = Bot.new()
	bot.begin(g.sim, SEED)
	for _day: int in range(DAYS):
		bot.on_day()
		g.sim.tick()
	g.coach.stop(false)
	g.selected = int(g.sim.state.settlements[0].region)
	g.map.setup(g.sim.geo)
	g.map.focus_region(g.selected)
	g.map.sync_state(g.sim.state)
	g.close_modal()
	g.menu_open = false
	g.paused = true
	g.refresh()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for page: String in ["population", "build", "economy"]:
		g.open_page(page)
		await _capture(g, page)
	# The market rows sit below the fold of the economy page.
	var scroll: ScrollContainer = g.find_child("Page_economy", true, false) as ScrollContainer
	if scroll != null:
		var box: Control = scroll.get_child(0) as Control
		for node: Node in scroll.find_children("*", "Label", true, false):
			var label: Label = node as Label
			if label.text.begins_with("出口价格"):
				scroll.scroll_vertical = int(label.global_position.y - box.global_position.y)
				break
		await _capture(g, "economy_market")
	g.get_tree().quit(0)


static func _capture(g, name: String) -> void:
	for _frame: int in range(6):
		await g.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUT + "/" + name + ".png")
	g.get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE_PAGE ", path)
