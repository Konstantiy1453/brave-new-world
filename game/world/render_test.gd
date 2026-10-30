extends SceneTree
const Geo=preload("res://world/world_gen.gd")
const Map=preload("res://world/map_view.gd")
func _initialize()->void:
	call_deferred("run")
func shot(name:String)->void:
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image()
	var error:int=image.save_png("res://../docs/evidence/"+name+".png")
	print("RENDER_FIXTURE ",name," ",error," ",image.get_size())
func run()->void:
	root.size=Vector2i(1600,900)
	var map:=Map.new()
	root.add_child(map)
	var gen:=Geo.new()
	var world:Dictionary=gen.generate(260129)
	map.setup(world)
	var buildings:Array=[]
	for kind in ["habitat","power","water","mine_ore","mine_copper","mine_crystal","farm","processor","lab","port","service"]:
		buildings.append({"kind":kind,"active":true,"remaining":0})
	map.sync_state({"settlements":[{"region":0,"base_housing":80,"buildings":buildings},{"region":1,"base_housing":40,"buildings":buildings}],"route":gen.route(world,0,1),"shipments":[],"enterprise":{"region":0}})
	await shot("world_planet_fixture")
	map.show_region(0)
	await shot("world_mining_fixture")
	map.show_region(1)
	await shot("world_valley_fixture")
	print("Rendered scene fixtures. Synthetic building states, NOT a gameplay test.")
	quit()
