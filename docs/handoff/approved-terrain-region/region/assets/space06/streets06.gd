extends RefCounted

# Actual X/Z extents and longest horizontal width in metres: original model AABB divided by units_per_metre.
const DISTRICT_SCALE := 1.3
const CENTRAL_ROAD_FACTOR := 1.25
const OUTER_ROAD_FACTOR := 1.5
const METRES_05 := 2.4 * DISTRICT_SCALE * 1.4
const MAP_METRES := METRES_05 * CENTRAL_ROAD_FACTOR
const OUTER_MAP_METRES := METRES_05 * OUTER_ROAD_FACTOR
# In 04 height_at() really honours pad levelling out to these local coordinates.
# These bounds affect actual lot admission in this prototype. The surrounding terrain is scenic.
const BASELINE_FOUNDATION_HALF := Vector2(115.0,109.0) * (2.4 * DISTRICT_SCALE)
const FOUNDATION_HALF := BASELINE_FOUNDATION_HALF * 1.5
const POSITION_FILE := "res://assets/space06/positions06.json"
const MODEL_FOOTPRINT := {
	"commerce": Vector3(34.0034023,22.2522232,34.0034023),
	"depot": Vector3(40.6115622,36.0536084,40.6115622),
	"smelter": Vector3(32.1928741,31.0124065,32.1928741),
	"processor": Vector3(40.7442030,35.1165482,40.7442030),
	"power": Vector3(30.6855643,24.7333333,30.6855643),
	"lab": Vector3(34.4520675,21.0012630,34.4520675),
	"farm": Vector3(29.4029455,31.2181188,31.2181188),
	"water": Vector3(31.7381728,27.9655986,31.7381728),
	"habitat": Vector3(29.7747658,27.3175985,29.7747658),
	"school": Vector3(68.5760039,60.6087914,68.5760039),
	"crew_quarters": Vector3(62.0155039,46.0115039,62.0155039),
	"clinic": Vector3(33.9881102,26.3907597,33.9881102),
	"apartment": Vector3(53.9811066,43.1898920,53.9811066),
	"civic_center": Vector3(60.6060561,44.4344389,60.6060561)
}

## Local X is facade width and local -Z faces the street. The vehicle convention matches.
static func road_network() -> Array:
	return [
		_road("through", 8.6, [Vector2(-94, 0), Vector2(-66, 7), Vector2(-41, 11),
			Vector2(-22, 18), Vector2(-6, 24), Vector2(14, 25), Vector2(35, 28),
			Vector2(52, 24), Vector2(68, 14), Vector2(91, 6)]),
		_road("crescent", 6.2, [Vector2(-41, 11), Vector2(-33, 6), Vector2(-26, -3),
			Vector2(-27, -16), Vector2(-21, -27), Vector2(-8, -36), Vector2(6, -40)]),
		_road("works", 7.0, [Vector2(35, 28), Vector2(33, 18), Vector2(26, 10),
			Vector2(19, -4), Vector2(17, -19), Vector2(12, -32), Vector2(6, -40),
			Vector2(-1, -57)]),
		_road("loading", 6.8, [Vector2(17, -19), Vector2(26, -24), Vector2(38, -26),
			Vector2(51, -32), Vector2(63, -40)])
	]

static func plan() -> Dictionary:
	var roads:=road_network()
	# Metre-space lots fitted to the original 19 centers, with clear footprints and frontage access.
	var lots: Array = [
		{"kind":"commerce","street":"through","pos":Vector3(-10.4559,0.,32.9668),"yaw":2.860000000,"extent":Vector2(34.0034023,22.2522232),"model_width":34.0034023,"frontage":Vector3(-14.6866,0.,52.9295),"road_width":8.60},
		{"kind":"depot","street":"loading","pos":Vector3(95.9247,0.,-97.7869),"yaw":-2.820000000,"extent":Vector2(40.6115622,36.0536084),"model_width":40.6115622,"frontage":Vector3(107.9462,0.,-73.2687),"road_width":6.80},
		{"kind":"depot","street":"loading","pos":Vector3(140.3169,0.,-60.2218),"yaw":0.620000000,"extent":Vector2(40.6115622,36.0536084),"model_width":40.6115622,"frontage":Vector3(129.7861,0.,-76.9972),"road_width":6.80},
		{"kind":"smelter","street":"loading","pos":Vector3(135.6594,0.,-111.2803),"yaw":-2.550000000,"extent":Vector2(32.1928741,31.0124065),"model_width":32.1928741,"frontage":Vector3(145.8836,0.,-96.7264),"road_width":6.80},
		{"kind":"processor","street":"works","pos":Vector3(46.0408,0.,-98.6806),"yaw":2.112901720,"extent":Vector2(40.7442030,35.1165482),"model_width":40.7442030,"frontage":Vector3(28.3126,0.,-84.2827),"road_width":7.00},
		{"kind":"power","street":"works","pos":Vector3(21.8151,0.,-133.5363),"yaw":1.870000000,"extent":Vector2(30.6855643,24.7333333),"model_width":30.6855643,"frontage":Vector3(5.3592,0.,-127.1639),"road_width":7.00},
		{"kind":"lab","street":"works","pos":Vector3(26.9584,0.,-3.8758),"yaw":-1.412868530,"extent":Vector2(34.4520675,21.0012630),"model_width":34.4520675,"frontage":Vector3(42.0439,0.,-8.5080),"road_width":7.00},
		{"kind":"farm","street":"crescent","pos":Vector3(-15.8138,0.,-110.3294),"yaw":-2.860000000,"extent":Vector2(29.4029455,31.2181188),"model_width":31.2181188,"frontage":Vector3(-10.5187,0.,-93.2420),"road_width":6.20},
		{"kind":"farm","street":"crescent","pos":Vector3(-54.4766,0.,-93.2094),"yaw":-2.370000000,"extent":Vector2(29.4029455,31.2181188),"model_width":31.2181188,"frontage":Vector3(-42.0163,0.,-76.4436),"road_width":6.20},
		{"kind":"water","street":"through","pos":Vector3(-156.7292,0.,-7.1601),"yaw":2.850000000,"extent":Vector2(31.7381728,27.9655986),"model_width":31.7381728,"frontage":Vector3(-160.8312,0.,11.6608),"road_width":8.60},
		{"kind":"habitat","street":"crescent","pos":Vector3(-50.4609,0.,10.8664),"yaw":1.118258225,"extent":Vector2(29.7747658,27.3175985),"model_width":29.7747658,"frontage":Vector3(-63.2678,0.,2.2443),"road_width":6.20},
		{"kind":"school","street":"crescent","pos":Vector3(-11.8293,0.,-41.2019),"yaw":0.660000000,"extent":Vector2(68.5760039,60.6087914),"model_width":68.5760039,"frontage":Vector3(-34.1296,0.,-73.9070),"road_width":6.20},
		{"kind":"habitat","street":"crescent","pos":Vector3(-75.8369,0.,-62.7985),"yaw":-1.951837215,"extent":Vector2(29.7747658,27.3175985),"model_width":29.7747658,"frontage":Vector3(-62.0132,0.,-54.8645),"road_width":6.20},
		{"kind":"crew_quarters","street":"crescent","pos":Vector3(-109.4059,0.,-17.3020),"yaw":-1.621282397,"extent":Vector2(62.0155039,46.0115039),"model_width":62.0155039,"frontage":Vector3(-65.4302,0.,-8.8225),"road_width":6.20},
		{"kind":"clinic","street":"works","pos":Vector3(71.0201,0.,-5.8181),"yaw":1.960000000,"extent":Vector2(33.9881102,26.3907597),"model_width":33.9881102,"frontage":Vector3(54.3730,0.,2.1951),"road_width":7.00},
		{"kind":"apartment","street":"through","pos":Vector3(-122.5747,0.,53.8617),"yaw":-0.250000000,"extent":Vector2(53.9811066,43.1898920),"model_width":53.9811066,"frontage":Vector3(-118.8490,0.,27.2463),"road_width":8.60},
		{"kind":"habitat","street":"through","pos":Vector3(-77.3464,0.,58.5866),"yaw":-0.320000000,"extent":Vector2(29.7747658,27.3175985),"model_width":29.7747658,"frontage":Vector3(-70.0771,0.,41.0984),"road_width":8.60},
		{"kind":"habitat","street":"through","pos":Vector3(-42.4323,0.,73.1012),"yaw":-0.263044044,"extent":Vector2(29.7747658,27.3175985),"model_width":29.7747658,"frontage":Vector3(-35.0041,0.,55.6799),"road_width":8.60},
		{"kind":"civic_center","street":"through","pos":Vector3(111.6039,0.,24.0356),"yaw":-2.810000000,"extent":Vector2(60.6060561,44.4344389),"model_width":60.6060561,"frontage":Vector3(125.8232,0.,52.1405),"road_width":8.60}
	]
	var config:Variant=JSON.parse_string(FileAccess.get_file_as_string(POSITION_FILE))
	if config is not Dictionary or config.get("lots",[]).size()!=lots.size():
		push_error("06 requires 19 absolute metric lot centers in "+POSITION_FILE)
		return {}
	var approved_lots:Array=[]
	for i in lots.size():
		var lot:Dictionary=lots[i]
		var choice:Dictionary=config.lots[i]
		if choice.kind!=lot.kind:
			push_error("06 placement ID mismatch at "+str(i))
			return {}
		lot.pos=Vector3(float(choice.x),0.,float(choice.z))
		# Preserve 04's actual extents; the original anchor list was authored in 02.
		lot.extent=Vector2(lot.extent)*DISTRICT_SCALE
		lot.model_width=float(lot.model_width)*DISTRICT_SCALE
		var receipt:Dictionary=place_lot(lot,approved_lots,roads)
		if not receipt.ok:
			push_error("06 rejected "+lot.kind+" at "+str(lot.pos)+": "+str(receipt.reason))
			return {}
	var main: Dictionary = roads[0]
	var cars: Array = [
		_vehicle(main, .55, 1, "bus"), _vehicle(main, .69, -1, "truck"),
		_vehicle(main, .77, 1, "van"), _vehicle(main, .38, -1, "van"),
		_vehicle(roads[3], .61, 1, "truck")
	]
	return {"roads":roads,"lots":approved_lots,"cars":cars,"planning_half_extent_m":FOUNDATION_HALF}


# Position, dimensions and clearances are in final scene metres.
static func _corners(lot:Dictionary)->PackedVector2Array:
	var center:=Vector2(lot.pos.x,lot.pos.z)
	var radii:Vector2=Vector2(lot.extent)*.5
	var out:=PackedVector2Array()
	for signs:Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		out.append(center+(radii*signs).rotated(-float(lot.yaw)))
	return out

static func _separate(a:PackedVector2Array,b:PackedVector2Array)->bool:
	for ring:PackedVector2Array in [a,b]:
		for i in 2:
			var axis:Vector2=(ring[i+1]-ring[i]).orthogonal().normalized()
			var low_a:=INF;var low_b:=INF;var high_a:=-INF;var high_b:=-INF
			for p:Vector2 in a:
				low_a=minf(low_a,p.dot(axis));high_a=maxf(high_a,p.dot(axis))
			for p:Vector2 in b:
				low_b=minf(low_b,p.dot(axis));high_b=maxf(high_b,p.dot(axis))
			if high_a<=low_b or high_b<=low_a:return true
	return false

static func _road_gap(lot:Dictionary, corners:PackedVector2Array,road:Dictionary)->float:
	var pts:PackedVector3Array=road.pts
	var c:=Vector2(lot.pos.x,lot.pos.z)
	var half_diagonal:=Vector2(lot.extent).length()*.5
	var half_width:=float(road.width)*.5
	var minimum:=INF
	for segment in range(1,pts.size()):
		var a:=Vector2(pts[segment-1].x,pts[segment-1].z)
		var b:=Vector2(pts[segment].x,pts[segment].z)
		var near:=Geometry2D.get_closest_point_to_segment(c,a,b)
		if near.distance_to(c)>half_diagonal+half_width+1.:continue
		var local_a:Vector2=(a-c).rotated(lot.yaw)
		if absf(local_a.x)<=lot.extent.x*.5 and absf(local_a.y)<=lot.extent.y*.5:return -half_width
		for edge in 4:
			var u:=corners[edge];var v:=corners[(edge+1)%4]
			if Geometry2D.segment_intersects_segment(a,b,u,v)!=null:return -half_width
			var pair:=Geometry2D.get_closest_points_between_segments(a,b,u,v)
			minimum=minf(minimum,pair[0].distance_to(pair[1])-half_width)
	return minimum

static func _assigned_frontage(lot:Dictionary,road:Dictionary)->Vector3:
	var fwd:=Vector3.FORWARD.rotated(Vector3.UP,float(lot.yaw))
	var entrance:Vector3=lot.pos+fwd*(float(lot.extent.y)*.5)
	var best:=INF;var nearest:=Vector3.ZERO;var fallback:=Vector3.ZERO
	for j in range(1,road.pts.size()):
		var a:Vector3=road.pts[j-1];var b:Vector3=road.pts[j]
		var n:=Geometry3D.get_closest_point_to_segment(entrance,a,b)
		var d:=n.distance_squared_to(entrance)
		if d<best:
			best=d;nearest=n;fallback=Vector3(lot.pos)-n
	var toward:=entrance-nearest if best>.00001 else fallback
	return nearest+toward.normalized()*(float(road.width)*.5+.22)

## Used for the 19 rendered buildings and any additional candidate provided to the local street planner.
## A candidate's entire oriented footprint must sit on gradable land and clear roads and current lots.
static func place_lot(lot:Dictionary,placed:Array,roads:Array)->Dictionary:
	if not lot.has("pos") or not lot.has("extent") or not lot.has("yaw") or not lot.has("street"):return {"ok":false,"reason":"invalid_lot"}
	var radii:Vector2=lot.extent
	if not lot.pos.is_finite() or not radii.is_finite() or not is_finite(float(lot.yaw)) or minf(radii.x,radii.y)<=0.:return {"ok":false,"reason":"invalid_lot"}
	var corners:=_corners(lot)
	for p:Vector2 in corners:
		if absf(p.x)>FOUNDATION_HALF.x or absf(p.y)>FOUNDATION_HALF.y:return {"ok":false,"reason":"outside_graded_site"}
	for prior:Dictionary in placed:
		if not _separate(corners,_corners(prior)):return {"ok":false,"reason":"overlapping_lot"}
	var assigned:Dictionary={}
	for road:Dictionary in roads:
		if road.id==lot.street:assigned=road
		if _road_gap(lot,corners,road)<-.001:return {"ok":false,"reason":"overlapping_road"}
	if assigned.is_empty():return {"ok":false,"reason":"missing_street"}
	var item:=lot.duplicate()
	item.frontage=_assigned_frontage(lot,assigned)
	item.road_width=assigned.width
	placed.append(item)
	return {"ok":true,"lot":item}


static func road_scale_from05(id:String, p05:Vector2) -> float:
	var author:=p05/METRES_05
	var ramp:=0.
	match id:
		"through":ramp=maxf(smoothstep(51.,66.,author.x),smoothstep(53.,75.,-author.x))
		"works":ramp=smoothstep(40.,44.,-author.y)
		"loading":ramp=smoothstep(53.,63.,author.x)
	return lerpf(CENTRAL_ROAD_FACTOR,OUTER_ROAD_FACTOR,ramp)

static func _road_point(id:String, p:Vector2)->Vector3:
	if id=="paving":return Vector3(p.x,0.,p.y)
	var in05:=p*1.4
	return Vector3(in05.x,0.,in05.y)*road_scale_from05(id,in05)

static func _road(id: String, width: float, controls: Array) -> Dictionary:
	if id != "paving":
		controls = controls.map(func(p: Vector2) -> Vector2: return p * (2.4 * DISTRICT_SCALE))
	var pts := PackedVector3Array()
	var lengths := PackedFloat32Array()
	var distance := 0.0
	for i in range(controls.size() - 1):
		var a: Vector2 = controls[i]
		var b: Vector2 = controls[i + 1]
		var previous: Vector2 = controls[maxi(i - 1, 0)]
		var following: Vector2 = controls[mini(i + 2, controls.size() - 1)]
		var sample_spacing := 1.2 if id == "paving" else 1.2 * DISTRICT_SCALE
		var pieces := ceili(a.distance_to(b) / sample_spacing)
		for j in range(pieces):
			var p := a.cubic_interpolate(b, previous, following, float(j) / pieces)
			var ground := _road_point(id,p)
			if not pts.is_empty():
				distance += pts[-1].distance_to(ground)
			pts.append(ground)
			lengths.append(distance)
	var last: Vector2 = controls[-1]
	var end := _road_point(id,last)
	distance += pts[-1].distance_to(end)
	pts.append(end)
	lengths.append(distance)
	return {"id": id, "width": width, "pts": pts, "lengths": lengths, "length": distance}


static func _frame(road: Dictionary, t: float) -> Dictionary:
	var lengths: PackedFloat32Array = road.lengths
	var pts: PackedVector3Array = road.pts
	var distance := clampf(t, 0.0, 1.0) * float(road.length)
	var i := clampi(lengths.bsearch(distance), 1, pts.size() - 1)
	var f := (distance - lengths[i - 1]) / (lengths[i] - lengths[i - 1])
	var dir := (pts[i] - pts[i - 1]).normalized()
	return {"p": pts[i - 1].lerp(pts[i], f), "dir": dir, "side": Vector3(-dir.z, 0, dir.x)}


static func _yaw(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


static func _vehicle(road: Dictionary, t: float, flow: int, kind: String) -> Dictionary:
	var f := _frame(road, t)
	var lane_offset := float(road.width) * (.16 if road.id == "loading" else .24)
	return {"kind": kind, "pos": f.p + f.side * flow * lane_offset,
		"yaw": _yaw(f.dir * flow), "road": road.id}


static func build(parent: Node3D, roads: Array, lots: Array, h: Callable) -> void:
	var root := Node3D.new()
	root.name = "Streets"
	parent.add_child(root)
	var buffers := {}
	var palette := {
		"asphalt": _finish(Color("#777572"), .34, true), "gutter": _finish(Color("#837f72"), .20),
		"walk": _finish(Color("#928a76"), .26), "edge": _finish(Color("#a09883"), .20),
		"paint": _finish(Color("#b6ab81"), .07), "white": _finish(Color("#c3c2ac"), .08),
		"gravel": _finish(Color("#a39983"), .32), "yard": _finish(Color("#a39b89"), .26),
		"sand": _finish(Color("#998b70"), .36), "joints": _finish(Color("#746e60"), .18),
		"dirt": _finish(Color("#655d49"), .49)
	}
	for key: String in palette:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(palette[key])
		buffers[key] = st
	var asphalt: SurfaceTool = buffers.asphalt
	for road: Dictionary in roads:
		var points: PackedVector3Array = road.pts
		var lengths: PackedFloat32Array = road.lengths
		var half := float(road.width) * .5
		var prev_side := Vector3.ZERO
		var countryside_started := false
		for i in range(points.size() - 1):
			var a := points[i]
			var b := points[i + 1]
			var heading := (b - a).normalized()
			if i == 0:
				prev_side = Vector3(-heading.z, 0, heading.x)
			var ahead := (points[mini(i + 2, points.size() - 1)] - a).normalized()
			var side := Vector3(-ahead.z, 0, ahead.x)
			var mid := a.lerp(b, .5)
			var outside: bool = (road.id == "through" and (mid.x < -75.*OUTER_MAP_METRES or mid.x > 66.*OUTER_MAP_METRES)) or (road.id == "works" and mid.z < -44.*OUTER_MAP_METRES)
			if outside:
				if road.id == "through" and mid.x < -75.*OUTER_MAP_METRES:
					if b.x >= -75.*OUTER_MAP_METRES or (i+2<points.size() and b.lerp(points[i+2],.5).x>=-75.*OUTER_MAP_METRES):
						_farm_track(buffers,b,-heading,half,h)
				elif not countryside_started:
					_farm_track(buffers,a,heading,half,h)
					countryside_started = true
				prev_side = side
				continue
			_strip(asphalt, a, b, prev_side, side, -half, half, h, .115)
			var junction := _junction(mid, road, roads)
			for signum in [-1., 1.]:
				var sign_f := float(signum)
				var rim := mid + side * ((half + .60) * sign_f)
				if _junction(rim, road, roads):
					continue
				var fraction := lengths[i] / float(road.length)
				var sidewalk := _sidewalk(str(road.id), fraction, sign_f)
				if sidewalk > 0.:
					_strip(buffers.walk, a, b, prev_side, side, half * sign_f, (half + sidewalk) * sign_f, h, .145)
					_strip(buffers.edge, a, b, prev_side, side, half * sign_f, (half + .18) * sign_f, h, .171)
					if floori(lengths[i] / 2.9) != floori(lengths[i+1] / 2.9):
						_strip(buffers.joints, mid, mid+heading*.04, side, side, (half+.2)*sign_f, (half+sidewalk)*sign_f,h,.151)
				else:
					_strip(buffers.gravel, a, b, prev_side, side, (half - .03) * sign_f, (half + .46) * sign_f, h, .080)
				_strip(buffers.gutter, a, b, prev_side, side, (half - .19) * sign_f, (half - .015) * sign_f, h, .126)
			if road.id == "through" and not junction:
				var distance := (lengths[i] + lengths[i+1]) * .5
				if fmod(distance, 8.8) < 3.25 and absf(distance - float(road.length) * .48) > 3.0:
					_strip(buffers.paint, a, b, prev_side, side, -.072, .072, h, .137)
				if lengths[i] / float(road.length) < .16 or lengths[i] / float(road.length) > .80:
					for side_sign in [-1., 1.]:
						var edge_offset := (half - .45) * float(side_sign)
						_strip(buffers.white, a, b, prev_side, side, edge_offset-.055, edge_offset+.055, h, .136)
			prev_side = side
	# The crossing links the shop frontage to its bus stop.
	var crossing := _frame(roads[0], .48)
	for i in range(-4, 5):
		var middle: Vector3 = crossing.p + crossing.side * i * .83
		_strip(buffers.white, middle-crossing.dir*1.18, middle+crossing.dir*1.18,
			crossing.side, crossing.side, -.205, .205, h, .151)
	for lot: Dictionary in lots:
		_frontage_paths(buffers,lot,roads,h)
	_district_paths(buffers,h)
	for key: String in buffers:
		var st: SurfaceTool = buffers[key]
		var mesh := st.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var m := MeshInstance3D.new()
		m.name = key.capitalize()
		m.mesh = mesh
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)
	_street_furniture(root, roads, h)
	_yard_furniture(root, lots, h)


static func _frontage_paths(buffers:Dictionary, lot:Dictionary, roads:Array, h:Callable) -> void:
	var front_axis := Vector3.FORWARD.rotated(Vector3.UP, float(lot.yaw))
	var doorstep: Vector3 = lot.pos + front_axis * (float(lot.extent.y) * .22)
	var street: Vector3 = lot.frontage
	var curb: Vector3 = _curb_connection(lot, roads)
	var dir := (street - doorstep).normalized()
	var perp := Vector3(-dir.z, 0, dir.x)
	var industrial: bool = lot.kind in ["depot", "repair", "smelter", "processor", "power", "water", "farm"]
	var pathway := 2.05 if industrial else .94
	if lot.kind == "commerce":
		pathway = 1.65
	var shoulder_centre := doorstep.lerp(street,.43)+perp*(.42 if industrial else -.7)
	_trail(buffers.yard if industrial else buffers.walk, [doorstep,shoulder_centre,street,curb] if street.distance_to(curb) > .10 else [doorstep,shoulder_centre,street],
		pathway*2.,h,.188)
	if lot.kind in ["commerce","school","clinic","depot","farm","civic_center","processor"]:
		var local_w := minf(float(lot.extent.x)*.56,5.4)
		var center := doorstep.lerp(street,.41)
		_fan(buffers.yard if industrial else buffers.walk,center,perp,dir,
			[Vector2(-local_w,-1.45),Vector2(-.58*local_w,-2.1),Vector2(local_w*.64,-1.75),
			Vector2(local_w,-.45),Vector2(local_w*.77,1.45),Vector2(-local_w*.50,1.84),Vector2(-local_w,1.05)],h,.177)


## Finish a building walkway at the actual-width kerb after the centred plan was enlarged.
## The frontage remains an unmodified scene anchor, including on roads without a paved sidewalk.
static func _curb_connection(lot: Dictionary, roads: Array) -> Vector3:
	var anchor: Vector3 = lot.frontage
	for road: Dictionary in roads:
		if road.id != lot.street:
			continue
		var line: PackedVector3Array = road.pts
		var nearest: Vector3 = line[0]
		var best := INF
		for i in range(1, line.size()):
			var p := Geometry3D.get_closest_point_to_segment(anchor, line[i-1], line[i])
			var d := anchor.distance_squared_to(p)
			if d < best:
				best = d
				nearest = p
		var normal := anchor - nearest
		if normal.length_squared() < .001:
			normal = Vector3(lot.pos) - nearest
		# The roads generate their narrow curb and gravel strips at this physical offset.
		return nearest + normal.normalized() * (float(road.width) * .5 + .22)
	return anchor


static func _sidewalk(id: String, t: float, side: float) -> float:
	match id:
		"through":
			if side < 0 and ((t > .26 and t < .58) or (t > .67 and t < .74)):
				return 1.4
			if side > 0 and t > .22 and t < .58:
				return 1.20
		"crescent":
			if t > .09 and t < .77:
				return 1.05 if side > 0.0 else .85
		"works":
			if side > 0. and t > .19 and t < .39:
				return 1.00
	return 0.


static func _junction(p: Vector3, road: Dictionary, roads: Array) -> bool:
	for other: Dictionary in roads:
		if other.id == road.id:
			continue
		var limit := float(other.width) * .5 + .64
		var samples: PackedVector3Array = other.pts
		for point: Vector3 in samples:
			if point.distance_squared_to(p) <= limit * limit:
				return true
	return false


static func _surface(p: Vector3, h: Callable, lift: float) -> Vector3:
	return Vector3(p.x, float(h.call(p.x, p.z)) + lift, p.z)


static func _trail(st: SurfaceTool, points: Array, width: float, h: Callable, lift: float,
		end_width: float = -1.) -> void:
	var controls := []
	for p in points:
		controls.append(Vector2(p.x,p.z) if p is Vector3 else p)
	var curve := _road("paving", width, controls)
	var path: PackedVector3Array = curve.pts
	var end := end_width if end_width > 0.0 else width
	for i in range(path.size()-1):
		var prev := path[maxi(0,i-1)]
		var after := path[mini(i+2,path.size()-1)]
		var a := path[i]
		var b := path[i+1]
		var normal_l := (b-prev).normalized()
		var normal_r := (after-a).normalized()
		var w := lerpf(width,end,float(i)/float(path.size()-1))
		_strip(st,a,b,Vector3(-normal_l.z,0,normal_l.x),Vector3(-normal_r.z,0,normal_r.x),
			-.5*w,.5*w,h,lift)


static func _fan(st: SurfaceTool, center: Vector3, right: Vector3, forward: Vector3, polygon: Array,
		h: Callable, lift: float) -> void:
	for i in range(polygon.size()):
		var va: Vector2 = polygon[i]
		var vb: Vector2 = polygon[(i+1)%polygon.size()]
		var a := center+right*va.x+forward*va.y
		var b := center+right*vb.x+forward*vb.y
		# The mesh uses clockwise front faces.
		var vs := [center,b,a] if (a-center).cross(b-center).y > 0. else [center,a,b]
		for p: Vector3 in vs:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2.ZERO)
			st.add_vertex(_surface(p,h,lift))


static func _district_paths(buffers: Dictionary, h: Callable) -> void:
	_trail(buffers.sand,[Vector2(-26,4)*MAP_METRES,Vector2(-21,5)*MAP_METRES,Vector2(-17.3,7.7)*MAP_METRES,Vector2(-12.1,9.7)*MAP_METRES,Vector2(-8.5,9)*MAP_METRES,Vector2(-6.2,8.6)*MAP_METRES],2.0,h,.12)
	_trail(buffers.sand,[Vector2(-8.5,9)*MAP_METRES,Vector2(-6.5,6)*MAP_METRES,Vector2(-5.2,2.3)*MAP_METRES,Vector2(-2,0)*MAP_METRES,Vector2(1,-3)*MAP_METRES,Vector2(2.8,-8.5)*MAP_METRES],1.45,h,.12)
	_trail(buffers.sand,[Vector2(-21,5)*MAP_METRES,Vector2(-20,1)*MAP_METRES,Vector2(-20.6,-4.8)*MAP_METRES,Vector2(-19.8,-10)*MAP_METRES,Vector2(-17.3,-15.3)*MAP_METRES],1.35,h,.12)
	_trail(buffers.yard,[Vector2(63,-40)*OUTER_MAP_METRES,Vector2(66,-43)*OUTER_MAP_METRES,Vector2(67,-47)*OUTER_MAP_METRES,Vector2(64,-50)*OUTER_MAP_METRES],5.40,h,.12,3.3)
	_fan(buffers.yard,Vector3(64,0,-48)*OUTER_MAP_METRES,Vector3.RIGHT,Vector3.BACK,
		[Vector2(-4,-1),Vector2(-2,-4),Vector2(2,-3.5),Vector2(4,.5),Vector2(2,3),Vector2(-1,3.3)],h,.16)


static func _farm_track(buffers: Dictionary, start: Vector3, heading: Vector3, half: float, h: Callable) -> void:
	# End the all-weather surface within the inhabited terrace. The last trace is a
	# pair of wheel ruts in native soil, contour-following and capped at 25 metres.
	var prev := start
	var forward := heading
	var side := Vector3(-heading.z,0,heading.x)
	var start_y := float(h.call(start.x,start.z))
	var controls: Array[Vector3] = [prev]
	for i in range(15):
		var best_cost := INF
		var pick := forward
		var here_y := float(h.call(prev.x,prev.z))
		for deg: float in [-32.,-18.,-8.,0.,8.,18.,32.]:
			var dir := forward.rotated(Vector3.UP,deg_to_rad(deg))
			var p := prev + dir*1.65
			var high := float(h.call(p.x,p.z))
			var slope := absf(high-here_y)/1.65
			var cost := slope*4.5 + absf(high-start_y)*.40 + absf(deg)/300. + (1.-dir.dot(heading))*.18
			if dir.dot(heading)>.04 and cost<best_cost:
				best_cost=cost
				pick=dir
		forward = forward.lerp(pick,.84).normalized()
		var next := prev + forward*1.65
		var height := float(h.call(next.x,next.z))
		if absf(height-start_y)>1.1 or absf(height-here_y)>.32:
			break
		controls.append(next)
		prev=next
	if controls.size()<2:
		return
	for i in range(controls.size()-1):
		var a: Vector3 = controls[i]
		var b: Vector3 = controls[i+1]
		var next_dir := (controls[mini(i+2,controls.size()-1)]-a).normalized()
		var next_side := Vector3(-next_dir.z,0,next_dir.x)
		var t := float(i)/maxf(controls.size()-2,1.)
		var u := minf(float(i+1)/maxf(controls.size()-2,1.),1.)
		if t < .5:
			var wa := maxf(.06, half*(1.-smoothstep(0.,.52,t)))
			var wb := maxf(.05, half*(1.-smoothstep(0.,.52,u)))
			_strip(buffers.dirt,a,b,side,next_side*wb/wa,-wa,wa,h,.065)
		for signum: float in [-1.,1.]:
			var ga := lerpf(1.04,.77,t)*signum
			var gb := lerpf(1.04,.77,u)*signum
			var wt := lerpf(.25,.035,t*t)
			_strip(buffers.dirt,a+side*ga,b+next_side*gb,side,next_side,-wt,wt,h,.082-.058*t)
		side=next_side


static func _strip(st: SurfaceTool, a: Vector3, b: Vector3, axis_a: Vector3, axis_b: Vector3,
		left: float, right: float, h: Callable, lift: float) -> void:
	var lo := minf(left, right)
	var hi := maxf(left, right)
	var al := _surface(a + axis_a * lo, h, lift)
	var ar := _surface(a + axis_a * hi, h, lift)
	var bl := _surface(b + axis_b * lo, h, lift)
	var br := _surface(b + axis_b * hi, h, lift)
	var points := [al, bl, ar, ar, bl, br]
	var lateral := [lo,lo,hi,hi,lo,hi]
	for i in range(6):
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(lateral[i],.5*(hi-lo)))
		st.add_vertex(points[i])


static func _finish(colour: Color, grain: float, has_lanes: bool = false) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
		shader_type spatial;
		render_mode cull_disabled;
		uniform vec4 tint : source_color;
		uniform float grain = 0.11;
		uniform bool road = false;
		varying vec2 at;
		float hash(vec2 p) { vec3 q=fract(vec3(p.xyx)*0.1031); q+=dot(q,q.yzx+33.33); return fract((q.x+q.y)*q.z); }
		float value_noise(vec2 p) { vec2 a=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
			return mix(mix(hash(a),hash(a+vec2(1,0)),f.x),mix(hash(a+vec2(0,1)),hash(a+vec2(1,1)),f.x),f.y); }
		void vertex(){at=VERTEX.xz;}
		void fragment(){
			float coarse=value_noise(at*.38)-.5;
			float fine=(value_noise(at*11.)-.5)*(1.0-smoothstep(.05,.30,max(fwidth(at.x),fwidth(at.y))));
			float middle=value_noise(at*2.1)-.5;
			float variation=1.0+grain*(coarse*1.26+middle*.72+fine*.9);
			if (road) {
				float offset=value_noise(at*.17)*.22-.11;
				float wheel=abs(abs(abs(UV.x)+offset-.51*UV.y)-.79);
				float rubbed=(1.-smoothstep(.06,.43,wheel))*(.48+value_noise(at*.21)*.5);
				float shoulder=smoothstep(.65,.99,abs(UV.x)/max(UV.y,1.));
				variation+=.42*shoulder-.23*rubbed+.18*(value_noise(floor(at*.27))-.5);
			}
			ALBEDO=tint.rgb*variation;
			ROUGHNESS=.93; SPECULAR=.23;
		}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", colour)
	mat.set_shader_parameter("grain", grain)
	mat.set_shader_parameter("road",has_lanes)
	return mat


static func _solid(colour: Color, glow: float = 0.) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = .81
	if glow > 0.:
		mat.emission_enabled = true
		mat.emission = colour
		mat.emission_energy_multiplier = glow
	return mat


static func _box(parent: Node3D, at: Vector3, size: Vector3, yaw: float, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.position = at
	instance.rotation.y = yaw
	parent.add_child(instance)
	return instance


static func _street_furniture(parent: Node3D, roads: Array, h: Callable) -> void:
	var metal := _solid(Color("#565951"))
	var panel := _solid(Color("#787a6d"))
	var light := _solid(Color("#ffdea2"), 2.0)
	var shelter_lens := _solid(Color("#eed5ac"), .55)
	for spec in [[0,.26,1],[0,.40,-1],[0,.51,1],[0,.59,-1],[0,.75,1],[1,.33,1],[1,.62,-1],[2,.41,1],[3,.77,1]]:
		var road: Dictionary = roads[spec[0]]
		var f := _frame(road, float(spec[1]))
		var toward: Vector3 = -f.side * float(spec[2])
		var p := _surface(f.p - toward * (.5 * float(road.width) + .68), h, .14)
		var yaw := _yaw(toward)
		_box(parent, p + Vector3.UP * 1.75, Vector3(.095,3.5,.095), yaw, metal)
		_box(parent, p + toward*.35 + Vector3.UP*3.50, Vector3(.09,.075,.77), yaw, metal)
		_box(parent, p + toward*.70 + Vector3.UP*3.43, Vector3(.30,.15,.62), yaw, metal)
		var lens := _box(parent, p+toward*.70+Vector3.UP*3.345, Vector3(.262,.032,.54), yaw, light)
		lens.add_to_group("district_street_lenses")
	var stop: Dictionary = _frame(roads[0], .505)
	var base := _surface(stop.p + stop.side * (float(roads[0].width) * .5 + 2.15), h, .07)
	var axis: Vector3 = stop.dir
	var side: Vector3 = stop.side
	var yaw := _yaw(-side)
	for dx in [-1.55, 1.55]:
		_box(parent, base+axis*dx+side*.47+Vector3.UP*1.18, Vector3(.082,2.36,.082), yaw, metal)
	_box(parent, base+Vector3.UP*2.38, Vector3(3.9,.16,1.6), yaw, panel)
	_box(parent, base+Vector3.UP*.47+side*.23, Vector3(2.66,.12,.42), yaw, metal)
	_box(parent, base+Vector3.UP*2.28-side*.46, Vector3(1.84,.025,.08), yaw, shelter_lens)
	var pole := base+axis*2.6-side*.35
	_box(parent, pole+Vector3.UP*1.0, Vector3(.065,2.,.065), yaw, metal)
	_box(parent, pole+Vector3.UP*1.83, Vector3(.40,.39,.075), yaw, panel)


static func _yard_furniture(parent: Node3D, lots: Array, h: Callable) -> void:
	var steel := _solid(Color("#505f61"))
	var wood := _solid(Color("#a78c66"))
	var crate := _solid(Color("#a09b85"))
	var indigo := _solid(Color("#788892"))
	var marking := _solid(Color("#dcba75"))
	for lot: Dictionary in lots:
		var pos: Vector3 = lot.pos
		var yaw: float = lot.yaw
		var forward := Vector3.FORWARD.rotated(Vector3.UP,yaw)
		var side := Vector3.RIGHT.rotated(Vector3.UP,yaw)
		var entrance := pos+forward*(float(lot.extent.y)*.5+.8)
		if lot.kind in ["commerce","school","civic_center","clinic"]:
			var p := _surface(entrance+side*(float(lot.extent.x)*.30),h,.17)
			var facing := yaw+.14
			var back := Vector3.BACK.rotated(Vector3.UP,facing)
			var leg := Vector3.RIGHT.rotated(Vector3.UP,facing)
			for signum in [-1.,1.]:
				_box(parent,p+leg*.62*float(signum)+Vector3.UP*.22,Vector3(.12,.42,.44),facing,steel)
			_box(parent,p+Vector3.UP*.45,Vector3(1.72,.12,.52),facing,wood)
			_box(parent,p+back*.24+Vector3.UP*.69,Vector3(1.72,.29,.082),facing,wood)
			if lot.kind in ["school","commerce"]:
				for i in range(3):
					var centre := _surface(entrance-side*(2.65-.53*i),h,.16)
					for dy in [-.30,.30]:
						_box(parent,centre+forward*dy+Vector3.UP*.34,Vector3(.065,.65,.065),yaw,steel)
					_box(parent,centre+Vector3.UP*.68,Vector3(.065,.065,.66),yaw,steel)
		elif lot.kind in ["depot","processor"]:
			for i in range(3):
				var crate_pos := _surface(entrance + side * (-float(lot.extent.x)*.24+i*1.25),h,.18)
				var offset := sin(float(i)*6.9)*.1
				var ht := .78 if i != 1 else 1.23
				_box(parent,crate_pos+Vector3.UP*.08,Vector3(1.16,.15,.93),yaw+offset,wood)
				_box(parent,crate_pos+Vector3.UP*(.15+ht*.5),Vector3(1.06,ht,.86),yaw+offset,crate if i==1 else indigo)
				_box(parent,crate_pos+Vector3.UP*(.17+ht),Vector3(.09,.025,.88),yaw+offset,marking)
