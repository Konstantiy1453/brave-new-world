extends SceneTree
const Sim=preload("res://simulation/sim.gd")
var checks:Array=[]
func _initialize():
	var s=Sim.new()
	var error:String=s.load_game("res://data/acceptance_midgame.json")
	checks.append({"name":"current_midgame_load","pass":error=="","error":error})
	if error!="":finish();return
	var baseline:PackedByteArray=var_to_bytes(s.state)
	var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/acceptance_midgame.json"))
	var cases:Array=[
		["stock_container",["settlements",0,"stock"],5],
		["stock_value",["settlements",0,"stock","food"],[]],
		["stock_nan",["settlements",0,"stock","ore"],NAN],
		["building_container",["settlements",0,"buildings"],4],
		["building_entry",["settlements",0,"buildings",0],3],
		["cohort_entry",["settlements",0,"cohorts",0],8],
		["negative_workers",["settlements",0,"workers"],-1],
		["world_regions",["world","regions"],3],
		["world_grid_entry",["world","grid",0],false],
		["mineral_container",["world","regions",0,"deposits"],7],
		["shipment_resource",["shipments",0,"resource"],"invalid"],
		["shipment_amount",["shipments",0,"amount"],{}],
		["research_completed",["research","completed"],3],
		["route_coordinates",["route","coordinates"],[4]],
		["policy_value",["policy","tax"],"high"],
		["enterprise_employees",["enterprise","employees"],[]],
		["resource_account",["resource_sources"],6],
		["ledger_entry",["ledger",0],9]
	]
	for c in cases:
		var candidate:Dictionary=s.state.duplicate(true)
		var target:Variant=candidate
		for i in range(c[1].size()-1):target=target[c[1][i]]
		target[c[1][-1]]=c[2]
		var e:Dictionary=original.duplicate(true)
		e.binary=Marshalls.raw_to_base64(var_to_bytes(candidate))
		e.binary_checksum=e.binary.sha256_text()
		FileAccess.open("user://review_nested_matrix.json",FileAccess.WRITE).store_string(JSON.stringify(e))
		error=s.load_game("user://review_nested_matrix.json")
		checks.append({"name":c[0],"error":error,"pass":error!="" and baseline==var_to_bytes(s.state)})
	var legacy=Sim.new()
	error=legacy.load_game("res://../saves/ui_day50.json")
	checks.append({"name":"legacy_ui_day50_load","error":error,"pass":error==""})
	var event_sim=Sim.new()
	event_sim.load_game("res://data/acceptance_midgame.json")
	while event_sim.state.day<35:event_sim.tick()
	event_sim.save_game("user://review_event_save.json")
	var event_load=Sim.new()
	error=event_load.load_game("user://review_event_save.json")
	checks.append({"name":"pending_event_exact_load","error":error,"pass":error=="" and var_to_bytes(event_sim.state)==var_to_bytes(event_load.state)})
	finish()
func finish():
	var failures:int=0
	for c in checks:
		if not c.pass:failures+=1
	var report={"scope":"bounded malformed nested-state rejection; hashes are recomputed intentionally; not an exhaustive hostile-file audit","checks":checks,"failures":failures}
	FileAccess.open("res://../evidence/v16/save_nested_final.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(1 if failures else 0)
