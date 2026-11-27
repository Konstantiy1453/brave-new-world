extends "res://world/building_models.gd"
## The regional ground: relief sampled from the planet into a height field, the terraces cut for
## plots, the wider landscape around generated worlds, rivers, lakes, the sea, trees and rocks.
## Everything placed on the ground afterwards reads the height field (region_view.gd).

const Rules = preload("res://simulation/rules.gd")
const DistrictLayout = preload("res://world/district/district_layout.gd")
const DistrictPlan = preload("res://world/district/district_plan.gd")
const WorldGen2 = preload("res://world/geo2/world_gen2.gd")
const DistrictGround = preload("res://world/district/district_ground.gd")
## Older worlds keep the field they were drawn on, to the vertex; towns on newer ones need more room.
const OLD_FIELD: Dictionary = {
	"res": 86, "width": 57.0, "depth": 47.0, "trees": 160, "gate": 24.0, "rows": 2
}
const WIDE_FIELD: Dictionary = {
	"res": 112, "width": 96.0, "depth": 72.0, "trees": 360, "gate": 44.0, "rows": 3
}
## Rows of triangles between frames: one long block here is what a cold region's worst frame was.
const TRIANGLE_ROWS: int = 24
const EDGE_MARGIN: float = 1.5
## Generated worlds: the playable field sits in a wider landscape that runs on into the haze, so
## its edge never shows. Rings of coarser ground reach this far past the field on every side.
const APRON_RINGS: int = 16
const APRON_REACH: float = 520.0
## Within this distance of the field the apron keeps the planet's true relief; beyond it the same
## relief is spread wider, as distant ranges seen through the haze, and stays on the planet.
const APRON_TRUE: float = 40.0
const APRON_SPREAD: float = 0.22
const APRON_LATITUDE: float = 88.0
## CC-GEO-2.3's water (1.12) in the approved district's muted palette: greyer and deeper than the
## older districts' sea, lakes and rivers, which read as saturated cyan under its evening light.
const NATURAL_WATER: Dictionary = {
	"sea": Color("2f4b55"),
	"lake": Color("35545b"),
}
## Every plot is a level pad graded into the slope: flat to PAD_FLAT from its centre, back to the
## natural ground by PAD_BLEND along a smooth curve, so no wall or mesa is cut.
const PAD_FLAT: float = 2.35
## The flat margin round a footprint and the blend back into the land, in metres; a free plot's
## pad; and the cell pads are binned by, in units.
const PAD_MARGIN_M: float = 22.0
const PAD_BLEND_M: float = 46.0
const FREE_PAD_M: float = 70.0
const PAD_BIN: float = 3.0
const PAD_BLEND: float = 5.2
## A pad never sits lower than this above the sea.
const PAD_ABOVE_SEA: float = 0.35
## Neighbouring pads' levels are pulled this share toward their mean, this many times.
const PAD_RELAX: float = 0.5
const PAD_RELAX_PASSES: int = 2
## Where the softening of tall relief begins to bite, in region units: the planet's relief is
## steep at the diorama's scale, so peaks grow on a log curve past this knee.
const RELIEF_KNEE: float = 3.2
## Natural ground on generated worlds (1.9 terrain pass): passes of a 1-2-1 blur over the whole
## landscape grid, which round off facets and stair-step shores; layered noise for detail, weak
## near water and strong in the hills (frequency per unit, amplitudes in units); ridges on high
## ground; a beach profile within SHORE_BAND of the sea; inland sites keep their lowest ground
## INLAND_FLOOR above the sea, so no sea shows there; the town's ground is pulled TOWN_PULL of
## the way toward its own level inside TOWN_CALM.
const SMOOTH_PASSES: int = 3
const DETAIL_FREQUENCY: float = 0.075
const DETAIL_LOW: float = 0.25
const DETAIL_HIGH: float = 1.45
const RIDGE_AMPLITUDE: float = 1.6
const SHORE_BAND: float = 1.6
const SHORE_POWER: float = 1.5
## The share of the beach profile that is straight, so the ground still crosses the waterline at
## a slope rather than touching it flat (`_shore`).
const SHORE_LINEAR: float = 0.35
const INLAND_FLOOR: float = 0.45
const INLAND_DATA_FLOOR: float = 0.0004
const INLAND_SWELL: float = 0.6
const TOWN_CALM: Vector2 = Vector2(10.0, 22.0)
const TOWN_PULL: float = 0.65
## CC-GEO-2.3 towns (1.12, `_settle_town`): full calm within TOWN_SETTLE.x units of a plot, none past
## TOWN_SETTLE.y; the share of hills and hollows taken off the broad lie, and of the broad slope
## eased toward the town's level; the broad lie's blur radius in field cells (three box passes);
## the lattice the distance to the plots is kept on; and the fade to nothing at the field's edge.
const TOWN_SETTLE: Vector2 = Vector2(5.0, 20.0)
const TOWN_RELIEF_EASE: float = 0.85
const TOWN_SLOPE_EASE: float = 0.5
## A hollow below the sea's level away from open water is raised this far over it (`_fill_hollows`).
const HOLLOW_LIFT: float = 0.2
const TOWN_BROAD_CELLS: int = 12
const TOWN_CALM_CELL: float = 2.0
const TOWN_EDGE_FADE: float = 7.0
## The ground leaves the sea's flat surface steeply (`_clear_waterline`), because ground and water
## within the depth buffer's precision of each other flicker as the camera moves: within
## WATERLINE_BAND of the sea's level, heights move away from it by up to WATERLINE_LIP on a smooth
## curve whose slope at the waterline is 1 + WATERLINE_LIP / WATERLINE_REACH. The curve is
## continuous and odd, so every shoreline stays where the ground put it (a fixed lift would snap the
## coast to the grid). Pads stand higher, at PAD_ABOVE_SEA, and keep their level.
const WATERLINE_LIP: float = 0.1
## CC-GEO-2.3's relief comes from measured terrain: flatter coastal plains take a stronger lip,
## its steepest steps are eased to STEP_LIMIT between neighbouring field vertices, and an inland
## river bed stays above the sea's level (1.12).
const WATERLINE_LIP_23: float = 0.15
const STEP_LIMIT: float = 1.45
const STEP_PASSES: int = 6
const INLAND_BED: float = 0.03
const WATERLINE_REACH: float = 0.05
const WATERLINE_BAND: float = 0.3
## Detail fades out over the coarse far rings of the landscape, past the field's edge.
const DETAIL_FADE: Vector2 = Vector2(10.0, 60.0)
const SLOT_SPACING: float = 6.0
var field_res: int = int(OLD_FIELD.res)
var field_width: float = float(OLD_FIELD.width)
var field_depth: float = float(OLD_FIELD.depth)
var half_width: float = field_width / 2.0
var half_depth: float = field_depth / 2.0
var tree_count: int = int(OLD_FIELD.trees)
var gate_reach: float = float(OLD_FIELD.gate)
var rows_per_frame: int = int(OLD_FIELD.rows)
var height_field := PackedFloat32Array()
## A generated world's ground material, the region's own (district_ground.gd): the town's streets
## give it their shoulders once drawn.
var ground_material: ShaderMaterial
## Vertices of the last landscape raised out of inland hollows of the sea (`_fill_hollows`).
var hollows_filled: int = 0
var forest_field := PackedFloat32Array()
## Temperature (degrees) and rainfall at each field vertex of a generated world, for its nature.
var climate_field := PackedVector2Array()
var field_has_sea: bool = false
## Terrace level per visible plot, keyed by its slot on the plot grid: Vector3(x, level, z).
## Each pad graded into the ground (1.12): the oriented footprint of the building on its plot at
## its drawn place (district_plan.gd), or a free plot's default, flat over the footprint and a
## margin wider than one cell of the ground, so a building's ground is exactly level.
## {id: {"centre": Vector2, "half": Vector2, "yaw": float, "level": float}}
var plot_levels: Dictionary = {}
## Pads by PAD_BIN cell, for the ground's lookups.
var pad_bins: Dictionary = {}
var terrace_region: int = -1
var parcel_surveys: Dictionary = {}
## Generated worlds: the landing pods stand on the nearest cell of the plot grid that holds no
## plot, so no building is ever put down on top of them.
var pods_spot: Vector2 = Vector2(-6.0, 0.0)


## The town grew beside the fixed river in old worlds; in generated worlds plots avoid the rivers.
func _town_offset() -> float:
	if Geo.is_generated(str(world.version)):
		return 0.0
	return 12.0 if world.regions[selected_region].river else 0.0


func _sample_ground(x: float, z: float) -> float:
	var ll := _local_coordinate(x, z)
	var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
	return _ground_from_geo(x, z, g, ll)


func _ground(x: float, z: float) -> float:
	if height_field.size() != (field_res + 1) * (field_res + 1):
		return _sample_ground(x, z)
	var fx: float = clampf((x / field_width + 0.5) * field_res, 0.0, field_res - 0.001)
	var fz: float = clampf((z / field_depth + 0.5) * field_res, 0.0, field_res - 0.001)
	var ix: int = int(fx)
	var iz: int = int(fz)
	var tx: float = fx - ix
	var tz: float = fz - iz
	var row: int = iz * (field_res + 1) + ix
	var next: int = row + field_res + 1
	return lerpf(
		lerpf(height_field[row], height_field[row + 1], tx),
		lerpf(height_field[next], height_field[next + 1], tx),
		tz
	)


## The ground as its mesh draws it: the same triangles (each cell split from its +x corner to its
## +z corner), so paving laid a few centimetres above it never dips under (1.12).
func _mesh_ground(x: float, z: float) -> float:
	if height_field.size() != (field_res + 1) * (field_res + 1):
		return _sample_ground(x, z)
	var fx: float = clampf((x / field_width + 0.5) * field_res, 0.0, field_res - 0.001)
	var fz: float = clampf((z / field_depth + 0.5) * field_res, 0.0, field_res - 0.001)
	var ix: int = int(fx)
	var iz: int = int(fz)
	var tx: float = fx - ix
	var tz: float = fz - iz
	var row: int = iz * (field_res + 1) + ix
	var next: int = row + field_res + 1
	if tx + tz <= 1.0:
		var h00: float = height_field[row]
		return h00 + (height_field[row + 1] - h00) * tx + (height_field[next] - h00) * tz
	var h11: float = height_field[next + 1]
	return (
		h11 + (height_field[next] - h11) * (1.0 - tx) + (height_field[row + 1] - h11) * (1.0 - tz)
	)


## The ground: the region's relief, with every visible plot's terrace cut into it.
func _ground_from_geo(x: float, z: float, g: Dictionary, ll: Vector2) -> float:
	if terrace_region != selected_region:
		_prepare_terraces()
	return _terraced(x, z, _relief_from_geo(x, z, g, ll))


func _relief_from_geo(x: float, z: float, g: Dictionary, ll: Vector2) -> float:
	if not bool(g.land):
		return (
			-1.0 + float(g.height) * 30.0
			if str(world.version) == "CC-GEO-1.4"
			else _lift((float(g.height) - region_ground) * 30.0)
		)
	var detail: float = noise.get_noise_2d(x * .65, z * .65) * .33
	var raw: float = _lift((float(g.height) - region_ground) * 30.0 + detail)
	# Planned development terraces blend smoothly into the actual regional relief.
	var town_center := Vector2(_town_offset(), 0)
	var d: float = Vector2(x, z).distance_to(town_center)
	var blend: float = smoothstep(9.0, 18.0, d)
	var height: float = lerpf(.25, raw, blend)
	if Geo.is_generated(str(world.version)):
		var p := Vector2(x, z)
		for lake in local_lakes:
			var distance: float = p.distance_to(lake.center)
			if distance < lake.radius * 1.25:
				height = lerpf(
					lake.height - .4,
					height,
					smoothstep(lake.radius * .8, lake.radius * 1.25, distance)
				)
	return height


## Generated worlds soften the relief's extremes: gentle ground is as it was, a peak that would
## stand thirty units over the town stands about ten, so no plot ends up on a pillar. Water is
## lifted by the same curve, so every shore stays where it was. Older worlds keep their relief.
func _lift(raw: float) -> float:
	if not Geo.is_generated(str(world.version)):
		return raw
	return signf(raw) * RELIEF_KNEE * log(1.0 + absf(raw) / RELIEF_KNEE)


## The sea's surface in the region's units.
func sea_level() -> float:
	return _lift(-region_ground * 30.0) + .04


## Generated worlds cut a level terrace for every plot the colony can see; older worlds keep the
## ground they were drawn with, to the vertex.
func _prepare_terraces() -> void:
	plot_levels.clear()
	pad_bins.clear()
	terrace_region = selected_region
	if not Geo.is_generated(str(world.version)):
		return
	var kinds: Dictionary = plot_kinds(selected_region)
	var plots: Array = world.regions[selected_region].get("plots", [])
	for index: int in range(plots.size()):
		if bool(plots[index].get("hidden", false)):
			continue
		_add_pad(index, plot_lot(selected_region, index, str(kinds.get(index, ""))))
		if plot_levels.has(index):
			plot_levels[index].built = kinds.has(index)
	pods_spot = landing_spot(selected_region)
	_add_pad(-1, slot_lot(pods_spot, "", -1))
	for colony: Dictionary in state.get("settlements", []):
		if int(colony.region) != selected_region:
			continue
		for i: int in range(colony.buildings.size()):
			var facility: Dictionary = colony.buildings[i]
			if int(facility.get("plot", -1)) >= 0:
				continue
			var role: String = str(Rules.read("economy").buildings.get(facility.kind, {}).get("role", ""))
			if role in ["harbor", "seabed"]:
				continue
			_add_pad(-2 - i, unplotted_lot(selected_region, i, str(facility.kind)))
			plot_levels[-2 - i].built = true
	if plot_levels.has(-1):
		plot_levels[-1].built = true


## The kind standing on each plot of a region's town: {plot index: kind}.
func plot_kinds(region: int) -> Dictionary:
	var kinds: Dictionary = {}
	for s: Dictionary in state.get("settlements", []):
		if int(s.get("region", -1)) != region:
			continue
		for b: Dictionary in s.get("buildings", []):
			if int(b.get("plot", -1)) >= 0:
				kinds[int(b.plot)] = str(b.kind)
	return kinds


## The seed of a region's bend (district_plan.gd): the world's seed and the region.
func district_key(region: int = -1) -> int:
	var at: int = selected_region if region < 0 else region
	return int(world.get("seed", 0)) * 131 + at * 7919


## A building's drawn lot on a plot (district_plan.gd `lot`), bent: where it stands, which way it
## faces, its footprint in units, the front of its footprint and its lane.
func plot_lot(region: int, plot: int, kind: String) -> Dictionary:
	var plots: Array = world.regions[region].get("plots", [])
	if plot < 0 or plot >= plots.size():
		return {}
	var slot := Vector2(float(plots[plot].x), float(plots[plot].z))
	if Geo.is_generated(str(world.version)):
		slot = _district_survey(region).plots[plot]
	return slot_lot(slot, kind, plot, region)


## Older facilities without a saved parcel use the same surveyed reserve as the landing camp.
func unplotted_lot(region: int, index: int, kind: String) -> Dictionary:
	var survey: Dictionary = _district_survey(region)
	var rank: int = 0
	for colony: Dictionary in state.get("settlements", []):
		if int(colony.region) != region:
			continue
		for i: int in range(index):
			if int(colony.buildings[i].get("plot", -1)) < 0:
				rank += 1
	var spots: Array = survey.spares
	return slot_lot(spots[rank], kind, 1000 + index, region)


func slot_lot(slot: Vector2, kind: String, key: int, region: int = -1) -> Dictionary:
	var seed_value: int = district_key(region)
	var reach: Dictionary = DistrictPlan.access(slot)
	var lot: Dictionary = DistrictPlan.lot(
		slot, float(reach.lane), float(reach.yaw), kind, key, seed_value
	)
	if kind == "":
		lot.size = Vector2.ONE * FREE_PAD_M * DistrictPlan.UNIT
	var plain: Vector2 = lot.pos
	lot.slot = slot
	lot.plain = plain
	lot.plain_front = lot.front
	lot.plain_yaw = float(lot.yaw)
	lot.pos = DistrictPlan.warp(plain, seed_value)
	lot.yaw = DistrictPlan.bent_yaw(plain, float(lot.yaw), seed_value)
	lot.front = DistrictPlan.warp(lot.front, seed_value)
	return lot


func _add_pad(id: int, lot: Dictionary) -> void:
	if lot.is_empty():
		return
	var centre: Vector2 = lot.pos
	var half: Vector2 = Vector2(lot.size) * 0.5 + Vector2.ONE * PAD_MARGIN_M * DistrictPlan.UNIT
	var ll := _local_coordinate(centre.x, centre.y)
	var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
	plot_levels[id] = {
		"centre": centre,
		"half": half,
		"yaw": float(lot.yaw),
		"level": _relief_from_geo(centre.x, centre.y, g, ll),
	}
	var reach: float = half.length() + PAD_BLEND_M * DistrictPlan.UNIT
	var low := Vector2i(floori((centre.x - reach) / PAD_BIN), floori((centre.y - reach) / PAD_BIN))
	var high := Vector2i(floori((centre.x + reach) / PAD_BIN), floori((centre.y + reach) / PAD_BIN))
	for bz: int in range(low.y, high.y + 1):
		for bx: int in range(low.x, high.x + 1):
			var key := Vector2i(bx, bz)
			if not pad_bins.has(key):
				pad_bins[key] = []
			pad_bins[key].append(id)


## Whether a point lies on any pad's flat.
func _on_pad(x: float, z: float) -> bool:
	for id: int in pad_bins.get(Vector2i(floori(x / PAD_BIN), floori(z / PAD_BIN)), []):
		if _pad_distance(plot_levels[id], Vector2(x, z)) <= 0.0:
			return true
	return false


## Distance in units from a point to the outside of a pad's flat (zero on it).
static func _pad_distance(pad: Dictionary, at: Vector2) -> float:
	var local: Vector2 = (at - Vector2(pad.centre)).rotated(float(pad.yaw))
	var outside: Vector2 = (local.abs() - Vector2(pad.half)).max(Vector2.ZERO)
	return outside.length()


## Distance in units from a point to the nearest building's footprint (the pad without its
## margin) or the landing camp; INF when none is within a pad's reach.
func footprint_clearance(x: float, z: float) -> float:
	var at := Vector2(x, z)
	var best: float = INF
	var margin: float = PAD_MARGIN_M * DistrictPlan.UNIT
	for id: int in pad_bins.get(Vector2i(floori(x / PAD_BIN), floori(z / PAD_BIN)), []):
		var pad: Dictionary = plot_levels[id]
		if not bool(pad.get("built", false)):
			continue
		var local: Vector2 = (at - Vector2(pad.centre)).rotated(float(pad.yaw))
		var outside: Vector2 = local.abs() - (Vector2(pad.half) - Vector2.ONE * margin)
		best = minf(
			best, outside.max(Vector2.ZERO).length() + minf(maxf(outside.x, outside.y), 0.0)
		)
	return best


## The site's temperature (degrees) and rainfall at a point of the field (generated worlds).
func climate_at(x: float, z: float) -> Vector2:
	if climate_field.size() != (field_res + 1) * (field_res + 1):
		return Vector2(14.0, 0.45)
	var fx: int = clampi(roundi((x / field_width + 0.5) * field_res), 0, field_res)
	var fz: int = clampi(roundi((z / field_depth + 0.5) * field_res), 0, field_res)
	return climate_field[fz * (field_res + 1) + fx]


## The nearest dry cell of the plot grid, off the main street, that no plot has been given.
## The landing camp's cell in a region: the first free slot of the plot grid, ring by ring from
## the centre, on land and clear of rivers and lakes. The district stands its pods there and the
## night lights put the camp's first lights there (light_field.gd), so both show the same place.
## Any region, not only the one on show.
func landing_spot(region: int) -> Vector2:
	if region < 0 or region >= world.get("regions", []).size():
		return Vector2(-6.0, 0.0)
	if Geo.is_generated(str(world.version)):
		return _district_survey(region).camp
	var reg: Dictionary = world.regions[region]
	var taken: Dictionary = {}
	for plot: Dictionary in reg.get("plots", []):
		taken[_slot_key(float(plot.x), float(plot.z))] = true
	var water: Array = _water_marks(reg)
	for ring: int in range(1, 8):
		for iz: int in range(-ring, ring + 1):
			for ix: int in range(-ring, ring + 1):
				if maxi(absi(ix), absi(iz)) != ring or ix == 0:
					continue
				if taken.has(Vector2i(ix, iz)):
					continue
				var x: float = ix * SLOT_SPACING
				var z: float = iz * SLOT_SPACING
				var ll: Vector2 = _coordinate_in(reg, x, z)
				var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
				if not bool(g.land) or _wet(water, Vector2(x, z), 1.6):
					continue
				return Vector2(x, z)
	return Vector2(-6.0, 0.0)


## A region's rivers and lakes in its own district units, as the district draws them
## (`_prepare_local_rivers`): [kind, a or centre, b, width or radius].
func _water_marks(reg: Dictionary) -> Array:
	var marks: Array = []
	for lake: Dictionary in world.get("lakes", []):
		var center: Vector2 = _point_to_local_in(reg, float(lake.lat), float(lake.lon))
		var radius: float = float(lake.get("radius_degrees", .45)) * 4.0
		if absf(center.x) > half_width - radius or absf(center.y) > half_depth - radius:
			continue
		marks.append(["lake", center, center, radius])
	return marks


static func _wet(marks: Array, point: Vector2, margin: float) -> bool:
	for mark: Array in marks:
		var a: Vector2 = mark[1]
		var b: Vector2 = mark[2]
		var t: float = clampf((point - a).dot(b - a) / maxf(a.distance_squared_to(b), .001), 0, 1)
		if point.distance_to(a.lerp(b, t)) < float(mark[3]) * margin:
			return true
	return false


## Reserve the entire rotated footprint before a saved or newly occupied plot is drawn.
## The survey depends on all parcel IDs, including hidden and vacant ones, so later construction
## keeps existing buildings, access roads and the coast in the same places.
func _district_survey(region: int) -> Dictionary:
	var reg: Dictionary = world.regions[region]
	var plots: Array = reg.get("plots", [])
	var reserve: int = 4
	for colony: Dictionary in state.get("settlements", []):
		if int(colony.region) == region:
			var count: int = 0
			for facility: Dictionary in colony.buildings:
				if int(facility.get("plot", -1)) < 0:
					count += 1
			reserve = maxi(reserve, count)
	if parcel_surveys.has(region) and parcel_surveys[region].plots.size() == plots.size() and parcel_surveys[region].spares.size() >= reserve:
		return parcel_surveys[region]
	var shore: Dictionary = {}
	if bool(reg.get("coast", false)):
		var direction := Vector2.ZERO
		var shortest: float = INF
		var nearest := Vector2.ZERO
		for heading: int in range(20):
			var axis := Vector2.RIGHT.rotated(TAU * heading / 20.0)
			for reach: float in [4.0, 8.0, 14.0, 23.0, 35.0, 52.0]:
				var ll := _coordinate_in(reg, axis.x * reach, axis.y * reach)
				if bool(Geo.sample_geo(ll.x, ll.y, noise, str(world.version)).land):
					continue
				direction += axis / reach
				if reach < shortest:
					shortest = reach
					nearest = axis
				break
		if direction.length_squared() < 0.0001:
			direction = nearest if nearest != Vector2.ZERO else Vector2.RIGHT.rotated(district_key(region))
		shore = {
			"out": direction.normalized(), "reach": clampf(shortest, 14.0, 27.0),
			"phase": Vector2(DistrictPlan._hash01(district_key(region), 31), DistrictPlan._hash01(district_key(region), 37)) * TAU
		}
	var lakes: Array = []
	for lake: Dictionary in world.get("lakes", []):
		var at: Vector2 = _point_to_local_in(reg, float(lake.lat), float(lake.lon))
		lakes.append({"center": at, "radius": float(lake.get("radius_degrees", .45)) * 4.0})
	var half := Vector2(59.0, 51.0)
	var surveyed: Dictionary = DistrictLayout.survey(plots, shore, lakes, half, reserve)
	while surveyed.is_empty():
		half += Vector2.ONE * DistrictLayout.PARCEL_PITCH * 2.0
		surveyed = DistrictLayout.survey(plots, shore, lakes, half, reserve)
	parcel_surveys[region] = surveyed
	return surveyed


func _coordinate_in(reg: Dictionary, x: float, z: float) -> Vector2:
	var lat: float = float(reg.get("canonical_lat", reg.lat)) - z / 4.0
	var lon: float = float(reg.get("canonical_lon", reg.lon)) + x / 4.0
	return Geo.project_coordinate(lat, lon, world)


func _point_to_local_in(reg: Dictionary, lat: float, lon: float) -> Vector2:
	var ll: Vector2 = Geo.unproject_coordinate(lat, lon, world)
	return Vector2(
		wrapf(ll.y - float(reg.get("canonical_lon", reg.lon)), -180, 180) * 4.0,
		(float(reg.get("canonical_lat", reg.lat)) - ll.x) * 4.0
	)


## Which plots the terrain was cut for: a cached region is rebuilt once a hidden plot is found.
func terrace_signature(region: int) -> String:
	if region < 0 or region >= world.get("regions", []).size():
		return ""
	if not Geo.is_generated(str(world.version)):
		return "old"
	var visible: PackedStringArray = []
	var plots: Array = world.regions[region].get("plots", [])
	var kinds: Dictionary = plot_kinds(region)
	for index: int in range(plots.size()):
		if not bool(plots[index].get("hidden", false)):
			visible.append("%d%s" % [index, ":" + str(kinds[index]) if kinds.has(index) else ""])
	return ",".join(visible)


static func _slot_key(x: float, z: float) -> Vector2i:
	return Vector2i(roundi(x / SLOT_SPACING), roundi(z / SLOT_SPACING))


## The ground graded toward the nearby pads: exactly level on a pad, and between pads a weighted
## mean of their levels that leans on the nearest one, eased back into the natural slope over
## PAD_BLEND_M.
func _terraced(x: float, z: float, height: float) -> float:
	if plot_levels.is_empty():
		return height
	var at := Vector2(x, z)
	var ids: Array = pad_bins.get(Vector2i(floori(x / PAD_BIN), floori(z / PAD_BIN)), [])
	var blend: float = PAD_BLEND_M * DistrictPlan.UNIT
	var weights: float = 0.0
	var levels: float = 0.0
	var strongest: float = 0.0
	# On a building's own footprint its pad's level; on overlapping margins the pad the point is
	# deepest inside.
	var margin: float = PAD_MARGIN_M * DistrictPlan.UNIT
	var flat: float = INF
	var deepest: float = -INF
	for id: int in ids:
		var pad: Dictionary = plot_levels[id]
		var local: Vector2 = (at - Vector2(pad.centre)).rotated(float(pad.yaw))
		var depth: float = minf(pad.half.x - absf(local.x), pad.half.y - absf(local.y))
		if depth >= margin:
			return float(pad.level)
		if depth >= 0.0 and depth > deepest:
			deepest = depth
			flat = float(pad.level)
	if is_finite(flat):
		return flat
	for id: int in ids:
		var pad: Dictionary = plot_levels[id]
		var d: float = _pad_distance(pad, at)
		if d >= blend:
			continue
		var reach: float = 1.0 - _smoother(0.0, blend, d)
		var weight: float = reach / pow(maxf(d, 0.05), 2.0)
		weights += weight
		levels += weight * float(pad.level)
		strongest = maxf(strongest, reach)
	if weights <= 0.0:
		return height
	return lerpf(height, levels / weights, strongest)


## Smootherstep: no kink where a pad's flat meets its slope, nor where the slope meets the land.
static func _smoother(edge0: float, edge1: float, value: float) -> float:
	var t: float = clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## Each pad's level from the natural ground under it (the field before pads), averaged over the
## footprint so a single bump does not set it, and kept above the sea; neighbouring pads then lean
## toward each other, so the steps between them stay low.
func _level_pads() -> void:
	var sea: float = sea_level()
	for id: int in plot_levels:
		var pad: Dictionary = plot_levels[id]
		var centre: Vector2 = pad.centre
		var half: Vector2 = Vector2(pad.half) * 0.6
		var total: float = 0.0
		for sz: int in [-1, 0, 1]:
			for sx: int in [-1, 0, 1]:
				var at: Vector2 = (
					centre + Vector2(sx * half.x, sz * half.y).rotated(-float(pad.yaw))
				)
				total += _ground(at.x, at.y)
		pad.level = maxf(total / 9.0, sea + PAD_ABOVE_SEA)
	var reach: float = DistrictPlan.SLOT_SPACING * 1.25
	for _pass: int in range(PAD_RELAX_PASSES):
		var relaxed: Dictionary = {}
		for id: int in plot_levels:
			var pad: Dictionary = plot_levels[id]
			var sum: float = 0.0
			var count: int = 0
			for other: int in plot_levels:
				if other == id:
					continue
				var near: Dictionary = plot_levels[other]
				if Vector2(near.centre).distance_to(pad.centre) <= reach:
					sum += float(near.level)
					count += 1
			var level: float = float(pad.level)
			if count > 0:
				level = lerpf(level, sum / count, PAD_RELAX)
			relaxed[id] = maxf(level, sea + PAD_ABOVE_SEA)
		for id: int in relaxed:
			plot_levels[id].level = relaxed[id]


func _water_height_at(x: float, z: float, margin: float = 1.0) -> float:
	var point := Vector2(x, z)
	var result: float = -INF
	for lake in local_lakes:
		if point.distance_to(lake.center) < float(lake.radius) * margin:
			result = maxf(result, lake.height)
	return result


func _local_coordinate(x: float, z: float) -> Vector2:
	var reg: Dictionary = world.regions[selected_region]
	var lat: float = float(reg.get("canonical_lat", reg.lat)) - z / 4.0
	var lon: float = float(reg.get("canonical_lon", reg.lon)) + x / 4.0
	return Geo.project_coordinate(lat, lon, world)


## Worlds whose generator spreads plots further out get the larger field.
func _fit_field() -> void:
	# The site rules a world was generated with (CC-GEO-2.3 keeps 2.2's plot grid), as the
	# generator reads them.
	var version: String = str(world.get("version", ""))
	var rules: Dictionary = WorldGen2.rules_for(version) if Geo.is_generated(version) else {}
	var field: Dictionary = WIDE_FIELD if rules.get("plots", {}).has("slot_x") else OLD_FIELD
	field_res = int(field.res)
	field_width = float(field.width)
	field_depth = float(field.depth)
	half_width = field_width / 2.0
	half_depth = field_depth / 2.0
	tree_count = int(field.trees)
	gate_reach = float(field.gate)
	rows_per_frame = int(field.rows)


func _point_to_local(lat: float, lon: float) -> Vector2:
	var reg: Dictionary = world.regions[selected_region]
	var ll: Vector2 = Geo.unproject_coordinate(lat, lon, world)
	return Vector2(
		wrapf(ll.y - float(reg.get("canonical_lon", reg.lon)), -180, 180) * 4.0,
		(float(reg.get("canonical_lat", reg.lat)) - ll.x) * 4.0
	)


func _clip_segment(a: Vector2, b: Vector2) -> Vector2:
	# Liang-Barsky against the exact local ground bounds; returns segment t's.
	var d := b - a
	var low: float = 0
	var high: float = 1
	var p: Array = [-d.x, d.x, -d.y, d.y]
	var q: Array = [a.x + half_width, half_width - a.x, a.y + half_depth, half_depth - a.y]
	for i in range(4):
		if absf(float(p[i])) < .000001:
			if float(q[i]) < 0:
				return Vector2(-1, -1)
		else:
			var t: float = float(q[i]) / float(p[i])
			if float(p[i]) < 0:
				low = maxf(low, t)
			else:
				high = minf(high, t)
			if low > high:
				return Vector2(-1, -1)
	return Vector2(low, high)


func _prepare_local_rivers() -> void:
	if Geo.is_generated(str(world.version)):
		var half: Vector2 = _district_survey(selected_region).half
		half_width = half.x
		half_depth = half.y
		field_width = half.x * 2.0
		field_depth = half.y * 2.0
		field_res = maxi(field_res, ceili(field_width / 0.86))
	local_river_segments.clear()
	local_lakes.clear()
	height_field = PackedFloat32Array()
	var reg: Dictionary = world.regions[selected_region]
	region_ground = float(Geo.sample_geo(reg.lat, reg.lon, noise, str(world.version)).height)
	if str(world.version) == "CC-GEO-1.4":
		return
	for lake in world.get("lakes", []):
		var center := _point_to_local(float(lake.lat), float(lake.lon))
		var radius: float = float(lake.get("radius_degrees", .45)) * 4.0
		if absf(center.x) > half_width - radius or absf(center.y) > half_depth - radius:
			continue
		var h: float = float(lake.get("height", float(lake.get("elevation", 0)) / 4300.0))
		local_lakes.append(
			{"center": center, "radius": radius, "height": _lift((h - region_ground) * 30.0) + .04}
		)


func _forest_chance(g: Dictionary) -> float:
	if not bool(g.land) or str(g.get("biome", "")) in ["alpine", "desert", "tundra"]:
		return 0.0
	return (
		clampf((float(g.rainfall) - .23) * 1.45, 0, .86) * smoothstep(-2, 10, float(g.temperature))
	)


func _build_terrain(token: int) -> bool:
	if Geo.is_generated(str(world.version)):
		return await _build_landscape(token)
	var reg: Dictionary = world.regions[selected_region]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var resolution: int = field_res
	var vertices: PackedVector3Array = []
	var colors: PackedColorArray = []
	vertices.resize((resolution + 1) * (resolution + 1))
	colors.resize(vertices.size())
	var heights := PackedFloat32Array()
	heights.resize(vertices.size())
	var forests := PackedFloat32Array()
	forests.resize(vertices.size())
	terrain_unique_samples = 0
	field_has_sea = false
	for iz in range(resolution + 1):
		for ix in range(resolution + 1):
			var x: float = (float(ix) / resolution - .5) * field_width
			var z: float = (float(iz) / resolution - .5) * field_depth
			var ll := _local_coordinate(x, z)
			var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
			terrain_unique_samples += 1
			field_has_sea = field_has_sea or not bool(g.land)
			# The ground shader colours from data, as the globe does: temperature, rainfall,
			# wet banks and height. See world/shaders.gd.
			var data: Color = Shaders.encode(
				float(g.height), float(g.temperature), float(g.rainfall), 0.0
			)
			data.b = 1.0 if is_finite(_water_height_at(x, z, 1.9)) else 0.0
			var index: int = iz * (resolution + 1) + ix
			colors[index] = data
			var height: float = _ground_from_geo(x, z, g, ll)
			heights[index] = height
			forests[index] = _forest_chance(g)
			vertices[index] = Vector3(x, height, z)
		if iz % rows_per_frame == 0:
			region_progress.emit(true, float(iz) / resolution * .9)
			await get_tree().process_frame
			if token != region_load_token:
				return false
	height_field = heights
	forest_field = forests
	# Preserve the original triangles and flat normals; only sampling is shared.
	for iz in range(resolution):
		for ix in range(resolution):
			for corner in [
				Vector2i(0, 0),
				Vector2i(1, 0),
				Vector2i(0, 1),
				Vector2i(1, 0),
				Vector2i(1, 1),
				Vector2i(0, 1)
			]:
				var index: int = (iz + corner.y) * (resolution + 1) + ix + corner.x
				st.set_color(colors[index])
				st.add_vertex(vertices[index])
		if iz % TRIANGLE_ROWS == TRIANGLE_ROWS - 1:
			await get_tree().process_frame
			if token != region_load_token:
				return false

	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	terrain.material_override = _terrain_material(false)
	surface.add_child(terrain)
	# Geological section of a floating regional cutaway, deliberately no debug grid.
	var border := SurfaceTool.new()
	border.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges: Array = [
		Vector2(-half_width, -half_depth),
		Vector2(half_width, -half_depth),
		Vector2(half_width, half_depth),
		Vector2(-half_width, half_depth)
	]
	for e in range(4):
		for k in range(80):
			var a: Vector2 = edges[e].lerp(edges[(e + 1) % 4], float(k) / 80)
			var b: Vector2 = edges[e].lerp(edges[(e + 1) % 4], float(k + 1) / 80)
			var top_a := Vector3(a.x, _ground(a.x, a.y), a.y)
			var top_b := Vector3(b.x, _ground(b.x, b.y), b.y)
			var bottom: float = minf(-4.0, minf(top_a.y, top_b.y) - 3.0)
			for v in [
				top_a,
				Vector3(a.x, bottom, a.y),
				top_b,
				top_b,
				Vector3(a.x, bottom, a.y),
				Vector3(b.x, bottom, b.y)
			]:
				border.add_vertex(v)
	border.generate_normals()
	var skirt := MeshInstance3D.new()
	skirt.mesh = border.commit()
	skirt.material_override = _mat("strata", Color("283a3e"), .15, .95)
	surface.add_child(skirt)
	_build_lakes()
	_build_sea()
	_build_nature()
	# Thin survey corner lights frame the playable terrain without a grid.
	for x in [-27.5, 27.5]:
		for z in [-22.5, 22.5]:
			var h: float = _ground(x, z)
			_cylinder(
				surface,
				Vector3(x, h + .35, z),
				.065,
				.7,
				_mat("survey", Color("71ccbe"), .3, .6, .8),
				8
			)

	return true


## Generated worlds: the field at its usual resolution inside rings of coarser ground that run on
## into the haze, all one mesh, so there is no edge, wall or gap anywhere to see. The planet's
## relief is sampled at every vertex, then shaped as one grid (`_shape_relief`): smoothed, given
## natural detail and shores, kept dry inland and calm in town. Rivers, lakes and the plots' pads
## are cut into the field last.
func _build_landscape(token: int) -> bool:
	var reg: Dictionary = world.regions[selected_region]
	_prepare_terraces()
	var xs: PackedFloat32Array = _apron_axis(field_width)
	var zs: PackedFloat32Array = _apron_axis(field_depth)
	var columns: int = xs.size()
	var rows: int = zs.size()
	var vertices := PackedVector3Array()
	vertices.resize(columns * rows)
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	var relief := PackedFloat32Array()
	relief.resize(vertices.size())
	var ridges := PackedFloat32Array()
	ridges.resize(vertices.size())
	var forests := PackedFloat32Array()
	forests.resize((field_res + 1) * (field_res + 1))
	var climate := PackedVector2Array()
	climate.resize(forests.size())
	var inland: bool = not bool(reg.get("coast", false))
	# Where the planet has sea but the region draws land (coastal plains, filled hollows), the
	# ground takes the site's own climate: the planet keeps no rain over its sea (1.12).
	var site: Dictionary = Geo.sample_geo(float(reg.lat), float(reg.lon), noise, str(world.version))
	terrain_unique_samples = 0
	for row: int in range(rows):
		var z: float = zs[row]
		var inner_z: int = row - APRON_RINGS
		for column: int in range(columns):
			var x: float = xs[column]
			var inner_x: int = column - APRON_RINGS
			var inner: bool = (
				inner_x >= 0 and inner_x <= field_res and inner_z >= 0 and inner_z <= field_res
			)
			var at: Vector2 = Vector2(x, z) if inner else _apron_sample(x, z)
			var ll: Vector2 = _local_coordinate(at.x, at.y) if inner else _apron_coordinate(at)
			var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
			terrain_unique_samples += 1
			var index: int = row * columns + column
			relief[index] = _lift((float(g.height) - region_ground) * 30.0)
			ridges[index] = float(g.get("ridge", 0.0))
			# Inland ground is coloured as land wherever the planet below dips under the sea.
			var shown: float = float(g.height)
			if inland:
				shown = maxf(shown, INLAND_DATA_FLOOR)
			var weather: Dictionary = g if bool(g.land) or not bool(site.land) else site
			var data: Color = Shaders.encode(
				shown, float(weather.temperature), float(weather.rainfall), 0.0
			)
			if inner:
				data.b = 1.0 if is_finite(_water_height_at(x, z, 1.9)) else 0.0
				forests[inner_z * (field_res + 1) + inner_x] = _forest_chance(weather)
				climate[inner_z * (field_res + 1) + inner_x] = Vector2(
					lerpf(
						float(site.temperature),
						float(weather.temperature),
						DistrictGround.SITE_LOCAL
					),
					lerpf(float(site.rainfall), float(weather.rainfall), DistrictGround.SITE_LOCAL)
				)
			else:
				data.b = 0.0
			colors[index] = data
		if row % rows_per_frame == 0:
			region_progress.emit(true, float(row) / rows * .8)
			await get_tree().process_frame
			if token != region_load_token:
				return false
	field_has_sea = not inland
	var natural: bool = str(world.version) == WorldGen2.VERSION
	if not await _shape_relief(relief, ridges, xs, zs, inland, token):
		return false
	# The ground's colours soften with it, so old shores leave no hard edge between patches.
	for _pass: int in range(SMOOTH_PASSES):
		_blur_colors(colors, columns, rows)
	var heights := PackedFloat32Array()
	heights.resize((field_res + 1) * (field_res + 1))
	for inner_z: int in range(field_res + 1):
		for inner_x: int in range(field_res + 1):
			var index: int = (inner_z + APRON_RINGS) * columns + inner_x + APRON_RINGS
			relief[index] = _carve_water(
				xs[inner_x + APRON_RINGS], zs[inner_z + APRON_RINGS], relief[index]
			)
			if natural and inland:
				relief[index] = maxf(relief[index], sea_level() + INLAND_BED)
	if natural:
		_limit_steps(relief, columns, rows)
	for inner_z: int in range(field_res + 1):
		for inner_x: int in range(field_res + 1):
			var index: int = (inner_z + APRON_RINGS) * columns + inner_x + APRON_RINGS
			heights[inner_z * (field_res + 1) + inner_x] = relief[index]
	# The pads take their level from the natural ground, then are graded into it.
	height_field = heights
	_level_pads()
	for inner_z: int in range(field_res + 1):
		for inner_x: int in range(field_res + 1):
			var index: int = (inner_z + APRON_RINGS) * columns + inner_x + APRON_RINGS
			var x: float = xs[inner_x + APRON_RINGS]
			var z: float = zs[inner_z + APRON_RINGS]
			relief[index] = _terraced(x, z, relief[index])
	if natural:
		# Grading pads into rugged ground leaves no wall either; the pads themselves stay level.
		var fixed := PackedByteArray()
		fixed.resize(relief.size())
		for inner_z: int in range(field_res + 1):
			for inner_x: int in range(field_res + 1):
				var index: int = (inner_z + APRON_RINGS) * columns + inner_x + APRON_RINGS
				if _on_pad(xs[inner_x + APRON_RINGS], zs[inner_z + APRON_RINGS]):
					fixed[index] = 1
		_limit_steps(relief, columns, rows, fixed)
	if field_has_sea and natural:
		hollows_filled = _fill_hollows(relief, xs, zs, sea_level())
	if field_has_sea:
		_clear_waterline(relief, sea_level(), WATERLINE_LIP_23 if natural else WATERLINE_LIP)
	for inner_z: int in range(field_res + 1):
		for inner_x: int in range(field_res + 1):
			var index: int = (inner_z + APRON_RINGS) * columns + inner_x + APRON_RINGS
			heights[inner_z * (field_res + 1) + inner_x] = relief[index]
	height_field = heights
	forest_field = forests
	climate_field = climate
	for row: int in range(rows):
		for column: int in range(columns):
			var index: int = row * columns + column
			vertices[index] = Vector3(xs[column], relief[index], zs[row])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(rows - 1):
		for column: int in range(columns - 1):
			for corner: Vector2i in [
				Vector2i(0, 0),
				Vector2i(1, 0),
				Vector2i(0, 1),
				Vector2i(1, 0),
				Vector2i(1, 1),
				Vector2i(0, 1)
			]:
				var index: int = (row + corner.y) * columns + column + corner.x
				st.set_color(colors[index])
				st.add_vertex(vertices[index])
		if row % TRIANGLE_ROWS == TRIANGLE_ROWS - 1:
			await get_tree().process_frame
			if token != region_load_token:
				return false
	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "Landscape"
	terrain.mesh = st.commit()
	ground_material = DistrictGround.material(false)
	if bool(site.land):
		DistrictGround.set_site(ground_material, float(site.temperature), float(site.rainfall))
	mats["district_ground"] = ground_material
	terrain_shader = ground_material
	terrain.material_override = ground_material
	surface.add_child(terrain)
	_build_lakes()
	_build_sea()
	# A generated world's nature is drawn with its town, clear of the paving (district_nature.gd).
	return true


## Natural ground from the sampled relief, over the whole landscape grid at once: smoothed, given
## layered detail (more in hills, little near water or far out), shaped into beaches at the
## coast or held above the sea inland, and calmer around the town. False if the load was dropped.
func _shape_relief(
	relief: PackedFloat32Array,
	ridges: PackedFloat32Array,
	xs: PackedFloat32Array,
	zs: PackedFloat32Array,
	inland: bool,
	token: int
) -> bool:
	var columns: int = xs.size()
	var rows: int = zs.size()
	for _pass: int in range(SMOOTH_PASSES):
		_blur_rows(relief, columns, rows)
		_blur_columns(relief, columns, rows)
	await get_tree().process_frame
	if token != region_load_token:
		return false
	var seed_value: int = int(world.get("seed", 0)) * 31 + selected_region * 977
	var detail := FastNoiseLite.new()
	detail.seed = seed_value
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.frequency = DETAIL_FREQUENCY
	detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail.fractal_octaves = 4
	var ridged := FastNoiseLite.new()
	ridged.seed = seed_value + 7
	ridged.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridged.frequency = DETAIL_FREQUENCY * 0.6
	ridged.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridged.fractal_octaves = 3
	var sea: float = sea_level()
	var shore: Dictionary = _district_survey(selected_region).shore if not inland else {}
	for row: int in range(rows):
		var z: float = zs[row]
		for column: int in range(columns):
			var x: float = xs[column]
			var index: int = row * columns + column
			var beyond: float = maxf(absf(x) - half_width, absf(z) - half_depth)
			var near: float = 1.0 - smoothstep(DETAIL_FADE.x, DETAIL_FADE.y, beyond)
			var h: float = relief[index]
			var above: float = h - sea
			var amount: float = lerpf(DETAIL_LOW, DETAIL_HIGH, smoothstep(0.6, 6.0, absf(above)))
			h += detail.get_noise_2d(x, z) * amount * near
			var crest: float = (ridged.get_noise_2d(x, z) + 1.0) * 0.5
			h += (
				crest
				* RIDGE_AMPLITUDE
				* smoothstep(3.0, 8.0, above)
				* (0.5 + clampf(ridges[index], 0.0, 1.0))
				* near
			)
			h = _shore(h, sea, inland)
			if inland:
				# Low plains where the planet has sea: gentle swells rather than a dead-flat floor.
				var low: float = 1.0 - smoothstep(0.0, 1.2, h - sea - INLAND_FLOOR)
				h += (
					(detail.get_noise_2d(x * 0.6 + 53.0, z * 0.6) + 0.6) * INLAND_SWELL * low * near
				)
			if not shore.is_empty():
				var local_shore: float = DistrictLayout.shore_height(Vector2(x, z), shore, sea, h)
				h = lerpf(local_shore, h, smoothstep(12.0, 100.0, beyond))
			relief[index] = h
		if row % (rows_per_frame * 4) == 0:
			await get_tree().process_frame
			if token != region_load_token:
				return false
	if str(world.version) == WorldGen2.VERSION:
		_settle_town(relief, xs, zs, sea)
	else:
		_calm_town(relief, xs, zs, sea)
	return true


## Beaches and shallows at the coast: the ground flattens as it meets the water and deepens
## gently. Inland, the lowest ground is held above the sea on a soft floor.
static func _shore(height: float, sea: float, inland: bool) -> float:
	if inland:
		var lift: float = height - sea - INLAND_FLOOR
		return sea + INLAND_FLOOR + log(1.0 + exp(2.0 * lift)) / 2.0
	var depth: float = height - sea
	if absf(depth) >= SHORE_BAND:
		return height
	var share: float = absf(depth) / SHORE_BAND
	var shaped: float = (1.0 - SHORE_LINEAR) * pow(share, SHORE_POWER) + SHORE_LINEAR * share
	return sea + signf(depth) * SHORE_BAND * shaped


## Every shoreline crosses the water steeply, on the final ground (after the town's calm, the
## rivers and the pads): see WATERLINE_LIP. A smooth curve, the same above and below the sea, so
## the waterline keeps its place between the grid's vertices.
static func _clear_waterline(
	relief: PackedFloat32Array, sea: float, lip: float = WATERLINE_LIP
) -> void:
	for index: int in range(relief.size()):
		var depth: float = relief[index] - sea
		if absf(depth) >= WATERLINE_BAND:
			continue
		var fade: float = 1.0 - smoothstep(0.0, WATERLINE_BAND, absf(depth))
		relief[index] += lip * tanh(depth / WATERLINE_REACH) * fade


## No walls: neighbouring vertices of the whole grid never differ by more than STEP_LIMIT; a
## steeper step is eased from both sides over a few passes.
static func _limit_steps(
	relief: PackedFloat32Array, columns: int, rows: int, fixed: PackedByteArray = PackedByteArray()
) -> void:
	var held: bool = fixed.size() == relief.size()
	for _pass: int in range(STEP_PASSES):
		var eased: bool = false
		for row: int in range(rows):
			for column: int in range(columns):
				var here: int = row * columns + column
				for there: int in [
					here + 1 if column + 1 < columns else -1,
					here + columns if row + 1 < rows else -1
				]:
					if there < 0:
						continue
					var step: float = relief[there] - relief[here]
					if absf(step) <= STEP_LIMIT:
						continue
					var excess: float = (absf(step) - STEP_LIMIT) * signf(step)
					var pinned_here: bool = held and fixed[here] == 1
					var pinned_there: bool = held and fixed[there] == 1
					if pinned_here and pinned_there:
						continue
					if pinned_here:
						relief[there] -= excess
					elif pinned_there:
						relief[here] += excess
					else:
						relief[here] += excess * 0.5
						relief[there] -= excess * 0.5
					eased = true
		if not eased:
			return


## The town's ground is pulled toward its own level, so plots sit on gentle land rather than on
## crests and gullies. The level itself stays above the sea.
func _calm_town(
	relief: PackedFloat32Array, xs: PackedFloat32Array, zs: PackedFloat32Array, sea: float
) -> void:
	var columns: int = xs.size()
	var centre_x: int = APRON_RINGS + int(field_res / 2.0)
	var centre_z: int = APRON_RINGS + int(field_res / 2.0)
	var level: float = maxf(relief[centre_z * columns + centre_x], sea + PAD_ABOVE_SEA + 0.15)
	var town := Vector2(_town_offset(), 0.0)
	for row: int in range(zs.size()):
		for column: int in range(columns):
			var distance: float = Vector2(xs[column], zs[row]).distance_to(town)
			if distance >= TOWN_CALM.y:
				continue
			var weight: float = (1.0 - smoothstep(TOWN_CALM.x, TOWN_CALM.y, distance)) * TOWN_PULL
			var index: int = row * columns + column
			relief[index] = lerpf(relief[index], level, weight)


## CC-GEO-2.3 (1.12): the town stands on gentle ground, as the approved district does, while the
## hills beyond keep their height. Over the plot grid, fading out between TOWN_SETTLE.x and
## TOWN_SETTLE.y units past the nearest plot, land keeps the broad lie of the relief (a wide blur
## of the field) with only 1 - TOWN_RELIEF_EASE of the hills and hollows on it, and that broad lie
## eases TOWN_SLOPE_EASE of the way toward the town's own level. The sea, the beach band and the
## ground beside water are left as they were, so every coast, river and lake stays where it is.
func _settle_town(
	relief: PackedFloat32Array, xs: PackedFloat32Array, zs: PackedFloat32Array, sea: float
) -> void:
	var columns: int = xs.size()
	var side: int = field_res + 1
	var broad := PackedFloat32Array()
	broad.resize(side * side)
	for inner_z: int in range(side):
		for inner_x: int in range(side):
			broad[inner_z * side + inner_x] = relief[
				(inner_z + APRON_RINGS) * columns + inner_x + APRON_RINGS
			]
	for _pass: int in range(3):
		_box_blur(broad, side, true)
		_box_blur(broad, side, false)
	var calm: PackedFloat32Array = _town_calm(xs, zs)
	var level_sum: float = 0.0
	var level_weight: float = 0.0
	for inner_z: int in range(side):
		for inner_x: int in range(side):
			var weight: float = calm[inner_z * side + inner_x]
			var lie: float = broad[inner_z * side + inner_x]
			if weight > 0.5 and lie > sea:
				level_sum += lie * weight
				level_weight += weight
	if level_weight <= 0.0:
		return
	var level: float = level_sum / level_weight
	# Settled land never sinks under the beach band's foot, nor lower than it was.
	var lowest: float = sea + WATERLINE_BAND
	for inner_z: int in range(side):
		for inner_x: int in range(side):
			var weight: float = calm[inner_z * side + inner_x]
			if weight <= 0.0:
				continue
			var index: int = (inner_z + APRON_RINGS) * columns + inner_x + APRON_RINGS
			var height: float = relief[index]
			weight *= smoothstep(sea + WATERLINE_BAND * 0.5, sea + WATERLINE_BAND * 2.0, height)
			var x: float = xs[inner_x + APRON_RINGS]
			var z: float = zs[inner_z + APRON_RINGS]
			if weight <= 0.0 or is_finite(_water_height_at(x, z, 2.2)):
				continue
			var lie: float = broad[inner_z * side + inner_x]
			var eased: float = lerpf(lie, level, TOWN_SLOPE_EASE * weight)
			var settled: float = eased + (height - lie) * (1.0 - TOWN_RELIEF_EASE * weight)
			relief[index] = maxf(settled, minf(height, lowest))


## A coast's sea reaches inland only where it is open water (1.12): ground below the sea's level
## that no path of such ground joins to the landscape's outer edge is a hollow, not a bay, and is
## raised just clear of the sea, so no pond of sea shows inland. Beds of rivers and lakes keep
## their depth (their own water covers them).
func _fill_hollows(
	relief: PackedFloat32Array, xs: PackedFloat32Array, zs: PackedFloat32Array, sea: float
) -> int:
	var columns: int = xs.size()
	var rows: int = zs.size()
	var open := PackedByteArray()
	open.resize(relief.size())
	var queue := PackedInt32Array()
	for row: int in range(rows):
		for column: int in range(columns):
			if row != 0 and column != 0 and row != rows - 1 and column != columns - 1:
				continue
			var index: int = row * columns + column
			if relief[index] < sea and open[index] == 0:
				open[index] = 1
				queue.append(index)
	var head: int = 0
	while head < queue.size():
		var here: int = queue[head]
		head += 1
		var row: int = here / columns
		var column: int = here % columns
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: int = column + step.x
			var r: int = row + step.y
			if c < 0 or r < 0 or c >= columns or r >= rows:
				continue
			var there: int = r * columns + c
			if open[there] == 0 and relief[there] < sea:
				open[there] = 1
				queue.append(there)
	var filled: int = 0
	for row: int in range(rows):
		for column: int in range(columns):
			var index: int = row * columns + column
			if open[index] == 1 or relief[index] >= sea:
				continue
			if is_finite(_water_height_at(xs[column], zs[row], 2.0)):
				continue
			relief[index] = sea + HOLLOW_LIFT
			filled += 1
	return filled


## How much each vertex of the field belongs to the town (1 on the plot grid, 0 well beyond it and
## at the field's edge), from the distance to the nearest visible plot or the landing pods, kept
## on a lattice of TOWN_CALM_CELL units and read bilinearly so the weight has no steps.
func _town_calm(xs: PackedFloat32Array, zs: PackedFloat32Array) -> PackedFloat32Array:
	var side: int = field_res + 1
	var calm := PackedFloat32Array()
	calm.resize(side * side)
	var nearest: Dictionary = {}
	var reach: float = TOWN_SETTLE.y + TOWN_CALM_CELL * 2.0
	for id: Variant in plot_levels:
		var centre: Vector2 = plot_levels[id].centre
		var low := Vector2i(
			floori((centre.x - reach) / TOWN_CALM_CELL), floori((centre.y - reach) / TOWN_CALM_CELL)
		)
		var high := Vector2i(
			ceili((centre.x + reach) / TOWN_CALM_CELL), ceili((centre.y + reach) / TOWN_CALM_CELL)
		)
		for lz: int in range(low.y, high.y + 1):
			for lx: int in range(low.x, high.x + 1):
				var key := Vector2i(lx, lz)
				var d: float = (Vector2(lx, lz) * TOWN_CALM_CELL).distance_to(centre)
				if d < float(nearest.get(key, INF)):
					nearest[key] = d
	for inner_z: int in range(side):
		var z: float = zs[inner_z + APRON_RINGS]
		for inner_x: int in range(side):
			var x: float = xs[inner_x + APRON_RINGS]
			var fx: float = x / TOWN_CALM_CELL
			var fz: float = z / TOWN_CALM_CELL
			var lx: int = floori(fx)
			var lz: int = floori(fz)
			var tx: float = fx - lx
			var tz: float = fz - lz
			var far: float = TOWN_SETTLE.y + TOWN_CALM_CELL * 2.0
			var d: float = lerpf(
				lerpf(
					float(nearest.get(Vector2i(lx, lz), far)),
					float(nearest.get(Vector2i(lx + 1, lz), far)),
					tx
				),
				lerpf(
					float(nearest.get(Vector2i(lx, lz + 1), far)),
					float(nearest.get(Vector2i(lx + 1, lz + 1), far)),
					tx
				),
				tz
			)
			var edge: float = maxf(absf(x) - half_width, absf(z) - half_depth)
			calm[inner_z * side + inner_x] = (
				(1.0 - smoothstep(TOWN_SETTLE.x, TOWN_SETTLE.y, d))
				* (1.0 - smoothstep(-TOWN_EDGE_FADE, -1.0, edge))
			)
	return calm


## A running-sum box blur of TOWN_BROAD_CELLS along the rows (or columns) of a square grid, the
## ends held at their edge values.
static func _box_blur(values: PackedFloat32Array, side: int, along_rows: bool) -> void:
	var radius: int = TOWN_BROAD_CELLS
	var line := PackedFloat32Array()
	line.resize(side)
	for lane: int in range(side):
		for step: int in range(side):
			line[step] = values[lane * side + step] if along_rows else values[step * side + lane]
		var total: float = 0.0
		for offset: int in range(-radius, radius + 1):
			total += line[clampi(offset, 0, side - 1)]
		var span: float = float(radius * 2 + 1)
		for step: int in range(side):
			var at: int = lane * side + step if along_rows else step * side + lane
			values[at] = total / span
			total += line[clampi(step + radius + 1, 0, side - 1)]
			total -= line[clampi(step - radius, 0, side - 1)]


static func _blur_colors(values: PackedColorArray, columns: int, rows: int) -> void:
	for row: int in range(rows):
		var base: int = row * columns
		var previous: Color = values[base]
		for column: int in range(1, columns - 1):
			var here: Color = values[base + column]
			values[base + column] = (previous + here * 2.0 + values[base + column + 1]) * 0.25
			previous = here
	for column: int in range(columns):
		var previous: Color = values[column]
		for row: int in range(1, rows - 1):
			var index: int = row * columns + column
			var here: Color = values[index]
			values[index] = (previous + here * 2.0 + values[index + columns]) * 0.25
			previous = here


static func _blur_rows(values: PackedFloat32Array, columns: int, rows: int) -> void:
	for row: int in range(rows):
		var base: int = row * columns
		var previous: float = values[base]
		for column: int in range(1, columns - 1):
			var here: float = values[base + column]
			values[base + column] = (previous + here * 2.0 + values[base + column + 1]) * 0.25
			previous = here


static func _blur_columns(values: PackedFloat32Array, columns: int, rows: int) -> void:
	for column: int in range(columns):
		var previous: float = values[column]
		for row: int in range(1, rows - 1):
			var index: int = row * columns + column
			var here: float = values[index]
			values[index] = (previous + here * 2.0 + values[index + columns]) * 0.25
			previous = here


## Rivers and lakes cut their channels and basins into the shaped field.
func _carve_water(x: float, z: float, height: float) -> float:
	var p := Vector2(x, z)
	for lake in local_lakes:
		var distance: float = p.distance_to(lake.center)
		if distance < lake.radius * 1.25:
			height = lerpf(
				lake.height - .4, height, smoothstep(lake.radius * .8, lake.radius * 1.25, distance)
			)
	return height


## One axis of the landscape grid: the field's own vertices, with rings outside that grow wider
## the further out they are.
func _apron_axis(span: float) -> PackedFloat32Array:
	var half: float = span * 0.5
	var axis := PackedFloat32Array()
	for ring: int in range(APRON_RINGS, 0, -1):
		axis.append(-half - _apron_ring(ring))
	for step: int in range(field_res + 1):
		axis.append((float(step) / field_res - .5) * span)
	for ring: int in range(1, APRON_RINGS + 1):
		axis.append(half + _apron_ring(ring))
	return axis


static func _apron_ring(ring: int) -> float:
	return APRON_REACH * pow(float(ring) / APRON_RINGS, 1.8)


## Where on the planet a point of the apron samples its ground: the true place near the field,
## then the relief spread wider, so the far haze holds whole ranges rather than half the globe.
func _apron_sample(x: float, z: float) -> Vector2:
	return Vector2(_apron_spread(x, half_width), _apron_spread(z, half_depth))


static func _apron_spread(value: float, half: float) -> float:
	var beyond: float = absf(value) - half
	if beyond <= APRON_TRUE:
		return value
	return signf(value) * (half + APRON_TRUE + (beyond - APRON_TRUE) * APRON_SPREAD)


## As `_local_coordinate`, kept off the poles: the far apron of a high site looks north or south.
func _apron_coordinate(at: Vector2) -> Vector2:
	var reg: Dictionary = world.regions[selected_region]
	var lat: float = clampf(
		float(reg.get("canonical_lat", reg.lat)) - at.y / 4.0, -APRON_LATITUDE, APRON_LATITUDE
	)
	var lon: float = float(reg.get("canonical_lon", reg.lon)) + at.x / 4.0
	return Geo.project_coordinate(lat, lon, world)


## One ground material per river setting: the uniforms carry the clock, not the region.
func _terrain_material(river: bool) -> ShaderMaterial:
	var key: String = "terrain_ground_" + str(river)
	if not mats.has(key):
		var material := ShaderMaterial.new()
		material.shader = Shaders.shader("terrain")
		material.set_shader_parameter("noise3d", Shaders.noise_texture())
		material.set_shader_parameter("river_tint", 1.0 if river else 0.0)
		mats[key] = material
	terrain_shader = mats[key]
	return mats[key]


## Inland lakes retain their water surface. Rivers are shown on the global maps only.
func _build_lakes() -> void:
	for lake in local_lakes:
		_cylinder(
			surface,
			Vector3(lake.center.x, lake.height, lake.center.y),
			lake.radius,
			.025,
			_water_material("lake", Color("2e798a")),
			40
		)


## One plane at sea level; the terrain itself draws the shoreline where it rises through it.
func _build_sea() -> void:
	if not field_has_sea:
		return
	var sea_height: float = -.72 if str(world.version) == "CC-GEO-1.4" else sea_level()
	var plane := PlaneMesh.new()
	plane.size = Vector2(field_width, field_depth)
	if Geo.is_generated(str(world.version)):
		# Under the whole landscape and on to the horizon.
		plane.size = Vector2(field_width, field_depth) + Vector2.ONE * (APRON_REACH * 2.0 + 200.0)
	var sea := _mesh(
		surface, plane, Vector3(0, sea_height, 0), _water_material("sea", Color("285e76"))
	)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Moving water: rippling normals over the same colours as before. A CC-GEO-2.3 district takes
## NATURAL_WATER instead.
func _water_material(kind: String, tint: Color) -> ShaderMaterial:
	var key: String = "water_" + kind
	if not mats.has(key):
		var material := ShaderMaterial.new()
		material.shader = Shaders.shader("water")
		material.set_shader_parameter("noise3d", Shaders.noise_texture())
		mats[key] = material
	if str(world.version) == WorldGen2.VERSION and NATURAL_WATER.has(kind):
		tint = NATURAL_WATER[kind]
	(mats[key] as ShaderMaterial).set_shader_parameter("tint", tint)
	return mats[key]


func _instanced(mesh: Mesh, material: Material, placed: Array) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = placed.size()
	for index: int in range(placed.size()):
		multi.set_instance_transform(index, placed[index][0])
		multi.set_instance_color(index, placed[index][1])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	return node


func _tree_mesh() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = .055
	trunk.bottom_radius = .055
	trunk.height = .5
	trunk.radial_segments = 6
	var crown := CylinderMesh.new()
	crown.top_radius = 0
	crown.bottom_radius = .35
	crown.height = 1.0
	crown.radial_segments = 9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3(0, .25, 0)))
	st.append_from(crown, 0, Transform3D(Basis.IDENTITY, Vector3(0, .65, 0)))
	return st.commit()


func _natural_material(key: String, roughness: float) -> StandardMaterial3D:
	var material := _mat(key, Color.WHITE, 0.0, roughness)
	material.vertex_color_use_as_albedo = true
	return material


func _forest_at(x: float, z: float) -> float:
	var fx: int = clampi(roundi((x / field_width + 0.5) * field_res), 0, field_res)
	var fz: int = clampi(roundi((z / field_depth + 0.5) * field_res), 0, field_res)
	return forest_field[fz * (field_res + 1) + fx]


func _near_plot(x: float, z: float) -> bool:
	for plot: Dictionary in world.regions[selected_region].get("plots", []):
		if absf(float(plot.x) - x) < 2.8 and absf(float(plot.z) - z) < 2.8:
			return true
	return false


func _build_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world.seed) + selected_region * 173
	var reg: Dictionary = world.regions[selected_region]
	var center := Vector2(_town_offset(), 0)
	var trees: Array = []
	var rocks: Array = []
	for i in range(tree_count):
		var x: float = rng.randf_range(-half_width + EDGE_MARGIN, half_width - EDGE_MARGIN)
		var z: float = rng.randf_range(-half_depth + EDGE_MARGIN, half_depth - EDGE_MARGIN)
		if (
			Vector2(x, z).distance_to(center) < 13.0
			or _ground(x, z) < -.4
			or is_finite(_water_height_at(x, z, 1.8))
			or _near_plot(x, z)
		):
			continue
		var height: float = rng.randf_range(.55, 1.8)
		var turn: float = rng.randf() * TAU
		var base := Vector3(x, _ground(x, z), z)
		if rng.randf() < _forest_at(x, z):
			var scaled := Basis(Vector3.UP, turn).scaled(Vector3(height, height, height))
			trees.append(
				[Transform3D(scaled, base), Color("304f45").lightened(float(i % 4) * .035)]
			)
		else:
			var flat := Basis(Vector3.UP, turn).scaled(Vector3(1.3, .6, 1.0) * height * .38)
			rocks.append([Transform3D(flat, base + Vector3(0, height * .17, 0)), Color("7c8174")])
	# A visible geological exposure marks actual mineral-bearing ground.
	if float(reg.deposits.ore) > 6000:
		for _i: int in range(16):
			var x: float = -16 + rng.randf_range(-3.4, 3.4)
			var z: float = -10 + rng.randf_range(-2.5, 2.5)
			var size: float = rng.randf_range(.4, 1.2)
			var seam := Basis.IDENTITY.scaled(Vector3(1.5, .55, 1.0) * size)
			rocks.append([Transform3D(seam, Vector3(x, _ground(x, z) + .3, z)), Color("9b735a")])
	if not trees.is_empty():
		surface.add_child(_instanced(_tree_mesh(), _natural_material("tree", .9), trees))
	if not rocks.is_empty():
		var pebble := SphereMesh.new()
		pebble.radius = 1.0
		pebble.height = 2.0
		pebble.radial_segments = 6
		pebble.rings = 3
		surface.add_child(_instanced(pebble, _natural_material("rock", .95), rocks))
