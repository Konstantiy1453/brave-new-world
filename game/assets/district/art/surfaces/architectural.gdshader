shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D patina : repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 coat : source_color = vec4(0.5,0.55,0.54,1.0);
uniform vec4 glow : source_color = vec4(0.0,0.0,0.0,1.0);
uniform float warmth=0.0;
uniform float micro_roughness=0.52;
uniform float metal_fraction=0.18;
uniform float local_to_metres=9.0;
uniform float base_height=0.0;
uniform int treatment=0;
uniform bool automobile=false;
varying vec3 p;
varying vec3 n;
varying float variation;

void vertex(){
	p=VERTEX*local_to_metres;
	n=NORMAL;
	vec2 place=MODEL_MATRIX[3].xz;
	variation=fract(sin(dot(floor(place*.71+vec2(.5)),vec2(31.17,17.74)))*1007.93);
}
float edge_mask(float x,float width){
	float e=min(x,1.0-x);
	float aa=clamp(fwidth(e),0.001,0.06);
	return 1.0-smoothstep(width-aa,width+aa,e);
}
void fragment(){
	vec3 normal_l=normalize(n);
	vec3 w=pow(abs(normal_l),vec3(4.));
	w/=max(w.x+w.y+w.z,0.001);
	vec2 shift=vec2(variation*.73,COLOR.r*.38);
	vec3 a=texture(patina,vec2(p.z,-p.y)*.28+shift).rgb;
	vec3 b=texture(patina,vec2(p.x,p.z)*.25+shift).rgb;
	vec3 c=texture(patina,vec2(p.x,-p.y)*.28+shift).rgb;
	vec3 grain=a*w.x+b*w.y+c*w.z;
	vec3 col=coat.rgb;
	float rough=micro_roughness;
	float wall=1.-abs(normal_l.y);
	float h=max(p.y-base_height,0.);
	float streak=smoothstep(.42,.77,grain.g)*wall;
	float age=(grain.r-.5);
	float perpart=(COLOR.r-.5);
	float pspan=max(COLOR.g*35.,.1);
	float pheight=max(COLOR.b*14.,.1);
	if(treatment>=6 && treatment<=8){
		// A gasket follows the actual glazing object, independently for every pane.
		float xframe=edge_mask(UV2.x,clamp(.038/pspan,.012,.065));
		float yframe=edge_mask(UV2.y,clamp(.036/pheight,.018,.085));
		float frame=max(xframe,yframe);
		float vertical=clamp(UV2.y,0.,1.);
		float facing=clamp(dot(NORMAL,VIEW),0.0,1.0);
		float horizon=smoothstep(.16,.88,vertical+.08*age);
		float sky=(.21+.79*pow(1.-facing,2.))*horizon;
		col=mix(col*vec3(.59,.76,.87),col*vec3(1.04,1.08,1.11),horizon);
		col+=vec3(.025,.05,.064)*sky;
		float mull=0.;
		if(treatment==7 && pspan>1.6){
			float dd=abs(UV2.x-.5);
			mull=1.-smoothstep(.003-fwidth(dd)*.4,.008+fwidth(dd)*.6,dd);
		}
		float blind=1.-.15*smoothstep(.72,.81,UV2.y+age*.07);
		col=mix(col*blind,vec3(.012,.018,.020),max(frame,mull)*.84);
		float inset=(1.-frame)*(1.-mull);
		float curtain=(.71+.29*smoothstep(.02,.32,vertical));
		EMISSION=glow.rgb*warmth*inset*curtain;
		ROUGHNESS=mix(clamp(rough+age*.065,.14,.34),.63,frame);
		METALLIC=metal_fraction;
		SPECULAR=.52;
	}else{
		float base_grit=1.-smoothstep(.08,automobile?1.1:1.50,h);
		float grains=age*(automobile?.15:.23)+(grain.b-.5)*.052;
		col*=1.+grains+perpart*(automobile?.035:.095);
		if(!automobile && (treatment==0||treatment==1||treatment==2||treatment==3||treatment==4)){
			col*=1.+(variation-.5)*.19;
			col=mix(col,col*vec3(.71,.75,.78),streak*.43);
			col=mix(col,col*vec3(.76,.72,.63),base_grit*(.21+.30*grain.g));
		}
		if(automobile){
			float dust=base_grit*(.38+.52*grain.r)+w.y*.035;
			col=mix(col,vec3(.19,.154,.106),dust*(treatment==10?.33:.19));
			rough+=dust*.11;
		}
		// Joints follow an existing wall/door in its own UV2. Roofs, tires and full body shells receive no grid.
		if(treatment==1||treatment==3){
			float side=edge_mask(UV2.x,clamp((treatment==3?.022:.016)/pspan,.001,.028));
			float end=edge_mask(UV2.y,clamp((treatment==3?.020:.012)/pheight,.001,.022));
			float inset=max(side,end)*wall;
			col*=1.-inset*(treatment==3?.37:.21);
			if(treatment==1 && pspan>3.8 && pheight>1.15){
				float modules=max(2.0,floor(pspan/2.7+.5));
				float grid=abs(fract(UV2.x*modules+.5)-.5);
				float aa=clamp(fwidth(UV2.x)*modules,.001,.25);
				float seam=1.-smoothstep(.008-aa*.30,.012+aa*.65,grid);
				col*=1.-seam*wall*.26;
			}
		}
		if(treatment==2 || treatment==4){
			col*=1.-.09*max(normal_l.y,0.)*(grain.r+.2);
		}
		ROUGHNESS=clamp(rough+(grain.b-.5)*.085+streak*.040,.16,.98);
		METALLIC=metal_fraction;
		SPECULAR=treatment==10?.26:.44;
	}
	ALBEDO=max(col,vec3(.001));
}
