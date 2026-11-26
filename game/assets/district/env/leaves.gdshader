shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D branches: source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec3 crown_normal;
varying vec3 world_pos;
varying vec3 instance_tint;
void vertex(){
 crown_normal=normalize(MODELVIEW_NORMAL_MATRIX*NORMAL);
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 instance_tint=COLOR.rgb;
}
void fragment(){
 vec4 spray=texture(branches,UV);
 ALPHA=spray.a;
 ALPHA_SCISSOR_THRESHOLD=.21+.10*(1.-smoothstep(25.,140.,length(VERTEX)));
 NORMAL=normalize(crown_normal);
 float patch=.90+.075*sin(world_pos.x*2.2+world_pos.y*.9)+.05*sin(world_pos.z*3.9-world_pos.x*1.5);
 ALBEDO=spray.rgb*patch*(.74+.26*instance_tint);
 BACKLIGHT=spray.rgb*.34;
 ROUGHNESS=.92;
 SPECULAR=.15;
}
