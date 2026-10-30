extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Geo = preload("res://world/world_gen.gd")
const Map = preload("res://world/map_view.gd")
var failures: Array = []
var probe_seed: int = 260129
var suffix: String = ""


func _initialize():
	Watchdog.arm(self)
	call_deferred("run")


func check(ok: bool, label: String):
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)


func shot(name: String):
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(
		"res://../evidence/v17/tests/evidence_" + name + suffix + ".png"
	)


func run():
	root.size = Vector2i(1600, 900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			probe_seed = int(arg.trim_prefix("--seed="))
	if probe_seed != 260129:
		suffix = "_" + str(probe_seed)
	var map = Map.new()
	root.add_child(map)
	var gen = Geo.new()
	var world = gen.generate(probe_seed)
	map.setup(world)
	var initial_setup_ms: int = map.last_setup_ms
	var initial_atlas_ms: int = map.last_atlas_ms
	var initial_atlas_source: String = map.last_atlas_source
	var required_refinement: bool = map.atlas_refining
	var responsive_frames: int = 0
	while map.atlas_refining:
		await process_frame
		responsive_frames += 1
	check(
		not required_refinement or responsive_frames > 10,
		"new-seed detail refinement leaves frame loop responsive"
	)
	var route = gen.route(world, 0, 1)
	map.sync_state(
		{
			"settlements":
			[
				{"region": 0, "base_housing": 80, "buildings": []},
				{"region": 1, "base_housing": 40, "buildings": []}
			],
			"route": route,
			"shipments": [{"from": 0, "to": 1, "remaining": 3, "total_days": 8}],
			"enterprise": {}
		}
	)
	map.show_flat()
	check(
		map.mode == "flat" and not map.planet.visible and map.flat_world.visible,
		"flat mode visibility"
	)
	check(map.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "flat orthographic projection")
	check(map._flat_point(0, 0) == Vector3(0, 0, .035), "longitude latitude projection origin")
	var selected = []
	map.region_selected.connect(func(id): selected.append(id))
	await process_frame
	var point = map._flat_point(world.regions[1].lat, world.regions[1].lon)
	var picked = map.pick_region(map.camera.unproject_position(point))
	check(picked == 1 and selected == [1], "flat projected region click")
	check(map.flat_marker_root.get_child_count() == 6, "six authoritative candidate markers")
	check(map.flat_transport_root.get_child_count() >= 2, "route and real shipment projected")
	await shot("world_flat_v15_fixture")
	map.zoom(-3)
	map.pan(120, 30)
	check(map.flat_size < 15.8 and map.flat_center.length() > 0, "flat zoom and pan")
	await shot("world_flat_zoom_v15_fixture")
	map.show_planet()
	check(
		map.mode == "planet" and map.planet.visible and not map.flat_world.visible,
		"switch back to globe"
	)
	check(map.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "globe perspective restored")
	await shot("world_planet_v15_fixture")
	map.show_region(1)
	check(
		map.mode == "region" and map.surface.visible and not map.flat_world.visible,
		"region still available"
	)
	check(
		map.local_river_segments.size() > 0, "real downhill world river clipped into farming region"
	)
	var local_origin: Vector2 = map._point_to_local(world.regions[1].lat, world.regions[1].lon)
	check(local_origin.length() < .001, "rotated geography regional projection round trip")
	var descending: bool = true
	for segment in map.local_river_segments:
		if segment.yb > segment.ya + .0001:
			descending = false
	check(descending, "rendered river height remains downstream monotone")
	await shot("world_region_v15_fixture")
	map.setup(world)
	check(map.last_atlas_cached, "same-world atlas cache reused")
	check(Map.atlas_cache.size() <= 2, "atlas cache bounded to two worlds")
	(
		FileAccess
		. open("res://../evidence/v17/tests/flat_render_test" + suffix + ".json", FileAccess.WRITE)
		. store_string(
			JSON.stringify(
				{
					"world_version": world.version,
					"seed": world.seed,
					"synthetic_state": true,
					"failures": failures,
					"initial_setup_ms": initial_setup_ms,
					"initial_atlas_ms": initial_atlas_ms,
					"initial_atlas_source": initial_atlas_source,
					"cached_setup_ms": map.last_setup_ms,
					"refinement_ms": map.last_refinement_ms,
					"responsive_frames": responsive_frames,
					"atlas_key": map.current_atlas_key,
					"atlas_file": "world_atlas_" + map.current_atlas_key.sha256_text() + ".png",
					"user_data_dir": OS.get_user_data_dir(),
					"river_segments": map.local_river_segments.size(),
					"scope": "native render and projection/control probe, not manual gameplay"
				},
				"\t"
			)
		)
	)
	quit(0 if failures.is_empty() else 1)
