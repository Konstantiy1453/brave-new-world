extends RefCounted
const ReferenceIO = preload("res://reference_io.gd")

const ROOT := "res://assets/surface07/rock_assets/"
const SOURCE_KEYS := ["boulder_01","namaqualand_boulder_04","namaqualand_boulder_06","namaqualand_boulder_05"]
const ORIGINAL_MAJOR := [3.2166,2.3054,4.9686]
static var meshes:Dictionary={}
static var materials:Dictionary={}
static var scan_shader:Shader

static func _mesh(key:String,lod:String)->ArrayMesh:
	var id:=key+"_"+lod
	if meshes.has(id):return meshes[id]
	var f:=FileAccess.open(ROOT+key+"/"+lod+".rock",FileAccess.READ)
	var nv:=f.get_32()
	var ni:=f.get_32()
	var a:Array=[]
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX]=f.get_buffer(nv*12).to_vector3_array()
	a[Mesh.ARRAY_NORMAL]=f.get_buffer(nv*12).to_vector3_array()
	a[Mesh.ARRAY_TANGENT]=f.get_buffer(nv*16).to_float32_array()
	a[Mesh.ARRAY_TEX_UV]=f.get_buffer(nv*8).to_vector2_array()
	a[Mesh.ARRAY_INDEX]=f.get_buffer(ni*4).to_int32_array()
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	meshes[id]=mesh
	return mesh

static func _tex(file:String) -> Texture2D:
	return ReferenceIO.texture(file)

static func _stone_material(key:String)->ShaderMaterial:
	if materials.has(key):return materials[key]
	if scan_shader==null:
		scan_shader=ReferenceIO.shader(ROOT+"weathered.gdshader")
	var m:=ShaderMaterial.new()
	m.shader=scan_shader
	var tag:=key
	var dir:=ROOT+tag+"/"
	m.set_shader_parameter("scan_color",_tex(dir+"weathered_diffuse.png"))
	m.set_shader_parameter("scan_normal",_tex(dir+"textures/"+tag+"_nor_gl_1k.jpg"))
	m.set_shader_parameter("scan_arm",_tex(dir+"textures/"+tag+"_arm_1k.jpg"))
	materials[key]=m
	return m

static func _draw(parent:Node3D,instances:Array,mesh:ArrayMesh,mat:Material,label:String,begin:float=0.,end:float=0.) -> void:
	if instances.is_empty():return
	var batch:=MultiMesh.new()
	batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.use_colors=true
	batch.mesh=mesh
	batch.instance_count=instances.size()
	for i in instances.size():
		batch.set_instance_transform(i,instances[i][0])
		batch.set_instance_color(i,instances[i][1])
	var node:=MultiMeshInstance3D.new()
	node.name=label
	node.multimesh=batch
	node.material_override=mat
	node.visibility_range_begin=begin
	node.visibility_range_end=end
	parent.add_child(node)

static func _append(groups:Dictionary,key:Vector3i,xf:Transform3D,tint:Color)->void:
	if not groups.has(key):groups[key]=[]
	groups[key].append([xf,tint])

static func _local_xf(parent:Node3D,yaw:float,scale_m:Vector3,ground_origin:Vector3)->Transform3D:
	var physical_basis:=Basis(Vector3.UP,yaw)*Basis.from_scale(scale_m)
	return Transform3D(parent.global_basis.inverse()*physical_basis,ground_origin)

static func _chips(parent:Node3D,terrain,bag:Dictionary,origin:Vector2,width:float,yaw:float,rock_id:int,rng:RandomNumberGenerator)->void:
	var horizontal:=parent.global_basis.x.length()
	var vertical:=parent.global_basis.y.length()
	var direction:=rng.randf_range(0.,TAU)
	var split:=rng.randf_range(.50,.80)
	var n:=clampi(roundi(5.0+3.15*width+rng.randfn(0.,2.6)),3,31)
	for j in n:
		var in_tail:=rng.randf()>split
		var angle:=direction+(1.78 if in_tail else 0.)+rng.randfn(0.,.58 if in_tail else .75)
		var off:=Vector2.from_angle(angle)
		var ellipse:=lerpf(.35,.5,absf(cos(angle+yaw)))
		var dist:=width*(ellipse+rng.randf_range(-.045,.40)) + rng.randf_range(.05,.42)
		var c:=origin+off*dist/horizontal
		var frac:=rng.randf()
		var size:=clampf(width*rng.randf_range(.082,.175),.19,.70) if (j<2 or frac>.79) else rng.randf_range(.055,.23)
		if terrain._distance(c)*horizontal < size*.77+.12:continue
		var variant:=rng.randi_range(0,3) if frac>.4 else rock_id
		var low:float=terrain._on_mesh(c.x,c.y)-(.17*size/vertical)
		var xf:=_local_xf(parent,rng.randf_range(0,TAU),Vector3(size*rng.randf_range(.75,1.14),size*rng.randf_range(.62,1.12),size),Vector3(c.x,low,c.y))
		var warm:=rng.randf_range(.72,1.23)
		_append(bag,Vector3i(floori((c.x*horizontal)/150.),floori((c.y*horizontal)/150.),variant),xf,Color(warm*.97,warm,warm*.96))

static func build_group(parent:Node3D,transforms:Array,model:String,terrain) -> void:
	var group_id:=int(model.right(2))
	var horizontal:=parent.global_basis.x.length()
	var vertical:=parent.global_basis.y.length()
	var original:Array=[]
	var inner:Dictionary={}
	var debris:Dictionary={}
	var rng:=RandomNumberGenerator.new()
	rng.seed=109793+group_id*13777
	var n_rocks:=0
	for i in transforms.size():
		var entry:Array=transforms[i]
		var src:Transform3D=entry[0]
		var c:=Vector2(src.origin.x,src.origin.z)
		var metric:=c*horizontal
		var slope:=Vector2(terrain._on_mesh(c.x+1.,c.y)-terrain._on_mesh(c.x-1.,c.y),terrain._on_mesh(c.x,c.y+1.)-terrain._on_mesh(c.x,c.y-1.)).length()*vertical/(2.*horizontal)
		var elevation:float=terrain._on_mesh(c.x,c.y)*vertical
		var r:=metric.length()
		var outer:=maxf(smoothstep(565.,810.,r),smoothstep(365.,610.,r)*maxf(smoothstep(.07,.19,slope),smoothstep(9.,34.,elevation)))
		if rng.randf()<outer:
			src.basis=src.basis.scaled(Vector3(vertical/horizontal,1.,vertical/horizontal))
			original.append([src,entry[1]])
			continue
		var index:=(i+group_id*2+2)%3
		if index==0 and i%5<2: index=3
		var major:float=ORIGINAL_MAJOR[group_id]*vertical*.5*(src.basis.x.length()+src.basis.z.length())
		var width:=clampf(major*([.85,.93,.65][group_id] as float),.42,5.5+rng.randf_range(-.45,.50))
		width=minf(width,maxf(.15,(terrain._distance(c)*horizontal-.16)/.78))
		var yaw:=atan2(-src.basis.x.z,src.basis.x.x)
		var yscale:=rng.randf_range(.82,1.08)
		if index==0: yaw-=1.12
		var pos:=src.origin
		pos.y=terrain._on_mesh(c.x,c.y)-width*(rng.randf_range(.095,.16)+(.075 if index==0 else 0.))/vertical
		var xf:=_local_xf(parent,yaw,Vector3(width*rng.randf_range(.92,1.06),width*yscale,width),pos)
		var tone:=rng.randf_range(.85,1.15)
		var tint:=Color(tone,rng.randf_range(.98,1.03)*tone,rng.randf_range(.94,1.03)*tone)
		_append(inner,Vector3i(floori(metric.x/150.),floori(metric.y/150.),index),xf,tint)
		if width>.85 and rng.randf()<.89:
			_chips(parent,terrain,debris,c,width,yaw,index,rng)
		n_rocks+=1
	var original_material:=StandardMaterial3D.new()
	original_material.vertex_color_use_as_albedo=true
	original_material.vertex_color_is_srgb=false
	original_material.roughness=.95
	original_material.metallic_specular=.22
	original_material.albedo_color=Color("#827e70")
	_draw(parent,original,terrain._mesh(model),original_material,model+"_RIDGE")
	for sector:Vector3i in inner:
		var id:String=SOURCE_KEYS[sector.z]
		var label:="Weathered_%s_%d_%d_%d" % [id,group_id,sector.x,sector.y]
		_draw(parent,inner[sector],_mesh(id,"near"),_stone_material(id),label+"_Near",0.,210.)
		_draw(parent,inner[sector],_mesh(id,"field"),_stone_material(id),label+"_Field",210.,0.)
	var n_chips:=0
	for sector:Vector3i in debris:
		var id:String=SOURCE_KEYS[sector.z]
		var list:Array=debris[sector]
		n_chips+=list.size()
		_draw(parent,list,_mesh(id,"chip"),_stone_material(id),"Footstone_%s_%d_%d_%d" % [id,group_id,sector.x,sector.y],0.,405.)
	print("ROCK07 ",model," boulders=",n_rocks," original_outcrops=",original.size()," toe_stones=",n_chips)
