extends SceneTree
const Watchdog=preload("res://tests/support/watchdog.gd")

var report:Dictionary={"scope":"synchronous handler wall time in headless engine; excludes display/input latency","samples":[]}
func measure(label:String, action:Callable):
	var start=Time.get_ticks_usec()
	action.call()
	var elapsed=(Time.get_ticks_usec()-start)/1000.0
	report.samples.append({"operation":label,"ms":elapsed})
	print("PERF ",label," ",elapsed," ms")

func _initialize():
	Watchdog.arm(self)
	call_deferred("run")

func run():
	var scene=load("res://main.tscn").instantiate()
	measure("startup",func():root.add_child(scene))
	scene.set_process(false)
	scene.map.set_process(false)
	scene.close_modal()
	measure("load_midgame",func():scene.load_path("res://data/acceptance_midgame.json"))
	for page in ["world","build","economy","research","transport","enterprise","contract","events","save"]:
		measure("page_"+page,func():scene.open_page(page))
		await process_frame
	scene.close_modal()
	scene.selected=0
	measure("region_0_cold",func():scene.navigate("region"))
	await process_frame
	measure("region_0_repeat",func():scene.navigate("region"))
	await process_frame
	measure("planet",func():scene.navigate("planet"))
	measure("region_0_return",func():scene.navigate("region"))
	await process_frame
	scene.selected=1
	measure("region_1_cold",func():scene.navigate("region"))
	await process_frame
	measure("flat",func():scene.navigate("flat"))
	measure("tick_map_refresh",func():scene.sim.tick();scene.map.sync_state(scene.sim.state);scene.refresh())
	var out="res://../evidence/v17/tests/perf_probe.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):out=arg.trim_prefix("--report=")
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit()
