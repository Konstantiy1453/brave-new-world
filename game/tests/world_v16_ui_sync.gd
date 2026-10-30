extends SceneTree
const Geo=preload("res://world/world_gen.gd")
const Map=preload("res://world/map_view.gd")
var failures:Array=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if not ok:failures.append(label)
func run():
	var map=Map.new();root.add_child(map);map.set_process(false)
	var world:Dictionary=Geo.new().generate(260129)
	map.setup(world)
	map.sync_state({"world":world,"day":10,"settlements":[{"region":0,"base_housing":0,"buildings":[{"kind":"power","remaining":0,"enabled":true,"active":true}]}],"route":{}})
	map.show_region(2)
	map.show_planet()
	var marker:Color=map.marker_root.get_child(2).get_child(0).material_override.albedo_color
	check(marker==Color("fff0b9"),"planet highlight follows region selection after cancel/return")
	map.show_region(0)
	while map.region_busy:await process_frame
	var old_root=map.buildings_root
	map.state.settlements[0].buildings[0].enabled=false
	map.sync_state(map.state)
	check(map.buildings_root!=old_root,"paused enabled change refreshes cached building view")
	var inactive:bool=false
	for mesh in map.buildings_root.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is StandardMaterial3D and mesh.material_override.albedo_color==Color("d18061"):inactive=true
	check(inactive,"disabled facility renders inactive accent before next simulation tick")
	var output:String="res://../evidence/v16/world_ui_sync_red.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"scope":"actual map marker material and cached building material/state assertions; includes in-flight cancellation"},"\t"))
	print("WORLD_UI_SYNC ",JSON.stringify(failures))
	map.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
