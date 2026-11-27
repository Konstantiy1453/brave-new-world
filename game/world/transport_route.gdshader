shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 tint : source_color;
uniform bool sea;
uniform bool flat_map;
uniform bool road_lamps;
uniform sampler2D atlas : filter_linear, repeat_enable;
varying vec3 route_point;
void vertex() {
	route_point = VERTEX;
}
void fragment() {
	vec3 n = normalize(route_point);
	vec2 uv = flat_map ? vec2(route_point.x / 18.0 + 0.5, 0.5 - route_point.y / 9.0)
		: vec2(atan(n.x, n.z) / TAU + 0.5, 0.5 - asin(clamp(n.y, -1.0, 1.0)) / PI);
	if (sea) {
		if (textureLod(atlas, uv, 0.0).a > 0.47) {
			discard;
		}
	}
	vec3 color = tint.rgb;
	if (road_lamps) {
		// A few fixed pools of warm light on the road itself, anchored in planet coordinates.
		vec3 surface = vec3(cos(PI * (0.5 - uv.y)) * sin(TAU * (uv.x - 0.5)),
			sin(PI * (0.5 - uv.y)), cos(PI * (0.5 - uv.y)) * cos(TAU * (uv.x - 0.5)));
		float station = dot(surface, vec3(91.0, 73.0, 133.0));
		float lamp = smoothstep(0.83, 1.0, cos(station));
		color = mix(color * 0.86, color * 1.6, lamp);
	}
	ALBEDO = color;
}
