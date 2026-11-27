extends RefCounted
## Local east/north azimuthal-equidistant chart. The drainage lines come from the
## same receivers and physical channel widths as the orbital water texture.

const Geo = preload("res://world/world_gen.gd")
const SeedGeo = preload("res://world/seed_geography.gd")
const Plates = preload("res://world/geo2/plates.gd")
const Hydrology = preload("res://world/hydrology.gd")
const SiteGen = preload("res://world/geo2/site_gen.gd")
const WET := -10000.0

var world: Dictionary
var plates: Dictionary
var noise := FastNoiseLite.new()
var center: Vector3
var east: Vector3
var north: Vector3
var lat: float
var lon: float
var span: float
var size: int
var channels: Image
var river_here := false
var lakes_here := false
var optical: Dictionary


func _init(data: Dictionary, location: Vector2, half_span: float, resolution: int) -> void:
	world = data
	plates = world.get("plates", {})
	optical = world.get("optical_drainage", {})
	noise.seed = int(world.get("seed", 0))
	noise.frequency = 1.8
	noise.fractal_octaves = 4
	lat = location.x
	lon = wrapf(location.y, -180, 180)
	center = SeedGeo.unit(lat, lon)
	east = Vector3(cos(deg_to_rad(lon)), 0, -sin(deg_to_rad(lon)))
	north = center.cross(east).normalized()
	span = half_span
	size = resolution
	channels = Image.create(size, size, false, Image.FORMAT_L8)
	if not optical.is_empty():
		_draw_drainage()
	else:
		_draw_legacy_water()


## Pixel coordinates refer to pixel centres; north is the top of the picture.
func coordinate(pixel: Vector2) -> Vector2:
	return SeedGeo.coordinate(_point(pixel))


func _point(pixel: Vector2) -> Vector3:
	var offset := ((pixel + Vector2(0.5, 0.5)) / size * 2.0 - Vector2.ONE) * deg_to_rad(span)
	var arc := offset.length()
	if arc < 0.0000001:
		return center
	var tangent := (east * offset.x - north * offset.y) / arc
	return center * cos(arc) + tangent * sin(arc)


func _pixel(ll: Vector2) -> Vector2:
	var point: Vector3 = SeedGeo.unit(ll.x, ll.y)
	var tangent := Vector2(point.dot(east), -point.dot(north))
	var length := tangent.length()
	var arc := atan2(length, point.dot(center))
	if length > 0.0000001:
		tangent *= arc / length
	return (tangent / deg_to_rad(span) + Vector2.ONE) * (0.5 * size) - Vector2(0.5, 0.5)


func _mark_line(a: Vector2, b: Vector2, radius: float) -> void:
	var pad := Vector2.ONE * (radius + 1.0)
	var lo := Vector2i((a.min(b) - pad).floor()).max(Vector2i.ZERO)
	var hi := Vector2i((a.max(b) + pad).ceil()).min(Vector2i(size - 1, size - 1))
	var ab := b - a
	var denom := maxf(ab.length_squared(), 0.000001)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var p := Vector2(x, y)
			var near := a + ab * clampf((p - a).dot(ab) / denom, 0.0, 1.0)
			if p.distance_squared_to(near) <= radius * radius:
				channels.set_pixel(x, y, Color.WHITE)
				river_here = true


func _draw_drainage() -> void:
	var width := int(optical.width)
	var height := int(optical.height)
	var receivers: PackedInt32Array = optical.route
	var widths: PackedFloat32Array = optical.widths_km
	var lake: PackedByteArray = optical.lake
	var km_to_pixel := size / (2.0 * deg_to_rad(span) * float(optical.radius_km))
	var dy := ceili(span * 1.5 / 180.0 * height) + 2
	# A spherical cap that reaches a pole must inspect every longitude.
	var cap := deg_to_rad(span * 1.5)
	var lon_span := 180.0
	if absf(lat) + rad_to_deg(cap) < 89.9:
		lon_span = rad_to_deg(asin(minf(1.0, sin(cap) / cos(deg_to_rad(lat)))))
	var dx := mini(width / 2, ceili(lon_span / 360.0 * width) + 2)
	var row := int((90.0 - lat) / 180.0 * height)
	var col := int((lon + 180.0) / 360.0 * width)
	for y in range(maxi(0, row - dy), mini(height, row + dy + 1)):
		for x in range(col - dx, mini(col + dx + 1, col - dx + width)):
			var i := y * width + posmod(x, width)
			lakes_here = lakes_here or lake[i] > 0
			var j := receivers[i]
			if widths[i] <= 0.0 or j < 0:
				continue
			var a := Vector2(90.0 - (y + 0.5) * 180.0 / height, (i % width + 0.5) * 360.0 / width - 180.0)
			var b := Vector2(90.0 - (j / width + 0.5) * 180.0 / height, (j % width + 0.5) * 360.0 / width - 180.0)
			_mark_line(_pixel(a), _pixel(b), maxf(0.8, widths[i] * km_to_pixel * 0.5))


func _draw_legacy_water() -> void:
	var reach := deg_to_rad(span * 1.7 + 9.0)
	for river: Array in world.get("rivers", []):
		for k in range(1, river.size()):
			var a := Vector2(float(river[k - 1][0]), float(river[k - 1][1]))
			var b := Vector2(float(river[k][0]), float(river[k][1]))
			if center.dot(SeedGeo.unit(a.x, a.y)) < cos(reach) and center.dot(SeedGeo.unit(b.x, b.y)) < cos(reach):
				continue
			_mark_line(_pixel(a), _pixel(b), maxf(0.9, size * 0.042 / (2.0 * span)))
	for lake: Dictionary in world.get("lakes", []):
		var ll := Vector2(float(lake.lat), float(lake.lon))
		if center.dot(SeedGeo.unit(ll.x, ll.y)) >= cos(reach):
			var p := _pixel(ll)
			_mark_line(p, p, float(lake.get("radius_degrees", 0.45)) * size / (2.0 * span))


func channel_at(p: Vector2i) -> bool:
	return channels.get_pixel(p.x, p.y).r > 0.5


## The detailed coastline may wind through a parcel even when its sampled
## centre and all neighbouring centres are dry. Test the actual emitted texels.
func dry(p: Vector2i) -> bool:
	if plates.is_empty():
		return elevation(p) >= 0.0
	if channel_at(p):
		return false
	var point := _point(Vector2(p))
	if lakes_here:
		var ll := SeedGeo.coordinate(point)
		if float(Hydrology.sample_water(world, ll.x, ll.y).lake_fraction) >= 0.30:
			return false
	var parts := Plates.raw_height(point, noise, plates)
	return float(parts.raw) > float(plates.sea_level)


## Elevation is in the same normalized units as the regional terrain. Negative
## values exclude sea, lakes and channels. Never substitute the nearest land cell
## for the actual sampled surface at an otherwise legal coastal landing.
func elevation(p: Vector2i) -> float:
	if channel_at(p):
		return WET
	var ll := coordinate(Vector2(p))
	if lakes_here and float(Hydrology.sample_water(world, ll.x, ll.y).lake_fraction) >= 0.30:
		return WET
	var sample: Dictionary
	if not plates.is_empty():
		sample = Plates.sample_with_context(ll.x, ll.y, noise, plates)
	elif world.has("version") and world.has("seed"):
		sample = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
	elif world.has("grid_width") and world.has("grid_height") and not world.get("grid", []).is_empty():
		sample = world.grid[SiteGen.cell_at(world, ll.x, ll.y)]
	else:
		return 0.0
	return (
		maxf(0.0, float(sample.get("height", 0.0)))
		if bool(sample.get("land", true)) and not bool(sample.get("lake", false))
		else WET
	)
