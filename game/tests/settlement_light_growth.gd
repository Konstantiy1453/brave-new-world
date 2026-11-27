extends SceneTree
## godot --headless --path game --script res://tests/settlement_light_growth.gd

const Lights = preload("res://world/settlement_light_generator.gd")
const Ground = preload("res://world/settlement_light_ground.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")
const World = preload("res://world/world_gen.gd")
const CENTER := Vector2i(Lights.SIZE / 2, Lights.SIZE / 2)
const DRY := {"land": true, "height": 0.1}
const WET := {"land": false, "height": 0.0}

var failures := PackedStringArray()
var checks := 0


func _initialize() -> void:
	_real_sites()
	_separated_banks()
	_unresolved_inlet()
	_polar_seam()
	_narrow_shore()
	if failures.is_empty():
		print("SETTLEMENT_LIGHT_GROWTH PASS checks=", checks)
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)


func _fixture(seed_value: int, width: int, height: int, surface: Dictionary) -> Dictionary:
	var grid := []
	grid.resize(width * height)
	grid.fill(surface)
	return {"seed": seed_value, "grid": grid, "grid_width": width, "grid_height": height}


func _frame(world: Dictionary, town: Dictionary, stage: int) -> PackedByteArray:
	var image: Image = Lights.generate(world, town, stage).image
	return image.get_data()


func _chart(world: Dictionary, town: Dictionary) -> Ground:
	return Ground.new(world, Vector2(town.lat, town.lon), Lights.HALF_SPAN, Lights.SIZE)


func _stages(world: Dictionary, town: Dictionary, label: String, check_water := true) -> void:
	var ground := _chart(world, town)
	var previous := PackedByteArray()
	var last_energy := 0
	var area := PackedInt32Array()
	for stage in 5:
		var pixels := _frame(world, town, stage)
		var energy := 0
		var occupied := 0
		var wet := false
		var dimmed := false
		for i in Lights.SIZE * Lights.SIZE:
			energy += pixels[i * 3]
			if pixels[i * 3] > 10:
				occupied += 1
			if pixels[i * 3] > 0 and check_water:
				var p := Vector2i(i % Lights.SIZE, i / Lights.SIZE)
				if ground.elevation(p) < 0:
					wet = true
			if not previous.is_empty():
				for channel in 3:
					if pixels[3 * i + channel] < previous[3 * i + channel]:
						dimmed = true
		_check(energy > last_energy, "%s stage %d did not grow (%d -> %d)" % [label, stage, last_energy, energy])
		_check(not dimmed, "%s stage %d erased previously lit streets" % [label, stage])
		_check(not wet, "%s stage %d illuminated water" % [label, stage])
		last_energy = energy
		previous = pixels
		area.append(occupied)
	if area[4] > 75:
		for stage in range(1, 5):
			_check(area[stage] > area[stage - 1], "%s stage %d footprint did not grow" % [label, stage])
		# Allow street texture contrast when comparing occupied texels.
		var mean_width := (sqrt(area[3]) - sqrt(area[1])) / 2
		var capital_width := sqrt(area[4]) - sqrt(area[3])
		_check(
			capital_width >= 0.65 * mean_width and capital_width <= 1.40 * mean_width,
			"%s final expansion %s should match previous mean %s" % [label, capital_width, mean_width]
		)
	print(label, " lit texels by stage: ", area)


func _real_sites() -> void:
	var world: Dictionary = World.new().build(260129, 1)
	var coast := {"lat": -1.11562597751617, "lon": 91.3167724609375, "region": 2}
	var inland := {"lat": 6.25, "lon": 163.75, "region": 25}
	_stages(world, coast, "CC-GEO coastal island")
	_stages(world, inland, "CC-GEO inland basin")
	var first := _frame(world, coast, 0)
	var final_stage := _frame(world, coast, 4)
	for mine in [{"frontier": true}, {"kind": "frontier"}]:
		_check(_frame(world, coast.merged(mine), 4) == first, "mining outpost exceeded first stage")
	_check(_frame(world, coast, 4) == final_stage, "city changed after visiting a mine")
	# Share the real plate/drainage fields, but give the known dry landing a
	# coarse water cell. The orbital surface, finer than the strategic grid,
	# must continue to follow the actual shore at this coordinate.
	var coarse_water := world.duplicate(false)
	var grid: Array = world.grid.duplicate()
	var index := SiteGen.cell_at(world, inland.lat, inland.lon)
	grid[index] = WET
	coarse_water.grid = grid
	_check(
		not coarse_water.grid[index].land and _chart(coarse_water, inland).elevation(CENTER) >= 0.0,
		"coarse-water fixture has no dry landing"
	)
	_check(_frame(coarse_water, inland, 4) == _frame(world, inland, 4), "coarse cell drowned fine land")


func _separated_banks() -> void:
	var world := _fixture(193, 720, 4, DRY)
	for y in 4:
		# One cell on each side of the longitude seam. Dry land continues on
		# the opposite bank well inside the high-stage city radius.
		for x in [0, 719]:
			world.grid[y * 720 + x] = WET
	var town := {"lat": 2.0, "lon": 179.30}
	var chart := _chart(world, town)
	var image := _frame(world, town, 4)
	var other_bank_lit := 0
	var other_bank_present := false
	for i in Lights.SIZE * Lights.SIZE:
		var p := Vector2i(i % Lights.SIZE, i / Lights.SIZE)
		var lon := chart.coordinate(p).y
		if lon < -179.5 or lon > -177.0:
			continue
		other_bank_present = other_bank_present or chart.elevation(p) >= 0.0
		if image[3 * i] > 0:
			other_bank_lit += 1
	_check(other_bank_present and other_bank_lit == 0, "city jumped to land across an ocean channel")
	_stages(world, town, "split coastline")


func _unresolved_inlet() -> void:
	# This 0.1-degree channel falls *between* dry parcel centres. The dry
	# opposite bank must not inflate the five growth quotas on the near side.
	var world := _fixture(269, 3600, 2, DRY)
	for row in 2:
		world.grid[row * 3600 + 1801] = WET
	var town := {"lat": 0.0, "lon": 0.035}
	var chart := _chart(world, town)
	var pixels := _frame(world, town, 4)
	var far_side := 0
	for i in Lights.SIZE * Lights.SIZE:
		if pixels[3 * i] and chart.coordinate(Vector2(i % Lights.SIZE, i / Lights.SIZE)).y > 0.2:
			far_side += 1
	_check(far_side == 0, "streets crossed a sub-parcel strait")
	_stages(world, town, "sub-parcel inlet")


func _polar_seam() -> void:
	var world := _fixture(17, 360, 90, DRY)
	var town := {"lat": 88.5, "lon": 180.0}
	var chart := _chart(world, town)
	for p in [Vector2(0, 0), Vector2(40, 20), Vector2(20, 90), Vector2(CENTER)]:
		var ll := chart.coordinate(p)
		_check(chart._pixel(ll).distance_to(p) < 0.20, "tangent projection failed across seam or pole")
	var polar := _frame(world, town, 4)
	_check(_frame(world, town.merged({"lon": -180.0}, true), 4) == polar, "equivalent seam longitude changed streets")
	var east := false
	var west := false
	for i in Lights.SIZE * Lights.SIZE:
		if polar[3 * i] > 10:
			var ll := chart.coordinate(Vector2(i % Lights.SIZE, i / Lights.SIZE))
			east = east or ll.y > 0
			west = west or ll.y < 0
	_check(east and west, "polar city did not span the texture seam")
	var again := world.duplicate(false)
	_check(_frame(again, town, 4) == polar, "rebuilding same world changed streets")
	again = world.merged({"seed": 18}, true)
	_check(_frame(again, town, 4) != polar, "different world seed produced identical streets")


func _narrow_shore() -> void:
	# A dry strip fits between ALL parcel centres, while the landing itself
	# touches a narrow river. Only the fine local terrain reveals its dry bank.
	var world := _fixture(23, 7200, 2, WET)
	for y in 2:
		for x in range(3600, 3603):
			world.grid[y * 7200 + x] = DRY
	world.rivers = [[[-6.0, 0.055], [6.0, 0.055]]]
	var town := {"lat": 0.0, "lon": 0.055}
	var chart := _chart(world, town)
	var coarse_dry := 0
	for i in Lights.GRID * Lights.GRID:
		if chart.elevation(Lights._center(i)) >= 0.0:
			coarse_dry += 1
	_check(
		coarse_dry == 0 and chart.elevation(CENTER + Vector2i.RIGHT) >= 0,
		"narrow-shore fixture did not isolate the sub-parcel fallback"
	)
	_stages(world, town, "sub-parcel riverbank")
