extends RefCounted
## Authoritative, deterministic spherical geography. All coordinates use degrees.
const VERSION := "CC-GEO-2.0"
const LEGACY_VERSION := "CC-GEO-1.6"
const SUPPORTED_VERSIONS := ["CC-GEO-1.4", "CC-GEO-1.5", "CC-GEO-1.6", "CC-GEO-2.0"]
const SeedGeo = preload("res://world/seed_geography.gd")
const Hydrology = preload("res://world/hydrology.gd")
const Plates = preload("res://world/geo2/plates.gd")
const WorldGen2 = preload("res://world/geo2/world_gen2.gd")
const GEO_CACHE_DIR: String = "user://geo_cache/"
const GEO_CACHE_FILES: int = 6
const GW := 144
const GH := 72
const GEO_CACHE_LIMIT: int = 6
const REGENERABLE_VERSIONS: Array[String] = ["CC-GEO-1.5", "CC-GEO-1.6"]
const RECORD_FIELDS: Array[String] = [
	"seed",
	"seed_input",
	"seed_protocol",
	"version",
	"size",
	"radius_km",
	"grid_width",
	"grid_height",
	"hash",
	"regions",
	"candidates",
]

static var _geo_cache: Dictionary = {}
## Worlds regenerate in about half a second, too long for a load. Exported builds keep them on disk.
static var use_disk_cache: bool = OS.has_feature("template")


static func world_compatibility_error(world: Dictionary) -> String:
	if not world.get("version", "") in SUPPORTED_VERSIONS:
		return "不支持的世界生成器版本；请使用原版本打开原存档"
	var value = int(world.get("seed", 0))
	if value < -2147483648 or value > 2147483647:
		return "此旧档使用超出 32 位范围的种子，原版全球显示与经营地理不一致。为保留原地理，本版拒绝静默重造；原存档未改动，请用保留的 v1.5 构建继续，或以原种子新建独立生涯。"
	return ""


static func road_blocked(route: Dictionary, day: int) -> bool:
	# Until is inclusive, matching transport and contract connectivity.
	return int(route.get("blocked_until", 0)) >= day


## Derived geography for a seed. Grid data is shared read-only between games on the same seed;
## `regions` is a private copy because deposits change during play.
func build(seed_input: Variant, size_id: int = 1, version: String = VERSION) -> Dictionary:
	var modern: bool = version == VERSION
	var key: String = (
		"%s|%d|%d"
		% ["2" if modern else "1", SeedGeo.normalize_seed(seed_input), clampi(size_id, 0, 2)]
	)
	if not _geo_cache.has(key):
		var world: Dictionary = _read_disk(key) if modern else {}
		if world.is_empty():
			world = (
				WorldGen2.generate(seed_input, size_id) if modern else generate(seed_input, size_id)
			)
			world.hash = geo_hash(world)
			if modern:
				_write_disk(key, world)
		if _geo_cache.size() >= GEO_CACHE_LIMIT:
			_geo_cache.erase(_geo_cache.keys()[0])
		_geo_cache[key] = world
	var entry: Dictionary = _geo_cache[key]
	if modern:
		Plates.activate(int(entry.seed), entry.plates)
	var copy: Dictionary = entry.duplicate(false)
	copy.regions = entry.regions.duplicate(true)
	copy.seed_input = str(seed_input)
	return copy


static func _disk_path(key: String) -> String:
	var rules: String = JSON.stringify(WorldGen2.Rules.read("geography")).sha256_text().left(12)
	var name: String = (key + "|" + str(WorldGen2.REVISION) + "|" + rules).sha256_text().left(32)
	return GEO_CACHE_DIR + name + ".geo"


static func _read_disk(key: String) -> Dictionary:
	if not use_disk_cache:
		return {}
	var path: String = _disk_path(key)
	if not FileAccess.file_exists(path):
		return {}
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 8:
		return {}
	var raw: PackedByteArray = bytes.slice(8).decompress(
		bytes.decode_u64(0), FileAccess.COMPRESSION_ZSTD
	)
	var world: Variant = bytes_to_var(raw)
	return world if world is Dictionary and world.has("plates") else {}


static func _write_disk(key: String, world: Dictionary) -> void:
	if not use_disk_cache:
		return
	DirAccess.make_dir_recursive_absolute(GEO_CACHE_DIR)
	var raw: PackedByteArray = var_to_bytes(world)
	var header := PackedByteArray()
	header.resize(8)
	header.encode_u64(0, raw.size())
	var file: FileAccess = FileAccess.open(_disk_path(key), FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(header + raw.compress(FileAccess.COMPRESSION_ZSTD))
	file.close()
	var names: PackedStringArray = DirAccess.get_files_at(GEO_CACHE_DIR)
	if names.size() <= GEO_CACHE_FILES:
		return
	var oldest: String = ""
	var oldest_time: int = 9223372036854775807
	for name: String in names:
		var modified: int = FileAccess.get_modified_time(GEO_CACHE_DIR + name)
		if modified < oldest_time:
			oldest_time = modified
			oldest = name
	DirAccess.remove_absolute(GEO_CACHE_DIR + oldest)


## The part of a world that belongs in the saved state.
static func world_record(world: Dictionary) -> Dictionary:
	var record: Dictionary = {}
	for field: String in RECORD_FIELDS:
		if world.has(field):
			record[field] = world[field]
	return record


## Geography for a saved record. Regenerated from the seed and checked against the stored hash;
## a legacy world that the generator cannot reproduce carries its own compressed copy.
## Returns {"error": message} instead of changing anything when the world cannot be restored.
func bind(record: Dictionary) -> Dictionary:
	var geo: Dictionary = {}
	if record.has("stored_geo"):
		var stored: Dictionary = record.stored_geo
		var bytes: PackedByteArray = stored.bytes
		var raw: PackedByteArray = bytes.decompress(
			int(stored.raw_size), FileAccess.COMPRESSION_ZSTD
		)
		var unpacked: Variant = bytes_to_var(raw)
		if not unpacked is Dictionary:
			return {"error": "存档中的旧版世界数据已损坏"}
		geo = unpacked
	else:
		var modern: bool = str(record.version) == VERSION
		geo = build(int(record.seed), int(record.size), VERSION if modern else LEGACY_VERSION)
		if str(geo.hash) != str(record.hash):
			return {"error": "此存档的世界与当前生成器的结果不一致，无法恢复原有地理。原存档未改动；请使用生成它的版本继续。"}
	geo.regions = record.regions
	geo.hash = record.hash
	geo.version = record.version
	geo.seed = record.seed
	geo.size = record.size
	geo.radius_km = record.radius_km
	geo.candidates = record.candidates
	return geo


## Fingerprint of everything derived from the seed.
static func geo_hash(world: Dictionary) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(world.get("grid", [])))
	context.update(var_to_bytes(world.get("rivers", [])))
	context.update(var_to_bytes(world.get("river_metadata", [])))
	context.update(var_to_bytes(world.get("lakes", [])))
	return context.finish().hex_encode()


## Whether the current generator reproduces this legacy world exactly.
func regenerates_world(world: Dictionary, world_hash: String) -> bool:
	if not str(world.get("version", "")) in REGENERABLE_VERSIONS:
		return false
	if not world_compatibility_error(world).is_empty():
		return false
	return str(build(int(world.seed), int(world.size), LEGACY_VERSION).hash) == world_hash


static func regenerates(world: Dictionary, world_hash: String) -> bool:
	return new().regenerates_world(world, world_hash)


## A compressed copy of a legacy world's derived data, for worlds that cannot be regenerated.
static func pack_geo(world: Dictionary) -> Dictionary:
	var derived: Dictionary = {}
	for field: Variant in world:
		if not field in RECORD_FIELDS:
			derived[field] = world[field]
	var raw: PackedByteArray = var_to_bytes(derived)
	return {"bytes": raw.compress(FileAccess.COMPRESSION_ZSTD), "raw_size": raw.size()}


func generate(seed_input: Variant, size_id: int = 1) -> Dictionary:
	var seed_value: int = SeedGeo.normalize_seed(seed_input)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.8
	noise.fractal_octaves = 4
	var world := {
		"seed": seed_value,
		"version": LEGACY_VERSION,
		"size": clampi(size_id, 0, 2),
		"radius_km": [730.0, 1000.0, 1430.0][clampi(size_id, 0, 2)],
		"grid_width": GW,
		"grid_height": GH,
		"grid": [],
		"regions": [],
		"candidates": [0, 1, 2, 3, 4, 5],
		"rivers": []
	}
	world.seed_protocol = SeedGeo.SEED_PROTOCOL
	world.seed_input = str(seed_input)
	world.generation = SeedGeo.context(seed_value).data.duplicate(true)
	# A stable continental scaffold guarantees two useful connected candidates;
	# seed changes coasts, relief, precipitation and the extractable resource mix.
	for y in range(GH):
		for x in range(GW):
			var lat := 90.0 - (y + 0.5) * 180.0 / GH
			var lon := (x + 0.5) * 360.0 / GW - 180.0
			world.grid.append(sample_geo(lat, lon, noise))
	var specs := [
		[
			"铁岬盆地",
			22.0,
			-31.0,
			"矿产盆地",
			0.30,
			0.42,
			{"ore": 18000.0, "copper": 7800.0, "crystal": 1450.0}
		],
		["青溪河谷", 5.0, -7.0, "肥沃河谷", 0.89, 0.96, {"ore": 1800.0, "copper": 550.0, "crystal": 140.0}],
		[
			"苍脊高原",
			27.0,
			-13.0,
			"高山矿区",
			0.14,
			0.30,
			{"ore": 6200.0, "copper": 12200.0, "crystal": 8100.0}
		],
		[
			"西风原野",
			-9.0,
			-41.0,
			"温带草原",
			0.58,
			0.51,
			{"ore": 6800.0, "copper": 3700.0, "crystal": 1000.0}
		],
		[
			"远汐群岛",
			-22.0,
			105.0,
			"海岛",
			0.63,
			0.76,
			{"ore": 2900.0, "copper": 2000.0, "crystal": 7400.0}
		],
		[
			"南栖海岸",
			-29.0,
			-18.0,
			"滨海平原",
			0.69,
			0.70,
			{"ore": 4100.0, "copper": 2100.0, "crystal": 750.0}
		]
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(specs.size()):
		var s: Array = specs[i]
		var canonical: Vector2 = (
			Vector2(s[1], s[2]) if i == 4 else SeedGeo.main_coordinate(s[1], s[2], seed_value)
		)
		var location: Vector2 = project_coordinate(canonical.x, canonical.y, world)
		var g: Dictionary = sample_geo(location.x, location.y, noise)
		var dep: Dictionary = s[6].duplicate()
		for key in dep:
			dep[key] = roundf(dep[key] * rng.randf_range(0.86, 1.16))
		world.regions.append(
			{
				"id": i,
				"name": s[0],
				"lat": location.x,
				"lon": location.y,
				"canonical_lat": canonical.x,
				"canonical_lon": canonical.y,
				"elevation": maxf(60.0, g.height * 4300.0),
				"fertility":
				clampf(
					s[4] * (.65 + g.rainfall * .6) * clampf((g.temperature + 8) / 18, .15, 1.1),
					.05,
					.98
				),
				"water": clampf(s[5] * .6 + g.rainfall * .4, .05, .98),
				"temperature": g.temperature,
				"rainfall": g.rainfall,
				"deposits": dep,
				"grade":
				{
					"ore": rng.randf_range(.85, 1.15),
					"copper": rng.randf_range(.8, 1.2),
					"crystal": rng.randf_range(.7, 1.3)
				},
				"neighbors": [] if i == 4 else [0, 1, 2, 3, 5],
				"terrain": s[3],
				"land_fraction": clampf(0.80 - g.height * .32, .35, .95),
				"river": i == 1,
				"grid_index": cell_index(location.x, location.y),
				"development_multiplier": 1.45 if i == 2 else 1.0
			}
		)
	world.rivers = []
	world.lakes = []
	Hydrology.apply(world)
	for r in world.regions:
		var canonical: Vector2 = unproject_coordinate(r.lat, r.lon, world)
		r.canonical_lat = canonical.x
		r.canonical_lon = canonical.y
	world.playability = {
		"checked": true,
		"mining_region": 0,
		"farming_region": 1,
		"isolated_region": 4,
		"method": "seeded provinces with protected economic region and terrain-aware route"
	}
	world.statistics = _statistics(world)
	return world


static func river_lon(lat: float) -> float:
	return -7.0 + sin((lat - 5.0) * .18) * 2.6


static func unit_point(lat: float, lon: float) -> Vector3:
	var a := deg_to_rad(lat)
	var b := deg_to_rad(lon)
	return Vector3(cos(a) * sin(b), sin(a), cos(a) * cos(b))


static func gaussian(
	lat: float, lon: float, clat: float, clon: float, sx: float, sy: float
) -> float:
	var dx := wrapf(lon - clon, -180.0, 180.0) / sx
	var dy := (lat - clat) / sy
	return exp(-(dx * dx + dy * dy) * 1.6)


static func sample_geo(
	lat: float, lon: float, noise: FastNoiseLite, version: String = LEGACY_VERSION
) -> Dictionary:
	if version == VERSION:
		return Plates.sample(lat, lon, noise)
	if version == "CC-GEO-1.4":
		return _sample_geo_v14(lat, lon, noise)
	return SeedGeo.sample(lat, lon, noise)


static func project_coordinate(lat: float, lon: float, world: Dictionary) -> Vector2:
	if world.get("version", "CC-GEO-1.4") in ["CC-GEO-1.4", VERSION]:
		return Vector2(lat, lon)
	return SeedGeo.project(lat, lon, int(world.seed))


static func unproject_coordinate(lat: float, lon: float, world: Dictionary) -> Vector2:
	if world.get("version", "CC-GEO-1.4") in ["CC-GEO-1.4", VERSION]:
		return Vector2(lat, lon)
	return SeedGeo.unproject(lat, lon, int(world.seed))


static func local_geo(
	world: Dictionary, region: int, x: float, z: float, noise: FastNoiseLite
) -> Dictionary:
	var r: Dictionary = world.regions[region]
	var ll: Vector2 = project_coordinate(
		float(r.get("canonical_lat", r.lat)) - z / 4.0,
		float(r.get("canonical_lon", r.lon)) + x / 4.0,
		world
	)
	return sample_geo(ll.x, ll.y, noise, str(world.version))


static func _sample_geo_v14(lat: float, lon: float, noise: FastNoiseLite) -> Dictionary:
	var p := unit_point(lat, lon)
	var n: float = noise.get_noise_3dv(p * 2.2)
	var detail: float = noise.get_noise_3dv(p * 9.0)
	var land: float = maxf(
		gaussian(lat, lon, 7, -28, 47, 61), gaussian(lat, lon, 41, 18, 32, 30) * .76
	)
	land = maxf(land, gaussian(lat, lon, -22, 105, 24, 27) * .90)
	land = maxf(land, gaussian(lat, lon, 27, -130, 34, 48) * 1.04)
	land = maxf(land, gaussian(lat, lon, -52, -90, 19, 17) * .8)
	var coast: float = land - .30 + n * .18 + detail * .06
	var ridge: float = gaussian(lat, lon, 17, -19, 6, 19) * .63
	ridge += gaussian(lat, lon, 32, -135, 8, 33) * .36
	var height: float = coast * .33 + ridge + maxf(detail, 0.0) * .17
	if coast <= 0:
		height = minf(-.008, coast * .65)
	var river_distance: float = absf(lon - river_lon(lat))
	var is_river: bool = lat <= 19.0 and lat >= -28.5 and river_distance < .55 and height > 0
	# A carved channel is monotonically downhill (276m -> 17m) and terminates
	# in a named endorheic lake. Noise cannot introduce an uphill water surface.
	if lat <= 19.0 and lat >= -28.5 and river_distance < 3 and height > 0:
		var channel_height: float = .004 + (lat + 28.5) / 47.5 * .060
		height = lerpf(channel_height, height, smoothstep(.55, 3.0, river_distance))
	var lake: bool = gaussian(lat, lon, -28.5, river_lon(-28.5), 2.6, 2.0) > .30
	if lake:
		height = -.004
	var temperature: float = 28.0 - absf(lat) * .55 - maxf(height, 0.0) * 28.0 + n * 4.0
	var rainfall: float = clampf(
		(
			.65
			- absf(lat) * .003
			+ noise.get_noise_3dv(p * 3.0 + Vector3(5, 3, 2)) * .40
			- ridge * .45
		),
		.08,
		.98
	)
	return {
		"height": height,
		"temperature": temperature,
		"rainfall": rainfall,
		"land": coast > 0 and not lake,
		"river": is_river and not lake,
		"lake": lake
	}


static func cell_index(lat: float, lon: float) -> int:
	var x := posmod(int(floor((lon + 180.0) / 360.0 * GW)), GW)
	var y := clampi(int(floor((90.0 - lat) / 180.0 * GH)), 0, GH - 1)
	return y * GW + x


static func _statistics(world: Dictionary) -> Dictionary:
	var stats: Dictionary = {
		"land_fraction": 0.0,
		"mean_temperature_c": 0.0,
		"mean_rainfall": 0.0,
		"mean_ocean_depth_m": 0.0,
		"max_elevation_m": 0.0,
		"continent_count": 0,
		"island_count": 0,
		"biome_counts": {}
	}
	var land_count: int = 0
	var ocean_count: int = 0
	var visited: Dictionary = {}
	for i in range(world.grid.size()):
		var g: Dictionary = world.grid[i]
		stats.mean_temperature_c += g.temperature
		stats.mean_rainfall += g.rainfall
		stats.max_elevation_m = maxf(stats.max_elevation_m, g.height * 4300)
		var biome: String = g.get("biome", "land" if g.land else "ocean")
		stats.biome_counts[biome] = int(stats.biome_counts.get(biome, 0)) + 1
		if not g.land:
			ocean_count += 1
			stats.mean_ocean_depth_m += maxf(0, -g.height * 4300)
			continue
		land_count += 1
		if visited.has(i):
			continue
		var queue: Array = [i]
		visited[i] = true
		var at: int = 0
		while at < queue.size():
			var index: int = queue[at]
			at += 1
			for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var y: int = index / GW + delta.y
				if y < 0 or y >= GH:
					continue
				var next: int = y * GW + posmod(index % GW + delta.x, GW)
				if not visited.has(next) and world.grid[next].land:
					visited[next] = true
					queue.append(next)
		if queue.size() >= 64:
			stats.continent_count += 1
		elif queue.size() >= 2:
			stats.island_count += 1
	stats.land_fraction = float(land_count) / world.grid.size()
	stats.mean_temperature_c /= world.grid.size()
	stats.mean_rainfall /= world.grid.size()
	stats.mean_ocean_depth_m /= maxi(ocean_count, 1)
	return stats


static func cell_coordinate(index: int) -> Vector2:
	return Vector2(
		90.0 - (float(index / GW) + .5) * 180.0 / GH, (float(index % GW) + .5) * 360.0 / GW - 180.0
	)


func route(world: Dictionary, a: int, b: int, mountain: bool = false) -> Dictionary:
	var empty: Dictionary = {
		"reachable": false,
		"distance": 0.0,
		"days": 0,
		"cost": 0.0,
		"path": [],
		"coordinates": [],
		"mountain": mountain,
		"reason": "海洋或高山阻断陆路；当前无海运设施"
	}
	if a < 0 or b < 0 or a >= world.regions.size() or b >= world.regions.size():
		return empty
	var start: int = world.regions[a].grid_index
	var finish: int = world.regions[b].grid_index
	var dist: Dictionary = {start: 0.0}
	var previous: Dictionary = {}
	var open: Array[int] = [start]
	var closed: Dictionary = {}
	# Dijkstra on spherical land cells; crossing high ridges requires mountain mode.
	while not open.is_empty():
		var best_index := 0
		for k in range(1, open.size()):
			if float(dist[open[k]]) < float(dist[open[best_index]]):
				best_index = k
		var current: int = open[best_index]
		open.remove_at(best_index)
		if current == finish:
			break
		if closed.has(current):
			continue
		closed[current] = true
		var cx: int = current % GW
		var cy: int = current / GW
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var ny: int = cy + offset.y
			if ny < 1 or ny >= GH - 1:
				continue
			var nx: int = posmod(cx + offset.x, GW)
			var ni: int = ny * GW + nx
			var g: Dictionary = world.grid[ni]
			if not g.land or closed.has(ni):
				continue
			if not mountain and float(g.height) > .38 and ni != finish and ni != start:
				continue
			var cc := cell_coordinate(current)
			var nc := cell_coordinate(ni)
			var km: float = (
				unit_point(cc.x, cc.y).angle_to(unit_point(nc.x, nc.y)) * float(world.radius_km)
			)
			var slope: float = absf(float(g.height) - float(world.grid[current].height))
			var penalty: float = (
				1.0
				+ maxf(float(g.height), 0.0) * (.08 if mountain else 2.5)
				+ slope * (.1 if mountain else 4.0)
			)
			var candidate: float = float(dist[current]) + km * penalty
			if not dist.has(ni) or candidate < float(dist[ni]):
				dist[ni] = candidate
				previous[ni] = current
				if not open.has(ni):
					open.append(ni)
	if not dist.has(finish):
		return empty
	var path: Array[int] = [finish]
	var cursor: int = finish
	while cursor != start:
		cursor = previous[cursor]
		path.push_front(cursor)
	var coords: Array = []
	var distance: float = 0.0
	for i in range(path.size()):
		var ll := cell_coordinate(path[i])
		coords.append([ll.x, ll.y])
		if i > 0:
			var old: Vector2 = cell_coordinate(path[i - 1])
			distance += (
				unit_point(old.x, old.y).angle_to(unit_point(ll.x, ll.y)) * float(world.radius_km)
			)
	var days: int = maxi(2, ceili(float(dist[finish]) / (260.0 if mountain else 210.0)))
	return {
		"reachable": true,
		"distance": roundf(distance),
		"days": days,
		"cost": roundf((390.0 + distance * 1.05) * (1.55 if mountain else 1.0)),
		"path": path,
		"coordinates": coords,
		"mountain": mountain,
		"a": a,
		"b": b,
		"capacity": 42 if mountain else 28,
		"reason": "跨山工程" if mountain else "沿河谷绕山"
	}
