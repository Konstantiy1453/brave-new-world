extends RefCounted
## Projects the light generator's local east/north images onto the world's equirectangular map.
const Generator = preload("res://world/settlement_light_generator.gd")
const LightRecord = preload("res://simulation/light_record.gd")
const WIDTH := 6144
const HEIGHT := WIDTH / 2

var _stamps: Dictionary = {}
var _last_layout: Array = []


## One instance belongs to one world. Only a change visible on the map requires an upload.
func paint(world: Dictionary, towns: Array, rules: Dictionary) -> Image:
	var layout: Array = []
	var stages: Array = rules.get("stages", [])
	for town: Dictionary in towns:
		var fade := clampi(roundi(float(town.get("fade", 1.0)) * 8.0), 0, 8)
		if fade == 0:
			continue
		var stage := clampi(floori(LightRecord.town_level(stages, town)), 0, 4)
		var key := var_to_str([town.region, town.lat, town.lon, town.get("frontier", false), stage])
		layout.append([key, fade])
		if not _stamps.has(key):
			_stamps[key] = _project(Generator.generate(world, town, stage), town)
	if layout == _last_layout:
		return null
	_last_layout = layout
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGB8)
	for entry: Array in layout:
		var stamp: Dictionary = _stamps[entry[0]]
		var addresses: PackedInt32Array = stamp.addresses
		var colors: PackedColorArray = stamp.colors
		var fade := float(entry[1]) / 8.0
		for i: int in addresses.size():
			var x := addresses[i] % WIDTH
			var y := floori(float(addresses[i]) / WIDTH)
			var ink: Color = colors[i] * fade
			var old := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(maxf(old.r, ink.r), maxf(old.g, ink.g), maxf(old.b, ink.b)))
	image.generate_mipmaps()
	return image


## Inverse azimuthal equidistant projection. Longitude wraps at the seam; a footprint that
## contains either pole can legitimately occupy the full width of its northern/southern rows.
static func _project(footprint: Dictionary, town: Dictionary) -> Dictionary:
	var addresses := PackedInt32Array()
	var colors := PackedColorArray()
	var stamp := {"addresses": addresses, "colors": colors}
	var source: Image = footprint.get("image")
	var span := float(footprint.get("half_span", 0.0))
	if source == null or span <= 0.0:
		return stamp
	source = source.duplicate()
	var size := maxi(2, ceili(2.0 * span * WIDTH / 360.0))
	source.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var lat := deg_to_rad(float(town.lat))
	var lon := deg_to_rad(wrapf(float(town.lon), -180.0, 180.0))
	var origin := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
	var east := Vector3(cos(lon), 0.0, -sin(lon))
	var north := Vector3(-sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
	var radius := deg_to_rad(span * sqrt(2.0))
	var north_y := maxi(0, floori((0.5 - (lat + radius) / PI) * HEIGHT))
	var south_y := mini(HEIGHT - 1, ceili((0.5 - (lat - radius) / PI) * HEIGHT))
	var west_x := 0
	var east_x := WIDTH - 1
	if absf(lat) + radius < PI * 0.5:
		var longitude_range := asin(clampf(sin(radius) / cos(lat), 0.0, 1.0))
		west_x = floori((0.5 + (lon - longitude_range) / TAU) * WIDTH)
		east_x = ceili((0.5 + (lon + longitude_range) / TAU) * WIDTH)
	for x: int in range(west_x, east_x + 1):
		var target_lon := ((float(x) + 0.5) / WIDTH - 0.5) * TAU
		var meridian := Vector3(sin(target_lon), 0.0, cos(target_lon))
		for y: int in range(north_y, south_y + 1):
			var target_lat := (0.5 - (float(y) + 0.5) / HEIGHT) * PI
			var q := meridian * cos(target_lat) + Vector3.UP * sin(target_lat)
			var tangent := Vector2(q.dot(east), -q.dot(north))
			var length := tangent.length()
			if length > 0.0:
				tangent *= rad_to_deg(atan2(length, q.dot(origin))) / length
			var uv := tangent / (2.0 * span) + Vector2(0.5, 0.5)
			if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
				continue
			var pixel := (uv * size - Vector2(0.5, 0.5)).clamp(Vector2.ZERO, Vector2(size - 1, size - 1))
			var ix := floori(pixel.x)
			var iy := floori(pixel.y)
			var jx := mini(ix + 1, size - 1)
			var jy := mini(iy + 1, size - 1)
			var top := source.get_pixel(ix, iy).lerp(source.get_pixel(jx, iy), pixel.x - ix)
			var bottom := source.get_pixel(ix, jy).lerp(source.get_pixel(jx, jy), pixel.x - ix)
			var ink := top.lerp(bottom, pixel.y - iy)
			if maxf(ink.r, maxf(ink.g, ink.b)) >= 0.5 / 255.0:
				addresses.append(y * WIDTH + posmod(x, WIDTH))
				colors.append(ink)
	return {"addresses": addresses, "colors": colors}
