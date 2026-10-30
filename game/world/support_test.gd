extends SceneTree
const Geo=preload("res://world/world_gen.gd")
const Map=preload("res://world/map_view.gd")
var failures:Array=[]
func _initialize()->void: call_deferred("run")
func verify(value:bool,message:String)->void:
	if not value: failures.append(message)
func run()->void:
	var gen:=Geo.new()
	var map:=Map.new()
	root.add_child(map)
	var world:Dictionary=gen.generate(260129)
	map.setup(world)
	var state:Dictionary={"day":0,"settlements":[{"region":0,"base_housing":80,"buildings":[{"kind":"farm","active":false,"remaining":4}]}],"route":{},"shipments":[]}
	map.sync_state(state)
	map.show_region(0)
	verify(map.buildings_root.get_node("LandingLivingCapsules").get_meta("base_housing")==80,"base housing80 represented")
	var original:Node=map.buildings_root
	state.day=1
	state.settlements[0].buildings[0].remaining=3
	map.sync_state(state)
	verify(map.buildings_root==original,"countdown tick avoids colony rebuild")
	var old_pivot:Vector3=map.camera_pivot
	map.pan(100,30)
	verify(map.camera_pivot!=old_pivot,"region pan changes target")
	map.pan(100000,100000)
	verify(absf(map.camera_pivot.x)<=18 and absf(map.camera_pivot.z)<=15,"pan clamps terrain bounds")
	state.route=gen.route(world,0,1)
	map.sync_state(state)
	verify(map.buildings_root!=original,"route creation refreshes current region")
	state.settlements[0].base_housing=40
	map.sync_state(state)
	verify(map.buildings_root.get_node("LandingLivingCapsules").get_meta("base_housing")==40,"base housing40 represented")
	map.show_planet()
	var planet_pivot:Vector3=map.camera_pivot
	map.pan(100,50)
	verify(map.camera_pivot==planet_pivot,"planet ignores regional pan")
	print("WORLD_SUPPORT_TEST: ","PASS" if failures.is_empty() else "FAIL"," ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
