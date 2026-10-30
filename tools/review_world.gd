extends SceneTree
const Watchdog=preload("res://tests/support/watchdog.gd")
const Geo=preload("res://world/world_gen.gd")
func _initialize()->void:
	Watchdog.arm(self)
	var out:Dictionary={"seeds":[],"limitations":"headless data probes, not visual acceptance"}
	var gen=Geo.new()
	for seed_value in [20261029,0,1,42,777,2147483647]:
		var w:Dictionary=gen.generate(seed_value)
		var n:=FastNoiseLite.new()
		n.seed=seed_value
		n.frequency=1.8
		n.fractal_octaves=4
		var row:Dictionary={"seed":seed_value,"candidate_land":[],"coastal_view_water_samples":[],"river_heights":[],"route":{}}
		for r in w.regions:
			var sample:Dictionary=Geo.sample_geo(r.lat,r.lon,n)
			row.candidate_land.append({"id":r.id,"land":sample.land,"route_cell_land":w.grid[r.grid_index].land,"height":sample.height,"rainfall":sample.rainfall,"fixed_water":r.water,"fixed_fertility":r.fertility})
			var water_count:=0
			for x in range(31):
				for z in range(31):
					if not Geo.sample_geo(r.lat-(-23.5+z*47.0/30.0)/4.0,r.lon+(-28.5+x*57.0/30.0)/4.0,n).land: water_count+=1
			row.coastal_view_water_samples.append({"region":r.id,"water_count":water_count,"total":961})
		for ll in w.rivers[0]: row.river_heights.append(Geo.sample_geo(ll[0],ll[1],n).height*4300)
		for mountain in [false,true]:
			var r:Dictionary=gen.route(w,0,1,mountain)
			row.route[str(mountain)]={"reachable":r.reachable,"distance":r.distance,"cost":r.cost,"days":r.days,"cells":r.path.size()}
		var island:Dictionary=gen.route(w,0,4)
		row.island_reachable=island.reachable
		row.river_final_land=Geo.sample_geo(w.rivers[0][-1][0],w.rivers[0][-1][1],n).land
		out.seeds.append(row)
	var file:=FileAccess.open("D:/勇敢新世界/evidence/v17/tests/world_review_probe_"+Geo.VERSION+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(out,"\t"))
	print("WORLD_REVIEW_PROBE_DONE ",out.seeds.size())
	quit(0)
