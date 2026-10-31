extends SceneTree
## Geography statistics over many seeds: site counts, validator results, archetype distribution,
## land fraction, continents, and the road trade-off. `-- --seeds=200 --first=1000 --size=1`.

const Watchdog = preload("res://tests/support/watchdog.gd")
const WorldGen2 = preload("res://world/geo2/world_gen2.gd")
const Routes = preload("res://world/routes.gd")
const Rules = preload("res://simulation/rules.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")

const VARIETY_CHECKS: int = 4
const MIN_TYPE_SEEDS: int = 8
const MIN_LAND_SPREAD: float = 0.15
const MIN_TEMPERATURE_SPREAD: float = 15.0
const MIN_RAIN_SPREAD: float = 0.2


func _initialize() -> void:
	Watchdog.arm(self, 3000)
	call_deferred("run")


func _option(name: String, fallback: int) -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--" + name + "="):
			return int(argument.get_slice("=", 1))
	return fallback


func run() -> void:
	var seeds: int = _option("seeds", 20)
	var first: int = _option("first", 1000)
	var size_arg: int = _option("size", -1)
	var rows: Array = []
	var started: int = Time.get_ticks_msec()
	var roads: Dictionary = Rules.read("economy").roads
	for i: int in range(seeds):
		var seed_value: int = first + i * 7919
		var size: int = size_arg if size_arg >= 0 else i % 3
		var t0: int = Time.get_ticks_msec()
		var world: Dictionary = WorldGen2.generate(seed_value, size)
		var ms: int = Time.get_ticks_msec() - t0
		rows.append(_row(world, seed_value, size, ms, roads))
	var total: int = Time.get_ticks_msec() - started
	var failed: int = _report(rows, total)
	quit(0 if failed == 0 else 1)


## Planets must not all come out alike: each layout and climate turns up, and the figures a player
## sees spread widely. Thin spreads were how every planet ended up looking like the same one.
func _variety_failures(rows: Array) -> int:
	var failures: int = 0
	var seen: Dictionary = {"layout": {}, "climate": {}, "relief": {}}
	var land: Array[float] = []
	var warmth: Array[float] = []
	var rain: Array[float] = []
	for row: Dictionary in rows:
		for part: String in seen:
			var value: String = str(row.character.get(part, ""))
			seen[part][value] = int(seen[part].get(value, 0)) + 1
		land.append(float(row.land))
		warmth.append(float(row.mean_temperature))
		rain.append(float(row.mean_rainfall))
	var types: Dictionary = Rules.read("geography").planet_types
	for part: String in seen:
		for key: String in types[part + "s"]:
			if int(seen[part].get(key, 0)) < MIN_TYPE_SEEDS:
				failures += 1
				print("FAIL %s %s appears on only %d seeds" % [part, key, seen[part].get(key, 0)])
	print("planet types ", seen)
	print(
		(
			"spreads: land %.2f, mean temperature %.1f C, rainfall %.2f"
			% [land.max() - land.min(), warmth.max() - warmth.min(), rain.max() - rain.min()]
		)
	)
	if land.max() - land.min() < MIN_LAND_SPREAD:
		failures += 1
		print("FAIL land fraction spread")
	if warmth.max() - warmth.min() < MIN_TEMPERATURE_SPREAD:
		failures += 1
		print("FAIL temperature spread")
	if rain.max() - rain.min() < MIN_RAIN_SPREAD:
		failures += 1
		print("FAIL rainfall spread")
	return failures


func _row(world: Dictionary, seed_value: int, size: int, ms: int, roads: Dictionary) -> Dictionary:
	var archetypes: Dictionary = {}
	var fertile: int = 0
	var plots: int = 0
	var names: Dictionary = {}
	for site: Dictionary in world.regions:
		archetypes[site.archetype] = int(archetypes.get(site.archetype, 0)) + 1
		names[site.name] = true
		plots += site.plots.size()
		if float(site.fertility) >= 0.6:
			fertile += 1
	var trade: Dictionary = _road_trade(world, roads)
	var valley0: Dictionary = Routes.find(world, 0, 1, "valley", roads)
	var engineered0: Dictionary = Routes.find(world, 0, 1, "engineered", roads)
	return {
		"seed": seed_value,
		"size": size,
		"ms": ms,
		"sites": world.regions.size(),
		"unique": names.size() == world.regions.size(),
		"land": float(world.statistics.land_fraction),
		"continents": int(world.statistics.continent_count),
		"islands": int(world.statistics.island_count),
		"pairs": int(world.generation.validation.pairs),
		"attempt": int(world.generation.attempt),
		"carved": bool(world.generation.validation.carved),
		"rejected": world.generation.validation.rejected.size(),
		"best": world.regions[0].archetype,
		"character": world.get("character", {}),
		"mean_temperature": float(world.statistics.mean_temperature_c),
		"mean_rainfall": float(world.statistics.mean_rainfall),
		"best_terrain": world.regions[0].terrain,
		"archetypes": archetypes,
		"fertile": fertile,
		"plots": plots,
		"rivers": world.rivers.size(),
		"lakes": world.lakes.size(),
		"valley0": valley0.reachable,
		"days0": int(valley0.days) if valley0.reachable else int(engineered0.days),
		"cost0": float(valley0.cost) if valley0.reachable else float(engineered0.cost),
		"fert1": float(world.regions[1].fertility),
		"value0": SiteGen.start_value(world.regions[0]),
		"trade_true": trade.yes,
		"trade_total": trade.total,
		"pair_days": trade.days,
	}


## For site pairs on one landmass: over 360 days, is the cheaper road the slower one?
func _road_trade(world: Dictionary, roads: Dictionary) -> Dictionary:
	var yes: int = 0
	var total: int = 0
	var days: Array[int] = []
	var regions: Array = world.regions
	for a: int in range(regions.size()):
		for b: int in range(a + 1, regions.size()):
			if int(regions[a].landmass) != int(regions[b].landmass):
				continue
			var pa: Vector3 = Routes.unit(float(regions[a].lat), float(regions[a].lon))
			var pb: Vector3 = Routes.unit(float(regions[b].lat), float(regions[b].lon))
			if rad_to_deg(pa.angle_to(pb)) > 45.0 or total >= 16:
				continue
			var valley: Dictionary = Routes.find(world, a, b, "valley", roads)
			var engineered: Dictionary = Routes.find(world, a, b, "engineered", roads)
			if not valley.reachable or not engineered.reachable:
				continue
			total += 1
			days.append(int(valley.days))
			var valley_cost: float = float(valley.cost) + 360.0 * float(roads.valley.upkeep)
			var engineered_cost: float = (
				float(engineered.cost)
				+ 360.0 * float(roads.engineered.upkeep)
				+ (
					360.0
					* float(roads.engineered.closure_chance_per_day)
					* float(roads.engineered.closure_cost)
				)
			)
			var valley_cheaper: bool = valley_cost <= engineered_cost
			var cheaper_days: int = int(valley.days) if valley_cheaper else int(engineered.days)
			var other_days: int = int(engineered.days) if valley_cheaper else int(valley.days)
			if cheaper_days > other_days:
				yes += 1
	return {"yes": yes, "total": total, "days": days}


func _report(rows: Array, total_ms: int) -> int:
	var by_size: Dictionary = {}
	var best: Dictionary = {}
	var kinds: Dictionary = {}
	var land_min: float = 1.0
	var land_max: float = 0.0
	var fails: Array = []
	var carved: int = 0
	var cont: Dictionary = {}
	var ms_sum: int = 0
	var ms_max: int = 0
	var pairs_min: int = 999
	var trade_yes: int = 0
	var trade_total: int = 0
	var attempts: Dictionary = {}
	var not_unique: int = 0
	var fertile_min: int = 999
	var valley_starts: int = 0
	var days_sum: int = 0
	var days_max: int = 0
	var cost_sum: float = 0.0
	var fert_low: float = 1.0
	for row: Dictionary in rows:
		var key: String = str(row.size)
		if not by_size.has(key):
			by_size[key] = {"min": 999, "max": 0, "plots": 0, "n": 0}
		by_size[key].min = mini(by_size[key].min, row.sites)
		by_size[key].max = maxi(by_size[key].max, row.sites)
		by_size[key].plots += row.plots
		by_size[key].n += 1
		best[row.best] = int(best.get(row.best, 0)) + 1
		land_min = minf(land_min, row.land)
		land_max = maxf(land_max, row.land)
		cont[str(row.continents)] = int(cont.get(str(row.continents), 0)) + 1
		attempts[str(row.attempt)] = int(attempts.get(str(row.attempt), 0)) + 1
		ms_sum += row.ms
		ms_max = maxi(ms_max, row.ms)
		pairs_min = mini(pairs_min, row.pairs)
		fertile_min = mini(fertile_min, row.fertile)
		valley_starts += 1 if row.valley0 else 0
		days_sum += row.days0
		days_max = maxi(days_max, row.days0)
		cost_sum += row.cost0
		fert_low = minf(fert_low, row.fert1)
		trade_yes += row.trade_true
		trade_total += row.trade_total
		carved += 1 if row.carved else 0
		not_unique += 0 if row.unique else 1
		for kind: String in row.archetypes:
			kinds[kind] = int(kinds.get(kind, 0)) + int(row.archetypes[kind])
		if row.pairs < 3:
			fails.append(row.seed)
	print(
		(
			"WORLD_STATS seeds=%d total_ms=%d mean_ms=%d max_ms=%d"
			% [rows.size(), total_ms, ms_sum / maxi(1, rows.size()), ms_max]
		)
	)
	print("sites by size ", by_size)
	print("land %.3f..%.3f continents %s attempts %s" % [land_min, land_max, cont, attempts])
	print("best archetype ", best)
	print("archetypes ", kinds)
	print(
		(
			"pairs min %d carved %d fails %s fertile_min %d not_unique %d"
			% [pairs_min, carved, fails, fertile_min, not_unique]
		)
	)
	print(
		(
			"road trade %d/%d = %.0f%%"
			% [trade_yes, trade_total, 100.0 * trade_yes / maxi(1, trade_total)]
		)
	)
	print(
		(
			"first pair: valley %d/%d days mean %.1f max %d cost mean %.0f partner fertility min %.2f"
			% [
				valley_starts,
				rows.size(),
				float(days_sum) / rows.size(),
				days_max,
				cost_sum / rows.size(),
				fert_low
			]
		)
	)
	var result: Dictionary = {
		"seeds": rows.size(),
		"sites": by_size,
		"land": [land_min, land_max],
		"continents": cont,
		"best": best,
		"archetypes": kinds,
		"pairs_min": pairs_min,
		"carved": carved,
		"road_trade": 100.0 * trade_yes / maxi(1, trade_total),
		"road_pairs": trade_total,
		"not_unique": not_unique,
		"mean_ms": ms_sum / maxi(1, rows.size()),
		"max_ms": ms_max,
	}
	return _judge(result, rows)


## The geography rows of the acceptance bar. Shares of seeds, sizes checked one by one.
func _judge(result: Dictionary, rows: Array) -> int:
	var failed: int = 0
	var checks: int = 0
	var rules: Dictionary = Rules.read("geography")
	for key: String in result.sites:
		var band: Array = rules.site_count[int(key)]
		checks += 1
		if int(result.sites[key].min) < int(band[0]) or int(result.sites[key].max) > int(band[1]):
			failed += 1
			print("FAIL sites for size " + key)
	checks += 1
	if float(result.land[0]) < 0.25 or float(result.land[1]) > 0.45:
		failed += 1
		print("FAIL land fraction")
	for row: Dictionary in rows:
		checks += 1
		if int(row.continents) < 2 or int(row.continents) > 6:
			failed += 1
			print("FAIL continents on seed %d: %d" % [row.seed, row.continents])
		if int(row.pairs) < 3:
			failed += 1
			print("FAIL start pairs on seed %d" % row.seed)
	var common: int = 0
	for key: String in result.best:
		if float(result.best[key]) / rows.size() >= 0.1:
			common += 1
	checks += 1
	if common < 3:
		failed += 1
		print("FAIL fewer than three common best-start archetypes")
	checks += 1
	if float(result.road_trade) < 30.0 or float(result.road_trade) > 70.0:
		failed += 1
		print("FAIL road trade-off %.0f%%" % float(result.road_trade))
	checks += 1
	if int(result.not_unique) > 0:
		failed += 1
		print("FAIL duplicate site names")
	failed += _variety_failures(rows)
	checks += VARIETY_CHECKS
	var out: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--json="):
			out = argument.get_slice("=", 1)
	if out != "":
		var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify(result))
		file.close()
	print("V17_WORLD_RESULT checks=%d failures=%d" % [checks, failed])
	return failed
