extends SceneTree
const Watchdog=preload("res://tests/support/watchdog.gd")
## Supplemental source-render QA: every primary page button can be scrolled into view.
var g:Node
var report:Dictionary={"scope":"actual source main, 1280x720 at 20/18 scale; programmatic ScrollContainer navigation, no OS mouse claim","checks":[],"failures":[],"captures":[]}
func check(ok:bool,label:String,details:Dictionary={}):
	report.checks.append({"passed":ok,"label":label,"details":details})
	if not ok:report.failures.append(label)
func _initialize():
	Watchdog.arm(self)
	call_deferred("run")
func frame():
	await process_frame
	await RenderingServer.frame_post_draw
func atlas():
	var deadline:int=Time.get_ticks_msec()+45000
	while g.map.atlas_refining and Time.get_ticks_msec()<deadline:await process_frame
	check(not g.map.atlas_refining,"atlas completed")
func run():
	DisplayServer.window_set_size(Vector2i(1280,720))
	g=load("res://main.tscn").instantiate();root.add_child(g)
	g.paused=true
	root.content_scale_factor=20.0/18.0
	await atlas()
	check(OS.get_user_data_dir().contains("userdata_"),"private userdata")
	var fixtures:Dictionary={"research":"acceptance_governor","company":"acceptance_crisis","events":"acceptance_event_mid","career":"acceptance_second_dividend","save":"acceptance_governor"}
	var folder:String="res://../evidence/v17/tests/scroll_source"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for page in fixtures:
		g.load_path("res://data/v16/"+fixtures[page]+".json")
		await atlas()
		g.open_page(page)
		await frame()
		var frozen:PackedByteArray=var_to_bytes(g.sim.state)
		var scroll:ScrollContainer=g.modal_box.get_parent()
		for node in g.modal_box.find_children("*","Button",true,false):
			if not node.visible:continue
			scroll.ensure_control_visible(node)
			await frame()
			var viewport_rect:Rect2=scroll.get_global_rect().grow(2)
			var button_rect:Rect2=node.get_global_rect()
			check(viewport_rect.encloses(button_rect),page+" button reachable "+node.text,{"scroll_rect":str(viewport_rect),"button_rect":str(button_rect)})
		scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
		await frame()
		var name:String=page+"_1280x720_20px_bottom.png"
		root.get_texture().get_image().save_png(folder+"/"+name)
		report.captures.append(name)
		check(var_to_bytes(g.sim.state)==frozen,page+" scrolling does not change simulation")
	report.runtime_source_hashes={}
	for path in ["res://ui/main.gd","res://ui/pages.gd","res://ui/progression_pages.gd"]:
		var source:Script=load(path)
		report.runtime_source_hashes[path]=source.source_code.sha256_text()
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SCROLL_PROBE ",JSON.stringify(report))
	g.queue_free();await process_frame
	quit(0 if report.failures.is_empty() else 1)
