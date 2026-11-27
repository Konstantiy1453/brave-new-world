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

## Preserve the generator's warm/cool street palette as sub-pixel roads merge at orbital scale.
const SETTLEMENT_EMISSION_GLSL: String = """
vec3 settlement_emission(vec2 uv, vec2 dx, vec2 dy) {
	vec2 atlas_size = vec2(textureSize(lights, 0));
	float footprint = max(length(dx * atlas_size), length(dy * atlas_size));
	// Keep magnified lamps distinct, then hand over to the usual mip chain in the distance.
	vec2 f = fract(uv * atlas_size - 0.5);
	vec2 eased = f * f * (3.0 - 2.0 * f);
	vec2 sample_uv = uv + (eased - f) * (0.62 * (1.0 - smoothstep(0.65, 1.6, footprint))) / atlas_size;
	float filter_width = mix(0.72, 1.0, smoothstep(2.6, 5.5, footprint));
	vec3 light = textureGrad(lights, sample_uv, dx * filter_width, dy * filter_width).rgb;
	float peak = max(light.r, max(light.g, light.b));
	return light * (1.65 * pow(max(peak, 0.002), -0.30));
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

# Versioned optical albedo. Angles, material coordinates and the runoff map are in the planet's
# frame, so turning the globe, zooming, or switching to a different projection does not move them.
const OPTICAL_SETTINGS_GLSL: String = """
uniform bool optical_v3 = false;
uniform vec3 optical_phase = vec3(0.0);
"""
const OPTICAL_SURFACE_GLSL: String = """
uniform sampler2D optical_tiles : filter_linear_mipmap, repeat_disable;
uniform sampler2D optical_water : filter_linear_mipmap, repeat_enable;
uniform sampler2D optical_coast : filter_linear_mipmap, repeat_enable;
uniform float radius_km = 6000.0;
uniform float low_haze = 1.0;

float optical_sample(float tile, vec2 p) {
	// Mirrored sampling keeps the six independent swatches from bleeding into their neighbours.
	vec2 mirrored = abs(fract(p * 0.5) * 2.0 - 1.0);
	vec2 coord = (mirrored * 127.0 + 0.5) / 128.0;
	return textureGrad(optical_tiles, vec2((tile + coord.x) / 6.0, coord.y),
		dFdx(p) * vec2(1.0 / 6.0, 1.0), dFdy(p) * vec2(1.0 / 6.0, 1.0)).r - 0.5;
}

// Geographic neighbours wrap at the date line. Submerged relief does not shade a land slope.
float optical_land_metres(vec2 uv, vec2 dx, vec2 dy) {
	vec2 coord = vec2(fract(uv.x), clamp(uv.y, 0.0, 1.0));
	return max(0.0, 4300.0 * geo_height(textureGrad(atlas, coord, dx, dy).a));
}

// x/y are east/north rises in metres per metre. Broad slopes reveal plateau shoulders,
// while the near neighbours keep snow-capped spurs and valleys attached to the actual terrain.
vec4 optical_relief(vec2 uv, vec2 dx, vec2 dy, vec3 n, float height) {
	vec2 step_uv = 1.0 / vec2(textureSize(atlas, 0));
	float stride = max(1.0, max(length(dx / step_uv), length(dy / step_uv)));
	vec2 east = vec2(step_uv.x * stride, 0.0);
	vec2 north = vec2(0.0, -step_uv.y * stride);
	vec4 near_z = vec4(optical_land_metres(uv + east, dx, dy), optical_land_metres(uv - east, dx, dy),
		optical_land_metres(uv + north, dx, dy), optical_land_metres(uv - north, dx, dy));
	vec4 far_z = vec4(optical_land_metres(uv + 4.0 * east, dx, dy), optical_land_metres(uv - 4.0 * east, dx, dy),
		optical_land_metres(uv + 4.0 * north, dx, dy), optical_land_metres(uv - 4.0 * north, dx, dy));
	float latitude_scale = max(0.12, sqrt(max(0.0, 1.0 - n.y * n.y)));
	vec2 span = 2.0 * radius_km * 1000.0 * stride *
		vec2(6.2831853 * step_uv.x * latitude_scale, 3.14159265 * step_uv.y);
	vec2 near_slope = (near_z.xz - near_z.yw) / span;
	vec2 far_slope = (far_z.xz - far_z.yw) / (4.0 * span);
	float surrounding = dot(far_z, vec4(0.25));
	return vec4(mix(near_slope, far_slope, 0.27), height - surrounding, surrounding);
}

vec3 optical_albedo(vec2 uv, vec2 dx, vec2 dy, vec3 n, float h, float t, float wet,
		float ridge, float n1, float n2, float coast, vec4 terrain, out float water_ice) {
	float z = h * 4300.0;
	float cold = 1.0 - smoothstep(-12.0, 8.0, t);
	float dry = (1.0 - smoothstep(0.27, 0.53, wet)) * smoothstep(-3.0, 18.0, t);
	float forest = smoothstep(0.38, 0.70, wet) * (1.0 - dry) * (1.0 - 0.76 * cold);
	float rock = (0.15 + 0.48 * ridge + 0.18 * dry) * smoothstep(180.0, 2200.0, z);
	vec3 surface = vec3(90.0, 91.0, 64.0) + n1 * vec3(5.0, 4.0, 1.0);
	surface = mix(surface, vec3(42.0, 64.0, 49.0), forest);
	surface = mix(surface, vec3(149.0, 126.0, 98.0), dry * 0.91);
	surface = mix(surface, vec3(107.0, 105.0, 87.0), cold * 0.79);
	surface = mix(surface, vec3(106.0, 102.0, 94.0) + 5.0 * n1, rock);

	vec3 pos = n + optical_phase * 2.0;
	vec2 p = vec2(dot(pos, vec3(0.74, 0.44, -0.51)), dot(pos, vec3(-0.36, 0.89, 0.28)));
	vec2 q = vec2(dot(pos, vec3(-0.24, 0.52, 0.82)), dot(pos, vec3(0.93, 0.36, 0.04)));
	p = p * 8.0 + vec2(n1, n2) * 0.68;
	q = q * 5.5 + vec2(n2, n1) * 0.51;
	float detail = mix(optical_sample(2.0, p), optical_sample(1.0, q), forest);
	detail = mix(detail, optical_sample(0.0, p * 0.82), forest * smoothstep(13.0, 25.0, t));
	detail = mix(detail, optical_sample(3.0, q * 1.24), dry);
	detail = mix(detail, optical_sample(5.0, p * 1.38), cold);
	detail = mix(detail, optical_sample(4.0, q * 1.53), rock);
	float fine_detail = mix(optical_sample(2.0, q * 2.35 + vec2(0.28,0.17)),
		optical_sample(4.0, p * 2.05), rock);
	surface += vec3(1.04, 1.0, 0.80) * (detail * 45.0 + fine_detail * 11.0 + n2 * 3.0);
	// The world temperature already contains a 28 °C / 4300 m lapse. Recover its
	// sea-level value before comparing elevation with a regional snowline (metres).
	float background_t = t + max(z, 0.0) * (28.0 / 4300.0);
	float pole_facing = clamp(-terrain.y * sign(n.y) * 24.0, -1.0, 1.0);
	float snowline = clamp(1000.0 + 74.0 * background_t + 1480.0 * (0.54 - wet)
		- 145.0 * ridge, 700.0, 3900.0);
	float steepness = length(terrain.xy);
	float hollow = smoothstep(35.0, 390.0, -terrain.z);
	float retention = 125.0 * pole_facing + 110.0 * hollow + 125.0 * detail;
	float alpine = smoothstep(-145.0, 155.0, z - snowline + retention);
	float exposed_face = smoothstep(0.014, 0.045, steepness) *
		(0.22 + 0.65 * smoothstep(-0.25, 0.26, detail + 0.12 * n2));
	float plateau = smoothstep(850.0, 1850.0, terrain.w) *
		(1.0 - smoothstep(0.004, 0.020, steepness));
	float parched = 1.0 - smoothstep(0.30, 0.58, wet);
	float alpine_rock = smoothstep(-850.0, -40.0, z - snowline) *
		(0.18 + 0.46 * ridge + 0.32 * exposed_face);
	surface = mix(surface, vec3(104.0, 101.0, 91.0) + detail * 24.0, alpine_rock);
	surface = mix(surface, vec3(125.0, 111.0, 91.0) + detail * 23.0, plateau * parched * 0.54);
	float polar_frost = (1.0 - smoothstep(-23.0, -8.0, t + 2.0 * n1)) *
		smoothstep(0.76, 0.95, abs(n.y));
	surface = mix(surface, vec3(159.0, 166.0, 164.0) + 7.0 * n2, 0.86 * polar_frost);
	// Dry tablelands keep bands of exposed stone. Humid, cold tablelands retain snow
	// between the high points. Steep faces expose rock even above the snowline.
	float snow = alpine * (1.0 - exposed_face * 0.78) * (1.0 - 0.46 * plateau * parched);
	surface = mix(surface, vec3(201.0, 207.0, 207.0) + detail * 10.0, snow * 0.96);
	vec2 water = textureGrad(optical_water, uv, dx, dy).rg;
	float turbidity = clamp(0.12 + 0.43 * (1.0 - wet) + 0.15 * (1.0 - smoothstep(80.0, 1000.0, z)), 0.0, 1.0);
	float cover = water.r * (0.28 + 0.68 * smoothstep(0.02, 0.60, water.r)) *
		(0.13 + 0.87 * smoothstep(-15.0, -1.0, t));
	surface = mix(surface, mix(vec3(26.0, 39.0, 38.0), vec3(79.0, 74.0, 57.0), turbidity), cover);
	// Patchy shallow mist over moist lowlands. The weather switch also clears this layer.
	float lowland = (1.0 - smoothstep(60.0, 420.0, z)) * smoothstep(0.63, 0.84, wet);
	float mild = smoothstep(-5.0, 10.0, t) * (1.0 - smoothstep(24.0, 35.0, t));
	float fog = lowland * mild * low_haze * smoothstep(-0.16, 0.44, n1 + n2 * 0.5);
	surface = mix(surface, vec3(117.0, 129.0, 127.0), 0.17 * fog);
	float rocky = textureGrad(optical_coast, uv, dx, dy).r;
	float shelf = (1.0 - smoothstep(0.18, 0.77, rocky)) * mix(0.35, 1.0, wet);
	float shoal = clamp(0.46 * exp(min(0.0, z) / 57.0) + shelf * exp(min(0.0, z) / 370.0), 0.0, 1.0);
	vec3 ocean = vec3(16.0, 31.0, 42.0) + 3.0 * (1.0 - 2.0 * n.y * n.y);
	ocean += vec3(32.0, 39.0, 33.0) * shoal + n1 * (0.7 + 2.5 * shoal);
	ocean = mix(ocean, vec3(100.0, 96.0, 76.0), water.g * 0.68);
	water_ice = (1.0 - smoothstep(-24.0, -15.5, t + 4.5 * (wet - 0.52) + n2 * 2.0)) *
		smoothstep(0.77, 0.965, abs(n.y)) * 0.74;
	float ice_breaks = texture(noise3d, n * 16.0 + optical_phase).r;
	water_ice *= mix(0.71, 1.0, smoothstep(0.30, 0.68, ice_breaks + n1 * 0.18));
	ocean = mix(ocean, vec3(142.0, 154.0, 157.0) + n2 * 8.0, water_ice);
	vec3 rgb = mix(ocean, surface, coast);
	float luma = dot(rgb, vec3(0.23, 0.66, 0.11));
	return (mix(vec3(luma), rgb, 0.76) * 0.93 + vec3(1.5, 2.0, 2.2)) / 255.0;
}

vec3 optical_display(vec3 rgb) {
	return OUTPUT_IS_SRGB ? rgb : to_linear(rgb);
}
"""

## Clouds: two layers carried by latitude winds and cross-faded so the bands never smear for
## good, a slow drift through the noise so the cover keeps changing, and storms that twist it.
const CLOUDS_GLSL: String = """
uniform sampler2D cloud_pattern : filter_linear_mipmap, repeat_enable;
uniform float weather_time = 0.0;
uniform float coverage = 0.5;
uniform vec4 storms[3];
uniform float storm_radius[3];
uniform sampler2D cyclone_pattern : filter_linear_mipmap, repeat_disable;

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

// Sample the observed Maysak cloud shield in the local tangent plane. Reflect southern
// storms and let the outflow turn at a different speed from the eyewall.
float cyclone(vec3 p, vec4 storm, float reach, float t) {
	float strength = abs(storm.w);
	float angle = acos(clamp(dot(p, storm.xyz), -1.0, 1.0));
	if (strength < 0.001 || angle >= reach) { return 0.0; }
	vec3 north = abs(storm.y) < 0.98 ? vec3(0.0,1.0,0.0) : vec3(0.0,0.0,1.0);
	vec3 east = normalize(cross(north, storm.xyz));
	vec2 local = vec2(dot(p,east), -dot(p,cross(storm.xyz,east))) / max(sin(reach),0.001);
	local.x *= sign(storm.w);
	float radius = length(local);
	float phase = t * 0.005 + (1.0 - strength) * 0.36 + radius * 0.27;
	local = mat2(vec2(cos(phase),sin(phase)),vec2(-sin(phase),cos(phase))) * local;
	float envelope = texture(cyclone_pattern, local * 0.5 + 0.5).r;
	return envelope * smoothstep(0.0, 0.7, strength);
}

float cloud_density(vec3 p, float t) {
	float storm = 0.0;
	vec3 q = p;
	for (int i = 0; i < 3; i++) {
		storm = max(storm, cyclone(p, storms[i], storm_radius[i], t));
		float d = acos(clamp(dot(p, storms[i].xyz), -1.0, 1.0));
		float k = max(0.0, 1.0 - d / max(0.0001, storm_radius[i] * 1.6));
		q = normalize(turn_about(q, storms[i].xyz, storms[i].w * k * k * 1.6));
	}
	// Domain warping (1.11 F): the noise is read through a slowly drifting noise of its own, so
	// the bands break into curls instead of stretched blobs.
	vec3 w = q * 0.9 + vec3(t * 0.0004, 0.0, 0.0);
	vec3 warp = vec3(texture(noise3d, w).r, texture(noise3d, w + vec3(0.37, 0.11, 0.53)).r,
		texture(noise3d, w + vec3(0.71, 0.29, 0.17)).r) - 0.5;
	q = normalize(q + warp * 0.07);
	float lat = asin(clamp(q.y, -1.0, 1.0));
	if (optical_v3) {
		// Two passages through a latitude wind crossfade; the active weather systems turn the layer locally.
		float period_cloud = 240.0;
		float phase0_cloud = fract(t / period_cloud);
		float phase1_cloud = fract(t / period_cloud + 0.5);
		float drift = zonal_wind(lat) * period_cloud * 0.045;
		vec2 c = vec2(atan(q.x, q.z) / 6.2831853 + 0.5 + optical_phase.x + t * 0.000085
			+ 0.017 * sin(lat * 2.0), clamp(0.5 - lat / 3.14159265, 0.0005, 0.9995));
		vec2 dcx = dFdx(c); dcx.x -= round(dcx.x);
		vec2 dcy = dFdy(c); dcy.x -= round(dcy.x);
		float a = textureGrad(cloud_pattern, c + vec2(drift * phase0_cloud, 0.0), dcx, dcy).r;
		float b = textureGrad(cloud_pattern, c + vec2(drift * phase1_cloud, 0.0), dcx, dcy).r;
		float cloud = mix(a, b, abs(2.0 * phase0_cloud - 1.0));
		// Near the source composite's polar pinch, reduce the loss of cloud structure.
		cloud -= smoothstep(0.91, 0.997, abs(q.y)) * (0.08 + 0.27 * cloud_fbm(q * 2.4));
		cloud = pow(smoothstep(0.16, 0.85, cloud + (coverage - 0.5) * 0.26), 1.35);
		return max(cloud * 0.76, storm * 0.84);
	}
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

## A soft pool of lamp light on the ground; `intensity` follows the night at the site. Not fogged:
## fog would add the haze's colour over the whole quad, by day as well (1.12).
const GLOW_CODE: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
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
uniform sampler2D far_lights : filter_linear_mipmap, repeat_enable;
uniform float road_visibility = 1.0;
varying vec3 local_point;
"""
		+ GEOGRAPHY_GLSL
		+ OPTICAL_SETTINGS_GLSL
		+ OPTICAL_SURFACE_GLSL
		+ LOOKUP_GLSL
		+ SETTLEMENT_EMISSION_GLSL
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
	float h = geo_height(g.a) + (optical_v3 ? 0.0 : n2 * 0.004);
	float t = g.r * 100.0 - 50.0 + season * sign(lat) * 7.0 * abs(lat) / 90.0;
	float coast = smoothstep(-0.0015, 0.0015, h);
	// Terraforming (1.9): each stage moves the land 1 C toward the comfortable band, adds rain
	// (drawn a little stronger than the rules' 5% so a stage shows from orbit) and clears the sea.
	float tt = t + clamp(20.0 - t, -terraform, terraform);
	float wet = min(1.0, g.g * (1.0 + 0.05 * terraform) + 0.03 * terraform);
	vec3 sea = mix(sea_color(h, n1), vec3(0.08, 0.36, 0.52), 0.06 * terraform);
	vec3 base = mix(sea, land_color(h, tt, wet, g.b, n1, n2), coast);
	float ice = ice_cover(lat, n1, n2, ice_latitude + (1.0 - coast) * 2.0, season);
	vec4 terrain = vec4(0.0);
	if (optical_v3) {
		terrain = optical_relief(uv, ddx_uv, ddy_uv, n, h * 4300.0);
		base = optical_albedo(uv, ddx_uv, ddy_uv, n, h, tt, wet, g.b, n1, n2, coast, terrain, ice);
	} else {
		base = to_linear(mix(base, ice_color(n2), ice));
	}
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
	if (optical_v3) {
		vec3 grade = east * terrain.x + north * terrain.y;
		surface = normalize(n - 17.0 * grade / (1.0 + 9.0 * length(grade)) *
			relief * smoothstep(8.0, 220.0, h * 4300.0));
	}
	vec3 light_dir = normalize(sun_local);
	float facing = dot(n, light_dir);
	float day = mix(1.0, smoothstep(-0.1, 0.16, facing), day_night);
	float diffuse = max(dot(surface, light_dir), 0.0);
	vec3 lit = base * (0.15 + 0.95 * diffuse);
	vec3 night = base * vec3(0.1, 0.12, 0.17) + vec3(0.004, 0.006, 0.012);
	vec3 color = mix(night, lit, day);
	if (optical_v3) {
		float incidence = max(dot(surface, light_dir), 0.0);
		float lit_day = mix(0.135 + 0.61 * pow(incidence, 0.57) + 0.36 * day,
			0.89 + 0.11 * incidence, 1.0 - day_night);
		color = optical_display(base * lit_day * vec3(1.01, 1.0, 0.98));
	}
	float twilight = exp(-facing * facing / 0.006) * day_night;
	color += vec3(0.2, 0.07, 0.02) * twilight * (optical_v3 ? 0.022 : 0.12);
	// Sun glint on open water.
	vec3 water_normal = normalize(n + (east * n2 + north * n1) * 0.01);
	vec3 view_dir = normalize(camera_local - local_point);
	vec3 halfway = normalize(light_dir + view_dir);
	float spec = pow(max(dot(water_normal, halfway), 0.0), 400.0) * 0.4;
	spec += pow(max(dot(n, halfway), 0.0), 30.0) * 0.025;
	color += vec3(1.0, 0.92, 0.78) * spec * (optical_v3 ? 0.13 : 1.0) * (1.0 - coast) * (1.0 - ice) * day;
	float dark = (1.0 - smoothstep(-0.06, 0.1, facing)) * day_night * night_lights;
	vec3 glow = settlement_emission(uv, ddx_uv, ddy_uv) * coast;
	glow += vec3(1.0, 0.70, 0.36) * textureGrad(far_lights, uv, ddx_uv, ddy_uv).r * 2.4 * road_visibility;
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
		+ OPTICAL_SETTINGS_GLSL
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
	if (optical_v3) {
		float sun = pow(max(0.0, facing), 0.57);
		color = (vec3(16.0, 19.0, 23.0) + vec3(174.0, 174.0, 170.0) * sun +
			vec3(38.0, 37.0, 35.0) * day) / 255.0;
		if (!OUTPUT_IS_SRGB) { color = pow(color, vec3(2.2)); }
	}
	// A warm edge along the terminator, and on the night side the towns' light on the clouds'
	// undersides (1.11 F).
	float twilight = exp(-facing * facing / 0.006) * day_night;
	color = mix(color, vec3(1.0, 0.52, 0.26), twilight * (optical_v3 ? 0.035 : 0.42));
	vec3 town = texture(lights, sphere_uv(p), 3.0).rgb;
	color += town * (1.0 - day) * night_lights * 0.55;
	ALBEDO = color;
	ALPHA = density * opacity * mix(0.6, 1.0, day);
}
"""
	)


static func _atmosphere_code() -> String:
	return """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform bool optical_v3 = false;
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
	if (optical_v3) {
		ALBEDO = vec3(0.15, 0.26, 0.33) * (0.15 + 0.85 * lit) * rim;
	}
	ALPHA = rim * (optical_v3 ? 0.28 : 0.55);
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
uniform sampler2D far_lights : filter_linear_mipmap, repeat_enable;
uniform float cloud_opacity = 0.22;
uniform float terraform = 0.0;
"""
		+ GEOGRAPHY_GLSL
		+ OPTICAL_SETTINGS_GLSL
		+ OPTICAL_SURFACE_GLSL
		+ CLOUDS_GLSL
		+ SETTLEMENT_EMISSION_GLSL
		+ """
void fragment() {
	vec4 g = texture(atlas, UV);
	float lat = (0.5 - UV.y) * 180.0;
	float lon = (UV.x - 0.5) * 360.0;
	vec3 n = vec3(cos(radians(lat)) * sin(radians(lon)), sin(radians(lat)), cos(radians(lat)) * cos(radians(lon)));
	float n1 = texture(noise3d, n * 1.7).r * 2.0 - 1.0;
	float n2 = texture(noise3d, n * 9.3 + vec3(0.37)).r * 2.0 - 1.0;
	float h = geo_height(g.a) + (optical_v3 ? 0.0 : n2 * 0.004);
	float t = g.r * 100.0 - 50.0 + season * sign(lat) * 7.0 * abs(lat) / 90.0;
	float coast = smoothstep(-0.0015, 0.0015, h);
	// Terraforming (1.9): each stage moves the land 1 C toward the comfortable band, adds rain
	// (drawn a little stronger than the rules' 5% so a stage shows from orbit) and clears the sea.
	float tt = t + clamp(20.0 - t, -terraform, terraform);
	float wet = min(1.0, g.g * (1.0 + 0.05 * terraform) + 0.03 * terraform);
	vec3 sea = mix(sea_color(h, n1), vec3(0.08, 0.36, 0.52), 0.06 * terraform);
	vec3 base = mix(sea, land_color(h, tt, wet, g.b, n1, n2), coast);
	vec4 terrain = vec4(0.0);
	if (optical_v3) {
		terrain = optical_relief(UV, dFdx(UV), dFdy(UV), n, h * 4300.0);
		float sea_ice;
		base = optical_albedo(UV, dFdx(UV), dFdy(UV), n, h, tt, wet, g.b, n1, n2, coast, terrain, sea_ice);
	} else {
		base = mix(base, ice_color(n2), ice_cover(lat, n1, n2, ice_latitude + (1.0 - coast) * 2.0, season));
	}
	// Cartographic hill shading from the north-west.
	vec2 texel = 1.0 / vec2(textureSize(atlas, 0));
	float gx = geo_height(texture(atlas, UV + vec2(texel.x, 0.0)).a);
	gx -= geo_height(texture(atlas, UV - vec2(texel.x, 0.0)).a);
	float gy = geo_height(texture(atlas, UV - vec2(0.0, texel.y)).a);
	gy -= geo_height(texture(atlas, UV + vec2(0.0, texel.y)).a);
	float shade = clamp(1.0 + (-gx + gy) * 9.0 * smoothstep(0.0, 0.012, h), 0.7, 1.3);
	vec3 color = to_linear(base) * 0.92 * shade;
	if (optical_v3) {
		float facing_nw = dot(terrain.xy, vec2(0.76, -0.65));
		float hill = 24.0 * facing_nw / (1.0 + 44.0 * abs(facing_nw));
		float land_relief = smoothstep(8.0, 220.0, h * 4300.0);
		color = optical_display(base * (1.0 + hill * land_relief));
	}
	float cloud = cloud_density(n, weather_time) * cloud_opacity * (optical_v3 ? 0.22 : 1.0);
	color *= 1.0 - cloud * 0.25;
	float facing = dot(n, normalize(sun_local));
	float dark = (1.0 - smoothstep(-0.08, 0.12, facing)) * day_night;
	// Night as the globe has it (1.10): the sea darkest, the land just legible, the lights clear.
	color *= 1.0 - dark * 0.8;
	color = mix(color, vec3(0.88, 0.9, 0.94) * mix(1.0, 0.45, dark), cloud);
	vec3 glow = settlement_emission(UV, dFdx(UV), dFdy(UV)) * coast;
	glow += vec3(1.0, 0.70, 0.36) * texture(far_lights, UV).r * 2.4;
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
