extends RefCounted
## Developer capture for 1.11 G, from the source project in a real window: the night time-lapse
## over a made-up eight-year record (a capital growing from a landing to 2,500 people, two towns
## founded later and joined to it by road), three frames along the way, in the forms of the
## user's concept sheet (world/town_forms.gd).
##   xvfb-run -a godot --path game --rendering-driver opengl3 -- --dev
##         --dev-script=res://ui/capture_timelapse.gd [--qa-out=<folder>]

const TimelapseView = preload("res://ui/timelapse_view.gd")
const SEED: int = 20261123
const YEARS: int = 8


static func run(g) -> void:
	var folder: String = _option("--qa-out=")
	if folder == "":
		folder = ProjectSettings.globalize_path("res://../evidence/v17/lights")
	DirAccess.make_dir_recursive_absolute(folder)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	g._begin_world(SEED, "capital", 1, "normal")
	g.menu_open = false
	g._hide_overlay()
	for reg: Dictionary in g.sim.state.world.regions:
		if g.sim.settle_refusal(int(reg.id)) == "":
			g.sim.act("settle", {"region": int(reg.id)})
			break
	g.sim.state.lights.snapshots = _record(g)
	g.map.sync_state(g.sim.state)
	g.refresh()
	g.sim.progression.lights.timelapse_seconds = 12.0
	TimelapseView.play(g, func(): print("TIMELAPSE_CAPTURE ended"))
	for at: Array in [
		[1.5, "timelapse_year1"], [6.5, "timelapse_year4"], [12.2, "timelapse_year8"]
	]:
		while g.map.timelapse_progress() >= 0.0 and _seconds(g) < float(at[0]):
			await g.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var file: String = folder.path_join(str(at[1]) + ".png")
		g.get_viewport().get_texture().get_image().save_png(file)
		print("TIMELAPSE_CAPTURE ", file, " day=", g.map.timelapse_day())
	g.get_tree().quit()


static func _seconds(g) -> float:
	return float(g.map.timelapse.get("elapsed", 999.0))


## A capital that grows every quarter, a second town from year three and a third from year five,
## each a little way off along the coast.
static func _record(g) -> Array:
	var capital: Dictionary = g.sim.state.settlements[0]
	var reg: Dictionary = g.sim.state.world.regions[int(capital.region)]
	var lat: float = float(capital.get("lat", reg.lat))
	var lon: float = float(capital.get("lon", reg.lon))
	var home: int = int(capital.region)
	var coastal: bool = bool(reg.get("coast", false))
	var out: Array = []
	for quarter: int in range(YEARS * 4 + 1):
		var t: float = float(quarter) / float(YEARS * 4)
		var capital_town: Dictionary = _town(
			home, lat, lon, 40.0 + 2460.0 * t * t, 3.0 + 50.0 * t, coastal
		)
		var towns: Array = [capital_town]
		if quarter >= 8:
			var u: float = float(quarter - 8) / float(YEARS * 4 - 8)
			towns.append(
				_town(9001, lat + 3.5, lon + 4.0, 30.0 + 700.0 * u, 2.0 + 18.0 * u, false, [home])
			)
			capital_town.roads.append(9001)
		if quarter >= 16:
			var v: float = float(quarter - 16) / float(YEARS * 4 - 16)
			towns.append(
				_town(9002, lat - 2.5, lon + 6.5, 20.0 + 300.0 * v, 1.0 + 9.0 * v, false, [home])
			)
			capital_town.roads.append(9002)
		out.append({"day": quarter * 90, "towns": towns})
	return out


static func _town(
	region: int,
	lat: float,
	lon: float,
	people: float,
	built: float,
	coastal: bool,
	roads: Array = []
) -> Dictionary:
	return {
		"region": region,
		"lat": lat,
		"lon": lon,
		"stage": 0,
		"population": int(people),
		"facilities": int(built),
		"coastal": coastal,
		"frontier": false,
		"roads": roads.duplicate(),
	}


static func _option(prefix: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return ""
