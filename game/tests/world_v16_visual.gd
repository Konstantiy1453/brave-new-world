extends SceneTree
const Geo=preload("res://world/world_gen.gd")
const Map=preload("res://world/map_view.gd")
class IsolatedMap extends Map:
	func _trim_disk_atlases(_current:String)->void:pass
var report:Dictionary={"scope":"source map rendered window; handler through frame_post_draw, programmatic navigation rather than OS input","samples":[],"failures":[]}
var status:Label
func _initialize():call_deferred("run")
func shot(name:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/v16/"+name+".png")
func enter(map,id:int,label:String):
	var start:int=Time.get_ticks_usec()
	map.show_region(id)
	var handler:float=(Time.get_ticks_usec()-start)/1000.0
	await RenderingServer.frame_post_draw
	var feedback:float=(Time.get_ticks_usec()-start)/1000.0
	var max_frame:float=0
	var previous:int=Time.get_ticks_usec()
	while map.region_busy:
		await process_frame
		var now:int=Time.get_ticks_usec()
		max_frame=maxf(max_frame,(now-previous)/1000.0)
		previous=now
	await RenderingServer.frame_post_draw
	report.samples.append({"operation":label,"handler_ms":handler,"first_frame_ms":feedback,"stable_frame_ms":(Time.get_ticks_usec()-start)/1000.0,"max_load_frame_ms":max_frame,"cached":map.last_region_cached})
func run():
	root.size=Vector2i(1280,720)
	var map=IsolatedMap.new()
	root.add_child(map)
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	status=Label.new();status.position=Vector2(24,18);status.add_theme_font_size_override("font_size",20);canvas.add_child(status)
	map.region_progress.connect(func(busy,progress):status.text="Region loading %d%% - navigation cancels"%roundi(progress*100) if busy else "Region ready - seed 2147483648 / effective -2147483648")
	var start:int=Time.get_ticks_usec()
	var w:Dictionary=Geo.new().generate("2147483648")
	report.generation_ms=(Time.get_ticks_usec()-start)/1000.0
	map.setup(w)
	map.pending_atlas.path=ProjectSettings.globalize_path("res://../evidence/v16/world_visual_atlas.png")
	map.sync_state({"world":w,"day":5,"settlements":[{"region":0,"base_housing":20,"buildings":[{"kind":"solar","active":true,"remaining":0},{"kind":"farm","active":false,"remaining":0}]}],"route":{}})
	report.setup_ms=map.last_setup_ms
	await enter(map,0,"region_0_cold_with_atlas_refining")
	await shot("world_region_0_1280")
	await enter(map,0,"region_0_repeat")
	map.show_planet()
	await enter(map,0,"region_0_return")
	await enter(map,1,"region_1_cold")
	await shot("world_region_1_1280")
	while map.atlas_refining:await process_frame
	if map.globe_shader.get_shader_parameter("atlas")!=map.flat_shader.get_shader_parameter("atlas"):report.failures.append("sphere flat texture differs")
	if map.geography_atlas.get_width()!=1536:report.failures.append("refined atlas unavailable")
	map.show_planet();status.text="Shared authoritative atlas, sphere - effective seed -2147483648"
	await shot("world_planet_1280")
	map.show_flat();status.text="Shared authoritative atlas, flat - effective seed -2147483648"
	await shot("world_flat_1280")
	report.refined_atlas_ms=map.last_refinement_ms
	report.renderer=RenderingServer.get_video_adapter_name()
	report.cpu=OS.get_processor_name()
	report.engine=Engine.get_version_info()
	FileAccess.open("res://../evidence/v16/world_visual.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WORLD_VISUAL ",JSON.stringify(report))
	map.queue_free();await process_frame
	quit(0 if report.failures.is_empty() else 1)
