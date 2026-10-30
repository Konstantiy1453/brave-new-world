extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
var failures: int = 0
var checks: int = 0
const Sim = preload("res://simulation/sim.gd")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)


func make():
	var sim = Sim.new()
	sim.new_game(260129, "science", 1)
	sim.state.contract.licences.append("expedition")
	sim.act("settle", {"region": 0})
	return sim


func _init() -> void:
	Watchdog.arm(self)
	var sim = make()
	var home: Dictionary = sim.settlement(0)
	home.buildings.append(sim._building("habitat", 0))
	sim._refresh(home)
	var enabled: int = home.housing
	sim.act("toggle", {"region": 0, "index": home.buildings.size() - 1})
	sim._refresh(home)
	check(home.housing == enabled - 45, "F07 disabled housing removed")
	home.port_capacity = 0
	home.shortages = []
	sim._trade(home)
	check(home.shortages.all(func(x): return x.key != "port_full"), "F08 no port not congestion")
	sim.act("settle", {"region": 1})
	sim.act("connect", {"a": 0, "b": 1})
	var dst: Dictionary = sim.settlement(1)
	dst.arrival = 0
	sim.state.day = 5
	sim.state.shipments = []
	home.stock.materials = 92.4
	home.exportable = {"materials": 2.4, "parts": 0.0}
	home.port_capacity = 38
	dst.stock.materials = 0
	dst.stock.food = 500
	home.stock.food = 500
	sim._trade(home)
	sim._dispatch()
	check(
		sim._incoming(1, "materials") > 2.39, "F01 open port preserves outbound construction stock"
	)
	sim.state.enterprise = {
		"name": "test",
		"region": 0,
		"industry": "service",
		"status": "closed",
		"remaining": 0,
		"employees": 0,
		"profit": 0.0,
		"sales_total": 0.0,
		"wages_total": 0.0,
		"tax_total": 0.0,
		"loss_days": 15,
		"reason": "test",
		"rent": 2.0
	}
	home.buildings.append(sim._building("service", 0))
	check(sim.act("enterprise_recover", {"region": 0}) == "", "F02 paid recovery action exists")
	check(sim.state.enterprise.status != "closed", "F02 halted enterprise resumes")
	check(sim.has_method("research_view"), "personnel research API")
	check(sim.has_method("company_view"), "conditional intervention API")
	check(
		sim.act("batch_toggle", {"region": 0, "category": "production", "enabled": false}) == "",
		"batch production API"
	)
	check(
		sim.act("stock_target", {"region": 0, "resource": "food", "target": 100}) == "",
		"stock targets API"
	)
	print("V16_ECONOMY_RED checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
