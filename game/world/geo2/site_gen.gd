extends RefCounted
## Candidate sites of a CC-GEO-2.0 world: archetype scores per cell, quotas for each archetype,
## Poisson-disk filling, deposits, plots and names. Numbers are in data/v17/geography.json.

const Plates = preload("res://world/geo2/plates.gd")
const SeedGeo = preload("res://world/seed_geography.gd")
const Routes = preload("res://world/routes.gd")
const Rules = preload("res://simulation/rules.gd")

## Rarest first, so the common archetypes cannot take every good spot before them.
const QUOTA_ORDER: Array[String] = [
	"island",
	"lake_basin",
	"cold",
	"arid",
	"highland_mining",
	"fertile_valley",
	"mining_basin",
	"coastal_plain",
	"grassland",
]
const GOODS: Array[String] = ["ore", "copper", "crystal"]
const GOOD_VALUE: Dictionary = {"ore": 8.0, "copper": 14.0, "crystal": 32.0}
const MAX_LATITUDE: float = 74.0
const LOCAL_UNITS_PER_DEGREE: float = 4.0
const SLOT_SPACING: float = 6.0
const SLOT_X: int = 4
const SLOT_Z: int = 3
const RIVER_CLEARANCE: float = 3.2
const PARTNER_TRIES: int = 3


static func place(world: Dictionary, rules: Dictionary, ctx: Dictionary, attempt: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = (int(world.seed) * 31 + attempt) * 1000003 + 0x51735
	var size: int = int(world.size)
	var count_range: Array = rules.site_count[size]
	var target: int = rng.randi_range(int(count_range[0]), int(count_range[1]))
	var separation: float = deg_to_rad(float(rules.separation_degrees[size]))
	var cells: Array = _land_cells(world, rng)
	var scores: Dictionary = _scores(world, cells, rules)
	var chosen: Array = []
	for archetype: String in QUOTA_ORDER:
		var quota: int = int(rules.archetypes[archetype].quota[size])
		_take_quota(cells, scores[archetype], archetype, quota, separation, chosen, rng)
	_fill(cells, scores, target, separation, int(count_range[0]), chosen)
	_build_sites(world, rules, ctx, chosen, rng)


## Land cells away from the poles, in a seeded order. That order is the Poisson-disk draw.
static func _land_cells(world: Dictionary, rng: RandomNumberGenerator) -> Array:
	var cells: Array = []
	var width: int = int(world.grid_width)
	var height: int = int(world.grid_height)
	for index: int in range(world.grid.size()):
		if not bool(world.grid[index].land):
			continue
		var lat: float = 90.0 - (index / width + 0.5) * 180.0 / height
		if absf(lat) > MAX_LATITUDE:
			continue
		(
			cells
			. append(
				{
					"index": index,
					"point": SeedGeo.unit(lat, (index % width + 0.5) * 360.0 / width - 180.0),
					"lat": lat,
				}
			)
		)
	for i: int in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Dictionary = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	return cells


## Archetype name to a score per cell position in `cells`; zero means the archetype does not fit.
static func _scores(world: Dictionary, cells: Array, rules: Dictionary) -> Dictionary:
	var scores: Dictionary = {}
	for archetype: String in QUOTA_ORDER:
		var row := PackedFloat32Array()
		row.resize(cells.size())
		scores[archetype] = row
	var island_limit: int = int(rules.continent_cells)
	var sizes: Array = world.landmass_sizes
	var landmass: PackedInt32Array = world.landmass
	for at: int in range(cells.size()):
		var index: int = cells[at].index
		var c: Dictionary = world.grid[index]
		var h: float = float(c.height)
		var t: float = float(c.temperature)
		var rain: float = float(c.rainfall)
		var rugged: float = float(c.ruggedness)
		var fert: float = float(c.fertility)
		var water: float = float(c.water)
		var ore: float = float(c.ore_potential)
		var copper: float = float(c.copper_potential)
		var crystal: float = float(c.crystal_potential)
		var is_island: bool = int(sizes[landmass[index]]) < island_limit
		var mild: bool = t > 2.0 and t < 30.0
		if is_island:
			scores.island[at] = 0.6 + water * 0.2 + crystal * 0.2
		if h < 0.34 and mild and rain > 0.26:
			scores.mining_basin[at] = (
				(ore + copper) * 0.5 * (1.0 - rugged * 0.5) * (0.7 + water * 0.5)
			)
		if bool(c.river) or float(c.get("discharge", 0.0)) > 0.8:
			scores.fertile_valley[at] = fert * 1.2
		else:
			scores.fertile_valley[at] = fert * 0.72
		if h >= 0.2 and t > -2.0:
			scores.highland_mining[at] = smoothstep(0.2, 0.45, h) * (copper + crystal) * 0.5
		if h < 0.3 and mild and rain > 0.3 and rain < 0.62:
			scores.grassland[at] = (1.0 - absf(rain - 0.46) * 3.0) * (1.0 - rugged)
		if bool(c.coast) and h < 0.2 and mild:
			scores.coastal_plain[at] = 0.5 + fert * 0.5
		if float(c.get("near_lake", 0.0)) > 0.0 and mild:
			scores.lake_basin[at] = 0.7 + water * 0.3
		if rain < 0.3 and t > 4.0:
			scores.arid[at] = float(c.risk_arid) * 0.6 + (ore + copper) * 0.2
		if t < 5.0 and h < 0.45:
			scores.cold[at] = float(c.risk_cold) * 0.6 + (ore + crystal) * 0.2
	return scores


static func _far_enough(point: Vector3, chosen: Array, separation: float) -> bool:
	var limit: float = cos(separation)
	for site: Dictionary in chosen:
		if point.dot(site.point) > limit:
			return false
	return true


static func _take_quota(
	cells: Array,
	row: PackedFloat32Array,
	archetype: String,
	quota: int,
	separation: float,
	chosen: Array,
	rng: RandomNumberGenerator
) -> void:
	# Best cell first, with jitter so that the same terrain does not always win.
	var order: Array[int] = []
	for at: int in range(cells.size()):
		if row[at] > 0.0:
			order.append(at)
	var keyed: Dictionary = {}
	for at: int in order:
		keyed[at] = row[at] + rng.randf_range(0.0, 0.12)
	order.sort_custom(
		func(a: int, b: int) -> bool: return a < b if keyed[a] == keyed[b] else keyed[a] > keyed[b]
	)
	var taken: int = 0
	for at: int in order:
		if taken >= quota:
			break
		if _far_enough(cells[at].point, chosen, separation):
			_choose(chosen, cells[at], archetype)
			taken += 1
	# A world short of good spots can still host this archetype, a little closer to its neighbours.
	if taken < quota:
		for at: int in order:
			if taken >= quota:
				break
			if _far_enough(cells[at].point, chosen, separation * 0.5):
				_choose(chosen, cells[at], archetype)
				taken += 1


static func _choose(chosen: Array, cell: Dictionary, archetype: String) -> void:
	chosen.append(
		{"index": cell.index, "point": cell.point, "lat": cell.lat, "archetype": archetype}
	)


static func _fill(
	cells: Array, scores: Dictionary, target: int, separation: float, minimum: int, chosen: Array
) -> void:
	var gap: float = separation
	for _round: int in range(5):
		for at: int in range(cells.size()):
			if chosen.size() >= target:
				return
			var cell: Dictionary = cells[at]
			if not _far_enough(cell.point, chosen, gap):
				continue
			var best: String = ""
			var best_score: float = 0.05
			for archetype: String in QUOTA_ORDER:
				var score: float = scores[archetype][at]
				if score > best_score:
					best_score = score
					best = archetype
			if best != "":
				_choose(chosen, cell, best)
		if chosen.size() >= minimum and gap < separation:
			return
		gap *= 0.8


static func _build_sites(
	world: Dictionary, rules: Dictionary, ctx: Dictionary, chosen: Array, rng: RandomNumberGenerator
) -> void:
	var names: Dictionary = {}
	var regions: Array = []
	var noise := FastNoiseLite.new()
	noise.seed = int(world.seed)
	noise.frequency = 1.8
	noise.fractal_octaves = 4
	for at: int in range(chosen.size()):
		var pick: Dictionary = chosen[at]
		regions.append(_site(world, rules, at, pick, rng, names))
	world.regions = regions
	var ids: Array = []
	for at: int in range(regions.size()):
		ids.append(at)
	world.candidates = ids
	for site: Dictionary in regions:
		var together: Array = []
		for other: Dictionary in regions:
			if int(other.id) != int(site.id) and int(other.landmass) == int(site.landmass):
				together.append(int(other.id))
		site.neighbors = together
	_add_plots(world, rules, ctx, rng, noise)


static func _site(
	world: Dictionary,
	rules: Dictionary,
	id: int,
	pick: Dictionary,
	rng: RandomNumberGenerator,
	names: Dictionary
) -> Dictionary:
	var index: int = pick.index
	var cell: Dictionary = world.grid[index]
	var spec: Dictionary = rules.archetypes[pick.archetype]
	var width: int = int(world.grid_width)
	var lat: float = float(pick.lat)
	var lon: float = (index % width + 0.5) * 360.0 / width - 180.0
	var deposits: Dictionary = {}
	var grade: Dictionary = {}
	for good: String in GOODS:
		var low: float = float(spec.deposits[good][0])
		var high: float = float(spec.deposits[good][1])
		var potential: float = float(cell[good + "_potential"])
		deposits[good] = roundf(rng.randf_range(low, high) * (0.75 + potential * 0.5))
		grade[good] = rng.randf_range(0.8, 1.2)
	var rugged: float = float(cell.ruggedness)
	return {
		"id": id,
		"name": _unique_name(rules, str(pick.archetype), rng, names),
		"lat": lat,
		"lon": lon,
		"canonical_lat": lat,
		"canonical_lon": lon,
		"elevation": maxf(20.0, float(cell.height) * 4300.0),
		"fertility": float(cell.fertility),
		"water": float(cell.water),
		"temperature": float(cell.temperature),
		"rainfall": float(cell.rainfall),
		"deposits": deposits,
		"grade": grade,
		"neighbors": [],
		"terrain": str(spec.name),
		"archetype": str(pick.archetype),
		"land_fraction": clampf(0.95 - rugged * 0.5, 0.35, 0.95),
		"river": bool(cell.river),
		"grid_index": index,
		"development_multiplier": float(spec.development) + rugged * 0.25,
		"ruggedness": rugged,
		"coast": bool(cell.coast),
		"landmass": int(world.landmass[index]),
		"risks":
		{
			"cold": float(cell.risk_cold),
			"arid": float(cell.risk_arid),
			"flood": float(cell.risk_flood),
		},
		"survey": 0,
		"plots": [],
	}


static func _unique_name(
	rules: Dictionary, archetype: String, rng: RandomNumberGenerator, names: Dictionary
) -> String:
	var adjectives: Array = rules.names.adjectives
	var nouns: Array = rules.names.nouns
	var features: Array = rules.archetypes[archetype].features
	for _try: int in range(200):
		var made: String = (
			str(adjectives[rng.randi_range(0, adjectives.size() - 1)])
			+ str(nouns[rng.randi_range(0, nouns.size() - 1)])
			+ str(features[rng.randi_range(0, features.size() - 1)])
		)
		if not names.has(made):
			names[made] = true
			return made
	# Twenty adjectives by eighteen nouns: a clash after 200 draws means the table was edited.
	var fallback: String = "%s%d" % [str(features[0]), names.size() + 1]
	names[fallback] = true
	return fallback


## Plot slots on a grid around the town centre, nearest first, leaving out sea and river corridors.
static func _slots(
	world: Dictionary, site: Dictionary, noise: FastNoiseLite, ctx: Dictionary
) -> Array:
	var near_rivers: Array = _local_rivers(world, site)
	var slots: Array = []
	for iz: int in range(-SLOT_Z, SLOT_Z + 1):
		for ix: int in range(-SLOT_X, SLOT_X + 1):
			var x: float = ix * SLOT_SPACING
			var z: float = iz * SLOT_SPACING
			if ix == 0:
				# The main street runs north to south through the centre.
				continue
			if _blocked_by_river(x, z, near_rivers):
				continue
			var lat: float = float(site.lat) - z / LOCAL_UNITS_PER_DEGREE
			var lon: float = float(site.lon) + x / LOCAL_UNITS_PER_DEGREE
			var sampled: Dictionary = Plates.sample_with_context(lat, lon, noise, ctx)
			if not bool(sampled.land):
				continue
			slots.append({"x": x, "z": z, "height": float(sampled.height)})
	slots.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var da: float = float(a.x) * float(a.x) + float(a.z) * float(a.z)
			var db: float = float(b.x) * float(b.x) + float(b.z) * float(b.z)
			if da != db:
				return da < db
			return float(a.x) < float(b.x) if a.x != b.x else float(a.z) < float(b.z)
	)
	return slots


static func _local_rivers(world: Dictionary, site: Dictionary) -> Array:
	var segments: Array = []
	for river: Array in world.get("rivers", []):
		for i: int in range(river.size() - 1):
			var a: Vector2 = _to_local(site, river[i])
			var b: Vector2 = _to_local(site, river[i + 1])
			if absf(a.x) < 40.0 and absf(a.y) < 35.0 or absf(b.x) < 40.0 and absf(b.y) < 35.0:
				segments.append([a, b])
	return segments


static func _to_local(site: Dictionary, ll: Array) -> Vector2:
	return Vector2(
		wrapf(float(ll[1]) - float(site.lon), -180.0, 180.0) * LOCAL_UNITS_PER_DEGREE,
		(float(site.lat) - float(ll[0])) * LOCAL_UNITS_PER_DEGREE
	)


static func _blocked_by_river(x: float, z: float, segments: Array) -> bool:
	var p := Vector2(x, z)
	for segment: Array in segments:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var t: float = clampf((p - a).dot(b - a) / maxf(a.distance_squared_to(b), 0.001), 0.0, 1.0)
		if p.distance_to(a.lerp(b, t)) < RIVER_CLEARANCE:
			return true
	return false


static func _add_plots(
	world: Dictionary,
	rules: Dictionary,
	ctx: Dictionary,
	rng: RandomNumberGenerator,
	noise: FastNoiseLite
) -> void:
	for site: Dictionary in world.regions:
		var slots: Array = _slots(world, site, noise, ctx)
		var plots: Array = []
		# Deposits take the outer ground first, the town and its fields what remains.
		_deposit_plots(site, rules, slots, plots, rng)
		_farm_plots(site, rules, slots, plots, rng)
		_general_plots(site, rules, slots, plots)
		site.plots = plots
		refresh_deposits(site)


static func _general_plots(site: Dictionary, rules: Dictionary, slots: Array, plots: Array) -> void:
	var spec: Dictionary = rules.plots
	var wanted: int = (
		int(spec.general_base)
		+ int(float(spec.general_flat_bonus) * (1.0 - float(site.ruggedness)))
	)
	# The centre belongs to the town: the nearest slots become general plots.
	var given: int = mini(wanted, slots.size())
	for _i: int in range(given):
		var slot: Dictionary = slots.pop_front()
		plots.append({"kind": "general", "x": slot.x, "z": slot.z})


static func _farm_plots(
	site: Dictionary, rules: Dictionary, slots: Array, plots: Array, rng: RandomNumberGenerator
) -> void:
	var spec: Dictionary = rules.plots
	var fertility: float = float(site.fertility)
	var wanted: int = mini(int(spec.farm_max), 1 + int(fertility / float(spec.farm_fertility_step)))
	# Lowest ground farms best: take it from what the town left.
	var by_height: Array = slots.duplicate()
	by_height.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a.height != b.height:
				return float(a.height) < float(b.height)
			return float(a.x) < float(b.x) if a.x != b.x else float(a.z) < float(b.z)
	)
	for slot: Dictionary in by_height:
		if wanted <= 0 or slots.size() <= 2:
			break
		slots.erase(slot)
		var spread: float = float(spec.fertility_spread)
		(
			plots
			. append(
				{
					"kind": "farm",
					"fertility":
					clampf(fertility * rng.randf_range(1.0 - spread, 1.0 + spread), 0.03, 0.98),
					"x": slot.x,
					"z": slot.z,
				}
			)
		)
		wanted -= 1


static func _deposit_plots(
	site: Dictionary, rules: Dictionary, slots: Array, plots: Array, rng: RandomNumberGenerator
) -> void:
	var spec: Dictionary = rules.plots
	var limit: int = int(spec.max_deposit_plots)
	# A town needs ground too; on a cramped site the richest goods get what little there is.
	var keep: int = mini(int(spec.town_minimum), slots.size() / 2)
	for good: String in ["crystal", "copper", "ore"]:
		var tonnes: float = float(site.deposits[good])
		var per_plot: float = float(spec.tonnes_per_plot[good])
		var count: int = clampi(ceili(tonnes / per_plot), 1, limit)
		count = mini(count, maxi(0, slots.size() - keep))
		for _i: int in range(count):
			var slot: Dictionary = slots.pop_back()
			plots.append(_deposit(good, tonnes / count, site, spec, rng, slot, 0, false))
		if count > 0 and slots.size() > keep and rng.randf() < float(spec.deep_chance):
			var deep: float = tonnes / count * float(spec.deep_tonnes)
			plots.append(_deposit(good, deep, site, spec, rng, slots.pop_back(), 1, false))
		if count > 0 and slots.size() > keep and rng.randf() < float(spec.hidden_chance):
			var hidden: float = per_plot * float(spec.hidden_tonnes) * rng.randf_range(0.7, 1.3)
			plots.append(_deposit(good, hidden, site, spec, rng, slots.pop_back(), 0, true))


static func _deposit(
	good: String,
	tonnes: float,
	site: Dictionary,
	spec: Dictionary,
	rng: RandomNumberGenerator,
	slot: Dictionary,
	depth: int,
	hidden: bool
) -> Dictionary:
	var spread: float = float(spec.grade_spread)
	var grade: float = float(site.grade[good]) * rng.randf_range(1.0 - spread, 1.0 + spread)
	if depth > 0:
		grade *= float(spec.deep_grade)
	return {
		"kind": "deposit",
		"resource": good,
		"grade": grade,
		"reserves": roundf(tonnes),
		"depth": depth,
		"hidden": hidden,
		"x": slot.x,
		"z": slot.z,
	}


## `deposits` holds the tonnage the colony knows about: shallow plots that are not hidden, and
## deep ones once deep mining is researched.
static func refresh_deposits(site: Dictionary) -> void:
	var totals: Dictionary = {"ore": 0.0, "copper": 0.0, "crystal": 0.0}
	var deep_known: bool = bool(site.get("deep_known", false))
	for plot: Dictionary in site.plots:
		if plot.kind != "deposit" or bool(plot.hidden):
			continue
		if int(plot.depth) == 0 or deep_known:
			totals[plot.resource] += float(plot.reserves)
	site.deposits = totals


## Viable start pairs, best start first. Puts the best start at index 0 and its partner at 1.
static func validate(world: Dictionary, rules: Dictionary) -> Dictionary:
	var spec: Dictionary = rules.validator
	var regions: Array = world.regions
	var roads: Dictionary = Rules.read("economy").roads
	var starts: Array = []
	var partners: Array = []
	for site: Dictionary in regions:
		if _viable_start(world, site, spec):
			starts.append(site)
		if float(site.fertility) >= float(spec.partner_fertility):
			partners.append(site)
	starts.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var sa: float = start_value(a)
			var sb: float = start_value(b)
			return int(a.id) < int(b.id) if sa == sb else sa > sb
	)
	var pairs: Array = []
	var wanted: int = int(spec.min_pairs)
	var leader: int = -1
	for start: Dictionary in starts:
		var found: Dictionary = _partner_for(world, start, partners, spec, roads)
		if found.is_empty():
			continue
		pairs.append([int(start.id), int(found.id)])
		# The world's first offer is one a beginner can connect with either kind of road.
		if leader < 0 and bool(found.valley):
			leader = pairs.size() - 1
		if pairs.size() >= wanted * 2 and leader >= 0:
			break
	if leader > 0:
		var first: Array = pairs[leader]
		pairs.remove_at(leader)
		pairs.push_front(first)
	if not pairs.is_empty():
		pairs = _reorder(world, pairs)
	return {"ok": pairs.size() >= wanted, "pairs": pairs}


## The nearest fertile site a road can reach in time. Checks only the few closest by air.
static func _partner_for(
	world: Dictionary, start: Dictionary, partners: Array, spec: Dictionary, roads: Dictionary
) -> Dictionary:
	var at: Vector3 = SeedGeo.unit(float(start.lat), float(start.lon))
	var near: Array = []
	for partner: Dictionary in partners:
		if int(partner.id) == int(start.id) or int(partner.landmass) != int(start.landmass):
			continue
		near.append([at.angle_to(SeedGeo.unit(float(partner.lat), float(partner.lon))), partner])
	near.sort_custom(
		func(a: Array, b: Array) -> bool:
			if float(a[0]) != float(b[0]):
				return float(a[0]) < float(b[0])
			return int(a[1].id) < int(b[1].id)
	)
	var limit: int = int(spec.partner_days)
	var fallback: Dictionary = {}
	for row: Array in near.slice(0, PARTNER_TRIES):
		var partner: Dictionary = row[1]
		var valley: Dictionary = Routes.find(world, int(start.id), int(partner.id), "valley", roads)
		if bool(valley.reachable) and int(valley.days) <= limit:
			return {"id": int(partner.id), "valley": true}
		if fallback.is_empty():
			var direct: Dictionary = Routes.find(
				world, int(start.id), int(partner.id), "engineered", roads
			)
			if bool(direct.reachable) and int(direct.days) <= limit:
				fallback = {"id": int(partner.id), "valley": false}
	return fallback


static func _viable_start(world: Dictionary, site: Dictionary, spec: Dictionary) -> bool:
	if float(site.water) < float(spec.start_water):
		return false
	if int(world.landmass_sizes[int(site.landmass)]) < int(Rules.read("geography").continent_cells):
		return false
	var tonnes: float = float(site.deposits.ore) + float(site.deposits.copper)
	return (
		tonnes >= float(spec.start_tonnes)
		or float(site.deposits.crystal) >= float(spec.start_crystal)
	)


## What a site's known deposits could earn over its life, per unit of its building cost.
static func start_value(site: Dictionary) -> float:
	var value: float = 0.0
	for good: String in GOODS:
		value += float(site.deposits[good]) * float(GOOD_VALUE[good]) * float(site.grade[good])
	value *= 0.7 + 0.6 * float(site.water)
	# Room to grow: a rich start on a crowded little landmass runs out of places to go.
	value *= 0.55 + 0.09 * mini(site.neighbors.size(), 5)
	return value / float(site.development_multiplier)


## Site ids are positions in `regions`: swap so that the best pair is sites 0 and 1.
static func _reorder(world: Dictionary, pairs: Array) -> Array:
	var regions: Array = world.regions
	var first: int = int(pairs[0][0])
	var second: int = int(pairs[0][1])
	var order: Array = [first, second]
	for at: int in range(regions.size()):
		if at != first and at != second:
			order.append(at)
	var moved: Array = []
	var renumber: Dictionary = {}
	for at: int in range(order.size()):
		renumber[int(order[at])] = at
		moved.append(regions[int(order[at])])
	for at: int in range(moved.size()):
		var site: Dictionary = moved[at]
		site.id = at
		var together: Array = []
		for old: Variant in site.neighbors:
			together.append(int(renumber[int(old)]))
		site.neighbors = together
	world.regions = moved
	var renamed: Array = []
	for pair: Array in pairs:
		renamed.append([int(renumber[int(pair[0])]), int(renumber[int(pair[1])])])
	return renamed


## Last resort: the land nearest the best start becomes a fertile basin. Recorded in validation.
static func carve_basin(world: Dictionary, rules: Dictionary) -> void:
	var spec: Dictionary = rules.validator
	var best: Dictionary = {}
	var best_value: float = -1.0
	for site: Dictionary in world.regions:
		var mass: int = int(world.landmass_sizes[int(site.landmass)])
		if mass >= int(rules.continent_cells) and start_value(site) > best_value:
			best_value = start_value(site)
			best = site
	if best.is_empty():
		best = world.regions[0]
	best.water = maxf(float(best.water), float(spec.start_water) + 0.05)
	var low: float = float(spec.start_tonnes)
	if float(best.deposits.ore) + float(best.deposits.copper) < low:
		var plot: Dictionary = {
			"kind": "deposit",
			"resource": "ore",
			"grade": 1.0,
			"reserves": low,
			"depth": 0,
			"hidden": false,
			"x": float(SLOT_X) * SLOT_SPACING,
			"z": 0.0,
		}
		best.plots.append(plot)
		refresh_deposits(best)
	var nearest: Dictionary = {}
	var nearest_angle: float = INF
	var at_point: Vector3 = SeedGeo.unit(float(best.lat), float(best.lon))
	var carved: Array = []
	for site: Dictionary in world.regions:
		if int(site.id) == int(best.id) or int(site.landmass) != int(best.landmass):
			continue
		var angle: float = at_point.angle_to(SeedGeo.unit(float(site.lat), float(site.lon)))
		carved.append([angle, site])
		if angle < nearest_angle:
			nearest_angle = angle
			nearest = site
	carved.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var wanted: float = float(spec.partner_fertility) + 0.05
	for row: Array in carved.slice(0, int(spec.min_pairs)):
		var site: Dictionary = row[1]
		site.fertility = maxf(float(site.fertility), wanted)
		site.water = maxf(float(site.water), 0.6)
		world.grid[int(site.grid_index)].fertility = float(site.fertility)
		for plot: Dictionary in site.plots:
			if plot.kind == "farm":
				plot.fertility = maxf(float(plot.fertility), wanted)
