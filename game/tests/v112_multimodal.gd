extends SceneTree
const Sim = preload("res://simulation/sim.gd")
const Sea = preload("res://world/sea_lane.gd")
const Watchdog = preload("res://tests/support/watchdog.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_ocean()
	_network()
	print("V112_MULTIMODAL checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _ocean() -> void:
	var atlas := Image.create_empty(256, 128, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0.25))
	atlas.fill_rect(Rect2i(122, 40, 12, 50), Color(0, 0, 0, 0.85))
	var sea := Sea.new()
	sea.setup(ImageTexture.create_from_image(atlas))
	var route := sea.coordinates(Vector2(0, -40), Vector2(0, 40))
	check(route.size() > 16, "a sea passage around the island has a continuous curve")
	var furthest := 0.0
	var wet := true
	for i in range(1, route.size()):
		furthest = maxf(furthest, absf(route[i].x))
		var a := sea._pixel(route[i - 1])
		var b := sea._near(a, sea._pixel(route[i]))
		for j in range(17):
			var p := a.lerp(b, float(j) / 16.0)
			var x := posmod(roundi(p.x), atlas.get_width())
			var y := clampi(roundi(p.y), 0, atlas.get_height() - 1)
			wet = wet and atlas.get_pixel(x, y).a < 0.5
	check(wet and furthest > 30.0, "every sampled segment skirts the island")
	var wrap := sea.coordinates(Vector2(10, 170), Vector2(10, -169))
	var bends := false
	var seam_only := not wrap.is_empty()
	for ll in wrap:
		bends = bends or absf(ll.x - wrap[0].x) > 0.1
		seam_only = seam_only and absf(ll.y) > 160.0
	check(seam_only and bends, "an open-water crossing curves over the antimeridian")
	check(sea.coordinates(Vector2(10, 170), Vector2(10, -169)) == wrap, "redraw reuses the checked path")
	atlas.fill(Color(0, 0, 0, 0.8))
	sea.setup(ImageTexture.create_from_image(atlas))
	check(sea.coordinates(Vector2(10, 170), Vector2(10, -169)).is_empty(), "never bridge land when no water path exists")
	# Two water pixel rows: the coarse grid's four-pixel bilinear neighbourhood is never
	# completely wet along this channel, but a lane fits at full resolution.
	var narrow := Image.create_empty(768, 384, false, Image.FORMAT_RGBA8)
	narrow.fill(Color(0, 0, 0, 0.85))
	narrow.fill_rect(Rect2i(80, 183, 610, 2), Color(0, 0, 0, 0.25))
	sea.setup(ImageTexture.create_from_image(narrow))
	check(not sea.coordinates(sea._geographic(Vector2(93, 183)), sea._geographic(Vector2(670, 183))).is_empty(), "a navigable sub-grid strait remains visible")

	# The closest water pixel to the departure lies in an enclosed lake.
	var harbour := Image.create_empty(256, 128, false, Image.FORMAT_RGBA8)
	harbour.fill(Color(0, 0, 0, 0.25))
	harbour.fill_rect(Rect2i(90, 45, 22, 30), Color(0, 0, 0, 0.85))
	harbour.fill_rect(Rect2i(99, 56, 6, 8), Color(0, 0, 0, 0.25))
	sea.setup(ImageTexture.create_from_image(harbour))
	var offshore := sea.coordinates(sea._geographic(Vector2(105, 60)), sea._geographic(Vector2(180, 60)))
	check(offshore.size() > 8 and sea._pixel(offshore[0]).x >= 112, "a harbour beside an isolated lake uses the reachable open coast")


func _network() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(1875339774, "capital", 1)
	var a := 0
	var b := 16
	check(sim.act("settle", {"site": a}) == "", "first coastal settlement")
	sim._transfer("external", "public", 300000.0, "test", false)
	sim.Crews.unlimited(sim)
	if not sim.state.contract.licences.has("expedition"):
		sim.state.contract.licences.append("expedition")
	check(sim.act("settle", {"site": b}) == "", "second coastal settlement")
	var src: Dictionary = sim.settlement(a)
	var dst: Dictionary = sim.settlement(b)
	if dst.is_empty():
		return
	for i in range(int(dst.arrival) + 1):
		sim.tick()
	sim._produce(src, "materials", 160.0, "test")
	check(sim.act("connect", {"a": a, "b": b, "variant": "engineered"}) == "", "order the road")
	check(sim.act("connect", {"a": b, "b": a, "variant": "sea"}) == "", "order the sea lane in the opposite direction")
	if sim.state.roads.size() != 2:
		return
	check(sim.act("connect", {"a": a, "b": b, "variant": "sea"}) != "", "duplicate terminals are refused")
	check(sim.act("connect", {"a": b, "b": a, "variant": "valley"}) != "", "a duplicate road is refused")
	var land: Dictionary = sim.state.roads[0]
	var sea: Dictionary = sim.state.roads[1]
	check(sea.capacity == 72 and sea.capacity > land.capacity and sea.days > land.days, "more cargo and a longer voyage")
	for r: Dictionary in sim.state.roads:
		r.ready_day = 0
		r.blocked_until = -1
	for place: Dictionary in [src, dst]:
		for key: String in place.stock:
			sim._consume(place, key, float(place.stock[key]))
	sim._produce(src, "parts", 70.0, "test")
	var stock_before: float = src.stock.parts
	var money_before: float = sim.state.cash
	sim.Logistics.dispatch(sim)
	var manifest := 0.0
	var fees := 0.0
	var each: Dictionary = {}
	for cargo: Dictionary in sim.state.shipments:
		if cargo.get("expedition", false) or cargo.resource != "parts":
			continue
		manifest += float(cargo.amount)
		each[cargo.road] = float(cargo.amount)
		var r: Dictionary = sim.state.roads[int(cargo.road)]
		var spec: Dictionary = sim.config.roads[r.variant]
		var unit_fee: float = float(sim.config.economy.transport_unit_cost) * float(spec.get("fee_factor", 1))
		unit_fee *= maxf(1.0, float(cargo.total_days) / float(sim.config.economy.transport_reference_days))
		fees += float(cargo.amount) * unit_fee
	check(each.size() == 2 and float(each.get(sea.id, 0)) > float(each.get(land.id, 0)), "both modes carry shares of the same small order")
	check(is_equal_approx(stock_before - float(src.stock.parts), manifest), "the split manifest debits stock once")
	check(is_equal_approx(money_before - float(sim.state.cash), fees), "each share pays exactly its line's fee")
	check(manifest <= float(sim.config.economy.construction_stock.parts) + 0.00001, "outgoing loads respect the destination deficit")
	var cargo_before: Array = sim.state.shipments.duplicate(true)
	sea.erase("sea_profile")
	sea.level = 2
	sea.capacity = 54
	sea.days = 11
	sim.Logistics.restore_transport(sim)
	check(sea.capacity == 108 and sea.days == maxi(5, ceili(sea.distance / 220.0)) - 1, "legacy upgraded docks retain level on new rates")
	check(cargo_before == sim.state.shipments, "shipments underway keep their cargo and arrival day")
	var upgraded: Dictionary = sea.duplicate(true)
	sim.Logistics.restore_transport(sim)
	check(sea == upgraded, "repeated migration is stable")
	var path := "user://multimodal.save"
	check(sim.save_game(path) == "", "save the two-mode network")
	var restored: RefCounted = Sim.new()
	check(restored.load_game(path) == "", "reload the two-mode network")
	if not restored.state.is_empty():
		check(restored.state.shipments == sim.state.shipments and restored.state.roads.size() == 2, "both routes and transit manifests survive reload")
	if not each.is_empty():
		for i in range(maxi(int(sea.days), int(land.days)) + 100):
			sim.Logistics.advance_shipments(sim)
		check(is_equal_approx(float(dst.stock.parts), manifest), "both loads arrive exactly once")
