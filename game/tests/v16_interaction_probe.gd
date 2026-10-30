extends SceneTree
## Automated native main-scene performance probe. Never invoked by normal UI.
const Career=preload("res://simulation/career.gd")
var g:Node
var report:Dictionary={"scope":"actual main scene in graphical engine; existing buttons emit pressed/confirmed programmatically, not OS mouse latency; completion is a second presented frame after handler/region completion; full atlas refinement separately timed","samples":[],"checks":[],"failures":[]}
func check(ok:bool,label:String):
	report.checks.append({"label":label,"passed":ok})
	if not ok:report.failures.append(label)
func _initialize():call_deferred("run")
func button(text:String)->Button:
	for node in g.ui.find_children("*","Button",true,false):
		if node.text==text and not node.is_queued_for_deletion():return node
	return null
func measure(label:String,condition:String,action:Callable,wait_region:bool=false,wait_atlas:bool=false):
	var day:int=g.sim.state.day
	var started:int=Time.get_ticks_usec()
	action.call()
	var handler:float=(Time.get_ticks_usec()-started)/1000.0
	var immediately_busy:bool=g.map.region_busy
	await RenderingServer.frame_post_draw
	var first_frame:float=(Time.get_ticks_usec()-started)/1000.0
	var max_frame:float=0.0
	var previous:int=Time.get_ticks_usec()
	if wait_region:
		while g.map.region_busy:
			await process_frame
			var now:int=Time.get_ticks_usec()
			max_frame=maxf(max_frame,(now-previous)/1000.0)
			previous=now
	await process_frame
	await RenderingServer.frame_post_draw
	var completed:float=(Time.get_ticks_usec()-started)/1000.0
	var detail:float=completed
	if wait_atlas:
		var deadline:int=Time.get_ticks_msec()+45000
		while g.map.atlas_refining and Time.get_ticks_msec()<deadline:await process_frame
		await RenderingServer.frame_post_draw
		detail=(Time.get_ticks_usec()-started)/1000.0
		check(not g.map.atlas_refining,label+" atlas completed")
	var row:Dictionary={"operation":label,"condition":condition,"handler_ms":handler,"first_presented_frame_ms":first_frame,"completed_view_ms":completed,"full_detail_ms":detail,"immediate_region_busy":immediately_busy,"max_observed_region_frame_ms":max_frame,"region_cached":g.map.last_region_cached,"atlas_source":g.map.last_atlas_source,"atlas_cached":g.map.last_atlas_cached,"page":g.current_page,"mode":g.map.mode,"day_before":day,"day_after":g.sim.state.day}
	report.samples.append(row)
	print("UI_PERF ",JSON.stringify(row))
func await_atlas(label:String):
	var deadline:int=Time.get_ticks_msec()+45000
	while g.map.atlas_refining and Time.get_ticks_msec()<deadline:await process_frame
	check(not g.map.atlas_refining,label+" atlas bounded wait")

func idle():
	g.close_modal();g.paused=true
	await process_frame
	await RenderingServer.frame_post_draw
func run():
	DisplayServer.window_set_size(Vector2i(1920,1080))
	root.content_scale_factor=1.0
	var started:int=Time.get_ticks_usec()
	g=load("res://main.tscn").instantiate()
	root.add_child(g)
	report.startup_handler_ms=(Time.get_ticks_usec()-started)/1000.0
	report.user_data=OS.get_user_data_dir()
	check(OS.get_user_data_dir().contains("userdata_perf"),"private performance userdata active")
	g.paused=true
	await await_atlas("startup")
	await idle()
	var load_path:String="res://data/v16/acceptance_governor.json"
	report.fixture=load_path
	for i in range(3):
		await measure("load_success",["first_load_startup_seed_atlas_warm","warm_same_save","warm_same_save_repeat"][i],func():g.load_path(load_path),false,true)
		check(g.sim.state.status=="success","actual success fixture load "+str(i))
		check(g.map.selected_region==g.selected,"load selection synchronized "+str(i))
		await idle()
	# A pending event is explicit fixture content; it uses production event APIs.
	var events=load("res://simulation/events_v2.gd")
	check(g.sim.state.has("events_v2"),"loaded/new simulation integrates event state before UI")
	if g.sim.state.has("events_v2"):events._open(g.sim,"seed_crate",0)
	var pages:Dictionary={"economy":"经营账本","research":"科研教育","company":"公司关系","events":"通讯事件","career":"生涯代管"}
	for i in range(3):
		for page in pages:
			await idle()
			var frozen:PackedByteArray=var_to_bytes(g.sim.state)
			var target:Button=button(pages[page])
			check(target!=null,"navigation button exists "+page)
			if target==null:continue
			await measure("page_"+page,["first_open","warm_repeat","warm_repeat_2"][i],func():target.pressed.emit())
			check(g.current_page==page and is_instance_valid(g.modal_box),"visible page "+page+str(i))
			check(g.paused,"management page pauses "+page+str(i))
			check(var_to_bytes(g.sim.state)==frozen,"page is read-only "+page+str(i))
	await idle()
	for i in range(3):
		g.selected=i
		g.map.focus_region(i)
		var region_button:Button=button("地区建设")
		await measure("region_cold","new_region_"+str(i),func():region_button.pressed.emit(),true)
		await measure("region_repeat","cached_region_"+str(i),func():region_button.pressed.emit(),true)
		button("球面总览").pressed.emit()
		await process_frame
		await measure("region_return","cached_region_"+str(i),func():region_button.pressed.emit(),true)
		check(g.map.selected_region==g.selected,"region UI target agrees "+str(i))
	await idle()
	for i in range(3):
		g.load_path(load_path)
		await await_atlas("handover fixture")
		g.open_page("career")
		await process_frame
		var next_seed:LineEdit=null
		for edit in g.modal_box.find_children("*","LineEdit",true,false):next_seed=edit
		check(next_seed!=null,"handover seed field")
		if next_seed==null:continue
		next_seed.text="260130" if i<2 else "殖民契约"
		button("确认交接并前往下一颗星球").pressed.emit()
		await process_frame
		var confirmation:ConfirmationDialog=null
		for dialog in g.find_children("*","ConfirmationDialog",true,false):
			if dialog.visible:confirmation=dialog
		check(confirmation!=null,"handover confirmation available")
		if confirmation==null:continue
		await measure("handover_next_world",["cold_new_seed","warm_same_seed","cold_text_seed"][i],func():confirmation.confirmed.emit(),false,true)
		check(g.sim.state.career.active_id==2 and g.sim.state.day==0,"handover actually committed "+str(i))
		check(g.map.selected_region==0 and g.selected==0,"handover resets selection "+str(i))
		check(g.paused and g.current_page=="contract","handover opens new contract paused "+str(i))
	report.runtime_source_hashes={}
	for source_path in ["res://ui/main.gd","res://ui/pages.gd","res://ui/progression_pages.gd","res://ui/design.gd","res://simulation/sim.gd","res://simulation/career.gd","res://simulation/company.gd","res://simulation/research.gd","res://simulation/events_v2.gd","res://world/map_view.gd"]:
		var runtime_script:Script=load(source_path)
		report.runtime_source_hashes[source_path]=runtime_script.source_code.sha256_text()
	report.cpu=OS.get_processor_name()
	report.adapter=RenderingServer.get_video_adapter_name()
	report.engine=Engine.get_version_info()
	report.resolution=str(DisplayServer.window_get_size())
	report.ui_scale=root.content_scale_factor
	var report_path:String="res://../evidence/v16/ui_perf.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("UI_PERF_RESULT samples=",report.samples.size()," failures=",JSON.stringify(report.failures))
	g.queue_free();await process_frame
	quit(0 if report.failures.is_empty() else 1)
