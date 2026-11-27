extends RefCounted
## The settlement in metres (1.12): the approved district's revision 06 (docs/handoff/
## approved-terrain-region/region, reference/approved-layout.json) applied to the live town.
## Buildings keep their plots, kinds and uids from the save; only how they are drawn changes:
## one metric scale for every model, the approved footprints of the fourteen reviewed kinds, street
## widths in metres (an 8.60 m through road), and the town grid bent into gently curving streets by
## one smooth displacement (`warp`) that roads, plots, traffic and lights all share. The scale puts
## the approved median clear space between neighbouring buildings (59.62 m) on the plot grid
## (site_gen.gd, plots 6 units apart). Display only: nothing here is saved or read by the rules.

const ModelArt = preload("res://world/model_art.gd")

## Metres in one district unit, and the inverse.
const METRES_PER_UNIT: float = 16.6
const UNIT: float = 1.0 / METRES_PER_UNIT
## Plots stand this far apart on the grid (site_gen.gd SLOT_SPACING), in units.
const SLOT_SPACING: float = 6.0
## The widest a building is drawn, in metres, so it keeps to its plot: just over the approved
## district's widest model (the school, 89.1 m).
const MAX_WIDTH_M: float = 91.0
## Revision 06 enlarged every reviewed footprint by this factor (streets06.gd DISTRICT_SCALE).
const DISTRICT_SCALE: float = 1.3
## Street widths in metres (streets06.gd road_network, approved-layout.json roads).
const ROAD_M: Dictionary = {
	"through": 8.6, "lane": 6.2, "works": 7.0, "loading": 6.8, "walk": 3.0, "yard": 6.4
}
## Facade width and depth of the fourteen reviewed kinds before DISTRICT_SCALE, in metres
## (streets06.gd MODEL_FOOTPRINT, from the high-detail meshes' bounds).
const REVIEWED_M: Dictionary = {
	"commerce": Vector2(34.0034023, 22.2522232),
	"depot": Vector2(40.6115622, 36.0536084),
	"smelter": Vector2(32.1928741, 31.0124065),
	"processor": Vector2(40.7442030, 35.1165482),
	"power": Vector2(30.6855643, 24.7333333),
	"lab": Vector2(34.4520675, 21.0012630),
	"farm": Vector2(29.4029455, 31.2181188),
	"water": Vector2(31.7381728, 27.9655986),
	"habitat": Vector2(29.7747658, 27.3175985),
	"school": Vector2(68.5760039, 60.6087914),
	"crew_quarters": Vector2(62.0155039, 46.0115039),
	"clinic": Vector2(33.9881102, 26.3907597),
	"apartment": Vector2(53.9811066, 43.1898920),
	"civic_center": Vector2(60.6060561, 44.4344389),
}
## Storey heights of the fourteen approved meshes, measured in the same 06 scene.
const REVIEWED_HEIGHT_M: Dictionary = {
	"commerce": 10.271,
	"depot": 18.488,
	"smelter": 24.450,
	"processor": 18.430,
	"power": 17.098,
	"lab": 14.548,
	"farm": 10.245,
	"water": 10.869,
	"habitat": 12.346,
	"school": 12.580,
	"crew_quarters": 9.726,
	"clinic": 8.161,
	"apartment": 53.008,
	"civic_center": 15.836,
}
## Kinds that work goods: their lane is a works road and their spur a yard.
const WORKS_ROLES: Array[String] = [
	"factory", "depot", "port", "mine", "harvest", "power", "water", "scrubber", "foodworks"
]
## The bend of the town grid: displacement in units and the wavelength of its two waves.
const WARP_AMPLITUDE: float = 0.85
const WARP_WAVELENGTH: Vector2 = Vector2(47.0, 41.0)
## A building's own offset on its plot, at most, in units, and its turn, at most, in radians.
const JITTER: float = 0.55
const TURN: float = 0.09
## The least space kept between a footprint and its plot's edge, in units.
const PLOT_MARGIN: float = 0.3

## How a plot is reached on the grid (region_view.gd `_access`): by the lane between its row and
## the next toward the middle of town, which it faces (the models' front is +z).
const LANE_OFFSET: float = 3.0


static func access(slot: Vector2) -> Dictionary:
	var side: float = -1.0 if slot.y > 0.0 else 1.0
	return {"lane": slot.y + side * LANE_OFFSET, "yaw": 0.0 if side > 0.0 else PI}


## The reviewed high-detail model for a kind, or "" when the kind has none (it keeps its own model,
## drawn at its metric size).
static func reviewed_kind(kind: String) -> String:
	if REVIEWED_M.has(kind):
		return kind
	return ""


## Facade width and depth in metres: the reviewed footprint, or the kind's model at its
## registered metre scale; never wider than MAX_WIDTH_M.
static func footprint_m(kind: String) -> Vector2:
	var size := Vector2.ZERO
	if REVIEWED_M.has(kind):
		size = Vector2(REVIEWED_M[kind]) * DISTRICT_SCALE
	else:
		var entry: Dictionary = ModelArt.kind_entry(kind)
		var model: Dictionary = ModelArt.registry().get("models", {}).get(
			str(entry.get("model", "")), {}
		)
		var bounds: Array = model.get("size", [])
		var per_metre: float = float(model.get("units_per_metre", 0.0))
		if bounds.size() >= 3 and per_metre > 0.0:
			size = Vector2(float(bounds[0]), float(bounds[2])) / per_metre * DISTRICT_SCALE
		else:
			size = Vector2(40.0, 34.0)
	var widest: float = maxf(size.x, size.y)
	if widest > MAX_WIDTH_M:
		size *= MAX_WIDTH_M / widest
	return size


## The same in district units.
static func footprint(kind: String) -> Vector2:
	return footprint_m(kind) * UNIT


## The scale that draws a model `model_width` wide (its longest horizontal side, in its own units)
## at the kind's metric width, in district units.
static func model_scale(kind: String, model_width: float) -> float:
	var size: Vector2 = footprint(kind)
	return maxf(size.x, size.y) / maxf(model_width, 0.0001)


## The smooth bend shared by everything on the town grid, as an offset at an unbent point. Two
## crossed waves per axis, phased by the region's seed; zero at no point in particular.
static func bend(p: Vector2, seed_value: int) -> Vector2:
	var phase := Vector4(
		_hash01(seed_value, 1) * TAU,
		_hash01(seed_value, 2) * TAU,
		_hash01(seed_value, 3) * TAU,
		_hash01(seed_value, 4) * TAU
	)
	var k := Vector2(TAU / WARP_WAVELENGTH.x, TAU / WARP_WAVELENGTH.y)
	var dx: float = (
		0.62 * sin(p.y * k.y + phase.x) + 0.38 * sin(p.y * k.x * 1.7 + p.x * k.y * 0.35 + phase.y)
	)
	var dz: float = (
		0.62 * sin(p.x * k.x + phase.z) + 0.38 * sin(p.x * k.y * 1.6 + p.y * k.x * 0.4 + phase.w)
	)
	return Vector2(dx, dz) * WARP_AMPLITUDE


static func warp(p: Vector2, seed_value: int) -> Vector2:
	return p + bend(p, seed_value)


## The unbent point that bends to `p`: a few fixed-point steps, exact to well under a millimetre
## for a bend this gentle.
static func unwarp(p: Vector2, seed_value: int) -> Vector2:
	var q: Vector2 = p
	for _step: int in range(8):
		q = p - bend(q, seed_value)
	return q


## The heading an unbent facing takes after bending, at `p`. Yaws are as Godot turns a node about
## +y, with the models' front on +z: a yaw faces (sin yaw, cos yaw) on the ground.
static func bent_yaw(p: Vector2, yaw: float, seed_value: int) -> float:
	var forward := Vector2(sin(yaw), cos(yaw))
	var a: Vector2 = warp(p, seed_value)
	var b: Vector2 = warp(p + forward * 0.5, seed_value)
	var bent: Vector2 = (b - a).normalized()
	return atan2(bent.x, bent.y)


## A building's lot on its plot: where it stands and which way it faces (unbent), its footprint in
## units, and its frontage point on the lane. `slot` is the plot centre, `lane` the lane's z and
## `yaw` the facing the plot grid gives (region_view.gd `_access`). The offset and turn are the
## plot's own, keyed by the plot index, so a save draws its town the same way every time.
static func lot(
	slot: Vector2, lane: float, yaw: float, kind: String, key: int, seed_value: int
) -> Dictionary:
	var size: Vector2 = footprint(kind)
	var free: Vector2 = (
		(Vector2.ONE * SLOT_SPACING - Vector2(size.x, size.y)) * 0.5 - Vector2.ONE * PLOT_MARGIN
	)
	var room := Vector2(clampf(free.x, 0.0, JITTER), clampf(free.y, 0.0, JITTER))
	var shift := Vector2(
		(_hash01(key, 11 + seed_value) * 2.0 - 1.0) * room.x,
		(_hash01(key, 13 + seed_value) * 2.0 - 1.0) * room.y * 0.5
	)
	var centre: Vector2 = slot + shift
	var toward: float = signf(lane - slot.y)
	# The front of the footprint keeps a verge to the lane: never closer than half a lane's width
	# and three metres of shoulder.
	var verge: float = float(ROAD_M.lane) * 0.5 * UNIT + 3.0 * UNIT
	var front_line: float = lane - toward * verge
	var reach: float = centre.y + toward * size.y * 0.5
	if toward > 0.0 and reach > front_line:
		centre.y -= reach - front_line
	elif toward < 0.0 and reach < front_line:
		centre.y += front_line - reach
	var turn: float = (_hash01(key, 17 + seed_value) * 2.0 - 1.0) * TURN
	return {
		"pos": centre,
		"yaw": yaw + turn,
		"size": size,
		"front": Vector2(centre.x, centre.y + toward * size.y * 0.5),
		"lane": lane,
	}


## The lane kind a building is reached by: works for goods, otherwise residential.
static func lane_kind(role: String) -> String:
	return "works" if role in WORKS_ROLES else "lane"


## Points every `step` units along an unbent polyline, bent: the drawn path of a straight street.
static func bent_path(
	points: PackedVector2Array, step: float, seed_value: int
) -> PackedVector2Array:
	var out := PackedVector2Array()
	for index: int in range(points.size() - 1):
		var a: Vector2 = points[index]
		var b: Vector2 = points[index + 1]
		var pieces: int = maxi(1, ceili(a.distance_to(b) / step))
		for piece: int in range(pieces):
			out.append(warp(a.lerp(b, float(piece) / pieces), seed_value))
	if not points.is_empty():
		out.append(warp(points[points.size() - 1], seed_value))
	return out


static func _hash01(key: int, salt: int) -> float:
	var h: int = posmod((key + 1) * 73856093 ^ (salt + 7) * 19349663, 1000003)
	return float(h) / 1000003.0
