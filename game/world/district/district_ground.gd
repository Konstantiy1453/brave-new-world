extends RefCounted
## The district's ground (1.12): revision 07's soil (docs/handoff/approved-terrain-region/region/
## assets/surface07/soil/soil07.gdshader) on a generated world's landscape. Near the town the
## approved weathered loam and sparse turf, packed earth and a gravel apron along the live town's
## paving (the shoulders' mask is rebuilt from the streets actually drawn, `fringe`); beyond it the
## earlier preview's ground with layered rock on steep and high slopes. The site's own climate
## tints it (07 was made for a dry temperate meadow): dry sites lose their turf, cold ones grey,
## high ground turns to rock and snow as the globe draws it, and banks of rivers and lakes darken.

const DistrictIO = preload("res://world/district/district_io.gd")
const DistrictPlan = preload("res://world/district/district_plan.gd")
const Shaders = preload("res://world/shaders.gd")

const SOIL_DIR: String = "res://assets/district/soil/"
const ENV_DIR: String = "res://assets/district/env/"
## The shoulders' mask: metres per texel, and the farthest distance from the paving it keeps
## (each channel holds the distance in metres over FRINGE_REACH_M, 1 beyond).
const FRINGE_M_PER_TEXEL: float = 2.0
const FRINGE_REACH_M: float = 14.0
## Paving classes of the mask's channels, as soil07's bake (tools/bake_road_fringe.py): roads
## (asphalt, gutters, kerbs, gravel shoulders), service yards, and footways.
const FRINGE_CLASSES: Array[String] = ["road", "yard", "walk"]

const GROUND_SHADER: String = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler3D noise3d : filter_linear, repeat_enable;
uniform float weather_time = 0.0;
uniform vec2 wind = vec2(0.6, 0.25);
uniform float cloud_shadow = 0.35;
uniform float river_tint = 0.0;
uniform sampler2D soil_patch : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_patch : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scrub : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D old_soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D old_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fringe : filter_linear, repeat_disable;
uniform vec4 fringe_rect = vec4(0.0);
uniform float metres_per_unit = 16.6;
uniform vec4 town = vec4(0.0, 0.0, 30.0, 24.0);
uniform float town_level = 0.0;
varying vec4 data;
varying vec3 world_pos;
varying vec3 world_normal;
GEOGRAPHY
float n(vec2 p) { return texture(scrub, p / 64.0).r; }
float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float vnoise(vec2 p) {
	vec2 a = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(a), hash21(a + vec2(1.0, 0.0)), f.x),
		mix(hash21(a + vec2(0.0, 1.0)), hash21(a + vec2(1.0, 1.0)), f.x), f.y);
}
float smooth01(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x * (3.0 - 2.0 * x);
}
// Packed earth (x) and loose gravel (y) at d metres from one class of paving (bake_road_fringe.py).
vec2 shoulder_of(float d, vec3 spec, float wv, float mid, float fine) {
	float packed = 1.0 - smooth01(d / (spec.x * wv));
	float end = spec.y * wv * (0.91 + 0.18 * mid);
	float start = 0.34 * wv;
	float grit = spec.z * (0.4 + 0.6 * smooth01(d / (0.53 * wv)))
		* (1.0 - smooth01((d - start) / max(end - start, 0.01))) * (0.51 + 0.54 * mid + 0.07 * fine);
	return vec2(packed, clamp(grit, 0.0, 1.0));
}

void vertex() {
	data = COLOR;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 m = world_pos.xz * metres_per_unit;
	vec2 p = m / 3.12;
	float n1 = texture(noise3d, world_pos * 0.035).r * 2.0 - 1.0;
	float n2 = texture(noise3d, world_pos * 0.21 + vec3(0.37)).r * 2.0 - 1.0;
	float h = geo_height(data.a);
	float t = data.r * 100.0 - 50.0;
	float rain = data.g;
	// The site's climate: 07's palette is a dry temperate meadow, so other sites shift from it.
	// Turf thins out in dry and cold places; bare ground bleaches toward sand where it is dry and
	// warm, and greys where it is cold.
	float warm = smoothstep(-6.0, 30.0, t);
	float arid = 1.0 - smoothstep(0.12, 0.40, rain + n1 * 0.04);
	float cold = smoothstep(4.0, -9.0, t + n1 * 2.0);
	vec3 tint = mix(vec3(1.0), vec3(1.5, 1.25, 0.9), arid * (0.35 + 0.65 * warm));
	float green = (1.0 - arid) * (1.0 - cold * 0.7);
	// The shoulders of the live town's paving.
	vec2 shoulder = vec2(0.0);
	if (fringe_rect.z > 0.0) {
		vec2 fuv = (world_pos.xz - fringe_rect.xy) / fringe_rect.zw;
		if (fuv.x > 0.0 && fuv.y > 0.0 && fuv.x < 1.0 && fuv.y < 1.0) {
			vec3 dist = texture(fringe, fuv).rgb * FRINGE_REACH;
			float coarse = vnoise(m / 5.9);
			float fine = vnoise(m / 0.95 + 17.0);
			float midn = vnoise((m + vec2(23.9, -45.0)) / 1.9);
			float wv = 0.62 + 0.62 * coarse + 0.32 * fine;
			vec2 road = shoulder_of(dist.r, vec3(1.95, 3.45, 0.92), wv, midn, fine);
			vec2 yard = shoulder_of(dist.g, vec3(2.25, 3.85, 0.96), wv, midn, fine);
			vec2 walk = shoulder_of(dist.b, vec3(1.15, 2.15, 0.75), wv, midn, fine);
			shoulder = max(road, max(yard, walk));
		}
	}
	vec2 warp = vec2(n(p * .057), n(p * .041 + 23.));
	float broad = .44 * n(p * .125 + 2.4 * warp) + .28 * n(p * .33 + warp) + .20 * n(p * .64 + warp.yx)
		+ .08 * n(p * 1.35);
	float old_cover = smoothstep(.28, .65, broad + .08 * n(p * 1.3)) * green;
	float along = dot(p, vec2(.865, -.501));
	float across = dot(p, vec2(.501, .865));
	float strata = n(vec2(along * .16 + 2. * warp.y, across * .25 + 2.7 * warp.x));
	float stone = smoothstep(.60, .88, .46 * strata + .45 * broad + 1.5 * (1. - world_normal.y)
		+ .13 * n(p * .61));
	float edge = clamp(shoulder.x * (.78 + .25 * n(p * .61)) + .03 * n(p * .39), 0., 1.);
	vec3 rgb_soil = texture(old_soil, p * .13).rgb;
	vec3 rgb_rock = texture(old_rock, vec2(.74 * along, .64 * across) * .18).rgb;
	float sl = dot(rgb_soil, vec3(.21, .72, .07));
	float rl = dot(rgb_rock, vec3(.21, .72, .07));
	float detail = .84 + clamp(sl * 1.25 + .16 * n(p * 3.7), .03, .38);
	vec3 old_base = mix(vec3(.126, .085, .046), vec3(.052, .077, .033), old_cover) * detail * tint;
	vec3 exposed = vec3(.109, .109, .086) * (.69 + 2.1 * rl) * (.94 + .11 * strata);
	old_base = mix(old_base, exposed, stone * .92);
	vec3 dust = mix(vec3(.128, .097, .063), vec3(.161, .125, .073), n(p * .25)) * detail
		* mix(vec3(1.0), tint, 0.5);
	old_base = mix(old_base, dust, edge * .88);
	old_base *= .79 + .23 * broad + .15 * (n(p * 3.1) + .55 * n(p * 8.3));
	// The approved close ground round the town, fading to the earlier ground on the hills.
	float reach = length((world_pos.xz - town.xy) / max(town.zw, vec2(1.0)));
	float local = 1. - smoothstep(1.0, 1.7, reach);
	float coarse2 = n(m * .165 + vec2(17.2, -31.));
	float ecology = n(m * .49 + vec2(89., -19.));
	float scatter = n(m * 1.47 + vec2(-63., 107.));
	vec2 drift = vec2(n(m * .068), n(m * .081 + 54.)) - vec2(.5);
	vec2 base_uv = (m + .54 * drift) / 8.;
	vec2 meadow_uv = vec2(.793 * base_uv.x + .609 * base_uv.y, -.609 * base_uv.x + .793 * base_uv.y)
		* 1.08;
	vec4 soil = texture(soil_patch, base_uv);
	vec4 meadow = texture(meadow_patch, meadow_uv + vec2(.21, .71));
	float cover = smoothstep(.26, .67, .48 * broad + .24 * coarse2 + .19 * ecology + .09 * scatter);
	cover = clamp(cover * (1. - .96 * shoulder.x) * (1. - .60 * shoulder.y) * (1. - .23 * stone), 0., 1.)
		* green;
	float upper_clast = smoothstep(.193, .312, soil.a);
	cover *= 1. - .46 * upper_clast * (.42 + .58 * shoulder.y);
	vec3 turf = meadow.rgb * vec3(.96, 1.05, .932);
	vec3 close_color = mix(soil.rgb, turf, cover);
	close_color *= .81 + .24 * broad + .16 * coarse2;
	close_color = mix(close_color, close_color * vec3(.91, .875, .84), .52 * shoulder.x);
	close_color *= 1. + shoulder.y * (.55 * upper_clast + .027);
	float terrain_luma = dot(close_color, vec3(.2126, .7152, .0722));
	close_color = mix(vec3(terrain_luma), close_color, .82) * vec3(.68, .76, .83) * tint;
	close_color = mix(close_color, exposed, .46 * stone);
	local *= 1. - .60 * smoothstep(5., 37., (world_pos.y - town_level) * metres_per_unit);
	vec3 ground = mix(old_base, close_color, local);
	// The globe's high ground, snow and shores, as land_color draws them.
	float rock = smoothstep(0.22, 0.44, h + n2 * 0.035);
	ground = mix(ground, exposed * (1.0 + 0.12 * strata), rock * 0.85);
	float snow = max(smoothstep(0.6, 0.8, h + n2 * 0.05 - t * 0.004),
		smoothstep(-6.0, -13.0, t + n1 * 2.5));
	snow *= 1.0 - 0.55 * smoothstep(0.8, 0.55, world_normal.y);
	ground = mix(ground, vec3(.80, .84, .87) * (.9 + .12 * broad), snow);
	float luma = dot(ground, vec3(0.2126, 0.7152, 0.0722));
	ground = mix(ground, vec3(luma) * vec3(1.02, 1.04, 1.08), cold * 0.55);
	float beach = smoothstep(0.028, 0.005, h) * (1.0 - snow) * smoothstep(-2.0, 8.0, t);
	ground = mix(ground, vec3(.36, .31, .22) * (.85 + .2 * broad) * mix(vec3(1.0), tint, 0.4),
		beach * 0.55 * (1.0 - local * 0.6));
	// Wet banks along rivers and lakes.
	ground = mix(ground, ground * vec3(.66, .74, .70), data.b * .5 + river_tint * .12);
	vec3 drift_at = vec3(world_pos.x + wind.x * weather_time * 3.0, 0.0,
		world_pos.z + wind.y * weather_time * 3.0);
	float cloud = smoothstep(0.52, 0.66,
		texture(noise3d, drift_at * 0.012 + vec3(0.0, weather_time * 0.001, 0.0)).r);
	ALBEDO = ground * (1.0 - cloud * cloud_shadow);
	float original_relief = .065 * n(p * .72) + .017 * n(p * 3.7) + .007 * n(p * 10.) + .014 * sl
		+ .018 * rl * stone;
	float patch_relief = .095 * mix(soil.a, meadow.a, cover);
	patch_relief += .017 * (ecology - .5) + .008 * (scatter - .5);
	patch_relief *= 1. - .23 * shoulder.x;
	float relief = mix(.49 * original_relief, patch_relief, local) / metres_per_unit;
	vec3 q = VERTEX;
	vec3 vn = normalize(NORMAL);
	vec3 px = dFdx(q);
	vec3 py = dFdy(q);
	vec3 r1 = cross(py, vn);
	vec3 r2 = cross(vn, px);
	float det = dot(px, r1);
	if (abs(det) > .0000001) {
		vec3 grad = sign(det) * (dFdx(relief) * r1 + dFdy(relief) * r2);
		NORMAL = normalize(abs(det) * vn - grad);
	}
	ROUGHNESS = clamp(.945 - .065 * upper_clast + .025 * cover, .83, .98);
	SPECULAR = .21;
}
"""

static var _shader: Shader
static var _textures: Dictionary = {}


## A new ground material for one region's landscape: its own shoulders' mask comes later, once the
## town's streets are drawn (`set_fringe`).
static func material(river: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = (GROUND_SHADER.replace("GEOGRAPHY", Shaders.GEOGRAPHY_GLSL).replace(
			"FRINGE_REACH", "%.1f" % FRINGE_REACH_M
		))
	var result := ShaderMaterial.new()
	result.shader = _shader
	result.set_shader_parameter("noise3d", Shaders.noise_texture())
	result.set_shader_parameter("river_tint", 1.0 if river else 0.0)
	result.set_shader_parameter("soil_patch", _texture(SOIL_DIR + "weathered_loam.png"))
	result.set_shader_parameter("meadow_patch", _texture(SOIL_DIR + "sparse_turf.png"))
	result.set_shader_parameter("scrub", _texture(ENV_DIR + "scrub_noise.png"))
	result.set_shader_parameter("old_soil", _texture(ENV_DIR + "soil_basecolor.jpg"))
	result.set_shader_parameter("old_rock", _texture(ENV_DIR + "rock_basecolor.jpg"))
	result.set_shader_parameter("metres_per_unit", DistrictPlan.METRES_PER_UNIT)
	return result


## The town's extent for the close ground: the middle of its buildings, the half extents of their
## box with a margin (units), and the level its pads stand at.
static func set_town(result: ShaderMaterial, centre: Vector2, reach: Vector2, level: float) -> void:
	result.set_shader_parameter("town", Vector4(centre.x, centre.y, reach.x, reach.y))
	result.set_shader_parameter("town_level", level)


## The shoulders' mask from the paving actually drawn: `edges` holds [bent polyline (units), half
## width to the paving's edge (units), class index (FRINGE_CLASSES)]. Each texel keeps, per class,
## the distance in metres from its centre to the nearest paving of that class, over FRINGE_REACH_M.
static func fringe(edges: Array) -> Dictionary:
	if edges.is_empty():
		return {}
	var reach: float = FRINGE_REACH_M * DistrictPlan.UNIT
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for entry: Array in edges:
		var margin: float = float(entry[1]) + reach * 1.5
		for point: Vector2 in entry[0]:
			low = low.min(point - Vector2.ONE * margin)
			high = high.max(point + Vector2.ONE * margin)
	var texel: float = FRINGE_M_PER_TEXEL * DistrictPlan.UNIT
	var width: int = ceili((high.x - low.x) / texel)
	var height: int = ceili((high.y - low.y) / texel)
	var bytes := PackedByteArray()
	bytes.resize(width * height * 3)
	bytes.fill(255)
	var scale: float = 255.0 / reach
	for entry: Array in edges:
		var path: PackedVector2Array = entry[0]
		var half: float = float(entry[1])
		var channel: int = int(entry[2])
		var span: float = half + reach
		for index: int in range(path.size() - 1):
			var a: Vector2 = path[index]
			var v: Vector2 = path[index + 1] - a
			var inverse: float = 1.0 / maxf(v.length_squared(), 0.000001)
			var from := Vector2i(((a.min(a + v) - low - Vector2.ONE * span) / texel).floor())
			var to := Vector2i(((a.max(a + v) - low + Vector2.ONE * span) / texel).ceil())
			from = from.max(Vector2i.ZERO)
			to = to.min(Vector2i(width - 1, height - 1))
			for row: int in range(from.y, to.y + 1):
				var dz: float = low.y + (row + 0.5) * texel - a.y
				var line: int = row * width
				for column: int in range(from.x, to.x + 1):
					var dx: float = low.x + (column + 0.5) * texel - a.x
					var along: float = clampf((dx * v.x + dz * v.y) * inverse, 0.0, 1.0)
					var ex: float = dx - v.x * along
					var ez: float = dz - v.y * along
					var code: int = int(
						clampf((sqrt(ex * ex + ez * ez) - half) * scale, 0.0, 255.0)
					)
					var at: int = (line + column) * 3 + channel
					if code < bytes[at]:
						bytes[at] = code
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGB8, bytes)
	return {
		"texture": ImageTexture.create_from_image(image),
		"rect": Vector4(low.x, low.y, width * texel, height * texel),
		"size": Vector2i(width, height),
		"bytes": bytes,
	}


## Metres from a ground point to the nearest paving of any class, as the mask holds it (to the
## nearest texel), FRINGE_REACH_M when further or outside it.
static func paving_distance(mask: Dictionary, at: Vector2) -> float:
	if mask.is_empty():
		return FRINGE_REACH_M
	var rect: Vector4 = mask.rect
	var size: Vector2i = mask.size
	var column: int = floori((at.x - rect.x) / rect.z * size.x)
	var row: int = floori((at.y - rect.y) / rect.w * size.y)
	if column < 0 or row < 0 or column >= size.x or row >= size.y:
		return FRINGE_REACH_M
	var bytes: PackedByteArray = mask.bytes
	var index: int = (row * size.x + column) * 3
	var code: int = mini(bytes[index], mini(bytes[index + 1], bytes[index + 2]))
	return float(code) / 255.0 * FRINGE_REACH_M


static func set_fringe(result: ShaderMaterial, mask: Dictionary) -> void:
	if mask.is_empty():
		result.set_shader_parameter("fringe_rect", Vector4.ZERO)
		return
	result.set_shader_parameter("fringe", mask.texture)
	result.set_shader_parameter("fringe_rect", mask.rect)


static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = DistrictIO.texture(path)
	return _textures[path]
