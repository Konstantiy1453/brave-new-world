extends RefCounted
## Map shaders. The atlas holds geography, not colour: red is temperature, green rainfall, blue
## mountain ridge and alpha height. Every view runs the same palette on it per pixel, so coasts
## stay smooth at any zoom and the globe, the flat map and the regional ground agree.
## All globe lighting happens in the planet's own frame: the sun and camera arrive as uniforms
## already turned by the planet's spin.

## Height is stored as alpha = 0.5 + 0.5 * sign(h) * sqrt(|h| / HEIGHT_RANGE): fine steps near the
## sea level, where a coastline needs them, and room for the deepest trenches.
const HEIGHT_RANGE: float = 2.0
const TEMPERATURE_LOW: float = -50.0
const TEMPERATURE_SPAN: float = 100.0

## Decoding the atlas and the shared palette. Colours are written in sRGB and converted once.
const GEOGRAPHY_GLSL: String = """
float geo_height(float a) {
	float s = (a - 0.5) * 2.0;
	return sign(s) * s * s * 2.0;
}

vec3 to_linear(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 land_color(float h, float t, float rain, float ridge, float n1, float n2) {
	float warm = smoothstep(-6.0, 30.0, t);
	vec3 dry = mix(vec3(0.66, 0.63, 0.52), vec3(0.87, 0.73, 0.5), warm);
	vec3 mid = mix(vec3(0.48, 0.57, 0.4), vec3(0.64, 0.65, 0.36), warm);
	vec3 wet = mix(vec3(0.28, 0.44, 0.33), vec3(0.19, 0.42, 0.24), warm);
	float r = rain + n1 * 0.05;
	vec3 c = mix(dry, mid, smoothstep(0.12, 0.44, r));
	c = mix(c, wet, smoothstep(0.46, 0.82, r));
	c = mix(c, vec3(0.6, 0.6, 0.51), smoothstep(5.0, -5.0, t) * 0.8);
	float rock = smoothstep(0.22, 0.44, h + ridge * 0.07 + n2 * 0.035);
	vec3 stone = mix(vec3(0.47, 0.44, 0.38), vec3(0.64, 0.61, 0.54), smoothstep(0.3, 0.75, h));
	c = mix(c, stone, rock);
	float snow = max(
		smoothstep(0.6, 0.8, h + n2 * 0.05 - t * 0.004),
		smoothstep(-6.0, -13.0, t + n1 * 2.5)
	);
	c = mix(c, vec3(0.92, 0.95, 0.96), snow);
	float beach = smoothstep(0.028, 0.005, h) * (1.0 - snow) * smoothstep(-2.0, 8.0, t);
	c = mix(c, vec3(0.80, 0.76, 0.58), beach * 0.7);
	return c * (1.0 + n2 * 0.06 + n1 * 0.04);
}

vec3 sea_color(float h, float n1) {
	float depth = -h;
	vec3 c = mix(vec3(0.2, 0.6, 0.62), vec3(0.12, 0.45, 0.58), smoothstep(0.0, 0.06, depth));
	c = mix(c, vec3(0.07, 0.29, 0.46), smoothstep(0.05, 0.35, depth));
	return mix(c, vec3(0.045, 0.17, 0.31), smoothstep(0.3, 1.1, depth + n1 * 0.08));
}

// Polar ice: an organic edge around the world's ice latitude that the seasons push and pull.
float ice_cover(float lat, float n1, float n2, float ice_lat, float year_phase) {
	float edge = ice_lat - year_phase * sign(lat) * 3.5 + n1 * 6.0 + n2 * 2.0;
	return smoothstep(edge - 1.4, edge + 1.4, abs(lat));
}

vec3 ice_color(float n2) {
	return mix(vec3(0.80, 0.87, 0.90), vec3(0.96, 0.97, 0.98), n2 * 0.5 + 0.5);
}
"""

## Settlements at night at planet scale (1.11 G), in the forms of the user's concept sheet
## 沿海与内陆的灯光形态 (docs/v17/lights/concept_light_forms.webp): two or three warm sparks at the
## landing; then a lit street grid with brighter arterials and dark patches round a white-hot core
## drawn out along the town's main axis, a ragged built-up edge that reaches out along the roads
## the player built and a few arms of its own, more as the town grows. On the coast the arms turn
## inland, the town reaches further inland, its core sits by the water, and the globe's land mask
## cuts it at the real coastline. A few numbers per town (town_forms.gd); a street grid finer than a
## screen pixel is drawn as its mean glow, not shimmer.
const TOWN_LIGHTS_GLSL: String = """
const int MAX_TOWNS = 48;
// A block's side in degrees, the same in every town.
const float STREET_CELL = 0.16;
uniform vec4 towns[48];
uniform vec4 town_style[48];
uniform vec4 town_shape[48];
uniform vec4 town_roads[48];
uniform int town_count = 0;

float town_hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float town_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = town_hash(i);
	float b = town_hash(i + vec2(1.0, 0.0));
	float c = town_hash(i + vec2(0.0, 1.0));
	float d = town_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float town_fbm(vec2 p) {
	return town_noise(p) * 0.55 + town_noise(p * 2.1 + 3.7) * 0.3 + town_noise(p * 4.3 + 7.1) * 0.15;
}

// The angle between two bearings, 0 to pi.
float angle_gap(float a, float b) {
	return abs(mod(a - b + 3.14159265, 6.2831853) - 3.14159265);
}

// The share of a pixel a line of half-width `half_width` lights at `distance` from its axis, all in
// the same units, where a pixel is `pixel` of them: thinner than a pixel, it fades, not breaks up.
float town_line(float distance, float half_width, float pixel) {
	float w = max(half_width, pixel * 0.5);
	return (half_width / w) * (1.0 - smoothstep(w * 0.5, w, distance));
}

// A street grid `cell` degrees apart, turned by `turn` and gently warped, each side of a block lit
// by chance `lit`. Too fine for the pixel, it gives its average instead.
float street_grid(vec2 d, float cell, float turn, float seed, float lit, float pixel, float half_width) {
	vec2 s = vec2(cos(turn) * d.x - sin(turn) * d.y, sin(turn) * d.x + cos(turn) * d.y) / cell;
	s += (vec2(town_noise(s * 0.21 + seed), town_noise(s * 0.21 + seed + 4.3)) - 0.5) * 1.3;
	float px = pixel / cell;
	float row = floor(s.y + 0.5);
	float col = floor(s.x + 0.5);
	float h = town_hash(vec2(floor(s.x), row) + seed);
	float v = town_hash(vec2(col, floor(s.y)) + seed + 0.5);
	float across = step(h, lit) * (0.55 + 0.45 * fract(h * 7.13)) * town_line(abs(s.y - row), half_width, px);
	float along = step(v, lit) * (0.55 + 0.45 * fract(v * 7.13)) * town_line(abs(s.x - col), half_width, px);
	return mix(max(across, along), lit * half_width * 2.9, smoothstep(0.35, 0.9, px));
}

// One settlement's warm and cold light at offset d (degrees east, north) from its centre, in the
// forms of the concept sheet: a web of lit streets, brighter towards a small white-hot core, thin
// roads leading out, a ragged edge.
vec2 town_glow(vec2 d, vec4 town, vec4 style, vec4 shape, vec4 roads, float pixel) {
	float radius = max(town.z, 0.0001);
	float seed = town.w;
	vec2 q = d / radius;
	float r = length(q);
	if (r > 1.7) {
		return vec2(0.0);
	}
	float level = style.z;
	float grown = clamp(level / 4.0, 0.0, 1.0);
	vec2 sea = shape.xy;
	float coastal = step(0.5, length(sea));
	float theta = atan(q.y, q.x);
	float pixel_q = pixel / radius;
	// The landing: a few warm sparks and nothing more.
	float spark = 0.0;
	for (int k = 0; k < 3; k++) {
		vec2 at = vec2(town_hash(vec2(seed, float(k))), town_hash(vec2(float(k) + 0.5, seed))) - 0.5;
		vec2 off = q - at * 0.9;
		spark += exp(-dot(off, off) * 40.0);
	}
	float landing = 1.0 - smoothstep(0.25, 1.0, level);
	// Roads out of town as thin lines of light: the player's past the edge, then the town's own, more
	// as it grows, turned inland on the coast. The built-up edge reaches a little out along them.
	float road = 0.0;
	float reach = 0.0;
	for (int k = 0; k < 4; k++) {
		float bearing = roads[k];
		if (bearing < 9.0) {
			vec2 way = vec2(cos(bearing), sin(bearing));
			float along = dot(q, way);
			float off = dot(q, vec2(-way.y, way.x)) + 0.03 * (town_noise(vec2(along * 5.0, seed + float(k))) - 0.5);
			float line = town_line(abs(off), 0.012, pixel_q) * step(0.0, along);
			road = max(road, line * (1.0 - smoothstep(1.3, 1.65, along)));
			float gap = angle_gap(theta, bearing) / 0.16;
			reach = max(reach, exp(-gap * gap));
		}
	}
	for (int k = 0; k < 10; k++) {
		if (float(k) >= 1.0 + 1.5 * level) {
			break;
		}
		float bearing = seed * 2.3 + float(k) * 2.39996;
		vec2 way = vec2(cos(bearing), sin(bearing));
		if (coastal > 0.5 && dot(way, sea) > 0.1) {
			way = reflect(way, sea);
			bearing = atan(way.y, way.x);
		}
		float span = 0.85 + 0.4 * town_hash(vec2(seed, float(k) + 9.0));
		float along = dot(q, way);
		float off = dot(q, vec2(-way.y, way.x)) + 0.08 * (town_noise(vec2(along * 5.0, seed + float(k) * 1.7)) - 0.5);
		float dashes = step(0.3, town_noise(vec2(along * 14.0, seed * 0.3 + float(k))));
		float line = town_line(abs(off), 0.008, pixel_q) * step(0.0, along) * dashes;
		road = max(road, 0.6 * line * (1.0 - smoothstep(span * 0.75, span, along)));
		float gap = angle_gap(theta, bearing) / 0.14;
		reach = max(reach, 0.6 * exp(-gap * gap) * (span - 0.85) * 2.5);
	}
	// The built-up area: a ragged round, a little out along the roads; a coastal town reaches
	// inland, and the coastline (the globe's land mask) cuts it.
	float inland = coastal * max(0.0, -dot(q / max(r, 0.0001), sea));
	float ragged = town_fbm(q * 2.4 + seed) - 0.5;
	float fine = town_noise(q * 8.0 + seed * 3.1) - 0.5;
	float edge = (0.82 + 0.32 * ragged + 0.1 * fine + 0.25 * reach) * (1.0 + 0.3 * inland);
	float inside = 1.0 - smoothstep(edge * 0.82, edge, r);
	// Dense in the middle, thinning out, with dark patches (parks, yards, water).
	float patches = smoothstep(0.25, 0.6, town_fbm(q * 3.1 + seed * 1.3));
	float density = inside * (0.15 + 0.85 * exp(-r * r * 3.0)) * (0.3 + 0.7 * patches);
	// The streets: block sides and, four blocks apart, main streets, each district on a heading of
	// its own; a block is the same size in every town.
	float turn = seed * 2.39 + 0.7 * step(0.5, town_noise(q * 1.6 + seed * 5.0));
	float minor = street_grid(d, STREET_CELL, turn, seed, density, pixel, 0.1);
	float major = street_grid(d, STREET_CELL * 4.0, turn + 0.15, seed + 11.0, min(1.0, density * 1.4), pixel, 0.04);
	float lit = minor * 0.55 + major * 0.42 + density * 0.06 + road * 0.5;
	// The white-hot core at the centre; on the coast it sits by the water.
	vec2 c = q - sea * 0.2 * coastal;
	float core = exp(-dot(c, c) * 70.0) * (0.35 + 0.35 * grown);
	float shine = style.x * (1.0 - landing);
	float warm = (lit * (1.0 - style.y) + core * 0.8) * shine + spark * 0.8 * landing * style.x;
	float cold = (lit * style.y + core * 0.6) * shine + spark * 0.15 * landing * style.x;
	return vec2(warm, cold);
}

// Every settlement's light at a point on the map; pixel is the screen pixel in degrees.
vec2 town_lights(float lat, float lon, float pixel) {
	vec2 light = vec2(0.0);
	for (int i = 0; i < MAX_TOWNS; i++) {
		if (i >= town_count) {
			break;
		}
		vec4 town = towns[i];
		float east = lon - town.y;
		east -= 360.0 * floor(east / 360.0 + 0.5);
		vec2 d = vec2(east * cos(radians(town.x)), lat - town.x);
		float reach = town.z * 1.7;
		if (abs(d.y) > reach || abs(d.x) > reach) {
			continue;
		}
		light += town_glow(d, town, town_style[i], town_shape[i], town_roads[i], pixel);
	}
	return light;
}
"""

## Seam-safe equirectangular lookup: atan() jumps at the antimeridian, so the derivatives come
## from whichever copy of u is continuous there and the mip level stays right on both sides.
const LOOKUP_GLSL: String = """
vec2 sphere_uv(vec3 n) {
	return vec2(atan(n.x, n.z) / 6.283185307 + 0.5, 0.5 - asin(clamp(n.y, -1.0, 1.0)) / 3.14159265);
}

void seam_derivatives(vec2 uv, out vec2 ddx_uv, out vec2 ddy_uv) {
	vec2 wrapped = vec2(fract(uv.x + 0.5), uv.y);
	ddx_uv = vec2(abs(dFdx(uv.x)) < abs(dFdx(wrapped.x)) ? dFdx(uv.x) : dFdx(wrapped.x), dFdx(uv.y));
	ddy_uv = vec2(abs(dFdy(uv.x)) < abs(dFdy(wrapped.x)) ? dFdy(uv.x) : dFdy(wrapped.x), dFdy(uv.y));
}
"""

## Clouds: two layers carried by latitude winds and cross-faded so the bands never smear for
## good, a slow drift through the noise so the cover keeps changing, and storms that twist it.
const CLOUDS_GLSL: String = """
uniform float weather_time = 0.0;
uniform float coverage = 0.5;
uniform vec4 storms[3];
uniform float storm_radius[3];

vec3 turn_y(vec3 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

vec3 turn_about(vec3 p, vec3 k, float a) {
	float c = cos(a);
	float s = sin(a);
	return p * c + cross(k, p) * s + k * dot(k, p) * (1.0 - c);
}

float cloud_fbm(vec3 q) {
	float v = texture(noise3d, q).r * 0.46;
	v += texture(noise3d, q * 2.03 + vec3(0.31, 0.17, 0.73)).r * 0.26;
	v += texture(noise3d, q * 4.17 + vec3(0.61, 0.43, 0.11)).r * 0.15;
	v += texture(noise3d, q * 8.61 + vec3(0.23, 0.71, 0.37)).r * 0.09;
	v += texture(noise3d, q * 17.3 + vec3(0.83, 0.29, 0.57)).r * 0.04;
	return v;
}

// Easterly trade winds, westerlies in the middle latitudes, easterlies again at the poles.
float zonal_wind(float lat) {
	return -cos(3.0 * lat) * 0.004 + 0.0005;
}

// A tropical cyclone: two spiral arms around a clear eye. The arms are drawn, not wound, so
// they can turn for ever without tightening into rings.
float cyclone(vec3 p, vec4 storm, float reach, float t) {
	float power = storm.w;
	vec3 centre = storm.xyz;
	float d = acos(clamp(dot(p, centre), -1.0, 1.0));
	if (abs(power) < 0.001 || d > reach) {
		return 0.0;
	}
	float r = d / reach;
	vec3 e1 = normalize(cross(centre, abs(centre.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 e2 = cross(centre, e1);
	float theta = atan(dot(p, e2), dot(p, e1));
	float turn = sign(power);
	float arms = cos(2.0 * (theta + turn * (3.0 * log(r + 0.04) - t * 0.09)));
	float body = smoothstep(0.0, 0.85, arms * 0.5 + 0.5 - r * 0.6) * (1.0 - smoothstep(0.55, 1.0, r));
	float wall = exp(-(r - 0.1) * (r - 0.1) / 0.003);
	float eye = smoothstep(0.035, 0.075, r);
	return clamp((body + wall) * eye * abs(power), 0.0, 1.0);
}

float cloud_density(vec3 p, float t) {
	float storm = 0.0;
	vec3 q = p;
	for (int i = 0; i < 3; i++) {
		storm = max(storm, cyclone(p, storms[i], storm_radius[i], t));
		float d = acos(clamp(dot(p, storms[i].xyz), -1.0, 1.0));
		float k = max(0.0, 1.0 - d / (storm_radius[i] * 1.6));
		q = normalize(turn_about(q, storms[i].xyz, storms[i].w * k * k * 1.6));
	}
	// Domain warping (1.11 F): the noise is read through a slowly drifting noise of its own, so
	// the bands break into curls instead of stretched blobs.
	vec3 w = q * 0.9 + vec3(t * 0.0004, 0.0, 0.0);
	vec3 warp = vec3(texture(noise3d, w).r, texture(noise3d, w + vec3(0.37, 0.11, 0.53)).r,
		texture(noise3d, w + vec3(0.71, 0.29, 0.17)).r) - 0.5;
	q = normalize(q + warp * 0.07);
	float lat = asin(clamp(q.y, -1.0, 1.0));
	float period = 90.0;
	float phase0 = fract(t / period);
	float phase1 = fract(t / period + 0.5);
	float wind = zonal_wind(lat);
	// Stretched along the wind: cloud bands run east to west.
	vec3 stretch = vec3(1.45, 2.5, 1.45);
	vec3 q0 = turn_y(q, wind * phase0 * period) * stretch + vec3(0.0, t * 0.0009, 0.0);
	vec3 q1 = turn_y(q, wind * phase1 * period) * stretch + vec3(0.47, t * 0.0009 + 0.21, 0.13);
	float w0 = 1.0 - abs(1.0 - 2.0 * phase0);
	float n = mix(cloud_fbm(q1), cloud_fbm(q0), w0);
	float a = abs(degrees(lat));
	float band = 0.05 * exp(-a * a / 100.0) - 0.05 * exp(-(a - 25.0) * (a - 25.0) / 80.0)
		+ 0.04 * exp(-(a - 55.0) * (a - 55.0) / 200.0);
	float threshold = mix(0.6, 0.52, coverage) - band;
	float body = smoothstep(threshold, threshold + 0.1, n);
	// A second, thin and higher layer that runs ahead of the first on faster winds (1.11 F).
	vec3 h = turn_y(q, wind * 2.4 * t) * vec3(3.1, 5.4, 3.1) + vec3(0.19, t * 0.002, 0.61);
	float high = smoothstep(0.6, 0.74, cloud_fbm(h)) * 0.42;
	return max(max(body, high), storm * (0.65 + 0.7 * (n - 0.5)));
}
"""

## Town and farmland patches on the globe fade after sunset, so the lights show through.
const FOOTPRINT_CODE: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 sun_world = vec3(0.6, 0.3, 0.7);
uniform float day_night = 1.0;
varying vec3 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = dot(normalize(world_point), normalize(sun_world));
	float day = mix(1.0, smoothstep(-0.1, 0.12, facing), day_night);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * mix(0.1, 1.0, day);
}
"""

## A free plot on the ground, in its kind's colour from the instance: a soft patch that fades
## out from the centre, or with `ring` > 0 a thin ring of that width (plot marks for planning).
const PLOTMARK_CODE: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform float ring = 0.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float a = 1.0 - smoothstep(0.3, 1.0, r);
	if (ring > 0.0) {
		a = smoothstep(1.0 - ring - 0.06, 1.0 - ring, r) * (1.0 - smoothstep(0.94, 1.0, r));
	}
	ALBEDO = tint.rgb;
	ALPHA = a * tint.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

## A soft pool of lamp light on the ground; `intensity` follows the night at the site.
const GLOW_CODE: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.4, 1.0);
uniform float intensity = 0.0;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float f = pow(clamp(1.0 - r, 0.0, 1.0), 2.4);
	ALBEDO = glow_color.rgb * f * intensity;
}
"""

## Rivers, lakes and the sea: ripples that move, a sheen at grazing angles.
const WATER_CODE: String = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler3D noise3d : filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(0.16, 0.37, 0.43, 1.0);
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	// Two scales at an angle to each other, so the tiling noise never shows its period.
	vec3 p = world_pos;
	float a = texture(noise3d, vec3(p.x * 0.11 + t * 0.012, t * 0.004, p.z * 0.11 + t * 0.008)).r - 0.5;
	vec3 across = vec3((p.x + p.z) * 0.23 - t * 0.02, 0.5 + t * 0.006, (p.z - p.x) * 0.23 + t * 0.011);
	float b = texture(noise3d, across).r - 0.5;
	float c = texture(noise3d, vec3(p.z * 0.61 + t * 0.03, 0.27 + t * 0.01, p.x * 0.61)).r - 0.5;
	vec3 wave = normalize(vec3(a * 0.32 + b * 0.22 + c * 0.1, 1.0, b * 0.32 - a * 0.22 + c * 0.1));
	NORMAL = normalize((VIEW_MATRIX * vec4(wave, 0.0)).xyz);
	float sheen = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(tint.rgb, vec3(0.5, 0.66, 0.74), sheen * 0.35);
	ROUGHNESS = 0.1;
	SPECULAR = 0.7;
}
"""

static var _cache: Dictionary = {}
static var _noise: NoiseTexture3D


## One shader per kind for the whole game: materials differ only in their parameters.
static func shader(kind: String) -> Shader:
	if _cache.has(kind):
		return _cache[kind]
	var code: String = ""
	match kind:
		"globe":
			code = _globe_code()
		"flat":
			code = _flat_code()
		"clouds":
			code = _clouds_code()
		"atmosphere":
			code = _atmosphere_code()
		"terrain":
			code = _terrain_code()
		"footprint":
			code = FOOTPRINT_CODE
		"glow":
			code = GLOW_CODE
		"plotmark":
			code = PLOTMARK_CODE
		"water":
			code = WATER_CODE
		_:
			push_error("unknown map shader " + kind)
	var made := Shader.new()
	made.code = code
	_cache[kind] = made
	return made


## Tileable 3D noise shared by clouds and surface detail. Generated once, on its own thread.
static func noise_texture() -> NoiseTexture3D:
	if _noise != null:
		return _noise
	var source := FastNoiseLite.new()
	source.seed = 1873
	source.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	source.frequency = 0.03
	source.fractal_octaves = 3
	_noise = NoiseTexture3D.new()
	_noise.width = 96
	_noise.height = 96
	_noise.depth = 96
	_noise.seamless = true
	_noise.noise = source
	return _noise


static func encode(height: float, temperature: float, rainfall: float, ridge: float) -> Color:
	var alpha: float = 0.5 + 0.5 * signf(height) * sqrt(minf(absf(height) / HEIGHT_RANGE, 1.0))
	return Color(
		clampf((temperature - TEMPERATURE_LOW) / TEMPERATURE_SPAN, 0.0, 1.0),
		clampf(rainfall, 0.0, 1.0),
		clampf(ridge, 0.0, 1.0),
		clampf(alpha, 0.004, 0.996)
	)


static func decode_height(alpha: float) -> float:
	var s: float = (alpha - 0.5) * 2.0
	return signf(s) * s * s * HEIGHT_RANGE


static func _globe_code() -> String:
	return (
		"""
shader_type spatial;
render_mode unshaded;
uniform sampler2D atlas : filter_linear_mipmap, repeat_enable;
uniform sampler2D lights : filter_linear_mipmap, repeat_enable;
uniform sampler3D noise3d : filter_linear, repeat_enable;
uniform vec3 sun_local = vec3(0.6, 0.3, 0.7);
uniform vec3 camera_local = vec3(0.0, 0.0, 10.0);
uniform float terraform = 0.0;
uniform float ice_latitude = 76.0;
uniform float season = 0.0;
uniform float relief = 1.0;
uniform float day_night = 1.0;
uniform float night_lights = 1.0;
// The per-plot lights' share (light_field.gd) and the planet-scale forms' share (town_forms.gd):
// the globe crossfades them by camera distance, adding up to one; the time-lapse shows only forms.
uniform float plot_lights = 1.0;
uniform float form_lights = 0.0;
// Faint strings along finished roads and points of far facilities, for the forms' view.
uniform sampler2D far_lights : filter_linear_mipmap, repeat_enable;
uniform float halo_warm = 2.2;
uniform float halo_cold = 1.6;
varying vec3 local_point;
"""
		+ GEOGRAPHY_GLSL
		+ LOOKUP_GLSL
		+ TOWN_LIGHTS_GLSL
		+ """
void vertex() {
	local_point = VERTEX;
}

void fragment() {
	vec3 n = normalize(local_point);
	vec2 uv = sphere_uv(n);
	vec2 ddx_uv;
	vec2 ddy_uv;
	seam_derivatives(uv, ddx_uv, ddy_uv);
	vec4 g = textureGrad(atlas, uv, ddx_uv, ddy_uv);
	float lat = degrees(asin(clamp(n.y, -1.0, 1.0)));
	float n1 = texture(noise3d, n * 1.7).r * 2.0 - 1.0;
	float n2 = texture(noise3d, n * 9.3 + vec3(0.37)).r * 2.0 - 1.0;
	float h = geo_height(g.a) + n2 * 0.004;
	float t = g.r * 100.0 - 50.0 + season * sign(lat) * 7.0 * abs(lat) / 90.0;
	float coast = smoothstep(-0.0015, 0.0015, h);
	// Terraforming (1.9): each stage moves the land 1 C toward the comfortable band, adds rain
	// (drawn a little stronger than the rules' 5% so a stage shows from orbit) and clears the sea.
	float tt = t + clamp(20.0 - t, -terraform, terraform);
	float wet = min(1.0, g.g * (1.0 + 0.05 * terraform) + 0.03 * terraform);
	vec3 sea = mix(sea_color(h, n1), vec3(0.08, 0.36, 0.52), 0.06 * terraform);
	vec3 base = mix(sea, land_color(h, tt, wet, g.b, n1, n2), coast);
	float ice = ice_cover(lat, n1, n2, ice_latitude + (1.0 - coast) * 2.0, season);
	base = to_linear(mix(base, ice_color(n2), ice));
	// Relief from the height field, lit by the real sun.
	vec2 texel = 1.0 / vec2(textureSize(atlas, 0));
	float he = geo_height(textureGrad(atlas, uv + vec2(texel.x, 0.0), ddx_uv, ddy_uv).a);
	float hw = geo_height(textureGrad(atlas, uv - vec2(texel.x, 0.0), ddx_uv, ddy_uv).a);
	float hn = geo_height(textureGrad(atlas, uv - vec2(0.0, texel.y), ddx_uv, ddy_uv).a);
	float hs = geo_height(textureGrad(atlas, uv + vec2(0.0, texel.y), ddx_uv, ddy_uv).a);
	vec3 east = normalize(vec3(n.z, 0.0, -n.x) + vec3(0.00001, 0.0, 0.0));
	vec3 north = cross(n, east);
	float gx = (he - hw) / (2.0 * 6.283185 * max(cos(radians(lat)), 0.15) * texel.x);
	float gy = (hn - hs) / (2.0 * 3.14159265 * texel.y);
	float land = smoothstep(0.0, 0.012, h) * (1.0 - ice * 0.6);
	vec3 surface = normalize(n - (east * gx + north * gy) * 0.06 * relief * land);
	vec3 light_dir = normalize(sun_local);
	float facing = dot(n, light_dir);
	float day = mix(1.0, smoothstep(-0.1, 0.16, facing), day_night);
	float diffuse = max(dot(surface, light_dir), 0.0);
	vec3 lit = base * (0.15 + 0.95 * diffuse);
	vec3 night = base * vec3(0.1, 0.12, 0.17) + vec3(0.004, 0.006, 0.012);
	vec3 color = mix(night, lit, day);
	float twilight = exp(-facing * facing / 0.006) * day_night;
	color += vec3(0.2, 0.07, 0.02) * twilight * 0.12;
	// Sun glint on open water.
	vec3 water_normal = normalize(n + (east * n2 + north * n1) * 0.01);
	vec3 view_dir = normalize(camera_local - local_point);
	vec3 halfway = normalize(light_dir + view_dir);
	float spec = pow(max(dot(water_normal, halfway), 0.0), 400.0) * 0.4;
	spec += pow(max(dot(n, halfway), 0.0), 30.0) * 0.025;
	color += vec3(1.0, 0.92, 0.78) * spec * (1.0 - coast) * (1.0 - ice) * day;
	// The colony's lights after sunset (light_field.gd), their halo from a coarser mip of the same
	// map, which also merges them smoothly as the camera pulls back. The halo answers by its
	// 0.7th power: a coarse mip averages a small town's few lights over hundreds of texels, and a
	// linear halo left it a few specks from orbit while a city would saturate.
	vec2 point_light = textureGrad(lights, uv, ddx_uv, ddy_uv).rg;
	// A round halo: the centre and a ring of six taps of a coarser mip, about six pixels out.
	vec2 spread = (abs(ddx_uv) + abs(ddy_uv)) * 4.0;
	vec2 gather = textureGrad(lights, uv, ddx_uv * 4.0, ddy_uv * 4.0).rg;
	for (int k = 0; k < 6; k++) {
		vec2 step_uv = vec2(cos(float(k) * 1.0472), sin(float(k) * 1.0472)) * spread;
		gather += textureGrad(lights, uv + step_uv, ddx_uv * 4.0, ddy_uv * 4.0).rg;
	}
	vec2 halo = pow(max(gather / 7.0, vec2(0.0)), vec2(0.7));
	float dark = (1.0 - smoothstep(-0.06, 0.1, facing)) * day_night * night_lights;
	vec3 glow = vec3(1.0, 0.7, 0.36) * (point_light.r * 3.6 + halo.r * halo_warm);
	glow += vec3(0.72, 0.86, 1.0) * (point_light.g * 3.0 + halo.g * halo_cold);
	glow *= plot_lights;
	// The planet-scale town forms (TOWN_LIGHTS_GLSL, town_forms.gd), cut by the coastline, with the
	// faint road strings and far facilities beside them (1.11 G).
	if (form_lights > 0.001) {
		float pixel = max(length(ddx_uv * vec2(360.0, 180.0)), length(ddy_uv * vec2(360.0, 180.0)));
		vec2 forms = town_count > 0 ? town_lights(lat, degrees(atan(n.x, n.z)), pixel) : vec2(0.0);
		forms *= coast;
		vec2 far = textureGrad(far_lights, uv, ddx_uv, ddy_uv).rg;
		vec2 far_halo = textureGrad(far_lights, uv, ddx_uv * 3.0, ddy_uv * 3.0).rg;
		vec3 shown = vec3(1.0, 0.7, 0.36) * (forms.x * 1.8 + far.r * 2.4 + far_halo.r * 0.8);
		shown += vec3(0.72, 0.86, 1.0) * (forms.y * 1.5 + far.g * 2.4 + far_halo.g * 0.8);
		glow += shown * form_lights;
	}
	ALBEDO = color + glow * dark;
}
"""
	)


static func _clouds_code() -> String:
	return (
		"""
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform sampler3D noise3d : filter_linear, repeat_enable;
uniform vec3 sun_local = vec3(0.6, 0.3, 0.7);
uniform float day_night = 1.0;
uniform float opacity = 0.88;
uniform sampler2D lights : filter_linear_mipmap, repeat_enable;
uniform float night_lights = 1.0;
varying vec3 local_point;
"""
		+ LOOKUP_GLSL
		+ CLOUDS_GLSL
		+ """
void vertex() {
	local_point = VERTEX;
}

void fragment() {
	vec3 p = normalize(local_point);
	float density = cloud_density(p, weather_time);
	float facing = dot(p, normalize(sun_local));
	float day = mix(1.0, smoothstep(-0.16, 0.2, facing), day_night);
	vec3 color = mix(vec3(0.035, 0.045, 0.07), vec3(0.93, 0.95, 0.98), day);
	color *= 0.86 + 0.14 * (1.0 - density);
	// A warm edge along the terminator, and on the night side the towns' light on the clouds'
	// undersides (1.11 F).
	float twilight = exp(-facing * facing / 0.006) * day_night;
	color = mix(color, vec3(1.0, 0.52, 0.26), twilight * 0.42);
	vec2 town = texture(lights, sphere_uv(p), 3.0).rg;
	float below = (town.r + town.g * 0.6) * (1.0 - day) * night_lights;
	color += vec3(1.0, 0.72, 0.4) * below * 0.55;
	ALBEDO = color;
	ALPHA = density * opacity * mix(0.6, 1.0, day);
}
"""
	)


static func _atmosphere_code() -> String:
	return """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec3 sun_local = vec3(0.6, 0.3, 0.7);
uniform float day_night = 1.0;
varying vec3 local_point;

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.2);
	float facing = dot(normalize(local_point), normalize(sun_local));
	float lit = mix(1.0, smoothstep(-0.4, 0.3, facing), day_night);
	float twilight = exp(-facing * facing / 0.025) * day_night;
	vec3 color = mix(vec3(0.13, 0.46, 0.85), vec3(0.95, 0.42, 0.16), twilight * 0.55);
	ALBEDO = color * (0.1 + 0.9 * lit) * rim;
	ALPHA = rim * 0.55;
}
"""


static func _flat_code() -> String:
	return (
		"""
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D lights : filter_linear_mipmap, repeat_enable;
uniform sampler3D noise3d : filter_linear, repeat_enable;
uniform vec3 sun_local = vec3(0.6, 0.3, 0.7);
uniform float ice_latitude = 76.0;
uniform float season = 0.0;
uniform float day_night = 1.0;
uniform float night_lights = 1.0;
uniform float halo_warm = 2.0;
uniform float halo_cold = 1.5;
uniform float cloud_opacity = 0.22;
uniform float terraform = 0.0;
"""
		+ GEOGRAPHY_GLSL
		+ CLOUDS_GLSL
		+ TOWN_LIGHTS_GLSL
		+ """
void fragment() {
	vec4 g = texture(atlas, UV);
	float lat = (0.5 - UV.y) * 180.0;
	float lon = (UV.x - 0.5) * 360.0;
	vec3 n = vec3(cos(radians(lat)) * sin(radians(lon)), sin(radians(lat)), cos(radians(lat)) * cos(radians(lon)));
	float n1 = texture(noise3d, n * 1.7).r * 2.0 - 1.0;
	float n2 = texture(noise3d, n * 9.3 + vec3(0.37)).r * 2.0 - 1.0;
	float h = geo_height(g.a) + n2 * 0.004;
	float t = g.r * 100.0 - 50.0 + season * sign(lat) * 7.0 * abs(lat) / 90.0;
	float coast = smoothstep(-0.0015, 0.0015, h);
	// Terraforming (1.9): each stage moves the land 1 C toward the comfortable band, adds rain
	// (drawn a little stronger than the rules' 5% so a stage shows from orbit) and clears the sea.
	float tt = t + clamp(20.0 - t, -terraform, terraform);
	float wet = min(1.0, g.g * (1.0 + 0.05 * terraform) + 0.03 * terraform);
	vec3 sea = mix(sea_color(h, n1), vec3(0.08, 0.36, 0.52), 0.06 * terraform);
	vec3 base = mix(sea, land_color(h, tt, wet, g.b, n1, n2), coast);
	base = mix(base, ice_color(n2), ice_cover(lat, n1, n2, ice_latitude + (1.0 - coast) * 2.0, season));
	// Cartographic hill shading from the north-west.
	vec2 texel = 1.0 / vec2(textureSize(atlas, 0));
	float gx = geo_height(texture(atlas, UV + vec2(texel.x, 0.0)).a);
	gx -= geo_height(texture(atlas, UV - vec2(texel.x, 0.0)).a);
	float gy = geo_height(texture(atlas, UV - vec2(0.0, texel.y)).a);
	gy -= geo_height(texture(atlas, UV + vec2(0.0, texel.y)).a);
	float shade = clamp(1.0 + (-gx + gy) * 9.0 * smoothstep(0.0, 0.012, h), 0.7, 1.3);
	vec3 color = to_linear(base) * 0.92 * shade;
	float cloud = cloud_density(n, weather_time) * cloud_opacity;
	color *= 1.0 - cloud * 0.25;
	float facing = dot(n, normalize(sun_local));
	float dark = (1.0 - smoothstep(-0.08, 0.12, facing)) * day_night;
	// Night as the globe has it (1.10): the sea darkest, the land just legible, the lights clear.
	color *= 1.0 - dark * 0.8;
	color = mix(color, vec3(0.88, 0.9, 0.94) * mix(1.0, 0.45, dark), cloud);
	// The colony's lights (light_field.gd): small bright cores and a restrained halo from a coarser
	// mip, which also merges them as the map zooms out; round and by a power, as on the globe.
	vec2 point_light = texture(lights, UV).rg;
	vec2 spread = vec2(0.0012, 0.0024);
	vec2 gather = textureLod(lights, UV, 2.0).rg;
	for (int k = 0; k < 6; k++) {
		vec2 step_uv = vec2(cos(float(k) * 1.0472), sin(float(k) * 1.0472)) * spread;
		gather += textureLod(lights, UV + step_uv, 2.0).rg;
	}
	vec2 halo = pow(max(gather / 7.0, vec2(0.0)), vec2(0.7));
	vec3 glow = vec3(1.0, 0.7, 0.36) * (point_light.r * 3.2 + halo.r * halo_warm);
	glow += vec3(0.72, 0.86, 1.0) * (point_light.g * 2.8 + halo.g * halo_cold);
	ALBEDO = color + glow * dark * night_lights * (1.0 - cloud * 0.6);
}
"""
	)


## Regional ground: the same palette on the same geography, lit by the scene's sun. The vertex
## colour carries temperature, rainfall, wet ground and encoded height; the detail and the drifting
## cloud shadows are drawn in world space so they hold still as the camera moves.
static func _terrain_code() -> String:
	return (
		"""
shader_type spatial;
render_mode cull_back;
uniform sampler3D noise3d : filter_linear, repeat_enable;
uniform float weather_time = 0.0;
uniform vec2 wind = vec2(0.6, 0.25);
uniform float cloud_shadow = 0.35;
uniform float river_tint = 0.0;
varying vec4 data;
varying vec3 world_pos;
varying vec3 world_normal;
"""
		+ GEOGRAPHY_GLSL
		+ """
void vertex() {
	data = COLOR;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n1 = texture(noise3d, world_pos * 0.035).r * 2.0 - 1.0;
	float n2 = texture(noise3d, world_pos * 0.21 + vec3(0.37)).r * 2.0 - 1.0;
	float n3 = texture(noise3d, world_pos * 0.9 + vec3(0.11, 0.53, 0.29)).r * 2.0 - 1.0;
	float h = geo_height(data.a);
	float t = data.r * 100.0 - 50.0;
	vec3 c = land_color(max(h, 0.0005), t, data.g, 0.0, n1, n2);
	if (h <= 0.0) {
		c = mix(c, vec3(0.62, 0.6, 0.5), 0.5);
	}
	c = mix(c, vec3(0.35, 0.44, 0.31), river_tint * 0.35);
	// Wet ground along rivers and lakes, rock where the ground is steep.
	c = mix(c, vec3(0.21, 0.31, 0.26), data.b * 0.5);
	float steep = smoothstep(0.82, 0.62, world_normal.y);
	c = mix(c, vec3(0.45, 0.43, 0.38) * (1.0 + n3 * 0.1), steep * 0.75);
	c *= 1.0 + n3 * 0.05;
	// Cloud shadows drift over the ground.
	vec3 drift = vec3(world_pos.x + wind.x * weather_time * 3.0, 0.0, world_pos.z + wind.y * weather_time * 3.0);
	float cloud = smoothstep(0.52, 0.66, texture(noise3d, drift * 0.012 + vec3(0.0, weather_time * 0.001, 0.0)).r);
	c *= 1.0 - cloud * cloud_shadow;
	ALBEDO = to_linear(c);
	ROUGHNESS = 0.93;
}
"""
	)
