extends RefCounted

# Optional hills beyond the original 464 m-wide town terrain. Local axes follow
# the valley's opening so the new crests continue the existing line of sight.
const ORIGIN := Vector2(-40.0, 45.0)
const FORWARD := Vector2(0.753568, -0.657370)
const RIGHT := Vector2(0.657370, 0.753568)
const NEAR_CREST := [
	Vector2(-1020,13),Vector2(-740,28),Vector2(-515,26),Vector2(-340,34),
	Vector2(-233,24),Vector2(-141,10),Vector2(-50,14),Vector2(33,22),
	Vector2(106,12),Vector2(204,3),Vector2(302,7),Vector2(427,13),
	Vector2(565,9),Vector2(750,25),Vector2(1020,17)
]
const FAR_CREST := [
	Vector2(-1050,26),Vector2(-760,36),Vector2(-614,48),Vector2(-480,40),
	Vector2(-371,50),Vector2(-265,31),Vector2(-152,13),Vector2(-67,24),
	Vector2(20,26),Vector2(112,10),Vector2(192,11),Vector2(324,21),
	Vector2(406,32),Vector2(510,18),Vector2(618,7),Vector2(735,21),
	Vector2(930,31),Vector2(1050,28)
]
static var field_noise: FastNoiseLite

static func _init_noise() -> void:
	if field_noise!=null: return
	field_noise=FastNoiseLite.new()
	field_noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	field_noise.seed=48193
	field_noise.frequency=.013
	field_noise.fractal_octaves=3

static func _trace(s:float, crest:Array) -> float:
	for i in range(1,crest.size()):
		var b:Vector2=crest[i]
		if s<=b.x:
			var a:Vector2=crest[i-1]
			# Blending linear and smooth avoids a repetitive succession of dome shapes.
			var f:=clampf((s-a.x)/(b.x-a.x),0.,1.)
			return lerpf(a.y,b.y,lerpf(f, f*f*(3.-2.*f), .58))
	return float(crest.back().y)

static func _jitter(i:int) -> float:
	return fposmod(sin(float(i)*43.725+1.81)*3161.91,1.)

static func _divide(s:float, distant:bool) -> float:
	if distant: return 874.+57.*sin(s*.0048+.4)+28.*sin(s*.012)
	return 510.+46.*sin(s*.0064-.42)+18.*sin(s*.015+.6)

# Each spur separates two irregular gullies that widen and develop tributaries
# towards the valley floor. Their heads cut notches into the main divide.
static func _gullies(s:float, downhill:float, distant:bool) -> float:
	var unit:=1.22 if distant else 1.
	var run:=downhill/unit
	var span:=74.0
	var lateral:=s/unit
	var cell:=floori(lateral/span)
	var result:=0.0
	for k in range(cell-2,cell+3):
		var a:=_jitter(k+22)
		var b:=_jitter(k-49)
		var c:=_jitter(k+56)
		var center:=(k+.18+.57*a)*span
		var sinuosity:=7.*sin(.030*run+4.*c)+3.*sin(.065*run+9.*a)
		center += (.53*b-.24)*run+sinuosity
		var channel_w:=5.+4.*c+.085*maxf(run,0.)
		var d:=absf(lateral-center)/channel_w
		var g:=1./(1.+d*d*d)
		# A short secondary hollow converges on each main ravine halfway down.
		var fork_at:=35.+46.*a
		var branch_center:=center+(fork_at-run)*(.5+.30*c)*(-1.0 if b>.5 else 1.0)
		var branch_dist:=absf(lateral-branch_center)/(3.6+.027*maxf(run,0.))
		var fork:=.65/(1.+branch_dist*branch_dist*branch_dist)
		fork*=smoothstep(-15.,16.,run)*(1.-smoothstep(fork_at-9.,fork_at+6.,run))
		result=maxf(result,maxf(g,fork))
	return result

static func _height(s:float, t:float, distant:bool) -> float:
	_init_noise()
	var divide:=_divide(s,distant)
	var v:=divide-t
	var width:=155. if distant else 103.
	var bottom:=-32. if distant else -23.
	var trace:=_trace(s,FAR_CREST if distant else NEAR_CREST)
	var macro:=field_noise.get_noise_2d(s*.38,t*.28)
	var fold:=field_noise.get_noise_2d(s*.82+t*.17,t*.49)
	var shelf:=field_noise.get_noise_2d(s*1.31+247.,t*.78-161.)
	var original_high:=trace+5.9*macro+2.7*fold+shelf
	var divide_form:=exp(-pow(v/width,2.0))
	var old:=bottom+(original_high-bottom)*divide_form
	var valleys:=_gullies(s,v,distant)
	var front:=smoothstep(-.23,.22,v/width)*(1.-smoothstep(1.35,2.20,v/width))
	var shoulder:=exp(-pow((v/width-.54)/.46,2.))
	var abutment:=.14*(original_high-bottom)*shoulder*(1.-valleys)
	var incisions:=(.036+.30*front)*(original_high-bottom)*valleys*divide_form
	var ridge_breaks:=2.05*absf(field_noise.get_noise_2d(s*3.1,t*1.27))*divide_form
	var incision_texture:=field_noise.get_noise_2d(s*3.4+t*.24+210.,t*2.17-547.)
	var small_spurs:=field_noise.get_noise_2d(s*4.8-t*.29-483.,t*.92+282.)
	var secondary:=divide_form*(4.9*incision_texture+2.9*small_spurs)*(.44+.56*front)
	return minf(original_high,old+abutment-incisions-ridge_breaks+secondary)

static func _range(parent:Node3D, distant:bool) -> void:
	const COLS:=513
	const ROWS:=128
	var start_t:=620.0 if distant else 255.0
	var end_t:=1213.0 if distant else 802.0
	var lateral:=1024.0
	var step_s:=2.*lateral/(COLS-1)
	var step_t:=(end_t-start_t)/(ROWS-1)
	var positions:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	positions.resize(COLS*ROWS)
	normals.resize(COLS*ROWS)
	colors.resize(COLS*ROWS)
	var wood:=Color("#46534b").srgb_to_linear() if distant else Color("#344638").srgb_to_linear()
	var dry:=Color("#79766b").srgb_to_linear() if distant else Color("#786b51").srgb_to_linear()
	var rock:=Color("#8a8982").srgb_to_linear() if distant else Color("#827c6c").srgb_to_linear()
	for z in ROWS:
		var t:=start_t+z*step_t
		for x in COLS:
			var s:=-lateral+x*step_s
			var p:=ORIGIN+s*RIGHT+t*FORWARD
			positions[z*COLS+x]=Vector3(p.x,_height(s,t,distant),p.y)
	for z in ROWS:
		var t:=start_t+z*step_t
		for x in COLS:
			var s:=-lateral+x*step_s
			var k:=z*COLS+x
			var ds:=(positions[z*COLS+mini(x+1,COLS-1)].y-positions[z*COLS+maxi(0,x-1)].y)/(2.*step_s)
			var dt:=(positions[mini(z+1,ROWS-1)*COLS+x].y-positions[maxi(0,z-1)*COLS+x].y)/(2.*step_t)
			var slope:=ds*RIGHT+dt*FORWARD
			var n:=Vector3(-slope.x,1.,-slope.y).normalized()
			var run:=_divide(s,distant)-t
			var valley:=_gullies(s,run,distant)
			var shale:=field_noise.get_noise_2d(s*1.06+t*.19,t*1.47)
			var beds:=field_noise.get_noise_2d(s*.71-t*.53,t*.42)
			var apron_texture:=field_noise.get_noise_2d(s*4.2+t*.30,t*2.77)
			var joints:=field_noise.get_noise_2d(s*2.22-t*.62+232.,t*4.73+881.)
			var exposed:=smoothstep(.10,.52,slope.length()+.33*shale+.30*apron_texture+.13*beds)
			var bare:=smoothstep(.20,1.08,.57*exposed+.38*(1.-valley)+.33*beds+.36*joints)
			var warmth:=clampf(.38+.31*shale+.24*beds-.19*valley+.54*apron_texture,0.,1.)
			var color:=wood.lerp(dry,warmth).lerp(rock,bare*.78)
			# Slope orientation and broad drainage shade survive atmospheric scattering
			# at kilometre distances, even beyond the sun's dynamic-shadow range.
			var sunward:=clampf(.53+1.17*slope.dot(Vector2(.83,-.41)),0.,1.)
			var drainage:=valley*smoothstep(-.1,.29,run/(155. if distant else 103.))
			var lightness:=lerpf(.58,1.12,sunward)*(1.-.23*drainage)
			normals[k]=n
			colors[k]=Color(color.r*lightness,color.g*lightness,color.b*lightness,1.)
			if z+1<ROWS and x+1<COLS:
				indices.append_array(PackedInt32Array([k,k+COLS,k+1,k+1,k+COLS,k+COLS+1]))
	var arrays:Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=positions
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var m:=ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true
	mat.vertex_color_is_srgb=false
	mat.roughness=.97
	mat.metallic_specular=.15
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	var node:=MeshInstance3D.new()
	node.name="Distant divide" if distant else "Outer foothills"
	node.mesh=m
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

static func build(parent:Node3D) -> void:
	_range(parent,false)
	_range(parent,true)


