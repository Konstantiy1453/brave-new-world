extends RefCounted
## The settlement's paving (1.12): revision 06's street widths and revision 07's paved roads,
## gutters, footways, kerbs, gravel shoulders and yards (the district handoff's streets06.gd) on
## the live town's streets, in district units with metric widths. Roads are polylines already
## bent (district_plan.gd); each surface is a strip lifted a few centimetres over the ground's own
## triangles and drawn a little toward the camera, so it never sinks into the slope or flickers.

const DistrictPlan = preload("res://world/district/district_plan.gd")

## Height over the ground of each surface, in metres (streets06.gd lifts).
const LIFT_M: Dictionary = {
	"asphalt": .115,
	"gutter": .126,
	"walk": .145,
	"edge": .171,
	"paint": .137,
	"white": .136,
	"gravel": .080,
	"yard": .110,
	"sand": .090,
}
const COLOURS: Dictionary = {
	"asphalt": ["777572", .34, true],
	"gutter": ["837f72", .20, false],
	"walk": ["928a76", .26, false],
	"edge": ["a09883", .20, false],
	"paint": ["b6ab81", .07, false],
	"white": ["c3c2ac", .08, false],
	"gravel": ["a39983", .32, false],
	"yard": ["a39b89", .26, false],
	"sand": ["998b70", .36, false],
}
## A strip is cut into pieces about this long, in metres, so it follows the ground.
const PIECE_M: float = 2.4
## Footways along the through road and the yards' gravel aprons, in metres.
const FOOTWAY_M: float = 2.2
const SHOULDER_M: float = .46
const GUTTER_M: float = .19

const PAVING_SHADER: String = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color;
uniform float grain = 0.11;
uniform bool road = false;
uniform float metres_per_unit = 16.6;
varying vec2 at;
float hash(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z); }
float value_noise(vec2 p) { vec2 a = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(a), hash(a + vec2(1, 0)), f.x), mix(hash(a + vec2(0, 1)),
		hash(a + vec2(1, 1)), f.x), f.y); }
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * metres_per_unit;
	// Drawn a little toward the camera, so paving never flickers against the ground below.
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz *= 0.9986;
	POSITION = PROJECTION_MATRIX * view;
}
void fragment() {
	float coarse = value_noise(at * .38) - .5;
	float fine = (value_noise(at * 11.) - .5) * (1.0 - smoothstep(.05, .30, max(fwidth(at.x),
		fwidth(at.y))));
	float middle = value_noise(at * 2.1) - .5;
	float variation = 1.0 + grain * (coarse * 1.26 + middle * .72 + fine * .9);
	if (road) {
		float offset = value_noise(at * .17) * .22 - .11;
		float wheel = abs(abs(abs(UV.x) + offset - .51 * UV.y) - .79);
		float rubbed = (1. - smoothstep(.06, .43, wheel)) * (.48 + value_noise(at * .21) * .5);
		float shoulder = smoothstep(.65, .99, abs(UV.x) / max(UV.y, 1.));
		variation += .42 * shoulder - .23 * rubbed + .18 * (value_noise(floor(at * .27)) - .5);
	}
	ALBEDO = tint.rgb * variation;
	ROUGHNESS = .93;
	SPECULAR = .23;
}
"""

static var _shader: Shader

var buffers: Dictionary = {}
var ground: Callable
## Paved footprints drawn, as [polyline (bent, units), half width (units)], for the shoulders'
## mask and for keeping rocks and plants off the paving.
var paved: Array = []


func _init(height: Callable) -> void:
	ground = height
	for key: String in COLOURS:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		buffers[key] = st


## A street along a bent polyline: "through" (paved, footways, centre line), "lane" or "works"
## (paved, gutters, gravel shoulders), "walk" (a footway) or "yard" (a service yard).
func street(points: PackedVector2Array, kind: String) -> void:
	if points.size() < 2:
		return
	var width_m: float = float(DistrictPlan.ROAD_M.get(kind, DistrictPlan.ROAD_M.lane))
	var path: PackedVector2Array = _resample(points, PIECE_M * DistrictPlan.UNIT)
	var half: float = width_m * .5
	match kind:
		"walk":
			_ribbon(path, "walk", -half, half)
			paved.append([path, half * DistrictPlan.UNIT])
		"yard":
			_ribbon(path, "yard", -half, half)
			_ribbon(path, "gravel", half, half + SHOULDER_M * 2.0)
			_ribbon(path, "gravel", -half - SHOULDER_M * 2.0, -half)
			paved.append([path, half * DistrictPlan.UNIT])
		_:
			_ribbon(path, "asphalt", -half, half)
			_ribbon(path, "gutter", -half, -half + GUTTER_M)
			_ribbon(path, "gutter", half - GUTTER_M, half)
			if kind == "through":
				_ribbon(path, "walk", half, half + FOOTWAY_M)
				_ribbon(path, "walk", -half - FOOTWAY_M, -half)
				_ribbon(path, "edge", half, half + .18)
				_ribbon(path, "edge", -half - .18, -half)
				_centre_line(path)
				paved.append([path, (half + FOOTWAY_M) * DistrictPlan.UNIT])
			else:
				_ribbon(path, "gravel", half - .03, half + SHOULDER_M)
				_ribbon(path, "gravel", -half - SHOULDER_M, -half + .03)
				paved.append([path, (half + SHOULDER_M) * DistrictPlan.UNIT])


## The meshes, one per surface that has any strip, under `parent`.
func commit(parent: Node3D) -> void:
	for key: String in buffers:
		var st: SurfaceTool = buffers[key]
		var mesh: ArrayMesh = st.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var node := MeshInstance3D.new()
		node.name = "Paving_" + key
		node.mesh = mesh
		node.material_override = material(key)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)


## Distance in units from a ground point to the nearest paving edge (negative inside).
func clearance(at: Vector2) -> float:
	var best: float = INF
	for entry: Array in paved:
		var path: PackedVector2Array = entry[0]
		var half: float = float(entry[1])
		for index: int in range(path.size() - 1):
			var near: Vector2 = Geometry2D.get_closest_point_to_segment(
				at, path[index], path[index + 1]
			)
			best = minf(best, at.distance_to(near) - half)
	return best


static func material(key: String) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = PAVING_SHADER
	var spec: Array = COLOURS.get(key, COLOURS.walk)
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", Color(str(spec[0])))
	m.set_shader_parameter("grain", float(spec[1]))
	m.set_shader_parameter("road", bool(spec[2]))
	m.set_shader_parameter("metres_per_unit", DistrictPlan.METRES_PER_UNIT)
	return m


## A strip from `left` to `right` metres across the path, as the reference's `_strip`: UV.x the
## distance across in metres, UV.y half the strip's width in metres.
func _ribbon(path: PackedVector2Array, key: String, left: float, right: float) -> void:
	var st: SurfaceTool = buffers[key]
	var lift: float = float(LIFT_M.get(key, .12)) * DistrictPlan.UNIT
	var lo: float = minf(left, right)
	var hi: float = maxf(left, right)
	var half_span: float = .5 * (hi - lo)
	for index: int in range(path.size() - 1):
		var a: Vector2 = path[index]
		var b: Vector2 = path[index + 1]
		var side_a: Vector2 = _side(path, index)
		var side_b: Vector2 = _side(path, index + 1)
		var al: Vector3 = _surface(a + side_a * lo * DistrictPlan.UNIT, lift)
		var ar: Vector3 = _surface(a + side_a * hi * DistrictPlan.UNIT, lift)
		var bl: Vector3 = _surface(b + side_b * lo * DistrictPlan.UNIT, lift)
		var br: Vector3 = _surface(b + side_b * hi * DistrictPlan.UNIT, lift)
		var points: Array = [al, bl, ar, ar, bl, br]
		var across: Array = [lo, lo, hi, hi, lo, hi]
		for corner: int in range(6):
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(float(across[corner]), half_span))
			st.add_vertex(points[corner])


## Dashes down the middle of the through road (streets06.gd: 3.25 m in every 8.8 m).
func _centre_line(path: PackedVector2Array) -> void:
	var st: SurfaceTool = buffers.paint
	var lift: float = float(LIFT_M.paint) * DistrictPlan.UNIT
	var travelled: float = 0.0
	for index: int in range(path.size() - 1):
		var a: Vector2 = path[index]
		var b: Vector2 = path[index + 1]
		var step: float = a.distance_to(b) * DistrictPlan.METRES_PER_UNIT
		var middle: float = travelled + step * .5
		travelled += step
		if fmod(middle, 8.8) >= 3.25:
			continue
		var side_a: Vector2 = _side(path, index)
		var side_b: Vector2 = _side(path, index + 1)
		var w: float = .072 * DistrictPlan.UNIT
		var al: Vector3 = _surface(a - side_a * w, lift)
		var ar: Vector3 = _surface(a + side_a * w, lift)
		var bl: Vector3 = _surface(b - side_b * w, lift)
		var br: Vector3 = _surface(b + side_b * w, lift)
		for corner: Vector3 in [al, bl, ar, ar, bl, br]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0.0, .072))
			st.add_vertex(corner)


func _surface(at: Vector2, lift: float) -> Vector3:
	return Vector3(at.x, float(ground.call(at.x, at.y)) + lift, at.y)


static func _side(path: PackedVector2Array, index: int) -> Vector2:
	var before: Vector2 = path[maxi(index - 1, 0)]
	var after: Vector2 = path[mini(index + 1, path.size() - 1)]
	var heading: Vector2 = (after - before).normalized()
	return Vector2(-heading.y, heading.x)


static func _resample(points: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for index: int in range(points.size() - 1):
		var a: Vector2 = points[index]
		var b: Vector2 = points[index + 1]
		var pieces: int = maxi(1, ceili(a.distance_to(b) / step))
		for piece: int in range(pieces):
			out.append(a.lerp(b, float(piece) / pieces))
	out.append(points[points.size() - 1])
	return out
