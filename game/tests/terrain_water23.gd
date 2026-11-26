extends SceneTree
## Run with --headless --script res://tests/terrain_water23.gd.
const Sim = preload("res://simulation/sim.gd")
const Gen = preload("res://world/world_gen.gd")
const Drain = preload("res://world/drainage23.gd")
const Hydro = preload("res://world/hydrology.gd")
var failures: Array = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _initialize() -> void:
	call_deferred("run")


func synthetic() -> void:
	var width := 64
	var height := 32
	var cell_count := width * height
	var elevation_m := PackedFloat32Array()
	elevation_m.resize(cell_count)
	var wetness := PackedFloat32Array()
	wetness.resize(cell_count)
	wetness.fill(0.75)
	for y in height:
		for x in width:
			elevation_m[y * width + x] = (
				0.0 if y > 23 else 210 + (24 - y) * 23 + mini(x, width - x) * 31
			)
	elevation_m[14 * width + 2] = 23.0
	var drainage := Drain.solve(elevation_m, wetness, width, height, 1100.0)
	var total := 0.0
	var terminal := 0.0
	var wrapped := false
	var cycle := false
	for i in cell_count:
		if elevation_m[i] <= 0.0:
			continue
		total += drainage.area[i / width]
		var j: int = drainage.rec[i]
		if j < 0 or elevation_m[j] <= 0.0:
			terminal += drainage.flow[i]
		else:
			if drainage.flow[j] <= drainage.flow[i]:
				cycle = true
			if absi(j % width - i % width) > 1:
				wrapped = true
	check(
		not cycle and absf(terminal - total) < total * 1e-10,
		"non-cyclic and conserved catchment km2"
	)
	check(wrapped, "downstream crosses the date line")
	check(
		float(drainage.filled[14 * width + 2]) > float(elevation_m[14 * width + 2]),
		"depression gets a spill elevation"
	)
	wetness.fill(0.0)
	var dry := Drain.solve(elevation_m, wetness, width, height, 1100.0)
	check(dry.widths.count(0.0) == cell_count, "fully dry catchment has no persistent channels")
	var lake_values := PackedByteArray([0, 0, 0, 204])
	check(
		is_equal_approx(Drain._fraction(lake_values, -0.5, 0.0, 4, 1), 0.4),
		"lake coverage bridges the date line"
	)
	check(
		is_equal_approx(Drain._fraction(lake_values, 3.5, 0.0, 4, 1), 0.4),
		"wrapped lake lookup matches"
	)


func profile_roundtrip(sim: RefCounted, original_pixels: PackedByteArray) -> void:
	var save_path := "user://terrain_water23_check_%d.ccs" % OS.get_process_id()
	var save_error: String = sim.save_game(save_path)
	check(save_error.is_empty(), "save real planning profile: " + save_error)
	if save_error.is_empty():
		var new_sim := Sim.new()
		Gen._geo_cache.clear()
		var load_error: String = new_sim.load_game(save_path)
		check(load_error.is_empty(), "load existing profile: " + load_error)
		if load_error.is_empty():
			var restored := Hydro.optical_atlas(new_sim.geo, 768, 384)
			check(
				restored.get_data() == original_pixels,
				"restored seed rebuilds the identical water atlas"
			)
			check(
				new_sim.geo.hash == sim.geo.hash, "regenerated world hash matches existing profile"
			)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func run() -> void:
	synthetic()
	var snapshots: Array = []
	for spec: Array in [[260129, 1], [42, 0], [17, 2]]:
		var start_ms := Time.get_ticks_msec()
		var sim = Sim.new()
		sim.new_game(spec[0], "capital", spec[1])
		var world: Dictionary = sim.geo
		check(world.version == "CC-GEO-2.3", "new-game selects hydrology version")
		if not world.has("optical_drainage"):
			failures.append("new-game missing fine hydrograph")
			continue
		var field: Dictionary = world.optical_drainage
		var graph_ms := Time.get_ticks_msec() - start_ms
		var img := Hydro.optical_atlas(world, 768, 384)
		var atlas_done_ms := Time.get_ticks_msec()
		var pixels := img.get_data()
		var red := 0
		var green := 0
		var saturated := 0
		for j in range(0, pixels.size(), 2):
			red += int(pixels[j] > 0)
			green += int(pixels[j + 1] > 0)
			saturated += int(pixels[j] == 255)
		check(
			red > 0 and saturated < red and green > 0 and green < 768 * 384 / 10,
			"surface coverage and sparse optical plume"
		)
		var invalid := 0
		var channel_cells := 0
		for i in field.route.size():
			if field.land[i] and field.plume[i] > 0:
				invalid += 1
			var j: int = field.route[i]
			if (
				field.land[i]
				and j >= 0
				and field.land[j]
				and field.flow_km2[j] <= field.flow_km2[i]
			):
				invalid += 1
			if field.widths_km[i] > 0.0:
				channel_cells += 1
		check(invalid == 0 and channel_cells >= 40, "land-water clipping and acyclic flow")
		check(
			world.rivers.size() >= 4 and world.rivers.size() == world.river_metadata.size(),
			"gameplay river schema"
		)
		var hash_ctx := HashingContext.new()
		hash_ctx.start(HashingContext.HASH_SHA256)
		hash_ctx.update(pixels)
		snapshots.append(
			{
				"seed": spec[0],
				"size": spec[1],
				"r": world.radius_km,
				"ms": graph_ms,
				"atlas_ms": atlas_done_ms - start_ms - graph_ms,
				"rivers": world.rivers.size(),
				"lakes": world.lakes.size(),
				"red_pixels": red,
				"green_pixels": green,
				"active_cells": channel_cells,
				"sha": hash_ctx.finish().hex_encode()
			}
		)
		if spec[1] == 1:
			profile_roundtrip(sim, pixels)
	check(snapshots.size() == 3, "three world sizes")
	if snapshots.size() == 3:
		check(
			snapshots[0].sha != snapshots[1].sha and snapshots[1].sha != snapshots[2].sha,
			"different seeds regenerate different optical atlases"
		)
	var legacy: Dictionary = Gen.new().build(260129, 1, "CC-GEO-2.2")
	check(
		not legacy.has("optical_drainage") and legacy.hydrology.method == Hydro.METHOD,
		"old generator keeps historic rivers"
	)
	print(JSON.stringify({"cases": snapshots, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
