extends Node3D
## Shared fields of the map layers. Layers build on each other: base, models, region, flat,
## planet, coordinator. Every geography query uses WorldGen.
signal region_selected(id: int)
signal atlas_refined
signal region_progress(busy: bool, progress: float)
signal region_ready(id: int)
## Shuttle lines (1.9) are drawn in cyan, as arcs above the globe this high at the middle.
const SHUTTLE_COLOR: Color = Color("8fd8ee")
const SHUTTLE_ARC: float = 0.07
const Geo = preload("res://world/world_gen.gd")
const Shaders = preload("res://world/shaders.gd")
## Cargo on the way: the size of its dot on the globe and on the flat map, and how brightly it
## glows. Small, so a busy road reads as a line of traffic rather than a string of beads.
const CARGO_DOT_GLOBE: float = 0.013
const CARGO_DOT_FLAT: float = 0.018
const CARGO_GLOW: float = 1.2
const NightLights = preload("res://world/night_lights.gd")
const VisualClock = preload("res://world/visual_clock.gd")
const REGION_CACHE_LIMIT: int = 3
static var atlas_cache: Dictionary = {}
var world: Dictionary = {}
var state: Dictionary = {}
var mode: String = "planet"
var selected_region: int = 0
var hovered_region: int = -1
var marker_filter: String = "all"
var camera: Camera3D
var planet: Node3D
var flat_world: Node3D
var flat_marker_root: Node3D
var flat_transport_root: Node3D
var geography_atlas: ImageTexture
var flat_size: float = 15.8
var flat_center: Vector2 = Vector2.ZERO
var flat_user_zoomed: bool = false
var surface: Node3D
var marker_root: Node3D
var transport_root: Node3D
var buildings_root: Node3D
var cloud_shell: MeshInstance3D
var globe_shader: ShaderMaterial
var cloud_shader: ShaderMaterial
var atmosphere_shader: ShaderMaterial
var terrain_shader: ShaderMaterial
var night_lights: ImageTexture
## The settlements' night lights for the shaders (night_lights.gd town_uniforms).
var town_lights: Dictionary = {}
var lights_signature: String = ""
## The visual clock: spin, sun, seasons, wind. Never part of the simulation.
var sky: VisualClock = VisualClock.new()
## Player settings for the moving map; the defaults are what a new player sees.
var day_night_enabled: bool = true
## Forward+ is running (高画质): real lamp lights, ambient occlusion and bloom; set at setup.
var high_quality: bool = false
var weather_enabled: bool = true
var sun_light: DirectionalLight3D
var flat_shader: ShaderMaterial
var noise: FastNoiseLite
var planet_yaw: float = -.38
var planet_pitch: float = .22
var planet_distance: float = 10.3
var local_yaw: float = .68
var local_pitch: float = .75
var local_distance: float = 67.0
var smooth_yaw: float = -.38
var smooth_pitch: float = .22
var smooth_distance: float = 10.3
var camera_pivot: Vector3 = Vector3.ZERO
var mats: Dictionary = {}
var signature: String = ""
var marker_signature: String = ""
var transport_signature: String = ""
var selection_ring: MeshInstance3D
var region_ground: float = 0.0
var label_font: Font
var local_river_segments: Array = []
var local_lakes: Array = []
var render_rivers: Array = []
var last_setup_ms: int = 0
var last_atlas_ms: int = 0
var last_atlas_cached: bool = false
var last_atlas_source: String = ""
var atlas_refining: bool = false
var last_refinement_ms: int = 0
var current_atlas_key: String = ""
var pending_atlas: Dictionary = {}
var atlas_job: Dictionary = {}
var region_cache: Dictionary = {}
var region_busy: bool = false
var region_load_token: int = 0
var region_build_count: int = 0
var last_region_ms: int = 0
var last_region_cached: bool = false
var terrain_unique_samples: int = 0


func _ice_latitude() -> float:
	return float(world.get("plates", {}).get("ice_latitude", 76.0))


## Wetter planets are cloudier.
func _cloud_coverage() -> float:
	var rain: float = float(world.get("plates", {}).get("rainfall_base", 0.5))
	return clampf(0.3 + (rain - 0.3) * 1.2, 0.2, 0.8)


## The night-side light map shared by the globe and the flat map; empty until towns exist.
## Hands the settlements' lights to a map shader: on every update and to a shader built later.
func _apply_town_lights(material: ShaderMaterial) -> void:
	if material == null or town_lights.is_empty():
		return
	material.set_shader_parameter("towns", town_lights.towns)
	material.set_shader_parameter("town_style", town_lights.styles)
	material.set_shader_parameter("town_count", int(town_lights.count))


func _night_lights_texture() -> ImageTexture:
	if night_lights == null:
		night_lights = ImageTexture.create_from_image(NightLights.paint([]))
	return night_lights


## Settlements go by their names, sites still waiting for one by the kind of place they are.
static func _site_text(reg: Dictionary, settled: bool) -> String:
	if settled:
		return "◆ " + str(reg.name)
	return str(reg.name) if bool(reg.get("named", true)) else str(reg.terrain)


func _geo_color(
	g: Dictionary,
	lat: float,
	lon: float,
	source_noise: FastNoiseLite = null,
	ice_latitude: float = 76.0
) -> Color:
	var h: float = g.height
	var active_noise: FastNoiseLite = noise if source_noise == null else source_noise
	var value: float = active_noise.get_noise_3dv(Geo.unit_point(lat, lon) * 43.0) * .16
	if absf(lat) > ice_latitude + value * 22.0:
		return Color("bfced2").lightened(maxf(value * .45, 0))
	if h <= 0:
		var sea := Color("123e5c").lerp(Color("12324c"), clampf(-h * 7.0, 0, 1))
		if h > -.026:
			sea = sea.lerp(Color("278d8d"), clampf(1.0 + h / .026, 0, 1) * .7)
		return sea.lightened(maxf(value * .25, 0.0))
	var c := Color("7b9474")
	if g.temperature < -8:
		c = Color("d8e7e6")
	elif h > .65:
		c = Color("c2c5b9").lerp(Color("eff4ec"), clampf((h - .65) * 4.4, 0, 1))
	elif h > .27:
		c = Color("777b6d").lerp(Color("b0aa94"), (h - .27) * 3.0)
	elif g.rainfall < .39:
		c = Color("b9ad7d")
	elif g.temperature > 31:
		c = Color("a8925f") if g.rainfall < .55 else Color("3d6f55")
	elif g.temperature > 19:
		c = Color("47765f")
	elif g.temperature > 3:
		c = Color("63846b")
	else:
		c = Color("8f9c8e")
	if h < .022:
		c = c.lerp(Color("b7b58b"), .6)
	if g.river:
		c = Color("308f94")
	return c.lightened(maxf(value, 0)).darkened(maxf(-value, 0))
