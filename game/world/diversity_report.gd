extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Geo = preload("res://world/world_gen.gd")


func _initialize():
	Watchdog.arm(self)
	var rows: Array = []
	var failures: Array = []
	var doc: String = "# CC-GEO-1.5 固定种子随机性实际对照\n\n实际Godot无界面运行；所有数值来自生成后的权威网格/路线。不是渲染质量或物理气候验证。大陆定义为>=64个陆地格的连通块，岛屿为2–63格；群落比例分母为全部陆地格。半径为中型1000km。\n\n|种子|实际大陆/岛|陆地%|最高m|平均海深m|气压atm/氧%|平均温度℃/降水|河/湖|森林%/荒漠%|普通km/日/成本|跨山km/日/成本|重复一致|\n|---|---:|---:|---:|---:|---|---|---|---|---|---|---|\n"
	for seed_value in [260129, 20261029, 42, 0, 17, 9981, -234]:
		var g = Geo.new()
		var w: Dictionary = g.generate(seed_value)
		var same: Dictionary = g.generate(seed_value)
		var hash1: String = JSON.stringify(w, "", true, true).sha256_text()
		var hash2: String = JSON.stringify(same, "", true, true).sha256_text()
		if hash1 != hash2:
			failures.append("determinism " + str(seed_value))
		var ordinary: Dictionary = g.route(w, 0, 1, false)
		var mountain: Dictionary = g.route(w, 0, 1, true)
		var s: Dictionary = w.statistics
		var d: Dictionary = w.generation
		var land_count: float = s.land_fraction * w.grid.size()
		var forest_percent: float = (
			100 * float(s.biome_counts.get("forest", 0)) / maxf(land_count, 1)
		)
		var desert_percent: float = (
			100 * float(s.biome_counts.get("desert", 0)) / maxf(land_count, 1)
		)
		var row: Dictionary = {
			"seed": seed_value,
			"sha256": hash1,
			"repeat_sha256": hash2,
			"identical": hash1 == hash2,
			"statistics": s,
			"generation": d,
			"hydrology": w.hydrology,
			"ordinary_route": ordinary,
			"mountain_route": mountain,
			"candidate_coordinates": [],
			"forest_percent_of_land": forest_percent,
			"desert_percent_of_land": desert_percent
		}
		for r in w.regions:
			row.candidate_coordinates.append(
				{
					"id": r.id,
					"lat": r.lat,
					"lon": r.lon,
					"elevation": r.elevation,
					"temperature": r.temperature,
					"water": r.water,
					"fertility": r.fertility
				}
			)
		rows.append(row)
		doc += (
			"|%d|%d / %d|%.2f|%.0f|%.0f|%.3f / %.2f|%.2f / %.3f|%d / %d|%.2f / %.2f|%.0f / %d / %.0f|%.0f / %d / %.0f|%s|\n"
			% [
				seed_value,
				s.continent_count,
				s.island_count,
				s.land_fraction * 100,
				s.max_elevation_m,
				s.mean_ocean_depth_m,
				d.pressure_atm,
				d.oxygen_fraction * 100,
				s.mean_temperature_c,
				s.mean_rainfall,
				w.rivers.size(),
				w.lakes.size(),
				forest_percent,
				desert_percent,
				ordinary.distance,
				ordinary.days,
				ordinary.cost,
				mountain.distance,
				mountain.days,
				mountain.cost,
				"PASS" if hash1 == hash2 else "FAIL"
			]
		)
	doc += "\n`docs/evidence/seed_diversity_v15.json` 保留每种子的完整生成参数、统计、候选坐标、两路线及重复生成SHA256。这里的气压用于温度修正，氧比例保持宜居条件但未建立人体生理模拟；最高海拔与海深均来自实际网格，不拿参数上界冒充实际极值。大陆/山脉/岛链采用有界随机地质区生成，六个功能候选及保护性可达核心仍是游戏设计约束；它不是自由板块构造演化。\n"
	FileAccess.open("res://../evidence/v17/tests/SEED_DIVERSITY.md", FileAccess.WRITE).store_string(
		doc
	)
	(
		FileAccess
		. open("res://../evidence/v17/tests/seed_diversity_v15.json", FileAccess.WRITE)
		. store_string(
			JSON.stringify(
				{
					"version": Geo.VERSION,
					"seeds": rows,
					"failures": failures,
					"scope":
					"actual generated geography and path statistics; not physical simulation"
				},
				"\t"
			)
		)
	)
	print("SEED_DIVERSITY ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	quit(0 if failures.is_empty() else 1)
