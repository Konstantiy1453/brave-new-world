extends SceneTree
const Geo=preload("res://world/world_gen.gd")
const Map=preload("res://world/map_view.gd")
var failures:Array=[]
func check(value:bool,message:String):
	if not value:failures.append(message)
func _initialize():call_deferred("run")
func run():
	var rows:Array=[]
	var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../evidence/v16/world_seed_red.json"))
	var samples:Array=[-2147483648,2147483647,260129,0,-1,2147483648,4294967297,-2147483649,-9223372036854775807,9223372036854775807,"-9223372036854775808","18446744073709551616","1234567890123456789012345678901234567890","Hello World","abc123","殖民契约"]
	var map=Map.new()
	for input in samples:
		var w:Dictionary=Geo.new().generate(input)
		var n:=FastNoiseLite.new()
		n.seed=int(w.seed); n.frequency=1.8; n.fractal_octaves=4
		check(w.seed>=-2147483648 and w.seed<=2147483647,"seed range "+str(input))
		check(Geo.SeedGeo.normalize_seed(str(input))==w.seed,"integer and decimal text equivalence "+str(input))
		var mismatch:int=0
		for y in range(5,68,7):
			for x in range(3,140,11):
				var ll:=Geo.cell_coordinate(y*Geo.GW+x)
				var raw:Dictionary=Geo.SeedGeo.sample_with_context(ll.x,ll.y,n,Geo.SeedGeo.context(int(w.seed)))
				var grid:Dictionary=w.grid[y*Geo.GW+x]
				if raw.land!=grid.land or absf(raw.height-grid.height)>.000001:mismatch+=1
		var tile:Dictionary=map._render_atlas_tile(0,1,int(w.seed),w.version,Geo.GW,Geo.GH,Geo.SeedGeo.context(int(w.seed)))
		var atlas_mismatch:int=0
		for y in range(5,68,7):
			for x in range(3,140,11):
				var expected:float=clampf(.5+float(w.grid[y*Geo.GW+x].height)*.45,.01,.99)
				if absf(tile.image.get_pixel(x,y).a-expected)>1.01/255.0:atlas_mismatch+=1
		var regional_mismatch:int=0
		for reg in w.regions:
			var local:Dictionary=Geo.local_geo(w,int(reg.id),0,0,n)
			var global:Dictionary=Geo.sample_geo(reg.lat,reg.lon,n,w.version)
			if local.land!=global.land or absf(local.height-global.height)>.00001:regional_mismatch+=1
		var road:Dictionary=Geo.new().route(w,0,1,false)
		if not road.reachable:road=Geo.new().route(w,0,1,true)
		check(road.reachable,"mining farming land connection "+str(input))
		for index in road.path:check(w.grid[index].land,"road crosses sea "+str(input))
		var row:Dictionary={"input":str(input),"effective":w.seed,"grid_mismatch":mismatch,"atlas_mismatch":atlas_mismatch,"region_mismatch":regional_mismatch,"grid_hash":JSON.stringify(w.grid).sha256_text(),"regions_hash":JSON.stringify(w.regions).sha256_text(),"generation_hash":JSON.stringify(w.generation).sha256_text(),"route_reachable":road.reachable,"route_cells":road.path.size()}
		rows.append(row)
		check(mismatch==0 and atlas_mismatch==0 and regional_mismatch==0,"view geography consistency "+str(input))
		for baseline in old.cases.slice(0,3):
			if baseline.input==str(input):
				for key in ["grid_hash","regions_hash","generation_hash"]:check(row[key]==baseline[key],"signed32 original "+str(input)+" "+key)
		var legacy:Dictionary=w.duplicate(true)
		legacy.version="CC-GEO-1.5"
		check(Geo.world_compatibility_error(legacy).is_empty(),"signed32 legacy supported")
		legacy.seed=4294967297
		var frozen:String=JSON.stringify(legacy)
		check(not Geo.world_compatibility_error(legacy).is_empty(),"legacy overflow explicitly rejected")
		check(JSON.stringify(legacy)==frozen,"legacy compatibility check never regenerates")
	check(Geo.SeedGeo.normalize_seed("-9223372036854775808")==0,"int64 min normalized exactly")
	check(Geo.SeedGeo.normalize_seed("18446744073709551616")==0,"uint64 overflow normalized exactly")
	check(Geo.SeedGeo.normalize_seed("1234567890123456789012345678901234567890")==-834729262,"arbitrary precision decimal modulo")
	map.free()
	FileAccess.open("res://../evidence/v16/world_seed.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"16 seed cases,117 global/grid+atlas locations each,6 regional centers each,reachable land routes and frozen signed32 geography hashes","cases":rows,"failures":failures,"engine":Engine.get_version_info()},"\t"))
	print("WORLD_V16_SEED ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
