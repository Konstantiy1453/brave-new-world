shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D soil_patch : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_patch : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scrub : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roads : filter_linear_mipmap, repeat_disable;
uniform sampler2D old_soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D old_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec3 normal_world;
float n(vec2 p) { return texture(scrub,p/64.).r; }

void vertex() {
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    normal_world=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
    vec2 m=world_position.xz;
    vec2 p=m/3.12;
    vec2 warp=vec2(n(p*.057),n(p*.041+23.));
    float broad=.44*n(p*.125+2.4*warp)+.28*n(p*.33+warp)+.20*n(p*.64+warp.yx)+.08*n(p*1.35);
    float old_cover=smoothstep(.28,.65,broad+.08*n(p*1.3));
    float along=dot(p,vec2(.865,-.501));
    float across=dot(p,vec2(.501,.865));
    float strata=n(vec2(along*.16+2.*warp.y,across*.25+2.7*warp.x));
    float stone=smoothstep(.60,.88,.46*strata+.45*broad+1.5*(1.-normal_world.y)+.13*n(p*.61));
    float edge=clamp(COLOR.r*(.78+.25*n(p*.61))+.03*n(p*.39),0.,1.);
    vec3 rgb_soil=texture(old_soil,p*.13).rgb;
    vec3 rgb_rock=texture(old_rock,vec2(.74*along,.64*across)*.18).rgb;
    float sl=dot(rgb_soil,vec3(.21,.72,.07));
    float rl=dot(rgb_rock,vec3(.21,.72,.07));
    float detail=.84+clamp(sl*1.25+.16*n(p*3.7),.03,.38);
    vec3 old_base=mix(vec3(.126,.085,.046),vec3(.052,.077,.033),old_cover)*detail;
    vec3 exposed=vec3(.109,.109,.086)*(.69+2.1*rl)*(.94+.11*strata);
    old_base=mix(old_base,exposed,stone*.92);
    vec3 dust=mix(vec3(.128,.097,.063),vec3(.161,.125,.073),n(p*.25))*detail;
    old_base=mix(old_base,dust,edge*.88);
    old_base*=.79+.23*broad+.15*(n(p*3.1)+.55*n(p*8.3));

    // The original hills remain the horizon material. The immediate ground uses
    // baked height in physical metres and two different surface communities.
    float local=1.-smoothstep(390.,755.,length(m*vec2(.93,1.03)));
    float coarse=n(m*.165+vec2(17.2,-31.));
    float ecology=n(m*.49+vec2(89.,-19.));
    float scatter=n(m*1.47+vec2(-63.,107.));
    vec2 road_uv=(m+vec2(640.,400.))/vec2(1280.,640.);
    vec2 shoulder=texture(roads,road_uv).rg;
    vec2 drift=vec2(n(m*.068),n(m*.081+54.))-vec2(.5);
    vec2 base_uv=(m+.54*drift)/8.;
    vec2 meadow_uv=vec2(.793*base_uv.x+.609*base_uv.y,-.609*base_uv.x+.793*base_uv.y)*1.08;
    vec4 soil=texture(soil_patch,base_uv);
    vec4 meadow=texture(meadow_patch,meadow_uv+vec2(.21,.71));
    float cover=smoothstep(.26,.67,.48*broad+.24*coarse+.19*ecology+.09*scatter);
    cover=clamp(cover*(1.-.96*shoulder.r)*(1.-.60*shoulder.g)*(1.-.23*stone),0.,1.);
    // Taller clasts survive in the turf; silt fills between them on the inner shoulder.
    float upper_clast=smoothstep(.193,.312,soil.a);
    cover*=1.-.46*upper_clast*(.42+.58*shoulder.g);
    vec3 bare=soil.rgb;
    vec3 turf=meadow.rgb*vec3(.96,1.05,.932);
    vec3 close_color=mix(bare,turf,cover);
    close_color*=.81+.24*broad+.16*coarse;
    // Slight darkening where soil is worn, then a light mineral apron.
    close_color=mix(close_color,close_color*vec3(.91,.875,.84),.52*shoulder.r);
    close_color*=1.+shoulder.g*(.55*upper_clast+.027);
    // Match the low sun palette of the settlement. The new textures retain
    // mineral colour at close range without turning the distant slopes pale.
    float terrain_luma=dot(close_color,vec3(.2126,.7152,.0722));
    close_color=mix(vec3(terrain_luma),close_color,.82)*vec3(.68,.76,.83);
    close_color=mix(close_color,exposed,.46*stone);
    local*=1.-.60*smoothstep(5.,37.,world_position.y);
    ALBEDO=mix(old_base,close_color,local);
    float original_relief=.065*n(p*.72)+.017*n(p*3.7)+.007*n(p*10.)+.014*sl+.018*rl*stone;
    float patch_relief=.095*mix(soil.a,meadow.a,cover);
    patch_relief+=.017*(ecology-.5)+.008*(scatter-.5);
    patch_relief*=1.-.23*shoulder.r;
    float relief=mix(.49*original_relief,patch_relief,local);
    vec3 q=VERTEX; vec3 vN=normalize(NORMAL);
    vec3 px=dFdx(q),py=dFdy(q);
    vec3 r1=cross(py,vN),r2=cross(vN,px);
    float det=dot(px,r1);
    if(abs(det)>.0000001) {
        vec3 grad=sign(det)*(dFdx(relief)*r1+dFdy(relief)*r2);
        NORMAL=normalize(abs(det)*vN-grad);
    }
    ROUGHNESS=clamp(.945-.065*upper_clast+.025*cover,.83,.98);
    SPECULAR=.21;
}
