extends RefCounted
const ReferenceIO = preload("res://reference_io.gd")
const HORIZONTAL_LAYOUT_SCALE := 1.3*1.5
const XZ_METRES := 2.4*HORIZONTAL_LAYOUT_SCALE
const BIN := 10.0
const BULK_CLEARANCE:=9.0
static var clearance_bins:Dictionary={}
static var pavement_triangles:=0
const INSTANCE_COMPENSATION := Vector3(1.0/HORIZONTAL_LAYOUT_SCALE, 1.0, 1.0/HORIZONTAL_LAYOUT_SCALE)
const ENV_DIR = "res://assets/artpreview/env/"
static var _relief_noise: FastNoiseLite
static var _cover_noise: FastNoiseLite
static var _spray_material: ShaderMaterial

static func _init_noise() -> void:
	if _relief_noise != null:
		return
	_relief_noise = FastNoiseLite.new()
	_relief_noise.seed = 17481
	_relief_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_relief_noise.frequency = 0.012
	_relief_noise.fractal_octaves = 3
	_cover_noise = FastNoiseLite.new()
	_cover_noise.seed = 6984
	_cover_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_cover_noise.frequency = 0.084
	_cover_noise.fractal_octaves = 2

static func _rise(x: float, z: float, cx: float, cz: float, sx: float, sz: float, amp: float) -> float:
	return amp * exp(-pow((x-cx)/sx,2.0)-pow((z-cz)/sz,2.0))

static var pads:Array=[]
static func set_foundations(lots:Array) -> void:
	pads.clear()
	for lot:Dictionary in lots:
		var centre:Vector3=lot.pos
		pads.append([Vector2(centre.x,centre.z),lot.extent*.5,lot.yaw,_raw_height(centre.x,centre.z)])

static func height_at(x:float,z:float)->float:
	var h:=_raw_height(x,z)
	if absf(x)>115.0 or absf(z)>109.0:return h
	for pad:Array in pads:
		var delta:=Vector2(x,z)-Vector2(pad[0])
		var half_lot:Vector2=pad[1]
		if delta.length_squared()>(half_lot.length()+2.5)*(half_lot.length()+2.5):continue
		var outside:Vector2=(delta.rotated(float(pad[2])).abs()-half_lot).max(Vector2.ZERO)
		var d:=outside.length()
		if d<0.05:return float(pad[3])
		h=lerpf(float(pad[3]),h,smoothstep(.05,2.45,d))
	return h

static func _raw_height(x: float, z: float) -> float:
	_init_noise()
	var radial := Vector2(x/1.15, z).length()
	var wild := smoothstep(40.0,130.0,radial)
	var macro := _relief_noise.get_noise_2d(x,z)
	var grain := _cover_noise.get_noise_2d(x,z)
	# The settlement sits on a naturally shallow terrace. Ridges extend past the camera.
	var h := -.005*x+.008*z+(0.82+6.2*wild)*macro+(.11+.95*wild)*grain
	h += _rise(x,z,-132,-93,68,33,22)+_rise(x,z,31,-155,78,47,25)
	h += _rise(x,z,-174,-12,45,67,34)+_rise(x,z,120,-75,48,32,14)
	h += _rise(x,z,-60,113,59,30,12)+_rise(x,z,158,69,46,34,10)
	# Fragmented rock ridges emerge in the hills, while their footslopes meet town gently.
	var ridge:=1.0-absf(_relief_noise.get_noise_2d(x*1.43+410.,z*1.85-220.)*2.25)
	h+=smoothstep(58.0,124.0,radial)*(2.9*pow(maxf(ridge,0.0),2.2)+.82*grain)
	return h

# The outer mesh uses four-metre triangles. Vegetation roots use the same face
# height on long ridges, so their silhouettes cannot hover above the horizon.
static func _on_mesh(x:float,z:float) -> float:
	var sx:=4.0 if absf(x)>112.0 else 1.0
	var sz:=4.0 if absf(z)>112.0 else 1.0
	var x0:=floorf(x/sx)*sx
	var z0:=floorf(z/sz)*sz
	var u:=(x-x0)/sx
	var v:=(z-z0)/sz
	var a:=height_at(x0,z0)
	var b:=height_at(x0+sx,z0)
	var c:=height_at(x0,z0+sz)
	if u+v<=1.0:
		return a*(1.-u-v)+b*u+c*v
	var d:=height_at(x0+sx,z0+sz)
	return b*(1.-v)+c*(1.-u)+d*(u+v-1.)

# Bins limit exact distance tests to nearby road/yard/parcel geometry. All
# clearances are measured from the current layout footprints, in local ground units.
static func _put(shape:Dictionary,lo:Vector2,hi:Vector2,padding:float=BULK_CLEARANCE) -> void:
	var a:=Vector2i(((lo-Vector2.ONE*padding)/BIN).floor())
	var b:=Vector2i(((hi+Vector2.ONE*padding)/BIN).floor())
	for i in range(a.x,b.x+1):
		for j in range(a.y,b.y+1):
			var key:=Vector2i(i,j)
			if not clearance_bins.has(key):clearance_bins[key]=[]
			clearance_bins[key].append(shape)

static func _segment(a:Vector2,b:Vector2,r:float) -> void:
	var v:=b-a
	_put({"a":a,"v":v,"inverse":1./maxf(v.length_squared(),.00001),"r":r},a.min(b)-Vector2.ONE*r,a.max(b)+Vector2.ONE*r)

static func _project(v:Vector3)->Vector2:
	return Vector2(v.x,v.z)

# The final pavement triangles include the plaza, curbs, service forecourts,
# small paths and the actual tapered ends of the back-country roads.
static func _index_pavement(ground:Node3D,streets:Node3D) -> void:
	var to_ground:=ground.global_transform.affine_inverse()
	for strip in streets.get_children():
		if not strip is MeshInstance3D:continue
		if str(strip.name).to_lower() not in ["asphalt","walk","yard","sand","dirt","gravel","edge"]:continue
		var verts:PackedVector3Array=strip.mesh.get_faces()
		var relative:Transform3D=to_ground*strip.global_transform
		for k in range(0,verts.size(),3):
			var a:=_project(relative*verts[k])
			var b:=_project(relative*verts[k+1])
			var c:=_project(relative*verts[k+2])
			if absf((b-a).cross(c-a))<.0000001:continue
			var lo:=a.min(b).min(c)
			var hi:=a.max(b).max(c)
			_put({"tri":a,"b":b,"c":c,"lo":lo,"hi":hi},lo,hi,4.5)
			pavement_triangles+=1

static func _index(ground:Node3D,roads:Array,lots:Array,streets:Node3D) -> void:
	clearance_bins.clear()
	pavement_triangles=0
	if streets!=null:
		_index_pavement(ground,streets)
	else:
		for road:Dictionary in roads:
			var pts:PackedVector3Array=road.pts
			var r:=float(road.width)*.5+1.55/XZ_METRES
			for j in range(1,pts.size()):
				_segment(_project(pts[j-1]),_project(pts[j]),r)
	for lot:Dictionary in lots:
		var p:=_project(lot.pos)
		var h:Vector2=lot.extent*.5
		var a:=Vector2.from_angle(-float(lot.yaw))
		var b:=Vector2(-a.y,a.x)
		var planar_h:=a.abs()*h.x+b.abs()*h.y
		_put({"p":p,"h":h,"x":a,"z":b},p-planar_h,p+planar_h)
		if streets==null and lot.has("frontage"):
			var industrial:=str(lot.get("kind","")) in ["depot","repair","smelter","processor","power","water","farm"]
			_segment(p,_project(lot.frontage),(3.5 if industrial else 1.65)/XZ_METRES)

static func _distance(p:Vector2)->float:
	var d:=300.0
	var key:=Vector2i((p/BIN).floor())
	for shape:Dictionary in clearance_bins.get(key,[]):
		if shape.has("tri"):
			if d<=0.:continue
			var lo:Vector2=shape.lo
			var hi:Vector2=shape.hi
			if p.x<lo.x-d or p.y<lo.y-d or p.x>hi.x+d or p.y>hi.y+d:continue
			var a:Vector2=shape.tri
			var b:Vector2=shape.b
			var c:Vector2=shape.c
			if Geometry2D.point_is_inside_triangle(p,a,b,c):return -.0001
			var u:=p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p,a,b))
			var v:=p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p,b,c))
			var w:=p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p,c,a))
			d=minf(d,sqrt(minf(u,minf(v,w))))
		elif shape.has("p"):
			var delta:Vector2=p-Vector2(shape.p)
			var local:=Vector2(absf(delta.dot(shape.x)),absf(delta.dot(shape.z)))-Vector2(shape.h)
			d=minf(d,local.max(Vector2.ZERO).length()+minf(maxf(local.x,local.y),0.))
		else:
			var u:=clampf((p-Vector2(shape.a)).dot(shape.v)*float(shape.inverse),0.,1.)
			d=minf(d,p.distance_to(Vector2(shape.a)+Vector2(shape.v)*u)-float(shape.r))
	return d

static func _tex(name_:String) -> Texture2D:
	return ReferenceIO.texture(ENV_DIR+name_)

static func _ground(parent:Node3D,roads:Array,lots:Array) -> void:
	var ticks:=PackedFloat32Array()
	for i in range(-232,-112,4): ticks.append(float(i))
	for i in range(-112,113): ticks.append(float(i))
	for i in range(116,233,4): ticks.append(float(i))
	var verts:=PackedVector3Array()
	var norms:=PackedVector3Array()
	var cols:=PackedColorArray()
	var inds:=PackedInt32Array()
	var n:=ticks.size()
	verts.resize(n*n)
	norms.resize(n*n)
	cols.resize(n*n)
	for iz in n:
		var z:=ticks[iz]
		for ix in n:
			var x:=ticks[ix]
			var id:=iz*n+ix
			verts[id]=Vector3(x,height_at(x,z),z)
			var delta:=lerpf(.55,2.45,smoothstep(68.,148.,Vector2(x,z).length()))
			norms[id]=Vector3(height_at(x-delta,z)-height_at(x+delta,z),2.*delta,height_at(x,z-delta)-height_at(x,z+delta)).normalized()
			var dist:=_distance(Vector2(x,z))*1.5
			var offset:=_cover_noise.get_noise_2d(x*2.4,z*2.4)*1.4
			var edge:=1.0-smoothstep(-.5,2.9,dist+offset)
			cols[id]=Color(edge,0,0,1)
			if ix<n-1 and iz<n-1:
				inds.append_array(PackedInt32Array([id,id+1,id+n,id+1,id+n+1,id+n]))
	var a:Array=[]
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX]=verts
	a[Mesh.ARRAY_NORMAL]=norms
	a[Mesh.ARRAY_COLOR]=cols
	a[Mesh.ARRAY_INDEX]=inds
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	var material:ShaderMaterial=load("res://assets/surface07/soil/soil07.gd").make_material()
	var node:=MeshInstance3D.new()
	node.name="Continuous dry terrace"
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.mesh=mesh
	node.material_override=material
	parent.add_child(node)

static func _mesh(id:String) -> ArrayMesh:
	var f:=FileAccess.open(ENV_DIR+id+".meshbin",FileAccess.READ)
	var count:=f.get_32()
	var nindices:=f.get_32()
	var a:Array=[]
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX]=f.get_buffer(count*12).to_vector3_array()
	a[Mesh.ARRAY_NORMAL]=f.get_buffer(count*12).to_vector3_array()
	a[Mesh.ARRAY_INDEX]=f.get_buffer(nindices*4).to_int32_array()
	if id.ends_with("_SPRAYS"):
		a[Mesh.ARRAY_TEX_UV]=f.get_buffer(count*8).to_vector2_array()
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	return mesh

static func _scatter(parent:Node3D,transforms:Array,model:String,kind:String) -> void:
	if kind=="grass":
		transforms=load("res://assets/surface07/lowgrass.gd").build(parent,transforms,load("res://assets/surface07/terrain07.gd"))
	if kind=="rock":
		load("res://assets/surface07/rock07.gd").build_group(parent,transforms,model,load("res://assets/surface07/terrain07.gd"))
		return
	if transforms.is_empty():return
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=false
	material.roughness=.95
	material.metallic_specular=.22
	var base:Color
	match kind:
		"trunk":base=Color("#665244")
		"leaf":base=Color("#4b5c3b")
		"shrub":base=Color("#5c6742")
		"grass":base=Color("#898155")
		_:base=Color("#827e70")
	if kind in ["leaf","shrub","grass"]:
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.albedo_color=base
	var group:=MultiMesh.new()
	group.transform_format=MultiMesh.TRANSFORM_3D
	group.use_colors=true
	group.mesh=_mesh(model)
	group.instance_count=transforms.size()
	for k in transforms.size():
		var entry:Array=transforms[k]
		# Layout expands each origin. Its local shape retains the previous metre scale.
		var placement:Transform3D=entry[0]
		placement.basis=placement.basis.scaled(INSTANCE_COMPENSATION)
		group.set_instance_transform(k,placement)
		group.set_instance_color(k,entry[1])
	var node:=MultiMeshInstance3D.new()
	node.name=model
	node.multimesh=group
	if model.ends_with("_SPRAYS"):
		if _spray_material==null:
			var leaf_shader:=ReferenceIO.shader(ENV_DIR+"leaves.gdshader")
			_spray_material=ShaderMaterial.new()
			_spray_material.shader=leaf_shader
			_spray_material.set_shader_parameter("branches",_tex("leaf-spray.png"))
		node.material_override=_spray_material
	else:
		node.material_override=material
	parent.add_child(node)

# Reuse the preceding preview's individual plants wherever the new buildings and
# paving leave room. A vacated old roof or road can receive fresh ground cover.
const BASELINE_PLANT_REFERENCE := "res://assets/space06/vegetation05_reference.bin"
static var continuity:Dictionary={}

static func _baseline_vegetation(group_name:String,candidates:Array,reference:Dictionary) -> Array:
	var group:Dictionary=reference.groups[group_name]
	var radius:float=group.radius
	var retained:=0
	var removed:=0
	var filled:=0
	var moved_y:=0
	var result:Array=[]
	for saved:Array in group.placements:
		var transform:Transform3D=saved[0]
		var center:=Vector2(transform.origin.x,transform.origin.z)
		var ax:=Vector2(transform.basis.x.x,transform.basis.x.z)
		var az:=Vector2(transform.basis.z.x,transform.basis.z.z)
		var a:=ax.length_squared()
		var b:=az.length_squared()
		var c:=ax.dot(az)
		var maximum_scale:=sqrt(.5*(a+b+sqrt((a-b)*(a-b)+4*c*c)))
		var reach:=radius*maximum_scale/HORIZONTAL_LAYOUT_SCALE
		if _distance(center)<reach+.01/XZ_METRES:
			removed+=1
			continue
		var surface_y:=_on_mesh(center.x,center.y)+float(saved[2])
		if absf(surface_y-transform.origin.y)>.00001:
			moved_y+=1
			transform.origin.y=surface_y
		result.append([transform,saved[1]])
		retained+=1
	var size_:int=reference.size
	var mask:PackedByteArray=reference.mask
	for row:Array in candidates:
		var xf:Transform3D=row[0]
		var p:=Vector2(xf.origin.x,xf.origin.z)
		var grid:=Vector2i(((p+Vector2(116.,116.))*2.).round())
		if grid.x<0 or grid.y<0 or grid.x>=size_ or grid.y>=size_:continue
		if mask[grid.y*size_+grid.x]==0:continue
		result.append(row)
		filled+=1
	continuity[group_name]={"retained_at_original_xz":retained,"retained_with_new_ground_y":moved_y,"removed_for_clearance":removed,"added_in_old_developed_land":filled}
	return result

# Road and footprint data must be expressed in this terrain node's local X/Z
# units. Pass the actual Streets mesh parent to include every rendered paved area.
static func build(parent:Node3D,roads:Array,lots:Array,streets:Node3D=null) -> void:
	_init_noise()
	_index(parent,roads,lots,streets)
	_ground(parent,roads,lots)
	var rng:=RandomNumberGenerator.new()
	rng.seed=917349
	var trees:Array=[[],[],[]]
	var shrubs:Array=[]
	var grass:Array=[]
	var rocks:Array=[[],[],[]]
	# The lowland keeps the previous density per square metre. Scatter thins
	# continuously into rocky distant slopes, without cutting off at a rectangle.
	for k in 78200:
		var x:=rng.randf_range(-231.5,231.5)
		var z:=rng.randf_range(-231.5,231.5)
		var p:=Vector2(x,z)
		var broad_density:=1.-.92*smoothstep(78.,202.,Vector2(x,z*1.10).length())
		if rng.randf()>broad_density:continue
		var distance:=_distance(p)*1.5
		if distance < .65: continue
		var canopy:=.62*_relief_noise.get_noise_2d(x*1.5+530.,z*1.45)+.38*_cover_noise.get_noise_2d(x*.63,z*.63)
		var cluster:=_cover_noise.get_noise_2d(x*.53-70.,z*.55+113.)
		var yaw:=rng.randf_range(0,TAU)
		var scale_:float
		var type_:String
		var t:=rng.randf()
		var outcrop:=smoothstep(52.,101.,p.length())*smoothstep(-.24,.14,cluster)
		var roadshade:=smoothstep(1.4,5.0,distance)
		var close_to_centre:=1.0-smoothstep(20.0,94.0,p.length())
		if t < .103 * roadshade and canopy > .14 and distance>3.8 and rng.randf()>.44*close_to_centre:
			type_="tree"
			scale_=rng.randf_range(.49,.82)*(1.-.18*close_to_centre)
		elif t < .15 and canopy+.31*cluster>.012 and distance>1.35:
			type_="shrub"
			scale_=rng.randf_range(.22,.56)
		elif t > .936-outcrop*.066 and cluster<.24 and distance>1.05:
			type_="rock"
			scale_=rng.randf_range(.12,.62)*(.75+smoothstep(3.,36.,distance)*.65)*(1.+outcrop*1.55)
		elif t > .26 and rng.randf() < .48+cluster*.83:
			type_="grass"
			scale_=rng.randf_range(.34,1.01)
		else:
			continue
		var basis:=Basis(Vector3.UP,yaw).scaled(Vector3(scale_*rng.randf_range(.87,1.12),scale_*rng.randf_range(.85,1.12),scale_))
		# The furthest crowns and elongated slabs must also clear the paving.
		var radius:=4.45 if type_=="tree" else (2.65 if type_=="rock" else (1.55 if type_=="shrub" else .78))
		if distance/1.5 < radius*scale_*1.14/HORIZONTAL_LAYOUT_SCALE+.28/XZ_METRES:continue
		var y:=_on_mesh(x,z)
		if type_=="rock": y-=.31*scale_
		elif type_=="tree" or type_=="shrub": y-=.12*scale_
		var xf:=Transform3D(basis,Vector3(x,y,z))
		var value:=rng.randf_range(.70,1.0)
		var tint:=Color(value*rng.randf_range(.92,1.),value,value*rng.randf_range(.86,1.),1.)
		var entry:=[xf,tint]
		match type_:
			"tree":trees[rng.randi_range(0,2)].append(entry)
			"shrub":shrubs.append(entry)
			"rock":rocks[rng.randi_range(0,2)].append(entry)
			"grass":grass.append(entry)
	# Perimeter groves follow the true occupied town shape. Interior groups
	# use rear/side corners of lived-in buildings, leaving entrances unobstructed.
	var anchors:Array[Vector2]=[]
	var dwellings:Array[Vector2]=[]
	if not lots.is_empty():
		var town:=Rect2(_project(lots[0].pos),Vector2.ZERO)
		for lot:Dictionary in lots:town=town.expand(_project(lot.pos))
		for i in 8:
			var angle:=TAU*(float(i)+rng.randf_range(-.18,.18))/8.
			anchors.append(town.get_center()+Vector2.from_angle(angle)*town.size*.57)
		for lot:Dictionary in lots:
			if str(lot.get("kind","")) not in ["commerce","clinic","lab","school","apartment","habitat","civic_center","crew_quarters"]:continue
			var c:=_project(lot.pos)
			var f:=_project(lot.get("frontage",lot.pos))-c
			var forward:=f.normalized() if f.length_squared()>.01 else Vector2.UP.rotated(-float(lot.yaw))
			var side:=Vector2(-forward.y,forward.x)
			var half:Vector2=lot.extent*.5
			var sign_:=-1. if rng.randf()<.5 else 1.
			for direction in [sign_,-sign_]:
				var point:=c+side*float(direction)*(half.x+2.2)-forward*rng.randf_range(.15,.90)*half.y
				if _distance(point)<1.4:continue
				var nearby:=false
				for old:Vector2 in dwellings:
					if old.distance_squared_to(point)<81.:nearby=true;break
				if nearby:continue
				dwellings.append(point)
				break
			if dwellings.size()>=9:break
	var urban_trees:=0
	for outer in [true,false]:
		for origin:Vector2 in (anchors if outer else dwellings):
			var placed:Array[Vector2]=[]
			var spread:=3.1 if outer else 2.25
			for attempt in 28:
				var p:=origin if attempt==0 else origin+Vector2(rng.randf_range(-spread,spread),rng.randf_range(-spread,spread))
				var size_:float=rng.randf_range(.66,.93) if outer else rng.randf_range(.46,.64)
				if not placed.is_empty():size_*=rng.randf_range(.57,.78)
				if _distance(p)<4.55*size_/HORIZONTAL_LAYOUT_SCALE+.21:continue
				var clear:=true
				for other:Vector2 in placed:
					if p.distance_squared_to(other)<2.25:clear=false;break
				if not clear:continue
				var basis:=Basis(Vector3.UP,rng.randf_range(0.,TAU)).scaled(Vector3.ONE*size_)
				var xform:=Transform3D(basis,Vector3(p.x,_on_mesh(p.x,p.y)-.12*size_,p.y))
				trees[rng.randi_range(0,2)].append([xform,Color(.76,.83,.74)])
				placed.append(p)
				if not outer:urban_trees+=1
				if placed.size()>=3:break
			for attempt in (5 if outer else 9):
				var p:=origin+Vector2(rng.randf_range(-3.4,3.4),rng.randf_range(-2.7,2.7))
				var size_:=rng.randf_range(.18,.39)
				if _distance(p)<1.6*size_/HORIZONTAL_LAYOUT_SCALE+.14:continue
				var basis:=Basis(Vector3.UP,rng.randf_range(0.,TAU)).scaled(Vector3.ONE*size_)
				var xf:=Transform3D(basis,Vector3(p.x,_on_mesh(p.x,p.y)-.12*size_,p.y))
				shrubs.append([xf,Color(.74,.80,.70)])
	# Preserve the camera backdrop and unrelated exterior street trees during this spacing review.
	continuity.clear()
	var baseline_source:=FileAccess.open(BASELINE_PLANT_REFERENCE,FileAccess.READ)
	if baseline_source==null:
		push_error("Cannot load 05 vegetation reference.")
		return
	var reference:Dictionary=baseline_source.get_var()
	for i in 3:
		trees[i]=_baseline_vegetation("tree"+str(i),trees[i],reference)
		rocks[i]=_baseline_vegetation("rock"+str(i),rocks[i],reference)
	shrubs=_baseline_vegetation("shrub",shrubs,reference)
	grass=_baseline_vegetation("grass",grass,reference)
	print("SURFACE07_NATURE paving_triangles=",pavement_triangles," trees=",trees[0].size()+trees[1].size()+trees[2].size()," shrubs=",shrubs.size()," grass=",grass.size()," rocks=",rocks[0].size()+rocks[1].size()+rocks[2].size())
	for i in 3:
		var key:="CC_TREE_SOURCE_%02d" % i
		_scatter(parent,trees[i],key+"_BRANCH_NETWORK","trunk")
		_scatter(parent,trees[i],key+"_CURVED_LEAF_CROWN_SPRAYS","leaf")
		_scatter(parent,rocks[i],"CC_ROCK_SOURCE_%02d" % i,"rock")
	_scatter(parent,shrubs,"CC_SHRUB_SOURCE_BRANCH_NETWORK","trunk")
	_scatter(parent,shrubs,"CC_SHRUB_SOURCE_CURVED_LEAF_CROWN_SPRAYS","shrub")
	_scatter(parent,grass,"CC_GRASS_SOURCE","grass")

