extends SceneTree
## 1.10, later metals and the seabed (November 20 brief):
## - nickel and cobalt have their own planetary deposits: nickel along the iron belts, cobalt rare
##   and with copper and nickel; a town founded on picked ground reaches them; their mines need
##   nickel and cobalt metallurgy; a superalloy works turns two nickel and half a cobalt into one
##   superalloy, sold dear;
## - offshore: the surveying technology halves the survey boat's price and days; a seabed mine on
##   a surveyed rich offshore deposit lands its ore at the town's working harbour as a recorded
##   cargo, which the town then sells; without a harbour it lands nothing and says so.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Rules = preload("res://simulation/rules.gd")
const Sim = preload("res://simulation/sim.gd")
const Bay = preload("res://simulation/bay.gd")
const Geology = preload("res://world/geo2/geology.gd")
const WorldGen = preload("res://world/world_gen.gd")
const SEED: int = 20261029

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, 600.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	# These features are frozen in 1.11 (features.gd); this suite keeps their code tested.
	Rules.read("progression").features.metals = true
	Rules.read("progression").features.seabed = true
	_deposits()
	_nickel_town()
	_superalloy()
	_seabed()
	print("V110_METALS_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _colony(coastal: bool = true) -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1)
	var region: int = -1
	for reg: Dictionary in sim.state.world.regions:
		if bool(reg.get("coast", false)) == coastal and region < 0:
			region = int(reg.id)
	sim.act("settle", {"region": region})
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 80000.0, "TEST funds", false)
	for good: String in ["materials", "parts", "food"]:
		sim._produce(sim.settlement(region), good, 600.0, "TEST stock")
	return sim


func _finished(sim: RefCounted, s: Dictionary, kind: String, plot: int = -1) -> Dictionary:
	var b: Dictionary = sim.Production.new_building(sim, kind, 0)
	b.plot = plot
	b.active = true
	s.buildings.append(b)
	return b


func _deposits() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1)
	var counts: Dictionary = {}
	var nickel: Array = []
	var cobalt: Array = []
	for deposit: Dictionary in Geology.deposits(sim.geo):
		counts[str(deposit.resource)] = int(counts.get(str(deposit.resource), 0)) + 1
		if str(deposit.resource) == "nickel":
			nickel.append(deposit)
		elif str(deposit.resource) == "cobalt":
			cobalt.append(deposit)
	check(
		nickel.size() > 20 and cobalt.size() > 10,
		"nickel and cobalt deposits of their own: %s" % str(counts)
	)
	var finite: bool = true
	for deposit: Dictionary in nickel + cobalt:
		finite = finite and float(deposit.reserve) > 0.0 and float(deposit.reserve) < 10000.0
	check(finite, "each with a finite reserve")
	# Cobalt keeps company with nickel and copper: most cobalt pockets lie near one of them.
	var near: int = 0
	for deposit: Dictionary in cobalt:
		for hit: Dictionary in Geology.reaching(
			sim.geo, float(deposit.lat), float(deposit.lon), 6.0
		):
			if str(hit.deposit.resource) in ["nickel", "copper"]:
				near += 1
				break
	check(
		near * 2 > cobalt.size(),
		"most cobalt pockets lie within 6° of nickel or copper (%d of %d)" % [near, cobalt.size()]
	)
	var again: RefCounted = Sim.new()
	again.new_game(SEED, "capital", 1)
	check(
		var_to_str(Geology.deposits(again.geo)) == var_to_str(Geology.deposits(sim.geo)),
		"the seed reproduces them"
	)


## A town founded on picked ground right on a nickel vein has a plot on that vein, even where no
## plot slot lies on it (slots stand 1.5° apart round a town); the mine needs the technology.
func _nickel_town() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1)
	var spot: Dictionary = {}
	for deposit: Dictionary in Geology.deposits(sim.geo):
		if str(deposit.resource) != "nickel" or bool(deposit.hidden) or not spot.is_empty():
			continue
		for point: Array in deposit.points:
			var lat: float = float(point[0])
			var lon: float = float(point[1])
			if spot.is_empty() and str(sim.Placement.view(sim, lat, lon).refusal) == "":
				spot = {"lat": lat, "lon": lon, "id": str(deposit.id)}
	check(not spot.is_empty(), "a nickel deposit where a capital can be founded")
	if spot.is_empty():
		return
	check(
		sim.act("settle_at", {"lat": spot.lat, "lon": spot.lon, "name": "镍城"}) == "",
		"the capital is founded on it"
	)
	var s: Dictionary = sim.state.settlements[0]
	var reg: Dictionary = sim.state.world.regions[int(s.region)]
	var plot: int = -1
	for index: int in range(reg.plots.size()):
		if (
			str(reg.plots[index].get("resource", "")) == "nickel"
			and not bool(reg.plots[index].get("hidden", false))
			and plot < 0
		):
			plot = index
	check(plot >= 0, "its district has a nickel plot")
	var on_vein: bool = false
	for entry: Dictionary in reg.plots:
		on_vein = on_vein or str(entry.get("deposit", "")) == str(spot.id)
	check(on_vein, "on the vein it was founded on (%s)" % str(spot.id))
	if plot < 0:
		return
	sim._transfer("external", "public", 80000.0, "TEST funds", false)
	check(
		sim.act("build", {"site": int(s.region), "kind": "mine_nickel", "plot": plot}).begins_with(
			"需要技术"
		),
		"a nickel mine needs nickel and cobalt metallurgy"
	)
	sim.state.research.completed.append("nickel_metallurgy")
	check(
		sim.act("build", {"site": int(s.region), "kind": "mine_nickel", "plot": plot}) == "",
		"then it can be ordered"
	)
	var mine: Dictionary = s.buildings.back()
	mine.remaining = 0
	var before: float = float(reg.plots[plot].reserves)
	for _day: int in range(5):
		sim.tick()
	check(
		float(s.stock.nickel) > 0.0 or float(sim.state.exports_total) > 0.0,
		"it mines nickel: %.1f units in store" % float(s.stock.nickel)
	)
	check(float(reg.plots[plot].reserves) < before, "and the deposit's reserve falls")
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))


func _superalloy() -> void:
	var sim: RefCounted = _colony(false)
	var s: Dictionary = sim.state.settlements[0]
	sim._produce(s, "nickel", 40.0, "TEST nickel")
	sim._produce(s, "cobalt", 10.0, "TEST cobalt")
	_finished(sim, s, "superalloy_works")
	var nickel: float = float(s.stock.nickel)
	var sold_before: float = float(sim.state.exports_total)
	for _day: int in range(4):
		sim.tick()
	var made: bool = float(s.stock.superalloy) > 0.0 or float(sim.state.exports_total) > sold_before
	check(
		made and float(s.stock.nickel) < nickel, "the works turns nickel and cobalt into superalloy"
	)
	var price: float = float(sim.Market.price(sim, "superalloy"))
	check(
		price > 2.0 * float(sim.Market.price(sim, "alloy")),
		(
			"sold dear: ¥ %.0f a unit against alloy's ¥ %.0f"
			% [price, float(sim.Market.price(sim, "alloy"))]
		)
	)
	check(sim.audit().is_empty(), "the audit holds")


func _seabed() -> void:
	var sim: RefCounted = _colony(true)
	var s: Dictionary = sim.state.settlements[0]
	var region: int = int(s.region)
	sim.tick()
	var reading: Dictionary = Bay.offshore_signal(sim, region)
	check(not reading.is_empty(), "the bay has an offshore signal")
	if reading.is_empty():
		return
	# Make it a rich cobalt-nodule field, as the survey would find it on some coasts.
	reading.good = "cobalt"
	reading.rich = true
	reading.tonnes = 3000.0
	var plain: Dictionary = Bay.survey_terms(sim)
	sim.state.research.completed.append("offshore_survey")
	var faster: Dictionary = Bay.survey_terms(sim)
	check(
		(
			is_equal_approx(float(faster.cost), float(plain.cost) * 0.5)
			and int(faster.days) < int(plain.days)
		),
		(
			"offshore surveying halves the boat: ¥ %.0f, %d days → ¥ %.0f, %d days"
			% [plain.cost, plain.days, faster.cost, faster.days]
		)
	)
	sim.state.research.completed.append("seabed_mining")
	check(
		sim.act("build", {"site": region, "kind": "seabed_mine"}).contains("测量船"),
		"no seabed mine before the signal is surveyed"
	)
	reading.surveyed = true
	check(
		sim.act("build", {"site": region, "kind": "seabed_mine"}) == "",
		"on a surveyed rich deposit it can be ordered"
	)
	var platform: Dictionary = s.buildings.back()
	platform.remaining = 0
	sim.tick()
	check(
		float(reading.tonnes) >= 3000.0 - 0.001 and not sim.state.get("firsts", {}).has("offshore"),
		"without a harbour nothing is landed"
	)
	var short: bool = false
	for entry: Dictionary in s.shortages:
		short = short or str(entry.key) == "no_harbour"
	check(short, "and the town says the ore has no harbour")
	_finished(sim, s, "harbor")
	var landed_before: float = float(reading.tonnes)
	for _day: int in range(3):
		sim.tick()
	var first: Dictionary = sim.state.firsts.get("offshore", {})
	check(
		(
			int(first.get("region", -1)) == region
			and int(first.get("building", 0)) == int(platform.uid)
			and str(first.get("resource", "")) == "cobalt"
			and float(first.get("amount", 0.0)) > 0.0
			and str(first.get("vehicle", "")) == "驳船"
		),
		(
			"the first barge lands %.0f t of cobalt at the harbour, recorded"
			% sim.tonnes(float(first.get("amount", 0.0)))
		)
	)
	check(
		float(reading.tonnes) < landed_before,
		"and the offshore deposit shrinks: %.0f → %.0f" % [landed_before, float(reading.tonnes)]
	)
	check(
		str(s.get("sea_cargo", {}).get("direction", "")) in ["landed", "export", "import"],
		"the harbour has cargo, so its ship calls"
	)
	var sold: float = float(sim.state.market.saturation.get("cobalt", 0.0))
	check(
		sold > 0.0 or float(s.stock.cobalt) > 0.0,
		"the cobalt is sold or kept to process (%.2f sold)" % sold
	)
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))
