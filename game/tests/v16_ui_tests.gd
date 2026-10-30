extends SceneTree
var failures:Array=[]
var count:int=0
func check(ok:bool,label:String):
	count+=1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func _initialize():call_deferred("run")
func run():
	var g=load("res://main.tscn").instantiate()
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g.close_modal()
	g.sim.act("settle",{"region":0})
	var day:int=g.sim.state.day
	g.open_page("economy")
	var key=InputEventKey.new()
	key.keycode=KEY_SPACE
	key.pressed=true
	g._unhandled_input(key)
	g.set_speed(4)
	g.advance_time(200)
	check(g.paused and g.sim.state.day==day,"F05 modal space and speed cannot advance")
	g.close_modal()
	check(g.paused,"closing management remains paused")
	g.set_speed(1)
	g.advance_time(20)
	var same=var_to_bytes(g.sim.state)
	g.sim.new_game(260129,"capital",1)
	g.sim.act("settle",{"region":0})
	g.set_speed(4)
	g.advance_time(5)
	check(var_to_bytes(g.sim.state)==same,"same simulation duration 1x versus fast exact state")
	var error:String=g.sim.load_game("res://data/v16/acceptance_pre_award.json")
	check(error=="","new formal-action pre-award load: "+error)
	if error!="":quit(1);return
	g.sim.state.status="active"
	g.sim.state.day=37
	g.sim.state.career.global_day=37
	g.sim.state.career.last_local_day=37
	g.sim.state.success_day=-1
	g.sim.state.events_v2.next_draw=9999
	g.sim.state.events_v2.instances=[]
	g.last_status="active"
	g.paused=false
	g.speed=4
	g.advance_time(50)
	print("F06_STATE ",g.sim.state.day," ",g.sim.state.status," ",g.sim.contract_progress()," paused ",g.paused," event ",g.event_pause_required())
	check(g.sim.state.day==38 and g.paused and g.accumulator==0,"F06 long frame stops exactly on governor award")
	g.close_modal()
	g.set_speed(1)
	g.advance_time(0.01)
	check(g.sim.state.day==38,"resume never replays discarded backlog")
	g.paused=true
	g.sim.new_game(260129,"capital",1)
	g.sim.act("settle",{"region":0})
	load("res://simulation/events_v2.gd")._open(g.sim,"seed_crate",0)
	g.close_modal();g.paused=false;g.advance_time(200)
	check(g.sim.state.day==0 and g.paused and g.accumulator==0,"required event blocks whole long frame before next day")
	g.close_modal()
	check(g.sim.load_game("res://data/v16/acceptance_crisis.json")=="","load actual crisis for company boundary fixture")
	g.sim.state.company.stage="warning";g.sim.state.company.stage_day=0;g.sim.state.company.distrust=39.9
	day=g.sim.state.day;g.last_status=g.sim.state.status;g.paused=false;g.advance_time(200)
	check(g.sim.state.company.stage=="review" and g.sim.state.day==day+1 and g.paused and g.accumulator==0,"company review interrupts on first affected day")
	g.close_modal();g.sim.state.company.stage="intervention";g.sim.state.company.deadline=g.sim.state.day+1
	day=g.sim.state.day;g.paused=false;g.advance_time(200)
	check(g.sim.state.status=="failed" and g.sim.state.day==day+1 and g.paused and g.accumulator==0,"takeover interrupts on exact failure day")
	g.sim.load_game("res://data/v16/acceptance_governor.json")
	g.paused=true
	for page in ["company","research","events","career","manage","economy","enterprise","contract","save"]:
		g.open_page(page)
		await process_frame
		check(is_instance_valid(g.modal_box),"page builds "+page)
	g.close_modal()
	g.sim.new_game("4294967297","capital",1)
	g.selected=0
	g.map.setup(g.sim.state.world)
	g.map.focus_region(0)
	check(g.map.selected_region==g.selected,"F09 new world selection agrees")
	print("UI_V16_RESULT checks=%d failures=%d %s"%[count,failures.size(),str(failures)])
	quit(0 if failures.is_empty() else 1)
