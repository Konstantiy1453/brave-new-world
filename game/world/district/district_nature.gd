extends RefCounted
## The district's nature (1.12): revision 07's trees, shrubs, fine dry grass and weathered
## boulders with their toe stones (docs/handoff/approved-terrain-region/region/assets/surface07:
## terrain07.gd, rock07.gd, lowgrass.gd) over a generated world's field, from the site's own
## climate and ground: trees as far as the planet grows forest there, scrub, grass and stone where
## it is dry, nothing in water or at the sea's edge, and everything clear of the live town's paving
## and buildings. Out on steep, high or far ground the earlier preview's layered outcrops stand in
## for the boulders. Batches cover squares of the field, so their draw limits hold per square.
## Positions are in district units; the meshes are in metres (district_plan.gd).

const DistrictIO = preload("res://world/district/district_io.gd")
const DistrictPlan = preload("res://world/district/district_plan.gd")
const DistrictGround = preload("res://world/district/district_ground.gd")

const ENV_DIR: String = "res://assets/district/env/"
const ROCK_DIR: String = "res://assets/district/rocks/"
## The weathered boulders, in rock07.gd's order.
const ROCK_KEYS: Array[String] = [
	"boulder_01", "namaqualand_boulder_04", "namaqualand_boulder_06", "namaqualand_boulder_05"
]
## Long axes of the three outcrop meshes (rock07.gd ORIGINAL_MAJOR) and the share of it a
## weathered boulder in their place takes.
const OUTCROP_MAJOR: Array[float] = [3.2166, 2.3054, 4.9686]
const OUTCROP_SHARE: Array[float] = [0.85, 0.93, 0.65]
## The approved district draws its plant and outcrop meshes at this many metres per mesh unit.
const SOURCE_SCALE: float = 2.4
## Candidate points per square kilometre of field (terrain07.gd: 78,200 over a 2.17 km square).
const CANDIDATES_PER_KM2: float = 16600.0
## Draw limits in metres for play (the approved still frames drew boulders' scans to 210 m, toe
## stones to 405 m and everything else to the horizon; a living district is drawn at 60 frames a
## second): boulders' near meshes, then their field meshes, then their toe-stone meshes far out;
## toe stones; trees' branches (crowns to the horizon); shrubs' stems and crowns; tussocks; fine
## grass. Near details batch by NEAR_SECTOR_M squares so their limits hold per sector; crowns and
## outcrops by FAR_SECTOR_M, for fewer draws.
const ROCK_NEAR_M: float = 120.0
const ROCK_FIELD_M: float = 600.0
const CHIP_M: float = 200.0
const BRANCH_M: float = 300.0
const SHRUB_M: float = 200.0
const SHRUB_CROWN_M: float = 700.0
const TUSSOCK_M: float = 700.0
const FINE_GRASS_M: float = 150.0
const NEAR_SECTOR_M: float = 75.0
const FAR_SECTOR_M: float = 300.0
## The share of rock points that become weathered boulders in play (the rest stay open ground).
const BOULDER_SHARE: float = 0.45
## The kinds of batch, by id: three trees' branches, shrubs' stems, tussocks, three outcrops, four
## boulders, four toe stones, five tufts of fine grass, three trees' crowns and shrubs' crowns.
const KIND_TREE: int = 0
const KIND_SHRUB: int = 3
const KIND_TUSSOCK: int = 4
const KIND_OUTCROP: int = 5
const KIND_BOULDER: int = 8
const KIND_CHIP: int = 12
const KIND_GRASS: int = 16
const KIND_CROWN: int = 21
const KIND_SHRUB_CROWN: int = 24
## The town's core holds this share of its buildings; density and grass are measured from it.
const CORE_SHARE: float = 0.7
## Tussocks give way to fine grass this far past the core, in metres (lowgrass.gd: 430-640 m).
const FINE_ZONE_M: Vector2 = Vector2(120.0, 320.0)
## Beyond it, this share of grass points still gets a clump or two.
const FAR_GRASS_SHARE: float = 0.5
## Kinds of building with lived-in grounds, where small groves stand at the side (terrain07.gd).
const DWELLINGS: Array[String] = [
	"commerce", "clinic", "lab", "school", "apartment", "habitat", "civic_center", "crew_quarters"
]
const FINE_GRASS_COLOURS: Array[String] = ["767c50", "787c57", "8b8057", "747a4b", "8d8564"]
const FINE_GRASS_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
varying vec3 tint;
void vertex() { tint = pow(COLOR.rgb, vec3(2.2)); }
void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = tint * .76;
	BACKLIGHT = tint * .23;
	ROUGHNESS = .94;
	SPECULAR = .15;
}
"""

## For comparison captures only: draw Boulder 01's approved 56,540-triangle scan near the camera,
## as the approved frames did, in place of its 12,000-triangle play mesh.
static var approved_closeups: bool = false
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


## Scatters the field's nature under `parent`. `map` is the region view (region_ground.gd), read
## for the ground, the sea, water, forest, climate and footprints; `fringe` the town's paving mask
## (district_ground.gd); `lots` the town's buildings as {pos, yaw, size, kind}. Returns counts and
## the milliseconds it took.
static func build(
	parent: Node3D,
	map: Node3D,
	seed_value: int,
	fringe: Dictionary,
	lots: Array,
	ore_seam: bool = false
) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var scatter := Scatter.new(map, seed_value, fringe, lots)
	scatter.field()
	scatter.groves()
	if ore_seam:
		scatter.seam()
	_commit(parent, scatter.bag)
	scatter.counts.ms = Time.get_ticks_msec() - started
	return scatter.counts


## One scattering of a field: the ground and water it reads, the town's core, the noise and the
## batches it fills, by kind and sector.
class Scatter:
	extends RefCounted

	var map: Node3D
	var fringe: Dictionary
	var lots: Array
	var rng := RandomNumberGenerator.new()
	var relief := FastNoiseLite.new()
	var cover := FastNoiseLite.new()
	var bag: Dictionary = {}
	var counts: Dictionary = {
		"trees": 0,
		"shrubs": 0,
		"tussocks": 0,
		"fine_grass": 0,
		"boulders": 0,
		"toe_stones": 0,
		"outcrops": 0,
		"candidates": 0,
	}
	var heights := PackedFloat32Array()
	var forests := PackedFloat32Array()
	var climates := PackedVector2Array()
	var res: int = 0
	var width: float = 1.0
	var depth: float = 1.0
	var half_width: float = 0.0
	var half_depth: float = 0.0
	var sea: float = 0.0
	var rivers: Array = []
	var lakes: Array = []
	var centre := Vector2.ZERO
	var core_radius: float = 0.0
	var town := Rect2()
	var town_level: float = 0.0
	var rock_turns: Array[int] = [0, 0, 0]

	func _init(source: Node3D, seed_value: int, mask: Dictionary, buildings: Array) -> void:
		map = source
		fringe = mask
		lots = buildings
		rng.seed = seed_value
		relief.seed = 17481 + seed_value % 9973
		relief.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		relief.frequency = 0.012 / 4.68
		relief.fractal_octaves = 3
		cover.seed = 6984 + seed_value % 7919
		cover.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		cover.frequency = 0.084 / 4.68
		cover.fractal_octaves = 2
		heights = map.get("height_field")
		forests = map.get("forest_field")
		climates = map.get("climate_field")
		res = int(map.get("field_res"))
		width = float(map.get("field_width"))
		depth = float(map.get("field_depth"))
		half_width = width * 0.5 - 1.0
		half_depth = depth * 0.5 - 1.0
		sea = float(map.call("sea_level"))
		rivers = map.get("local_river_segments")
		lakes = map.get("local_lakes")
		centre = Vector2(float(map.call("_town_offset")), 0.0)
		town = Rect2(centre, Vector2.ZERO)
		var distances := PackedFloat32Array()
		if not lots.is_empty():
			var sum := Vector2.ZERO
			for index: int in range(lots.size()):
				var at: Vector2 = lots[index].pos
				sum += at
				town = Rect2(at, Vector2.ZERO) if index == 0 else town.expand(at)
			centre = sum / lots.size()
			for lot: Dictionary in lots:
				distances.append(Vector2(lot.pos).distance_to(centre))
			distances.sort()
			core_radius = distances[int((distances.size() - 1) * CORE_SHARE)]
		town_level = height(centre.x, centre.y)

	## The ground as the landscape's triangles draw it (region_ground.gd `_mesh_ground`).
	func height(x: float, z: float) -> float:
		if heights.size() != (res + 1) * (res + 1):
			return float(map.call("_ground", x, z))
		var fx: float = clampf((x / width + 0.5) * res, 0.0, res - 0.001)
		var fz: float = clampf((z / depth + 0.5) * res, 0.0, res - 0.001)
		var ix: int = int(fx)
		var iz: int = int(fz)
		var tx: float = fx - ix
		var tz: float = fz - iz
		var row: int = iz * (res + 1) + ix
		var next: int = row + res + 1
		if tx + tz <= 1.0:
			var h00: float = heights[row]
			return h00 + (heights[row + 1] - h00) * tx + (heights[next] - h00) * tz
		var h11: float = heights[next + 1]
		return h11 + (heights[next] - h11) * (1.0 - tx) + (heights[row + 1] - h11) * (1.0 - tz)

	## The field vertex nearest a point (region_ground.gd `_forest_at`).
	func vertex(p: Vector2) -> int:
		var fx: int = clampi(roundi((p.x / width + 0.5) * res), 0, res)
		var fz: int = clampi(roundi((p.y / depth + 0.5) * res), 0, res)
		return fz * (res + 1) + fx

	## Whether a point is in or beside a river or lake (region_ground.gd `_water_height_at`).
	func wet(p: Vector2, margin: float = 1.6) -> bool:
		for segment: Dictionary in rivers:
			var a: Vector2 = segment.a
			var b: Vector2 = segment.b
			var t: float = clampf((p - a).dot(b - a) / maxf(a.distance_squared_to(b), .001), 0, 1)
			if p.distance_to(a.lerp(b, t)) < float(segment.width) * margin:
				return true
		for lake: Dictionary in lakes:
			if p.distance_to(lake.center) < float(lake.radius) * margin:
				return true
		return false

	## Metres past the town's core: the ring holding CORE_SHARE of its buildings.
	func beyond_m(p: Vector2) -> float:
		return maxf(p.distance_to(centre) - core_radius, 0.0) * DistrictPlan.METRES_PER_UNIT

	func clear_for(p: Vector2, reach_m: float) -> bool:
		if absf(p.x) > half_width or absf(p.y) > half_depth:
			return false
		if height(p.x, p.y) < sea + 0.15 or wet(p):
			return false
		if DistrictGround.paving_distance(fringe, p) < minf(reach_m, DistrictGround.FRINGE_REACH_M):
			return false
		var foot_m: float = (
			float(map.call("footprint_clearance", p.x, p.y)) * DistrictPlan.METRES_PER_UNIT
		)
		return foot_m >= reach_m

	func add(kind: int, p: Vector2, placed: Transform3D, tint: Color) -> void:
		var far: bool = kind >= KIND_CROWN or (kind >= KIND_OUTCROP and kind < KIND_BOULDER)
		var sector: float = FAR_SECTOR_M if far else NEAR_SECTOR_M
		var key := Vector3i(
			kind,
			floori(p.x * DistrictPlan.METRES_PER_UNIT / sector),
			floori(p.y * DistrictPlan.METRES_PER_UNIT / sector)
		)
		if not bag.has(key):
			bag[key] = []
		bag[key].append([placed, tint])

	## The field's candidates (terrain07.gd `build`): each becomes a tree, shrub, rock or grass,
	## or nothing, by its noise, its climate, its distance from paving and from the town's core.
	func field() -> void:
		var metres: float = DistrictPlan.METRES_PER_UNIT
		var unit: float = DistrictPlan.UNIT
		var area_km2: float = (half_width * 2.0 * metres) * (half_depth * 2.0 * metres) / 1e6
		var candidates: int = int(area_km2 * CANDIDATES_PER_KM2)
		counts.candidates = candidates
		for _k: int in range(candidates):
			var p := Vector2(
				rng.randf_range(-half_width, half_width), rng.randf_range(-half_depth, half_depth)
			)
			var keep: float = rng.randf()
			var t: float = rng.randf()
			var chance: float = rng.randf()
			var yaw: float = rng.randf_range(0.0, TAU)
			var size_roll: float = rng.randf()
			var stretch := Vector2(rng.randf_range(.87, 1.12), rng.randf_range(.85, 1.12))
			var variant: int = rng.randi_range(0, 2)
			var value: float = rng.randf_range(.70, 1.0)
			var tint := Color(
				value * rng.randf_range(.92, 1.0), value, value * rng.randf_range(.86, 1.0)
			)
			var past: float = beyond_m(p)
			if keep > 1.0 - .85 * smoothstep(250.0, 900.0, past):
				continue
			var pave_m: float = DistrictGround.paving_distance(fringe, p)
			if pave_m < 2.03:
				continue
			var level: float = height(p.x, p.y)
			if level < sea + 0.15 or wet(p):
				continue
			var far_m: float = (
				pave_m if pave_m < DistrictGround.FRINGE_REACH_M else maxf(pave_m, past)
			)
			if t >= .15 and t <= .26:
				continue
			var m: Vector2 = p * metres
			# Canopy noise matters only to trees and shrubs (the lowest draws of t).
			var canopy: float = -1.0
			if t < .15:
				canopy = (
					.62 * relief.get_noise_2d(m.x * 1.5 + 2480.0, m.y * 1.45)
					+ .38 * cover.get_noise_2d(m.x * .63, m.y * .63)
				)
			var cluster: float = cover.get_noise_2d(m.x * .53 - 328.0, m.y * .55 + 529.0)
			var at_vertex: int = vertex(p)
			var climate: Vector2 = (
				climates[at_vertex] if at_vertex < climates.size() else Vector2(14.0, 0.45)
			)
			var forest: float = forests[at_vertex] if at_vertex < forests.size() else 0.3
			var green: float = smoothstep(.08, .40, climate.y) * smoothstep(-8.0, 4.0, climate.x)
			var outcrop: float = (
				smoothstep(240.0, 470.0, past + 120.0) * smoothstep(-.24, .14, cluster)
			)
			var roadshade: float = smoothstep(4.4, 15.6, far_m)
			var close: float = 1.0 - smoothstep(94.0, 440.0, past + 94.0)
			var kind: String = ""
			var scale: float = 0.0
			var radius: float = 0.0
			if (
				t < .103 * roadshade * clampf(0.3 + forest * 1.6, 0.0, 1.6)
				and canopy > .14
				and far_m > 11.9
				and chance > .44 * close
			):
				kind = "tree"
				scale = lerpf(.49, .82, size_roll) * (1.0 - .18 * close)
				radius = 4.45
			elif t < .15 and canopy + .31 * cluster > .012 and far_m > 4.2 and green > .12:
				kind = "shrub"
				scale = lerpf(.22, .56, size_roll)
				radius = 1.55
			elif t > .936 - outcrop * .066 - (1.0 - green) * .03 and cluster < .24 and far_m > 3.3:
				kind = "rock"
				scale = (
					lerpf(.12, .62, size_roll)
					* (.75 + smoothstep(9.4, 112.0, far_m) * .65)
					* (1.0 + outcrop * 1.55)
				)
				radius = 2.65
			elif t > .26 and chance < (.48 + cluster * .83) * green:
				kind = "tussock"
				scale = lerpf(.34, 1.01, size_roll)
				radius = .78
			else:
				continue
			var reach_m: float = radius * scale * 2.74 + .28
			if far_m < reach_m:
				continue
			var foot_m: float = float(map.call("footprint_clearance", p.x, p.y)) * metres
			if foot_m < reach_m + 1.0:
				continue
			var at := Vector3(p.x, level, p.y)
			match kind:
				"tree", "shrub":
					var size := Vector3(scale * stretch.x, scale * stretch.y, scale) * SOURCE_SCALE
					at.y -= .12 * scale * SOURCE_SCALE * unit
					var placed := Transform3D(Basis(Vector3.UP, yaw).scaled(size * unit), at)
					if kind == "tree":
						add(KIND_TREE + variant, p, placed, tint)
						add(KIND_CROWN + variant, p, placed, tint)
						counts.trees += 1
					else:
						add(KIND_SHRUB, p, placed, tint)
						add(KIND_SHRUB_CROWN, p, placed, tint)
						counts.shrubs += 1
				"tussock":
					# Fine grass near the town, sparser beyond it: the source tussock reads as a
					# solid lump at the district's close cameras, so it is not drawn (1.12).
					var near_town: bool = (
						rng.randf() < 1.0 - smoothstep(FINE_ZONE_M.x, FINE_ZONE_M.y, past)
					)
					if near_town or rng.randf() < FAR_GRASS_SHARE:
						counts.fine_grass += fine_grass(p, 4 if near_town else 2)
				"rock":
					rock(p, level, scale, yaw, variant, far_m, past, tint)

	func rock(
		p: Vector2,
		level: float,
		scale: float,
		yaw: float,
		variant: int,
		far_m: float,
		past: float,
		tint: Color
	) -> void:
		var unit: float = DistrictPlan.UNIT
		var slope: float = (
			(
				Vector2(
					height(p.x + 1.0, p.y) - height(p.x - 1.0, p.y),
					height(p.x, p.y + 1.0) - height(p.x, p.y - 1.0)
				)
				. length()
			)
			* 0.5
		)
		var elevation_m: float = (level - town_level) * DistrictPlan.METRES_PER_UNIT
		var outer_m: float = past + 300.0
		var outer: float = maxf(
			smoothstep(565.0, 810.0, outer_m),
			(
				smoothstep(365.0, 610.0, outer_m)
				* maxf(smoothstep(.07, .19, slope), smoothstep(9.0, 34.0, elevation_m))
			)
		)
		if rng.randf() < outer:
			var size := Vector3.ONE * scale * SOURCE_SCALE
			var placed := Transform3D(
				Basis(Vector3.UP, yaw).scaled(size * unit),
				Vector3(p.x, level - .31 * scale * SOURCE_SCALE * unit, p.y)
			)
			add(KIND_OUTCROP + variant, p, placed, tint)
			counts.outcrops += 1
			return
		if rng.randf() > BOULDER_SHARE:
			return
		var turn: int = rock_turns[variant]
		rock_turns[variant] += 1
		var index: int = (turn + variant * 2 + 2) % 3
		if index == 0 and turn % 5 < 2:
			index = 3
		var major: float = OUTCROP_MAJOR[variant] * SOURCE_SCALE * scale
		var wide: float = clampf(
			major * OUTCROP_SHARE[variant], .42, 5.5 + rng.randf_range(-.45, .50)
		)
		wide = minf(wide, maxf(.15, (far_m - .16) / .78))
		boulder(p, level, wide, index, yaw)
		if wide > .85 and rng.randf() < .89:
			toe_stones(p, wide, yaw, index)

	## One weathered boulder, half sunk (rock07.gd build_group).
	func boulder(p: Vector2, level: float, wide: float, index: int, yaw: float) -> void:
		var unit: float = DistrictPlan.UNIT
		var turn: float = yaw - (1.12 if index == 0 else 0.0)
		var tall: float = wide * rng.randf_range(.82, 1.08)
		var sink: float = wide * (rng.randf_range(.095, .16) + (.075 if index == 0 else 0.0))
		var size := Vector3(wide * rng.randf_range(.92, 1.06), tall, wide) * unit
		var placed := Transform3D(
			Basis(Vector3.UP, turn).scaled(size), Vector3(p.x, level - sink * unit, p.y)
		)
		var tone: float = rng.randf_range(.85, 1.15)
		var tint := Color(
			tone, rng.randf_range(.98, 1.03) * tone, rng.randf_range(.94, 1.03) * tone
		)
		add(KIND_BOULDER + index, p, placed, tint)
		counts.boulders += 1

	## The toe stones round a large boulder: a fan of fragments and a tail of smaller ones, partly
	## buried (rock07.gd `_chips`), fewer than the still preview's.
	func toe_stones(origin: Vector2, wide: float, yaw: float, rock_index: int) -> void:
		var unit: float = DistrictPlan.UNIT
		var direction: float = rng.randf_range(0.0, TAU)
		var split: float = rng.randf_range(.50, .80)
		var count: int = clampi(roundi(3.0 + 2.0 * wide + rng.randfn(0.0, 1.6)), 2, 16)
		for j: int in range(count):
			var in_tail: bool = rng.randf() > split
			var angle: float = (
				direction + (1.78 if in_tail else 0.0) + rng.randfn(0.0, .58 if in_tail else .75)
			)
			var off := Vector2.from_angle(angle)
			var ellipse: float = lerpf(.35, .5, absf(cos(angle + yaw)))
			var dist_m: float = (
				wide * (ellipse + rng.randf_range(-.045, .40)) + rng.randf_range(.05, .42)
			)
			var c: Vector2 = origin + off * dist_m * unit
			var frac: float = rng.randf()
			var size: float = (
				clampf(wide * rng.randf_range(.082, .175), .19, .70)
				if (j < 2 or frac > .79)
				else rng.randf_range(.055, .23)
			)
			var variant: int = rng.randi_range(0, 3) if frac > .4 else rock_index
			var turn: float = rng.randf_range(0.0, TAU)
			var shape := Vector3(rng.randf_range(.75, 1.14), rng.randf_range(.62, 1.12), 1.0)
			var warm: float = rng.randf_range(.72, 1.23)
			if DistrictGround.paving_distance(fringe, c) < size * .77 + .12:
				continue
			var low: float = height(c.x, c.y) - .17 * size * unit
			var placed := Transform3D(
				Basis(Vector3.UP, turn).scaled(shape * size * unit), Vector3(c.x, low, c.y)
			)
			add(KIND_CHIP + variant, c, placed, Color(warm * .97, warm, warm * .96))
			counts.toe_stones += 1

	## Small clumps of fine dry grass round a point near the town (lowgrass.gd), fewer per point
	## than the still preview's.
	func fine_grass(p: Vector2, most: int = 5) -> int:
		var unit: float = DistrictPlan.UNIT
		var yaw: float = rng.randf() * TAU
		var axis := Vector2(cos(yaw), sin(yaw))
		var across := Vector2(-axis.y, axis.x)
		var span: float = rng.randf_range(.75, 2.8)
		var count: int = rng.randi_range(mini(2, most), most)
		var made: int = 0
		for j: int in range(count):
			var offset_m: Vector2 = (
				Vector2.ZERO
				if j == 0
				else axis * rng.randfn(0.0, span * .68) + across * rng.randfn(0.0, span * .31)
			)
			var at: Vector2 = p + offset_m * unit
			var scale: float = rng.randf_range(.65, 1.35)
			var family: int = rng.randi_range(0, 4)
			var turn: float = rng.randf() * TAU
			if DistrictGround.paving_distance(fringe, at) < .62 * scale:
				continue
			var placed := Transform3D(
				Basis(Vector3.UP, turn).scaled(Vector3.ONE * scale * unit),
				Vector3(at.x, height(at.x, at.y), at.y)
			)
			add(KIND_GRASS + family, at, placed, Color.WHITE)
			made += 1
		return made

	## Groves round the town's edge and beside its lived-in buildings, clear of doors and paving
	## (terrain07.gd's perimeter and dwelling groups).
	func groves() -> void:
		if lots.is_empty():
			return
		var unit: float = DistrictPlan.UNIT
		var anchors: Array[Vector2] = []
		for i: int in range(8):
			var angle: float = TAU * (float(i) + rng.randf_range(-.18, .18)) / 8.0
			anchors.append(centre + Vector2.from_angle(angle) * (core_radius * 1.14 + 3.0))
		var dwellings: Array[Vector2] = []
		for lot: Dictionary in lots:
			if str(lot.kind) not in DWELLINGS:
				continue
			var c: Vector2 = lot.pos
			var turn: float = float(lot.yaw)
			var forward := Vector2(sin(turn), cos(turn))
			var side := Vector2(-forward.y, forward.x)
			var half: Vector2 = Vector2(lot.size) * 0.5
			var sign_value: float = -1.0 if rng.randf() < .5 else 1.0
			for direction: float in [sign_value, -sign_value]:
				var point: Vector2 = (
					c
					+ side * direction * (half.x + 2.2 * 4.68 * unit)
					- forward * rng.randf_range(.15, .90) * half.y
				)
				if DistrictGround.paving_distance(fringe, point) < 6.5:
					continue
				var crowded: bool = false
				for old: Vector2 in dwellings:
					if old.distance_squared_to(point) < pow(9.0 * 4.68 * unit, 2.0):
						crowded = true
						break
				if crowded:
					continue
				dwellings.append(point)
				break
			if dwellings.size() >= 9:
				break
		for outer: bool in [true, false]:
			for origin: Vector2 in anchors if outer else dwellings:
				grove(origin, outer)

	func grove(origin: Vector2, outer: bool) -> void:
		var unit: float = DistrictPlan.UNIT
		var placed: Array[Vector2] = []
		var spread: float = (3.1 if outer else 2.25) * 4.68 * unit
		for attempt: int in range(28):
			var jitter := Vector2(
				rng.randf_range(-spread, spread), rng.randf_range(-spread, spread)
			)
			var p: Vector2 = origin if attempt == 0 else origin + jitter
			var size: float = rng.randf_range(.66, .93) if outer else rng.randf_range(.46, .64)
			if not placed.is_empty():
				size *= rng.randf_range(.57, .78)
			var turn: float = rng.randf_range(0.0, TAU)
			var variant: int = rng.randi_range(0, 2)
			if not clear_for(p, 4.55 * size * SOURCE_SCALE + 1.0):
				continue
			var crowded: bool = false
			for other: Vector2 in placed:
				if p.distance_squared_to(other) < pow(1.5 * 4.68 * unit, 2.0):
					crowded = true
					break
			if crowded:
				continue
			var basis := Basis(Vector3.UP, turn).scaled(Vector3.ONE * size * SOURCE_SCALE * unit)
			var at := Vector3(p.x, height(p.x, p.y) - .12 * size * SOURCE_SCALE * unit, p.y)
			add(KIND_TREE + variant, p, Transform3D(basis, at), Color(.76, .83, .74))
			add(KIND_CROWN + variant, p, Transform3D(basis, at), Color(.76, .83, .74))
			counts.trees += 1
			placed.append(p)
			if placed.size() >= 3:
				break

	## A visible geological exposure marks mineral-bearing ground (region_ground.gd's old nature):
	## rust-stained boulders in a band south-west of the town's middle.
	func seam() -> void:
		var unit: float = DistrictPlan.UNIT
		for _i: int in range(16):
			var p := Vector2(-16.0 + rng.randf_range(-3.4, 3.4), -10.0 + rng.randf_range(-2.5, 2.5))
			var wide: float = rng.randf_range(1.4, 4.2)
			var yaw: float = rng.randf_range(0.0, TAU)
			var variant: int = rng.randi_range(1, 3)
			if not clear_for(p, wide + 2.0):
				continue
			var size := Vector3(wide * 1.3, wide * .55, wide) * unit
			var placed := Transform3D(
				Basis(Vector3.UP, yaw).scaled(size),
				Vector3(p.x, height(p.x, p.y) - .12 * wide * unit, p.y)
			)
			add(KIND_BOULDER + variant, p, placed, Color("c08a66"))
			counts.boulders += 1


## One multimesh per kind and sector, each with its meshes, materials and draw limits.
static func _commit(parent: Node3D, bag: Dictionary) -> void:
	var keys: Array = bag.keys()
	keys.sort()
	for key: Vector3i in keys:
		var kind: int = key.x
		var list: Array = bag[key]
		var label: String = "Nature_%d_%d_%d" % [kind, key.y, key.z]
		if kind < KIND_SHRUB:
			var source: String = "CC_TREE_SOURCE_%02d" % (kind - KIND_TREE)
			var branches: ArrayMesh = _env_mesh(source + "_BRANCH_NETWORK")
			_batch(parent, label, list, branches, _bark(), 0.0, BRANCH_M, false)
		elif kind == KIND_SHRUB:
			var stems: ArrayMesh = _env_mesh("CC_SHRUB_SOURCE_BRANCH_NETWORK")
			_batch(parent, label, list, stems, _bark(), 0.0, SHRUB_M, false)
		elif kind >= KIND_CROWN and kind < KIND_SHRUB_CROWN:
			var source: String = "CC_TREE_SOURCE_%02d" % (kind - KIND_CROWN)
			var crown: ArrayMesh = _env_mesh(source + "_CURVED_LEAF_CROWN_SPRAYS")
			_batch(parent, label, list, crown, _leaves())
		elif kind == KIND_SHRUB_CROWN:
			var leaves: ArrayMesh = _env_mesh("CC_SHRUB_SOURCE_CURVED_LEAF_CROWN_SPRAYS")
			_batch(parent, label, list, leaves, _leaves(), 0.0, SHRUB_CROWN_M)
		elif kind == KIND_TUSSOCK:
			var tuft: ArrayMesh = _env_mesh("CC_GRASS_SOURCE")
			var straw: StandardMaterial3D = _plain("tussock", "898155", true)
			_batch(parent, label, list, tuft, straw, 0.0, TUSSOCK_M, false)
		elif kind < KIND_BOULDER:
			var ridge: ArrayMesh = _env_mesh("CC_ROCK_SOURCE_%02d" % (kind - KIND_OUTCROP))
			_batch(parent, label, list, ridge, _plain("outcrop", "827e70", false))
		elif kind < KIND_CHIP:
			var rock: String = ROCK_KEYS[kind - KIND_BOULDER]
			var near: ArrayMesh = _rock_mesh(rock, _near_detail(rock))
			var stone: ShaderMaterial = _stone(rock)
			_batch(parent, label + "_near", list, near, stone, 0.0, ROCK_NEAR_M)
			var field: ArrayMesh = _rock_mesh(rock, "field")
			_batch(parent, label + "_field", list, field, stone, ROCK_NEAR_M, ROCK_FIELD_M)
			var far: ArrayMesh = _rock_mesh(rock, "chip")
			_batch(parent, label + "_far", list, far, stone, ROCK_FIELD_M, 0.0, false)
		elif kind < KIND_GRASS:
			var chip: String = ROCK_KEYS[kind - KIND_CHIP]
			_batch(parent, label, list, _rock_mesh(chip, "chip"), _stone(chip), 0.0, CHIP_M, false)
		else:
			var tufts: ArrayMesh = _fine_grass_mesh(kind - KIND_GRASS)
			var material: ShaderMaterial = _fine_grass_material()
			_batch(parent, label, list, tufts, material, 0.0, FINE_GRASS_M, false)


## The near mesh a boulder plays with: Boulder 01's 12,000-triangle play mesh, or its approved
## scan when a comparison capture asks for it; the other rocks' approved near meshes as they are.
static func _near_detail(rock: String) -> String:
	if rock == "boulder_01" and not approved_closeups:
		return "near_game"
	return "near"


static func _batch(
	parent: Node3D,
	label: String,
	list: Array,
	mesh: Mesh,
	material: Material,
	begin_m: float = 0.0,
	end_m: float = 0.0,
	shadows: bool = true
) -> void:
	if mesh == null or list.is_empty():
		return
	var group := MultiMesh.new()
	group.transform_format = MultiMesh.TRANSFORM_3D
	group.use_colors = true
	group.mesh = mesh
	group.instance_count = list.size()
	for index: int in range(list.size()):
		group.set_instance_transform(index, list[index][0])
		group.set_instance_color(index, list[index][1])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = group
	node.material_override = material
	node.visibility_range_begin = begin_m * DistrictPlan.UNIT
	node.visibility_range_end = end_m * DistrictPlan.UNIT
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


## A plant or outcrop mesh of the approved district (terrain07.gd `_mesh`).
static func _env_mesh(id: String) -> ArrayMesh:
	if _meshes.has(id):
		return _meshes[id]
	var file := FileAccess.open(ENV_DIR + id + ".meshbin", FileAccess.READ)
	if file == null:
		push_error("district nature: no mesh " + id)
		return null
	var count: int = file.get_32()
	var indices: int = file.get_32()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = file.get_buffer(count * 12).to_vector3_array()
	arrays[Mesh.ARRAY_NORMAL] = file.get_buffer(count * 12).to_vector3_array()
	arrays[Mesh.ARRAY_INDEX] = file.get_buffer(indices * 4).to_int32_array()
	if id.ends_with("_SPRAYS"):
		arrays[Mesh.ARRAY_TEX_UV] = file.get_buffer(count * 8).to_vector2_array()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[id] = mesh
	return mesh


## A weathered boulder's mesh at one detail: near, field or chip (rock07.gd `_mesh`).
static func _rock_mesh(key: String, detail: String) -> ArrayMesh:
	var id: String = key + "_" + detail
	if _meshes.has(id):
		return _meshes[id]
	var file := FileAccess.open(ROCK_DIR + key + "/" + detail + ".rock", FileAccess.READ)
	if file == null:
		push_error("district nature: no rock " + id)
		return null
	var count: int = file.get_32()
	var indices: int = file.get_32()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = file.get_buffer(count * 12).to_vector3_array()
	arrays[Mesh.ARRAY_NORMAL] = file.get_buffer(count * 12).to_vector3_array()
	arrays[Mesh.ARRAY_TANGENT] = file.get_buffer(count * 16).to_float32_array()
	arrays[Mesh.ARRAY_TEX_UV] = file.get_buffer(count * 8).to_vector2_array()
	arrays[Mesh.ARRAY_INDEX] = file.get_buffer(indices * 4).to_int32_array()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[id] = mesh
	return mesh


## One tuft family of fine grass, its blades in metres (lowgrass.gd `_family`).
static func _fine_grass_mesh(index: int) -> ArrayMesh:
	var id: String = "fine_grass_%d" % index
	if _meshes.has(id):
		return _meshes[id]
	var rand := RandomNumberGenerator.new()
	rand.seed = 96513 + index * 521
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := Color(FINE_GRASS_COLOURS[index])
	for _clump: int in range(rand.randi_range(4, 8)):
		var angle: float = rand.randf() * TAU
		var r: float = rand.randf_range(.03, .38)
		var origin := Vector3(cos(angle) * r, -.015, sin(angle) * r)
		var base_height: float = rand.randf_range(.09, .25)
		for _blade: int in range(rand.randi_range(6, 12)):
			var turn: float = rand.randf() * TAU
			var direction := Vector3(cos(turn), 0.0, sin(turn))
			var side := Vector3(-direction.z, 0.0, direction.x)
			var height: float = base_height * rand.randf_range(.58, 1.52)
			var width: float = rand.randf_range(.005, .012)
			var root: Vector3 = origin + direction * rand.randf_range(0.0, .085)
			var bend: float = height * rand.randf_range(.22, 1.25)
			var middle: Vector3 = root + direction * bend * .34 + Vector3.UP * height * .68
			var tip: Vector3 = root + direction * bend + Vector3.UP * height
			var colour: Color = base.lerp(Color("a89b6b"), rand.randf() * .53)
			var bottom: Color = colour.darkened(.18)
			var top: Color = colour.lightened(rand.randf_range(.04, .15))
			_blade(
				surface,
				[root - side * width, root + side * width, middle - side * width * .64],
				[bottom, bottom, colour]
			)
			_blade(
				surface,
				[root + side * width, middle + side * width * .64, middle - side * width * .64],
				[bottom, colour, colour]
			)
			_blade(
				surface,
				[middle - side * width * .64, middle + side * width * .64, tip],
				[colour, colour, top]
			)
	var mesh: ArrayMesh = surface.commit()
	_meshes[id] = mesh
	return mesh


static func _blade(surface: SurfaceTool, corners: Array, colours: Array) -> void:
	for index: int in range(3):
		surface.set_color(colours[index])
		surface.set_normal(Vector3.UP)
		surface.add_vertex(corners[index])


static func _stone(key: String) -> ShaderMaterial:
	var id: String = "stone_" + key
	if _materials.has(id):
		return _materials[id]
	var material := ShaderMaterial.new()
	material.shader = DistrictIO.shader(ROCK_DIR + "weathered.gdshader")
	var folder: String = ROCK_DIR + key + "/"
	material.set_shader_parameter(
		"scan_color", DistrictIO.texture(folder + "weathered_diffuse.png")
	)
	material.set_shader_parameter(
		"scan_normal", DistrictIO.texture(folder + "textures/" + key + "_nor_gl_1k.jpg")
	)
	material.set_shader_parameter(
		"scan_arm", DistrictIO.texture(folder + "textures/" + key + "_arm_1k.jpg")
	)
	_materials[id] = material
	return material


## The leaf sprays' material (leaves.gdshader), its distances turned from metres to units.
static func _leaves() -> ShaderMaterial:
	if _materials.has("leaves"):
		return _materials.leaves
	var code: String = DistrictIO.shader(ENV_DIR + "leaves.gdshader").code
	var metres: String = "%.1f" % DistrictPlan.METRES_PER_UNIT
	code = code.replace(
		"world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;",
		"world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz*" + metres + ";"
	)
	code = code.replace("length(VERTEX)", "length(VERTEX)*" + metres)
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("branches", DistrictIO.texture(ENV_DIR + "leaf-spray.png"))
	_materials.leaves = material
	return material


static func _bark() -> StandardMaterial3D:
	return _plain("bark", "665244", false)


static func _plain(id: String, colour: String, both_sides: bool) -> StandardMaterial3D:
	if _materials.has(id):
		return _materials[id]
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.roughness = .95
	material.metallic_specular = .22
	material.albedo_color = Color(colour)
	if both_sides:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[id] = material
	return material


static func _fine_grass_material() -> ShaderMaterial:
	if _materials.has("fine_grass"):
		return _materials.fine_grass
	var shader := Shader.new()
	shader.code = FINE_GRASS_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	_materials.fine_grass = material
	return material
