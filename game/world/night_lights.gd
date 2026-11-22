extends RefCounted
## The night side of the map, painted from the colony's own lights (light_field.gd) into one
## equirectangular texture shared by the globe and the flat map: red is warm light (homes), green
## cold white light (work lamps). Each light lands where it stands, spread over the four texels
## round its exact position so it never snaps to the grid, with a faint ring. The mipmaps merge
## lights smoothly as the camera pulls back; the shaders add a restrained halo from a coarser mip.
## At the closest zoom a texel is about a screen pixel, so neighbourhoods stay apart.

const WIDTH: int = 4096
const HEIGHT: int = 2048
## The shaders still declare arrays for towns drawn from a few numbers (1.9); nothing fills them.
const MAX_TOWNS: int = 48
## How much of a light its ring of neighbouring texels gets.
const RING: float = 0.22


## The colony's lights tonight, painted.
static func paint(lights: Array) -> Image:
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RG8)
	for light: Dictionary in lights:
		_add(image, float(light.lat), float(light.lon), float(light.warm), float(light.cold))
	image.generate_mipmaps()
	return image


## Empty town arrays for the shaders' old uniforms: lights come from the texture alone.
static func town_uniforms(_towns: Array = []) -> Dictionary:
	var places: Array = []
	var styles: Array = []
	while places.size() < MAX_TOWNS:
		places.append(Vector4.ZERO)
		styles.append(Vector4.ZERO)
	return {"towns": places, "styles": styles, "count": 0}


## The texel position of a point: x east from the antimeridian, y south from the pole.
static func texel(lat: float, lon: float) -> Vector2:
	return Vector2(
		(wrapf(lon, -180.0, 180.0) + 180.0) / 360.0 * WIDTH - 0.5,
		(90.0 - lat) / 180.0 * HEIGHT - 0.5
	)


## A light: its share on each of the four texels round it, and a faint ring outside them.
static func _add(image: Image, lat: float, lon: float, warm: float, cold: float) -> void:
	var at: Vector2 = texel(lat, lon)
	var x0: int = int(floor(at.x))
	var y0: int = int(floor(at.y))
	var fx: float = at.x - x0
	var fy: float = at.y - y0
	for dy: int in [0, 1]:
		for dx: int in [0, 1]:
			var share: float = (fx if dx == 1 else 1.0 - fx) * (fy if dy == 1 else 1.0 - fy)
			_lighten(image, x0 + dx, y0 + dy, warm * share, cold * share)
	for step: Vector2i in [
		Vector2i(-1, 0),
		Vector2i(2, 0),
		Vector2i(0, -1),
		Vector2i(0, 2),
		Vector2i(-1, 1),
		Vector2i(2, 1),
		Vector2i(1, -1),
		Vector2i(1, 2)
	]:
		_lighten(image, x0 + step.x, y0 + step.y, warm * RING * 0.5, cold * RING * 0.5)


static func _lighten(image: Image, x: int, y: int, warm: float, cold: float) -> void:
	if warm <= 0.0 and cold <= 0.0:
		return
	var px: int = posmod(x, WIDTH)
	var py: int = clampi(y, 0, HEIGHT - 1)
	var old: Color = image.get_pixel(px, py)
	image.set_pixel(px, py, Color(minf(old.r + warm, 1.0), minf(old.g + cold, 1.0), 0.0, 1.0))
