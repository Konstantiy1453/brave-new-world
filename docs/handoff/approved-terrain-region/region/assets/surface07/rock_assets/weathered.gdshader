shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D scan_color : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D scan_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D scan_arm : filter_linear_mipmap_anisotropic;
varying vec3 stone_local;
varying vec4 individual;
void vertex(){
    stone_local=VERTEX;
    individual=COLOR;
}
void fragment(){
    vec3 stone=texture(scan_color,UV).rgb;
    vec3 arm=texture(scan_arm,UV).rgb;
    float base=1.-smoothstep(.12,.35,stone_local.y+.11*(stone.g-.16));
    vec3 heel=stone*vec3(.86,.83,.73);
    ALBEDO=mix(stone,heel,base*.55)*individual.rgb*1.16;
    NORMAL_MAP=texture(scan_normal,UV).rgb;
    NORMAL_MAP_DEPTH=.83;
    AO=mix(1.,arm.r,.66);
    AO_LIGHT_AFFECT=.12;
    ROUGHNESS=clamp(.37+.59*arm.g,.70,.98);
    SPECULAR=.22;
}
