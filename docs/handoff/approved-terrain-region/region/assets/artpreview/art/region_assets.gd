extends RefCounted
const ReferenceIO = preload("res://reference_io.gd")
const DIR: String = "res://assets/artpreview/art/"
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _textures: Dictionary = {}
var counts: Dictionary = {}
var _finish_library = preload("res://assets/artpreview/art/surfaces/finishes.gd").new()

func building(parent:Node3D, id:String, position:Vector3, world_width:float, yaw_deg:float=0.0)->MeshInstance3D:
	return _place(parent, id, position, world_width, yaw_deg, false)

func vehicle(parent:Node3D, id:String, position:Vector3, world_length:float, yaw_deg:float=0.0)->MeshInstance3D:
	return _place(parent, "vehicle_"+id.trim_prefix("vehicle_"), position, world_length, yaw_deg+180.0, true)

func _mesh(id:String)->ArrayMesh:
	if not _meshes.has(id):
		_meshes[id]=ResourceLoader.load(DIR+"meshes_v2/"+id+".res")
	return _meshes[id]

func _place(parent:Node3D,id:String,pos:Vector3,extent:float,yaw:float,veh:bool)->MeshInstance3D:
	var mesh=_mesh(id)
	if mesh==null:return null
	var item:=MeshInstance3D.new()
	item.name="Preview_"+id
	item.mesh=mesh
	var bounds=mesh.get_aabb()
	var factor:float=extent/(bounds.size.z if veh else maxf(bounds.size.x,bounds.size.z))
	item.rotation.y=deg_to_rad(yaw)
	item.scale=Vector3.ONE*factor
	var pivot:=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	item.position=pos-item.basis*pivot
	_finish(item,id)
	parent.add_child(item)
	counts[id]=int(counts.get(id,0))+1
	return item

func _finish(item:MeshInstance3D,id:String):
	for i in item.mesh.get_surface_count():
		var slot:String=item.mesh.surface_get_name(i)
		item.set_surface_override_material(i,_material(id,slot))

func _texture(name:String)->Texture2D:
	if not _textures.has(name):
		_textures[name]=ReferenceIO.texture(DIR+"textures/"+name+"_1k.png")
	return _textures[name]

func _material(id:String,slot:String)->Material:
	var cache_id:String=id+"/"+slot
	if _materials.has(cache_id):return _materials[cache_id]
	if _finish_library.supports(slot):
		var custom:Material = _finish_library.make(id,slot)
		_materials[cache_id]=custom
		return custom
	var m:=StandardMaterial3D.new()
	m.resource_name=cache_id
	var veh:bool=id.begins_with("vehicle_")
	var palette:Dictionary={
		"paint":["c0c5be",0.15,0.54], "dark":["34444b",0.26,0.51],
		"accent":["af8352",0.24,0.45],"glass":["264653",0.26,0.19],
		"concrete":["a6a69b",0.0,0.9], "wood":["917559",0.0,0.67],
		"soil":["998b69",0.0,0.97], "leaf":["61755b",0.0,0.87],
		"metal":["76858a",0.63,0.39], "rubber":["232729",0.0,0.71],
		"greenhouse":["81a7a4",0.15,0.20],"window_cool":["415860",0.30,0.22],
		"window_warm":["7c7260",0.27,0.23],"window_dim":["304751",0.28,0.24],
		"salon_glass":["42565a",0.28,0.20],
		"signal":["d0bb8b",0.14,0.30],"taillight":["b14028",0.1,0.26],"headlight":["e5dac1",0.16,0.26]
	}
	if id=="vehicle_bus":
		palette.paint=["9cb3ad",0.31,0.34]
		palette.accent=["d8b76e",0.25,0.41]
	elif id=="vehicle_truck":
		palette.paint=["b89373",0.23,0.45]
		palette.accent=["c59950",0.27,0.40]
	elif id=="vehicle_van":
		palette.paint=["d2d0bf",0.29,0.40]
		palette.accent=["517c80",0.32,0.39]
	else:
		var shells={"habitat":"bdc3b7","commerce":"c7bda9","apartment":"c0b7aa","clinic":"c7cec5","lab":"b8c4c8","school":"c6bfab","crew_quarters":"b4bdb7","processor":"a8b1b2","depot":"acb1a6","power":"adb7b4"}
		palette.paint[0]=shells.get(id,"b3bcb7")
	var spec:Array=palette.get(slot,palette.paint)
	m.albedo_color=Color(spec[0]);m.metallic=spec[1];m.roughness=spec[2]
	if slot in ["concrete","soil"]:
		m.albedo_texture=_texture(slot+"_basecolor")
		m.roughness_texture=_texture(slot+"_roughness")
		m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.albedo_color=Color("d4cfc2") if slot=="concrete" else Color.WHITE
	if slot=="greenhouse":
		m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a=0.33
	if veh and slot in ["paint","glass","salon_glass"]:
		m.clearcoat_enabled=true;m.clearcoat=0.34;m.clearcoat_roughness=0.31
	var emit:Dictionary={
		"signal":["f3c67d",1.20],"headlight":["ffecd0",2.55],"taillight":["ff5433",1.50],
		"window_warm":["f8ca8b",0.80],"window_dim":["c2966c",0.085],"window_cool":["afc8cb",0.42],
		"salon_glass":["dcc6a1",0.32]}
	if emit.has(slot):
		m.emission_enabled=true;m.emission=Color(emit[slot][0]);m.emission_energy_multiplier=emit[slot][1]
	_materials[cache_id]=m
	return m
