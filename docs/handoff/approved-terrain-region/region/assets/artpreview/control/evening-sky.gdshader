shader_type sky;
uniform vec4 top_color : source_color = vec4(.29,.41,.62,1.);
uniform vec4 horizon_color : source_color = vec4(.76,.72,.70,1.);
uniform vec4 cloud_color : source_color = vec4(.68,.70,.77,1.);
float hash_p(vec2 v) {
 vec3 q=fract(vec3(v.xyx)*0.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);
}
float octave(vec2 p){
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash_p(i),hash_p(i+vec2(1,0)),f.x),mix(hash_p(i+vec2(0,1)),hash_p(i+vec2(1,1)),f.x),f.y);
}
void sky() {
 vec3 dir=EYEDIR;
 float up=max(dir.y,0.0);
 vec3 base=mix(horizon_color.rgb,top_color.rgb,pow(up,.42));
 vec2 projected=dir.xz/(.17+up);
 vec2 p=mat2(vec2(.83,-.56),vec2(.56,.83))*projected*vec2(1.5,4.8);
 float tex=octave(p)*.52+octave(p*2.19+3.4)*.27+octave(p*4.6)*.141+octave(p*9.3)*.069;
 float w=smoothstep(.43,.74,tex)*smoothstep(-.035,.095,dir.y);
 base=mix(base,cloud_color.rgb,w*.25);
 base+=vec3(.035,.019,.009)*pow(max(0.0,dot(dir,normalize(vec3(-.84,.055,.43)))),19.);
 COLOR=base;
}
