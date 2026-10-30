extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Geo = preload("res://world/world_gen.gd")
var failures: Array = []


func _initialize():
	Watchdog.arm(self)
	call_deferred("run")


func run():
	var cases: Array = []
	var seeds: Array = [
		1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 99, 314159, 271828, 123456, 987654, 2147483647, -2147483647
	]
	for seed_value in seeds:
		var world: Dictionary = Geo.new().generate(seed_value)
		var route: Dictionary = Geo.new().route(world, 0, 1, false)
		var tributaries: int = 0
		for meta in world.get("river_metadata", []):
			if int(meta.downstream_index) >= 0:
				tributaries += 1
			for i in range(1, meta.cell_path.size()):
				if (
					float(world.grid[meta.cell_path[i]].height)
					>= float(world.grid[meta.cell_path[i - 1]].height)
				):
					failures.append("uphill " + str(seed_value))
		if not route.reachable:
			failures.append("farming route inaccessible " + str(seed_value))
		if not bool(world.regions[1].river):
			failures.append("farming candidate no actual river " + str(seed_value))
		if world.rivers.size() < 4:
			failures.append("too few generated rivers " + str(seed_value))
		cases.append(
			{
				"seed": seed_value,
				"rivers": world.rivers.size(),
				"lakes": world.lakes.size(),
				"mouths": world.hydrology.ocean_mouth_count,
				"tributaries": tributaries,
				"farm_route_reachable": route.reachable,
				"farm_route_km": route.distance
			}
		)
	var report: Dictionary = {
		"scope":
		"additional 17 fixed seeds; grid hydrology and normal mining-to-farm road only; no full economy replay",
		"cases": cases,
		"failures": failures
	}
	(
		FileAccess
		. open("res://../evidence/v17/tests/hydrology_sweep.json", FileAccess.WRITE)
		. store_string(JSON.stringify(report, "\t"))
	)
	print(
		"HYDROLOGY_SWEEP ", "PASS" if failures.is_empty() else "FAIL", " ", JSON.stringify(failures)
	)
	quit(0 if failures.is_empty() else 1)
