shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform float phase=0.;
float hash2(vec2 v) { vec3 q=fract(vec3(v.xyx)*.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z); }
float noise2(vec2 p){vec2 id=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash2(id),hash2(id+vec2(1,0)),f.x),mix(hash2(id+vec2(0,1)),hash2(id+vec2(1,1)),f.x),f.y);}
void vertex(){
 vec3 centre=(MODEL_MATRIX*vec4(0.,0.,0.,1.)).xyz;
 vec3 up=vec3(0,1,0);
 vec3 right=normalize(vec3(INV_VIEW_MATRIX[0].x,0,INV_VIEW_MATRIX[0].z));
 float t=1.-UV.y;
 vec3 wind=vec3(2.6,0,-1.6)*t*t;
 vec3 world=centre+up*t*11.+wind+right*(UV.x-.5)*8.;
 POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(world,1.);
}
void fragment(){
 float t=1.-UV.y;
 vec2 p=vec2(UV.x*6.,t*4.+phase);
 float n=.55*noise2(p)+.27*noise2(2.18*p+11.)+.14*noise2(4.8*p+4.1)+.04*noise2(p*9.);
 float centre=.5+(noise2(vec2(t*7.+phase,6.))-.5)*(.045+.12*t);
 float width=.040+.22*t;
 float offset=abs((UV.x-centre)/width);
 float edge=max(0.,1.-smoothstep(.06,.98,offset+.50-.98*n));
 float body=smoothstep(.22,.69,n);
 ALBEDO=mix(vec3(.29,.31,.33),vec3(.65,.67,.66),n);
 ALPHA=edge*body*(1.-smoothstep(.25,1.,t))*.28*smoothstep(0.,.06,t);
}
