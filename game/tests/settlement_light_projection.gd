extends SceneTree
## The colored landmarks have known east and north offsets. Measuring their centers on the
## sphere exercises longitude wrapping and polar distortion independently of city artwork.
const Atlas = preload("res://world/settlement_light_atlas.gd")
const Rules = preload("res://simulation/rules.gd")
const Geo = preload("res://world/seed_geography.gd")
const SPAN := 3.65
const SIZE := 175
const OFFSET := 32

var failures: Array[String] = []


func _initialize() -> void:
	var chart := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var corner := Vector2i(SIZE / 2 - 3, SIZE / 2 - 3)
	chart.fill_rect(Rect2i(corner + Vector2i.RIGHT * OFFSET, Vector2i(7, 7)), Color.RED)
	chart.fill_rect(Rect2i(corner + Vector2i.UP * OFFSET, Vector2i(7, 7)), Color.GREEN)
	for site: Vector2 in [Vector2(0, 179.9), Vector2(89, -45), Vector2(-89.8, 173), Vector2(45, 0)]:
		_check_projection(chart, site)
	_check_many_sites()
	for failure: String in failures:
		push_error(failure)
	print("SETTLEMENT_LIGHT_PROJECTION ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)


func _check_projection(chart: Image, site: Vector2) -> void:
	var stamp := Atlas._project({"image": chart, "half_span": SPAN}, {"lat": site.x, "lon": site.y})
	var addresses: PackedInt32Array = stamp.addresses
	var colors: PackedColorArray = stamp.colors
	var red := Vector3.ZERO
	var green := Vector3.ZERO
	for i: int in addresses.size():
		var x := addresses[i] % Atlas.WIDTH
		var y := addresses[i] / Atlas.WIDTH
		var lat := (0.5 - (y + 0.5) / Atlas.HEIGHT) * 180.0
		var lon := ((x + 0.5) / Atlas.WIDTH - 0.5) * 360.0
		# Each polar equirectangular texel covers proportionally less ground.
		var weighted := Geo.unit(lat, lon) * cos(deg_to_rad(lat))
		red += weighted * colors[i].r
		green += weighted * colors[i].g
	var origin := Geo.unit(site.x, site.y)
	var east := Vector3(cos(deg_to_rad(site.y)), 0.0, -sin(deg_to_rad(site.y)))
	var north := origin.cross(east)
	var arc := deg_to_rad(OFFSET * 2.0 * SPAN / SIZE)
	var expected_red := origin * cos(arc) + east * sin(arc)
	var expected_green := origin * cos(arc) + north * sin(arc)
	var tolerance := deg_to_rad(360.0 / Atlas.WIDTH)
	if red.is_zero_approx() or red.angle_to(expected_red) > tolerance:
		failures.append("East landmark misplaced at %s" % site)
	if green.is_zero_approx() or green.angle_to(expected_green) > tolerance:
		failures.append("North landmark misplaced at %s" % site)


func _check_many_sites() -> void:
	var world := {"grid_width": 1, "grid_height": 1, "grid": [{"land": true, "height": 0.1}]}
	var rules: Dictionary = Rules.read("progression").lights
	var towns: Array = []
	for i: int in 50:
		towns.append({"region": i, "lat": 0.0, "lon": -180.0 + i * 7.0, "frontier": true,
			"population": 1.0, "facilities": 1.0})
	var atlas := Atlas.new()
	var image := atlas.paint(world, towns, rules)
	for town: Dictionary in towns:
		var x := roundi((float(town.lon) / 360.0 + 0.5) * Atlas.WIDTH)
		var area := Rect2i(maxi(0, x - 6), Atlas.HEIGHT / 2 - 6, 13, 13)
		if not _has_light(image.get_region(area)):
			failures.append("Missing mining camp %d" % int(town.region))
	if atlas.paint(world, towns, rules) != null:
		failures.append("An unchanged scene triggered a new upload")
	towns[0].population = 100000
	towns[0].facilities = 1000
	if atlas.paint(world, towns, rules) != null:
		failures.append("Mine expansion changed its fixed light footprint")
	var left := Rect2i(0, Atlas.HEIGHT / 2 - 6, 8, 13)
	var right := Rect2i(Atlas.WIDTH - 8, left.position.y, 8, 13)
	towns[0].lon = 180.0
	var mirrored := atlas.paint(world, towns, rules)
	# A renderer may reuse the atlas for equivalent longitudes.
	if mirrored == null:
		mirrored = image
	for area: Rect2i in [left, right]:
		var original := image.get_region(area)
		if not _has_light(original) or original.get_data() != mirrored.get_region(area).get_data():
			failures.append("The mining camp changed or vanished across the date line at %s" % area)


func _has_light(image: Image) -> bool:
	var data := image.get_data().slice(0, image.get_width() * image.get_height() * 3)
	return data.count(0) < data.size()
