extends "res://world/building_models.gd"
## The regional ground: relief sampled from the planet into a height field, the terraces cut for
## plots, the wider landscape around generated worlds, rivers, lakes, the sea, trees and rocks.
## Everything placed on the ground afterwards reads the height field (region_view.gd).

const Rules = preload("res://simulation/rules.gd")
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
## Every plot is a level pad graded into the slope: flat to PAD_FLAT from its centre, back to the
## natural ground by PAD_BLEND along a smooth curve, so no wall or mesa is cut.
const PAD_FLAT: float = 2.35
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
const INLAND_FLOOR: float = 0.45
const INLAND_DATA_FLOOR: float = 0.0004
const INLAND_SWELL: float = 0.6
const TOWN_CALM: Vector2 = Vector2(10.0, 22.0)
const TOWN_PULL: float = 0.65
## The ground keeps clear of the sea's flat surface (`_clear_waterline`), because ground and water
## within the depth buffer's precision of each other flicker as the camera moves. Land up to
## WATERLINE_BAND above the sea is lifted by up to WATERLINE_LIP (a low bank; pads stand higher,
## at PAD_ABOVE_SEA, and keep their level). Seabed drops to at least SEABED_DROP below the sea,
## or SEABED_SLOPE of the grid's cell where the far rings are coarse, so even there the shore
## crosses the water at a slope of a tenth or more.
const WATERLINE_LIP: float = 0.08
const WATERLINE_BAND: float = 0.3
const SEABED_DROP: float = 0.3
const SEABED_SLOPE: float = 0.12
## Detail fades out over the coarse far rings of the landscape, past the field's edge.
const DETAIL_FADE: Vector2 = Vector2(10.0, 60.0)
const SLOT_SPACING: float = 6.0
const RIVER_STEP: float = 0.5
var field_res: int = int(OLD_FIELD.res)
var field_width: float = float(OLD_FIELD.width)
var field_depth: float = float(OLD_FIELD.depth)
var half_width: float = field_width / 2.0
var half_depth: float = field_depth / 2.0
var river_steps: int = int(field_depth / RIVER_STEP)
var tree_count: int = int(OLD_FIELD.trees)
var gate_reach: float = float(OLD_FIELD.gate)
var rows_per_frame: int = int(OLD_FIELD.rows)
var height_field := PackedFloat32Array()
var forest_field := PackedFloat32Array()
var field_has_sea: bool = false
## Terrace level per visible plot, keyed by its slot on the plot grid: Vector3(x, level, z).
var plot_levels: Dictionary = {}
var terrace_region: int = -1
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


## The ground: the region's relief, with every visible plot's terrace cut into it.
func _ground_from_geo(x: float, z: float, g: Dictionary, ll: Vector2) -> float:
	if terrace_region != selected_region:
		_prepare_terraces()
	return _terraced(x, z, _relief_from_geo(x, z, g, ll))


func _relief_from_geo(x: float, z: float, g: Dictionary, ll: Vector2) -> float:
	var reg: Dictionary = world.regions[selected_region]
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
	if reg.river and str(world.version) == "CC-GEO-1.4":
		var river_x: float = (Geo.river_lon(ll.x) - float(reg.lon)) * 4.0
		var river_dist: float = absf(x - river_x)
		if river_dist < 2.8:
			height = lerpf(-.55, height, smoothstep(.9, 2.8, river_dist))
	elif str(world.version) != "CC-GEO-1.4":
		var p := Vector2(x, z)
		for segment in local_river_segments:
			var a: Vector2 = segment.a
			var b: Vector2 = segment.b
			var t: float = clampf((p - a).dot(b - a) / maxf(a.distance_squared_to(b), .001), 0, 1)
			var distance: float = p.distance_to(a.lerp(b, t))
			var width: float = segment.width
			if distance < width * 2:
				var water: float = lerpf(segment.ya, segment.yb, t)
				height = lerpf(water - .28, height, smoothstep(width * .72, width * 2, distance))
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
	terrace_region = selected_region
	if not Geo.is_generated(str(world.version)):
		return
	var taken: Dictionary = {}
	for plot: Dictionary in world.regions[selected_region].get("plots", []):
		taken[_slot_key(float(plot.x), float(plot.z))] = true
		if bool(plot.get("hidden", false)):
			continue
		_add_terrace(float(plot.x), float(plot.z))
	pods_spot = _free_cell(taken)
	_add_terrace(pods_spot.x, pods_spot.y)


func _add_terrace(x: float, z: float) -> void:
	var ll := _local_coordinate(x, z)
	var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
	plot_levels[_slot_key(x, z)] = Vector3(x, _relief_from_geo(x, z, g, ll), z)


## The nearest dry cell of the plot grid, off the main street, that no plot has been given.
func _free_cell(taken: Dictionary) -> Vector2:
	for ring: int in range(1, 8):
		for iz: int in range(-ring, ring + 1):
			for ix: int in range(-ring, ring + 1):
				if maxi(absi(ix), absi(iz)) != ring or ix == 0:
					continue
				if taken.has(Vector2i(ix, iz)):
					continue
				var x: float = ix * SLOT_SPACING
				var z: float = iz * SLOT_SPACING
				var ll := _local_coordinate(x, z)
				var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
				if not bool(g.land) or is_finite(_water_height_at(x, z, 1.6)):
					continue
				return Vector2(x, z)
	return Vector2(-6.0, 0.0)


## Which plots the terrain was cut for: a cached region is rebuilt once a hidden plot is found.
func terrace_signature(region: int) -> String:
	if region < 0 or region >= world.get("regions", []).size():
		return ""
	if not Geo.is_generated(str(world.version)):
		return "old"
	var visible: PackedStringArray = []
	var plots: Array = world.regions[region].get("plots", [])
	for index: int in range(plots.size()):
		if not bool(plots[index].get("hidden", false)):
			visible.append(str(index))
	return ",".join(visible)


static func _slot_key(x: float, z: float) -> Vector2i:
	return Vector2i(roundi(x / SLOT_SPACING), roundi(z / SLOT_SPACING))


## The ground graded toward the nearby plots' pads: exactly level on a pad, and between pads a
## weighted mean of their levels that leans on the nearest one, eased back into the natural
## slope by PAD_BLEND. Plots are a slot apart, so only neighbours can reach.
func _terraced(x: float, z: float, height: float) -> float:
	if plot_levels.is_empty():
		return height
	var here: Vector2i = _slot_key(x, z)
	var weights: float = 0.0
	var levels: float = 0.0
	var strongest: float = 0.0
	for dz: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			var key := Vector2i(here.x + dx, here.y + dz)
			if not plot_levels.has(key):
				continue
			var plot: Vector3 = plot_levels[key]
			var d: float = Vector2(x - plot.x, z - plot.z).length()
			if d <= PAD_FLAT:
				return plot.y
			if d >= PAD_BLEND:
				continue
			var reach: float = 1.0 - _smoother(PAD_FLAT, PAD_BLEND, d)
			var weight: float = reach / pow(maxf(d - PAD_FLAT, 0.05), 2.0)
			weights += weight
			levels += weight * plot.y
			strongest = maxf(strongest, reach)
	if weights <= 0.0:
		return height
	return lerpf(height, levels / weights, strongest)


## Smootherstep: no kink where a pad's flat meets its slope, nor where the slope meets the land.
static func _smoother(edge0: float, edge1: float, value: float) -> float:
	var t: float = clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## Each pad's level from the natural ground it stands on (the field before pads), averaged over
## the pad so a single bump does not set it, and kept above the sea.
func _level_pads() -> void:
	var sea: float = sea_level()
	for key: Vector2i in plot_levels:
		var plot: Vector3 = plot_levels[key]
		var total: float = _ground(plot.x, plot.z)
		for step: int in range(6):
			var at: Vector2 = (
				Vector2(plot.x, plot.z) + Vector2.RIGHT.rotated(TAU * step / 6.0) * 1.5
			)
			total += _ground(at.x, at.y)
		plot_levels[key] = Vector3(plot.x, maxf(total / 7.0, sea + PAD_ABOVE_SEA), plot.z)
	# Neighbouring pads lean toward each other, so the steps between them stay low.
	for _pass: int in range(PAD_RELAX_PASSES):
		var relaxed: Dictionary = {}
		for key: Vector2i in plot_levels:
			var plot: Vector3 = plot_levels[key]
			var sum: float = 0.0
			var count: int = 0
			for offset: Vector2i in [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
			]:
				if plot_levels.has(key + offset):
					sum += float(plot_levels[key + offset].y)
					count += 1
			var level: float = plot.y
			if count > 0:
				level = lerpf(plot.y, sum / count, PAD_RELAX)
			relaxed[key] = Vector3(plot.x, maxf(level, sea + PAD_ABOVE_SEA), plot.z)
		plot_levels = relaxed


func _water_height_at(x: float, z: float, margin: float = 1.0) -> float:
	var point := Vector2(x, z)
	var result: float = -INF
	for segment in local_river_segments:
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var t: float = clampf((point - a).dot(b - a) / maxf(a.distance_squared_to(b), .001), 0, 1)
		if point.distance_to(a.lerp(b, t)) < float(segment.width) * margin:
			result = maxf(result, lerpf(segment.ya, segment.yb, t))
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
	var overrides: Dictionary = Rules.read("geography").get("overrides", {})
	var rules: Dictionary = overrides.get(str(world.get("version", "")), {})
	var field: Dictionary = WIDE_FIELD if rules.get("plots", {}).has("slot_x") else OLD_FIELD
	field_res = int(field.res)
	field_width = float(field.width)
	field_depth = float(field.depth)
	half_width = field_width / 2.0
	half_depth = field_depth / 2.0
	river_steps = int(field_depth / RIVER_STEP)
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
	local_river_segments.clear()
	local_lakes.clear()
	height_field = PackedFloat32Array()
	var reg: Dictionary = world.regions[selected_region]
	region_ground = float(Geo.sample_geo(reg.lat, reg.lon, noise, str(world.version)).height)
	if str(world.version) == "CC-GEO-1.4":
		return
	var rivers: Array = render_rivers
	for river_index in range(rivers.size()):
		var river = rivers[river_index]
		var coordinates: Array = river.coordinates
		var heights: Array = river.heights
		# Water only runs downhill: each point may not stand above the one upstream of it.
		var water_level: float = INF
		for i in range(coordinates.size() - 1):
			var ca = coordinates[i]
			var cb = coordinates[i + 1]
			var a := _point_to_local(float(ca[0]), float(ca[1]))
			var b := _point_to_local(float(cb[0]), float(cb[1]))
			var ha: float = minf(water_level, _river_height(heights, i, ca))
			var hb: float = minf(ha, _river_height(heights, i + 1, cb))
			water_level = hb
			if a.distance_to(b) > 60:
				continue
			var clip := _clip_segment(a, b)
			if clip.x < 0:
				continue
			var wa: float = (
				.45 + .18 * float(i) / maxi(1, coordinates.size() - 1) + .035 * sin(float(i) * .51)
			)
			var wb: float = (
				.45
				+ .18 * float(i + 1) / maxi(1, coordinates.size() - 1)
				+ .035 * sin(float(i + 1) * .51)
			)
			local_river_segments.append(
				{
					"a": a.lerp(b, clip.x),
					"b": a.lerp(b, clip.y),
					"ya": _lift((lerpf(ha, hb, clip.x) - region_ground) * 30.0) + .04,
					"yb": _lift((lerpf(ha, hb, clip.y) - region_ground) * 30.0) + .04,
					"width": maxf(wa, wb),
					"width_a": wa,
					"width_b": wb,
					"river_index": river_index
				}
			)
	for lake in world.get("lakes", []):
		var center := _point_to_local(float(lake.lat), float(lake.lon))
		var radius: float = float(lake.get("radius_degrees", .45)) * 4.0
		if absf(center.x) > half_width - radius or absf(center.y) > half_depth - radius:
			continue
		var h: float = float(lake.get("height", float(lake.get("elevation", 0)) / 4300.0))
		local_lakes.append(
			{"center": center, "radius": radius, "height": _lift((h - region_ground) * 30.0) + .04}
		)


func _river_height(heights: Array, index: int, ll: Array) -> float:
	if index < heights.size():
		return float(heights[index])
	return float(Geo.sample_geo(float(ll[0]), float(ll[1]), noise, str(world.version)).height)


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
	terrain.material_override = _terrain_material(bool(reg.river))
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
	_build_river()
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
	var inland: bool = not bool(reg.get("coast", false))
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
			var data: Color = Shaders.encode(shown, float(g.temperature), float(g.rainfall), 0.0)
			if inner:
				data.b = 1.0 if is_finite(_water_height_at(x, z, 1.9)) else 0.0
				forests[inner_z * (field_res + 1) + inner_x] = _forest_chance(g)
			else:
				data.b = 0.0
			colors[index] = data
		if row % rows_per_frame == 0:
			region_progress.emit(true, float(row) / rows * .8)
			await get_tree().process_frame
			if token != region_load_token:
				return false
	field_has_sea = not inland
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
	if field_has_sea:
		_clear_waterline(relief, xs, zs, sea_level())
	for inner_z: int in range(field_res + 1):
		for inner_x: int in range(field_res + 1):
			var index: int = (inner_z + APRON_RINGS) * columns + inner_x + APRON_RINGS
			heights[inner_z * (field_res + 1) + inner_x] = relief[index]
	height_field = heights
	forest_field = forests
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
	terrain.material_override = _terrain_material(bool(reg.river))
	surface.add_child(terrain)
	_build_river()
	_build_sea()
	_build_nature()
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
			relief[index] = h
		if row % (rows_per_frame * 4) == 0:
			await get_tree().process_frame
			if token != region_load_token:
				return false
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
	return sea + signf(depth) * SHORE_BAND * pow(absf(depth) / SHORE_BAND, SHORE_POWER)


## Every shoreline crosses the water steeply, on the final ground (after the town's calm, the
## rivers and the pads): land just above the sea is lifted into a low bank, and seabed just below
## it drops away, by at least a set part of the grid's cell where the far rings are coarse. The
## seabed is hidden under the opaque sea, so its drop changes nothing to see but where the bank
## meets the water.
static func _clear_waterline(
	relief: PackedFloat32Array, xs: PackedFloat32Array, zs: PackedFloat32Array, sea: float
) -> void:
	var columns: int = xs.size()
	for row: int in range(zs.size()):
		var cell_z: float = _cell(zs, row)
		for column: int in range(columns):
			var index: int = row * columns + column
			var depth: float = relief[index] - sea
			if depth >= WATERLINE_BAND:
				continue
			if depth >= 0.0:
				relief[index] += WATERLINE_LIP * (1.0 - smoothstep(0.0, WATERLINE_BAND, depth))
				continue
			var drop: float = maxf(SEABED_DROP, SEABED_SLOPE * maxf(_cell(xs, column), cell_z))
			relief[index] = minf(relief[index], sea - drop)


## The widest gap from a grid line to its neighbours.
static func _cell(axis: PackedFloat32Array, index: int) -> float:
	var before: float = axis[index] - axis[index - 1] if index > 0 else 0.0
	var after: float = axis[index + 1] - axis[index] if index < axis.size() - 1 else 0.0
	return maxf(before, after)


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
	for segment in local_river_segments:
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var t: float = clampf((p - a).dot(b - a) / maxf(a.distance_squared_to(b), .001), 0, 1)
		var distance: float = p.distance_to(a.lerp(b, t))
		var width: float = segment.width
		if distance < width * 2:
			var water: float = lerpf(segment.ya, segment.yb, t)
			height = lerpf(water - .28, height, smoothstep(width * .72, width * 2, distance))
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


## One ribbon per river, so a winding channel is one mesh rather than one node per bend.
func _build_river() -> void:
	if str(world.version) == "CC-GEO-1.4":
		if world.regions[selected_region].river:
			_build_legacy_river()
		return
	var ribbons: Dictionary = {}
	for segment in local_river_segments:
		var key: int = int(segment.river_index)
		if not ribbons.has(key):
			var fresh := SurfaceTool.new()
			fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
			ribbons[key] = fresh
		var st: SurfaceTool = ribbons[key]
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var normal: Vector2 = (b - a).normalized().orthogonal()
		var side_a: Vector2 = normal * float(segment.width_a)
		var side_b: Vector2 = normal * float(segment.width_b)
		var aa := Vector3(a.x - side_a.x, segment.ya, a.y - side_a.y)
		var ab := Vector3(a.x + side_a.x, segment.ya, a.y + side_a.y)
		var ba := Vector3(b.x - side_b.x, segment.yb, b.y - side_b.y)
		var bb := Vector3(b.x + side_b.x, segment.yb, b.y + side_b.y)
		for vertex in [aa, ab, ba, ab, bb, ba]:
			st.add_vertex(vertex)
	var material: Material = _water_material("river", Color("224f59"))
	for key: int in ribbons:
		var st: SurfaceTool = ribbons[key]
		st.generate_normals()
		_mesh(surface, st.commit(), Vector3.ZERO, material)
	for lake in local_lakes:
		_cylinder(
			surface,
			Vector3(lake.center.x, lake.height, lake.center.y),
			lake.radius,
			.025,
			_water_material("lake", Color("2e798a")),
			40
		)


func _build_legacy_river() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var reg: Dictionary = world.regions[selected_region]
	for i in range(river_steps):
		var z: float = -half_depth + i * RIVER_STEP
		var nz: float = z + RIVER_STEP
		var x: float = (Geo.river_lon(float(reg.lat) - z / 4.0) - float(reg.lon)) * 4.0
		var nx: float = (Geo.river_lon(float(reg.lat) - nz / 4.0) - float(reg.lon)) * 4.0
		for v in [
			Vector3(x - 1.35, -.24, z),
			Vector3(x + 1.35, -.24, z),
			Vector3(nx - 1.35, -.24, nz),
			Vector3(x + 1.35, -.24, z),
			Vector3(nx + 1.35, -.24, nz),
			Vector3(nx - 1.35, -.24, nz)
		]:
			st.add_vertex(v)
	st.generate_normals()
	var river := MeshInstance3D.new()
	river.mesh = st.commit()
	river.material_override = _mat("river", Color("2a818b"), .42, .19)
	surface.add_child(river)
	for lane in [-.7, .25, .85]:
		var points: Array[Vector3] = []
		for i in range(river_steps):
			var z: float = -half_depth + i * RIVER_STEP
			var x: float = (Geo.river_lon(float(reg.lat) - z / 4.0) - float(reg.lon)) * 4.0 + lane
			points.append(Vector3(x, -.225, z))
		_line(surface, points, Color(.4, .7, .72, .4), .2)


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


## Moving water: rippling normals over the same colours as before.
func _water_material(kind: String, tint: Color) -> ShaderMaterial:
	var key: String = "water_" + kind
	if not mats.has(key):
		var material := ShaderMaterial.new()
		material.shader = Shaders.shader("water")
		material.set_shader_parameter("noise3d", Shaders.noise_texture())
		material.set_shader_parameter("tint", tint)
		mats[key] = material
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
