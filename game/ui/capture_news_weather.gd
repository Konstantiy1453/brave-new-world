extends RefCounted
## Developer capture for 1.11 F and I, from the source project in a real window: a new colony
## with a cyclone on its way (the storm notice, the ring on the globe, the news line at the bottom),
## the weather page, and the force majeure clause on the contract page.
##   xvfb-run -a godot --path game --rendering-driver opengl3 -- --dev
##         --dev-script=res://ui/capture_news_weather.gd [--qa-out=<folder>]

const Weather = preload("res://simulation/weather.gd")
const SEED: int = 20261123


static func run(g) -> void:
	var folder: String = _option("--qa-out=")
	if folder == "":
		folder = ProjectSettings.globalize_path("res://../evidence/v17/news_weather")
	DirAccess.make_dir_recursive_absolute(folder)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	g._begin_world(SEED, "capital", 1, "normal")
	g.menu_open = false
	g._hide_overlay()
	for reg: Dictionary in g.sim.state.world.regions:
		if g.sim.settle_refusal(int(reg.id)) == "":
			g.sim.act("settle", {"region": int(reg.id)})
			break
	g.sim.state.settlements[0].name = "望港"
	g.sim.state.events_v2.next_draw = 99999
	var town: Dictionary = g.sim.state.settlements[0]
	var here: Vector2 = Weather.town_point(g.sim, town)
	(
		g
		. sim
		. state
		. weather
		. systems
		. append(
			{
				"id": int(g.sim.state.weather.next_id),
				"kind": "cyclone",
				"lat": here.x - 9.0,
				"lon": here.y + 3.0,
				"born": [here.x - 9.0, here.y + 3.0],
				"heading": 340.0,
				"speed": 1.4,
				"radius": 4.0,
				"age": 6,
				"life": 16,
				"warned": {},
				"struck": {},
				"prepared": {},
			}
		)
	)
	g.sim.state.weather.next_id = int(g.sim.state.weather.next_id) + 1
	for _day: int in range(2):
		g.sim.tick()
	g.selected = int(town.region)
	g.map.sync_state(g.sim.state)
	g.map.focus_region(g.selected)
	g.refresh()
	g.paused = true
	for _frame: int in range(30):
		await g.get_tree().process_frame
	await _save(g, folder, "globe_storm_news")
	print("NEWS_WEATHER_STORMS %s radii %s" % [g.map.sky.storm_vectors(), g.map.sky.storm_radii()])
	for entry: Dictionary in g.map.weather_markers:
		var ring: MeshInstance3D = entry.node
		var warned: bool = not entry.system.warned.is_empty()
		print(
			(
				"NEWS_WEATHER_RING %s warned=%s colour=%s visible=%s"
				% [ring.name, warned, ring.material_override.albedo_color.to_html(), ring.visible]
			)
		)
	g.open_page("weather")
	await _save(g, folder, "weather_page")
	g.open_page("contract")
	await g.get_tree().process_frame
	var link: Button = _find_button(g.modal_box, "不可抗力申请")
	print("NEWS_WEATHER_LINK found=%s" % (link != null))
	if link != null:
		var parent: Node = link.get_parent()
		while parent != null and not parent is ScrollContainer:
			parent = parent.get_parent()
		if parent != null:
			await g.get_tree().process_frame
			(parent as ScrollContainer).ensure_control_visible(link)
	await _save(g, folder, "contract_force_majeure")
	g.close_modal()
	print("NEWS_WEATHER_CAPTURE done line=%s" % str(g.news.line.get("text", "")))
	g.get_tree().quit()


static func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text.contains(text):
		return node
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


static func _save(g, folder: String, name: String) -> void:
	for _frame: int in range(6):
		await g.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var file: String = folder.path_join(name + ".png")
	g.get_viewport().get_texture().get_image().save_png(file)
	print("NEWS_WEATHER_CAPTURE ", file)


static func _option(prefix: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return ""
