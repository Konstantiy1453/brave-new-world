extends Node
const ReferenceIO = preload("res://reference_io.gd")

const BASE := "res://assets/artpreview/"
const REV := "res://assets/scale02/"
const OUT := "res://assets/space06/"
const S := 2.4
const HORIZONTAL := S*1.3*1.5
const VEHICLE_LENGTHS := {"bus": 12.12, "truck": 10.105, "van": 6.155, "car": 6.155}
var measured:Array=[]
var hills:Variant
var scene := Node3D.new()
var camera := Camera3D.new()
var captures := []
var film:=SubViewport.new()
var sun_ref: DirectionalLight3D
var environment_ref: Environment

var capture_name := ""
var output_dir := "user://approved_region_frames"
var validate_only := false
var views: Array = []
var ready_to_view := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--validate":
				validate_only = true
			"--output", "--capture":
				if i + 1 >= args.size():
					push_error("Missing value for " + args[i])
					get_tree().quit(2)
					return
				if args[i] == "--capture":
					capture_name = args[i + 1]
				else:
					output_dir = args[i + 1]
				i += 1
			_:
				push_error("Unknown option: " + args[i])
				get_tree().quit(2)
				return
		i += 1
	if not capture_name.is_empty() and not capture_name in ["rocks", "verge", "settlement"]:
		push_error("Use --capture rocks, verge or settlement.")
		get_tree().quit(2)
		return
	if DisplayServer.get_name() == "headless" and not validate_only:
		push_error("Headless mode supports --validate. Use a graphics device to capture frames.")
		get_tree().quit(2)
		return
	call_deferred("render_district")

func _unhandled_key_input(event: InputEvent) -> void:
	if ready_to_view and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: apply_view(views[0])
			KEY_2: apply_view(views[1])
			KEY_3: apply_view(views[2])
			KEY_ESCAPE: get_tree().quit()

func apply_view(view: Dictionary) -> void:
	set_hour(str(view.id))
	sun_ref.shadow_enabled = true
	sun_ref.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun_ref.directional_shadow_blend_splits = true
	environment_ref.fog_enabled = true
	environment_ref.ssao_enabled = true
	var p: Array = view.position
	var t: Array = view.target
	camera.fov = float(view.fov)
	camera.look_at_from_position(Vector3(p[0],p[1],p[2])*S, Vector3(t[0],t[1],t[2])*S, Vector3.UP)

func add_environment() -> void:
	var world_env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	environment_ref = e
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#627fa4")
	sky_material.sky_horizon_color = Color("#d0c9b6")
	sky_material.ground_horizon_color = Color("#b9b3a2")
	sky_material.ground_bottom_color = Color("#68735c")
	sky_material.sun_angle_max = 2.0
	sky.sky_material = sky_material
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b6c9de")
	e.ambient_light_energy = 0.80
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.08
	e.tonemap_white = 5.0
	e.ssao_enabled = true
	e.ssao_radius = 1.25
	e.ssao_intensity = 1.7
	e.ssao_power = 1.35
	e.glow_enabled = true
	e.glow_intensity = 0.25
	e.glow_bloom = 0.03
	e.glow_hdr_threshold = 1.45
	e.fog_enabled = true
	e.fog_light_color = Color("#a6b1b9")
	e.fog_light_energy = 0.75
	e.fog_density = 0.00145
	e.fog_sun_scatter = 0.10
	world_env.environment = e
	scene.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffdab0")
	sun.light_energy = 1.68
	sun.light_angular_distance = 0.48
	sun.shadow_enabled = true
	sun.shadow_bias = 0.026
	sun.shadow_normal_bias = 0.78
	sun.directional_shadow_max_distance = 250.0*S
	scene.add_child(sun)
	sun_ref = sun
	sun.look_at_from_position(Vector3(-102,61,48),Vector3.ZERO,Vector3.UP)
	camera.near = 0.20
	camera.far = 1500.0*S
	scene.add_child(camera)
	camera.current = true
	film.msaa_3d = Viewport.MSAA_4X
	film.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

func set_hour(mode: String) -> void:
	var e:=environment_ref
	var sm:=ShaderMaterial.new()
	var shader:=ReferenceIO.shader(BASE+"control/evening-sky.gdshader")
	sm.shader=shader
	e.sky.sky_material=sm
	var late:=mode.ends_with("-sun")
	var blue:=mode.ends_with("-blue")
	sm.set_shader_parameter("top_color",Color("#657ea0") if late else Color("#435b85"))
	sm.set_shader_parameter("horizon_color",Color("#b5b4b0") if late else Color("#a6a5b5"))
	sm.set_shader_parameter("cloud_color",Color("#f5d2b8") if late else Color("#cfbcc1"))
	e.ambient_light_color=Color("#bac7d5") if not blue else Color("#a9b7d1")
	e.ambient_light_energy=0.60 if not blue else 0.49
	e.tonemap_mode=Environment.TONE_MAPPER_ACES
	e.tonemap_exposure=1.02
	e.tonemap_white=4.0
	e.adjustment_enabled=true
	e.adjustment_contrast=1.07
	e.adjustment_saturation=1.08
	e.fog_light_color=Color("#97a6bd")
	e.fog_light_energy=0.7
	e.fog_sky_affect=0.08
	e.fog_density=0.00075/S
	sun_ref.light_color=Color("#ffce9e") if not blue else Color("#ffc69b")
	sun_ref.light_energy=1.09 if late else (0.50 if blue else 0.77)
	sun_ref.look_at_from_position(Vector3(-95,34,47),Vector3.ZERO,Vector3.UP)

func bring_up_practicals() -> void:
	for fixture:Node3D in get_tree().get_nodes_in_group("district_street_lenses"):
		var lamp:=SpotLight3D.new()
		lamp.light_color=Color("#ffd69d")
		lamp.light_energy=1.48
		lamp.spot_angle=56.
		lamp.spot_attenuation=0.6
		lamp.spot_range=10.8
		scene.add_child(lamp)
		lamp.position=fixture.global_position-Vector3.UP*0.05
		lamp.rotation_degrees.x=-90.0

func add_door_light(p:Vector3, direction:Vector3, depth:float, kind:String) -> void:
	if kind in ["water","smelter","power","farm"]:
		return
	var lamp:=OmniLight3D.new()
	lamp.light_color=Color("#ffdcac") if kind!="lab" else Color("#d4e3f5")
	lamp.light_energy=1.65
	lamp.omni_attenuation=1.6
	lamp.omni_range=6.2
	scene.add_child(lamp)
	lamp.position=p+direction*(depth*.47+0.18)+Vector3.UP*2.05

func add_vehicle_lights(position_3d: Vector3, yaw: float, length_m: float) -> void:
	var anchor := Node3D.new()
	scene.add_child(anchor)
	anchor.position = position_3d
	anchor.rotation.y = yaw
	for side in [-1.0,1.0]:
		var headlamp := SpotLight3D.new()
		headlamp.light_color = Color("#fff1d1")
		headlamp.light_energy = 0.38
		headlamp.spot_angle = 22
		headlamp.spot_range = 15.0
		headlamp.spot_attenuation = 0.85
		anchor.add_child(headlamp)
		headlamp.position = Vector3(0.88*side,0.85,-0.48*length_m)
		headlamp.rotation_degrees.x = -8

func add_working_vent(instance:MeshInstance3D) -> void:
	var v:Array=JSON.parse_string(FileAccess.get_file_as_string(BASE+"control/vent.json"))
	var centre:=instance.to_global(Vector3(v[0],v[1],v[2]))
	var plume:=MeshInstance3D.new()
	var mesh:=QuadMesh.new()
	mesh.size=Vector2(8,11)
	plume.mesh=mesh
	var shader:=ReferenceIO.shader(BASE+"control/vapour.gdshader")
	var material:=ShaderMaterial.new()
	material.shader=shader
	plume.material_override=material
	plume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plume.extra_cull_margin=15
	scene.add_child(plume)
	plume.position=centre

func metric_h(x:float,z:float)->float:
	return S*float(hills.height_at(x/HORIZONTAL,z/HORIZONTAL))

func map_footprints(roads:Array,lots:Array,scale_xz:float=HORIZONTAL)->Dictionary:
	var road_shapes:Array=[]
	var lot_shapes:Array=[]
	for road:Dictionary in roads:
		var r:=road.duplicate()
		var pts:=PackedVector3Array()
		for pos:Vector3 in road.pts:pts.append(pos/scale_xz)
		r.pts=pts
		r.width=float(road.width)/scale_xz
		road_shapes.append(r)
	for lot:Dictionary in lots:
		var l:=lot.duplicate()
		l.pos=Vector3(lot.pos)/scale_xz
		l.extent=Vector2(lot.extent)/scale_xz
		l.frontage=Vector3(lot.frontage)/scale_xz
		lot_shapes.append(l)
	return {"roads":road_shapes,"lots":lot_shapes}

func render_district() -> void:
	film.size=Vector2i(3840,2160)
	film.world_3d=World3D.new()
	film.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(film)
	film.add_child(scene)
	add_environment()
	var topography = load("res://assets/surface07/terrain07.gd")
	hills=topography
	var street_system = load(OUT+"streets06.gd")
	var model_factory = load(BASE+"art/region_assets.gd")
	if topography == null or street_system == null or model_factory == null or not topography.can_instantiate() or not street_system.can_instantiate() or not model_factory.can_instantiate():
		print("PREVIEW_ERROR missing module")
		get_tree().quit(2)
		return
	var ground_at: Callable = Callable(self,"metric_h")
	var plan: Dictionary = street_system.plan()
	if not plan.has("lots") or plan.lots.size() != 19:
		push_error("Could not admit all 19 buildings to the scene")
		get_tree().quit(3)
		return
	var roads: Array = plan.roads
	var parcels: Array = plan.lots
	var vehicles: Array = plan.cars
	var models = model_factory.new()
	var topography_parent:=Node3D.new()
	scene.add_child(topography_parent)
	topography_parent.scale=Vector3(HORIZONTAL,S,HORIZONTAL)
	var normalized:=map_footprints(roads,parcels)
	topography.set_foundations(normalized.lots)
	street_system.build(scene,roads,parcels,ground_at)
	topography.build(topography_parent,normalized.roads,normalized.lots,scene.get_node("Streets"))
	var remote_band:=Node3D.new()
	topography_parent.add_child(remote_band)
	remote_band.position.y=-6.5
	load(REV+"ridge.gd").build(remote_band)
	load(BASE+"control/residents.gd").build(scene,roads,street_system,ground_at)
	bring_up_practicals()
	var building_kinds := {}
	for parcel: Dictionary in parcels:
		var p: Vector3 = parcel.pos
		p.y = float(ground_at.call(p.x,p.z))
		var size: Vector2 = parcel.extent
		var kind: String = parcel.kind
		var building:MeshInstance3D=models.building(scene,kind,p,float(parcel.model_width),rad_to_deg(float(parcel.yaw)))
		var bounds:=building.mesh.get_aabb()
		var floor_anchor:=building.to_global(Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z))
		building.scale.y/=1.3
		building.position+=floor_anchor-building.to_global(Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z))
		var metric_bounds:=bounds.size*building.scale
		measured.append({"kind":kind,"centre":str(p),"x":metric_bounds.x,"y":metric_bounds.y,"z":metric_bounds.z})
		load(REV+"assets_fix/crop_site.gd").apply(building,kind)
		if kind=="processor" and building!=null:
			add_working_vent(building)
		add_door_light(p,Vector3.FORWARD.rotated(Vector3.UP,float(parcel.yaw)),size.y,kind)
		building_kinds[kind] = 1+int(building_kinds.get(kind,0))
	var contact=load(BASE+"control/road_contact.gd").new()
	contact.setup(scene,ground_at)
	var vehicle_kinds := {}
	for car: Dictionary in vehicles:
		var p: Vector3 = car.pos
		p.y = float(ground_at.call(p.x,p.z))+0.145
		var kind: String = car.kind
		if kind=="car":kind="van"
		var real_length: float = car.get("length",VEHICLE_LENGTHS.get(kind,5.2))
		var aligned:Node3D=contact.align_to_road(scene,p,float(car.yaw),real_length)
		models.vehicle(aligned,kind,Vector3.ZERO,real_length,rad_to_deg(float(car.yaw)))
		add_vehicle_lights(p,float(car.yaw),real_length)
		vehicle_kinds[kind] = 1+int(vehicle_kinds.get(kind,0))
	print("ART_PLACED ",JSON.stringify(building_kinds)," vehicles ",JSON.stringify(vehicle_kinds)," roads ",roads.size())
	views = JSON.parse_string(FileAccess.get_file_as_string("res://views.json"))
	if views.size() != 3 or measured.size() != 19 or vehicles.size() != 5 or roads.size() != 4:
		push_error("Invalid reference layout or cameras")
		get_tree().quit(4)
		return
	if validate_only:
		print("REGION_REFERENCE_VALID 19 buildings, 5 vehicles, 4 roads, 3 cameras")
		get_tree().quit()
		return
	if capture_name.is_empty():
		var display := TextureRect.new()
		display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		display.texture = film.get_texture()
		add_child(display)
		ready_to_view = true
		apply_view(views[1])
		return
	for view: Dictionary in views:
		if not str(view.id).begins_with(capture_name + "-"):
			continue
		apply_view(view)
		for i in 14:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var pic := film.get_texture().get_image()
		var target := ProjectSettings.globalize_path(output_dir)
		var error := DirAccess.make_dir_recursive_absolute(target)
		if error == OK:
			var dest := target.path_join(str(view.id) + ".png")
			error = pic.save_png(dest)
			print("PREVIEW_FRAME ", dest, " ", pic.get_size(), " rc=", error)
		if error != OK:
			push_error("Could not create the reference capture: " + error_string(error))
			get_tree().quit(5)
			return
		get_tree().quit()
		return
