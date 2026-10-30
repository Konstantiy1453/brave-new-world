extends SceneTree
const Geo=preload("res://world/world_gen.gd")
var failures:Array=[]
func _initialize()->void:
	call_deferred("run")
func check(value:bool,message:String)->void:
	if not value: failures.append(message)
func run()->void:
	var gen:=Geo.new()
	var reports:Array=[]
	for seed_value in [260129,20261029,42,0,17,9981,-234]:
		var w:Dictionary=gen.generate(seed_value)
		check(JSON.stringify(w)==JSON.stringify(gen.generate(seed_value)),"determinism "+str(seed_value))
		var normal:Dictionary=gen.route(w,0,1,false)
		var mountain:Dictionary=gen.route(w,0,1,true)
		var isolated:Dictionary=gen.route(w,0,4,false)
		check(normal.reachable,"playable connected pair "+str(seed_value))
		check(not isolated.reachable,"island inaccessible "+str(seed_value))
		for cell in normal.path: check(w.grid[cell].land,"path crossed ocean "+str(seed_value))
		var safe:bool=true
		for r in w.regions: safe=safe and w.grid[r.grid_index].land
		check(safe,"candidate in land cell "+str(seed_value))
		var noise=FastNoiseLite.new()
		noise.seed=seed_value
		noise.frequency=1.8
		noise.fractal_octaves=4
		for river in w.rivers:
			var previous_height:float=INF
			for point in river:
				var river_sample:Dictionary=Geo.sample_geo(point[0],point[1],noise,w.version)
				check(river_sample.height<=previous_height+0.000001,"river climbs uphill "+str(seed_value))
				previous_height=river_sample.height
		reports.append({"seed":seed_value,"normal":normal,"mountain":mountain,"island_reachable":isolated.reachable,"generation":w.generation,"statistics":w.statistics,"regions":w.regions})
	var small:Dictionary=gen.route(gen.generate(20261029,0),0,1)
	var large:Dictionary=gen.route(gen.generate(20261029,2),0,1)
	check(large.distance>small.distance,"size changes real route distance")
	var output:Dictionary={"generator_version":Geo.VERSION,"engine":Engine.get_version_info(),"failures":failures,"cases":reports,"small_distance":small.distance,"large_distance":large.distance,"evidence_scope":"headless generation, determinism and routes; no rendered visual claim"}
	FileAccess.open("res://../docs/world_self_test.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("WORLD_SELF_TEST: ","PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(failures))
	print("Recommended route normal: ",reports[0].normal.distance," km / ",reports[0].normal.days," d / ",reports[0].normal.cost)
	print("Recommended route mountain: ",reports[0].mountain.distance," km / ",reports[0].mountain.days," d / ",reports[0].mountain.cost)
	quit(0 if failures.is_empty() else 1)
