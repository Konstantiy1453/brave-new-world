extends SceneTree
const Geo=preload("res://world/world_gen.gd")
const Sim=preload("res://simulation/sim.gd")
var failures:Array=[]
func _initialize():
	var legacy=Sim.new()
	var err:String=legacy.load_game("res://../evidence/v1_4/acceptance_midgame.json")
	if err!="":failures.append("legacy load: "+err)
	var noise=FastNoiseLite.new()
	noise.seed=260129
	noise.frequency=1.8
	noise.fractal_octaves=4
	var max_error:float=0
	if err=="":
		for i in range(legacy.state.world.grid.size()):
			var ll=Geo.cell_coordinate(i)
			var exact=Geo.sample_geo(ll.x,ll.y,noise,"CC-GEO-1.4")
			var stored:Dictionary=legacy.state.world.grid[i]
			for k in ["height","temperature","rainfall"]:max_error=maxf(max_error,absf(exact[k]-stored[k]))
			for k in ["land","river","lake"]:
				if exact[k]!=stored[k]:failures.append("legacy geography flag mismatch at "+str(i))
		if max_error>0.000000001:failures.append("legacy geography float drift")
	var canvas=Image.create(1440,360,false,Image.FORMAT_RGB8)
	var metrics:Array=[]
	for version_id in range(2):
		var version:String="CC-GEO-1.4" if version_id==0 else Geo.VERSION
		var mask:Array=[]
		var land_count:int=0
		for y in range(360):
			for x in range(720):
				var g=Geo.sample_geo(90.0-(y+.5)/2.0,(x+.5)/2.0-180,noise,version)
				mask.append(g.land)
				if g.land:land_count+=1
				var col=Color("193448") if not g.land else Color("618b65")
				if g.land and g.height>.35:col=Color("9a9784")
				if g.river:col=Color("54bfd1")
				canvas.set_pixel(x+version_id*720,y,col)
		var edges:int=0
		for y in range(359):
			for x in range(720):
				var i:int=y*720+x
				if mask[i]!=mask[y*720+(x+1)%720]:edges+=1
				if mask[i]!=mask[i+720]:edges+=1
		metrics.append({"version":version,"land_pixels":land_count,"coastal_edges_at_half_degree":edges})
	canvas.save_png("res://../evidence/coast_v14_left_v15_right.png")
	if metrics[1].coastal_edges_at_half_degree<metrics[0].coastal_edges_at_half_degree*1.15:failures.append("new coast lacks measurable outline complexity")
	var report={"scope":"geography data/silhouette probe, not game UI","legacy_load_error":err,"legacy_max_sample_error":max_error,"metrics":metrics,"failures":failures}
	FileAccess.open("res://../docs/evidence/coast_v15_review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(1 if not failures.is_empty() else 0)
