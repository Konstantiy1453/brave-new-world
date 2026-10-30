extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Geo = preload("res://world/world_gen.gd")
const Map = preload("res://world/map_view.gd")
var failures: Array = []
var report: Dictionary = {
	"scope": "headless handler and frame-yield timings, not OS click latency", "samples": []
}


func check(value: bool, message: String):
	if not value:
		failures.append(message)


func _initialize():
	Watchdog.arm(self)
	call_deferred("run")


func enter(map, id: int, label: String):
	var start: int = Time.get_ticks_usec()
	var old_builds: int = map.region_build_count
	map.show_region(id)
	var feedback: float = (Time.get_ticks_usec() - start) / 1000.0
	var frames: int = 0
	while map.region_busy:
		await process_frame
		frames += 1
	report.samples.append(
		{
			"operation": label,
			"handler_ms": feedback,
			"completion_ms": (Time.get_ticks_usec() - start) / 1000.0,
			"frames": frames,
			"builds": map.region_build_count - old_builds,
			"cache_size": map.region_cache.size(),
			"unique_samples": map.terrain_unique_samples,
			"map_setup_ms": map.last_setup_ms
		}
	)


func run():
	var map = Map.new()
	root.add_child(map)
	map.set_process(false)  # prevent full atlas workers during isolated region timings
	var world: Dictionary = Geo.new().generate(260129)
	map.setup(world)
	map.sync_state(
		{
			"world": world,
			"day": 5,
			"settlements":
			[
				{
					"region": 0,
					"base_housing": 20,
					"buildings": [{"kind": "solar", "active": true, "remaining": 0}]
				}
			],
			"route": {}
		}
	)
	await enter(map, 0, "region_0_cold")
	check(map.terrain_unique_samples == 7569, "terrain samples each unique point once")
	var terrain = map.surface.get_child(0)
	var buildings = map.buildings_root
	await enter(map, 0, "region_0_repeat")
	check(map.surface.get_child(0) == terrain, "repeat keeps terrain identity")
	check(map.buildings_root == buildings, "unchanged buildings reused")
	map.show_planet()
	map.state.settlements[0].buildings[0].active = false
	map.state.settlements[0].buildings.append({"kind": "farm", "active": true, "remaining": 3})
	await enter(map, 0, "region_0_return_buildings_changed")
	check(map.surface.get_child(0) == terrain, "return keeps terrain")
	check(map.buildings_root != buildings, "return refreshes changed buildings")
	check(map.signature == map._building_signature(), "dynamic signature current")
	map.state.route = Geo.new().route(world, 0, 1, false)
	map.state.route.blocked_until = 5
	for day in [4, 5, 6]:
		map.state.day = day
		map.sync_state(map.state)
		var stopped: bool = false
		for label in map.buildings_root.find_children("*", "Label3D", true, false):
			if label.text.begins_with("停运"):
				stopped = true
		check(stopped == (day <= 5), "regional road label cutoff " + str(day))
		var sphere_color: Color = (
			map.transport_root.get_child(0).mesh.surface_get_material(0).albedo_color
		)
		var flat_color: Color = (
			map.flat_transport_root.get_child(0).mesh.surface_get_material(0).albedo_color
		)
		check((sphere_color == Color("d77963")) == (day <= 5), "sphere road cutoff " + str(day))
		check((flat_color == Color("d77963")) == (day <= 5), "flat road cutoff " + str(day))
	await enter(map, 1, "region_1_cold")
	await enter(map, 0, "region_0_return_after_other")
	check(map.surface.get_child(0) == terrain, "other region does not replace cached terrain")
	map.show_region(2)
	check(map.region_busy, "cold region reports busy immediately")
	map.show_flat()
	await process_frame
	check(
		not map.region_busy and map.mode == "flat" and not map.region_cache.has(2),
		"navigation cancels cold build"
	)
	await enter(map, 2, "region_2_cold")
	await enter(map, 3, "region_3_cold")
	check(map.region_cache.size() == Map.REGION_CACHE_LIMIT, "bounded region cache")
	map.setup(Geo.new().generate(42))
	check(
		map.selected_region == 0 and map.region_cache.is_empty(),
		"new world resets selection and cache"
	)
	map.show_region(5)
	await process_frame
	map.setup(world)
	await process_frame
	check(
		not map.region_busy and map.selected_region == 0 and map.region_cache.is_empty(),
		"world change cancels in-flight build"
	)
	for day in [4, 5, 6]:
		check(
			Geo.road_blocked({"blocked_until": 5}, day) == (day <= 5), "road inclusive " + str(day)
		)
	report.failures = failures
	report.engine = Engine.get_version_info()
	report.cpu = OS.get_processor_name()
	FileAccess.open("res://../evidence/v17/tests/world_region.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	print("WORLD_V16_REGION ", JSON.stringify(report))
	map.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
