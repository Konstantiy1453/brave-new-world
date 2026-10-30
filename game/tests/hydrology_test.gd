extends SceneTree
const Geo=preload("res://world/world_gen.gd")
const Hydro=preload("res://world/hydrology.gd")
var failures:Array=[]
func _initialize():call_deferred("run")
func check(value:bool,message:String):
	if not value:failures.append(message)
func run():
	var cases:Array=[]
	var signatures:Dictionary={}
	for seed_value in [260129,20261029,42,0,17,9981,-234]:
		var world:Dictionary=Geo.new().generate(seed_value)
		# Before generator integration this explicit call also tests the helper.
		if not world.has("hydrology"):Hydro.apply(world)
		var other:Dictionary=Geo.new().generate(seed_value)
		if not other.has("hydrology"):Hydro.apply(other)
		check(JSON.stringify(world)==JSON.stringify(other),"deterministic "+str(seed_value))
		check(world.rivers.size()>=4,"multiple river systems "+str(seed_value))
		check(world.hydrology.ocean_mouth_count>=1,"river mouth "+str(seed_value))
		var longest:int=0
		var tributaries:int=0
		for river_index in range(world.rivers.size()):
			var meta:Dictionary=world.river_metadata[river_index]
			var path:Array=meta.cell_path
			longest=maxi(longest,path.size())
			check(path.size()>=3,"nontrivial river "+str(seed_value))
			for j in range(1,path.size()):
				check(float(world.grid[path[j]].height)<float(world.grid[path[j-1]].height),"strict downhill "+str(seed_value))
				check(float(meta.heights[j])<=float(meta.heights[j-1]),"water level downhill "+str(seed_value))
			if meta.terminal=="ocean":check(not world.grid[path.back()].land,"actual sea endpoint "+str(seed_value))
			elif meta.terminal=="lake":check(world.grid[path.back()].lake,"actual lake endpoint "+str(seed_value))
			else:
				tributaries+=1
				check(int(meta.downstream_index)>=0 and int(meta.downstream_index)<river_index,"tributary linkage "+str(seed_value))
		var farm:Dictionary=world.regions[1]
		check(tributaries>=1,"at least one actual confluence "+str(seed_value))
		check(bool(farm.river),"farm on real river "+str(seed_value))
		check(Geo.new().route(world,0,1,false).reachable,"farm connected by land "+str(seed_value))
		var fingerprint:String=JSON.stringify(world.rivers).sha256_text()
		signatures[fingerprint]=true
		cases.append({"seed":seed_value,"river_count":world.rivers.size(),"lake_count":world.lakes.size(),"mouths":world.hydrology.ocean_mouth_count,"longest_cells":longest,"tributaries":tributaries,"farm_cell":farm.grid_index,"river_sha256":fingerprint})
	check(signatures.size()==7,"all fixed seeds produce different river networks")
	var report={"method":Hydro.METHOD,"failures":failures,"cases":cases,"scope":"actual Godot deterministic grid drainage; no fluid or visual quality claim"}
	FileAccess.open("res://../docs/evidence/hydrology_tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("HYDROLOGY_TEST: ","PASS" if failures.is_empty() else "FAIL"," ",JSON.stringify(failures))
	print(JSON.stringify(cases))
	quit(0 if failures.is_empty() else 1)
