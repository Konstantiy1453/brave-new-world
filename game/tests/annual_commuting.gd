extends SceneTree

const Sim = preload("res://simulation/sim.gd")

var failures: Array[String] = []


func _initialize() -> void:
	if not exercise():
		failures.append("fixture could not finish")
	for reason: String in failures:
		push_error(reason)
	print("ANNUAL_COMMUTING ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)


func exercise() -> bool:
	var sim: RefCounted = Sim.new()
	var start: String = sim.new_game(260129, "capital", 1, "normal")
	if start != "":
		failures.append(start)
		return false
	check(sim.act("settle", {"site": 0}) == "", "capital landing")
	var home: Dictionary = sim.state.settlements[0]
	var annual: Dictionary = sim.state.annual
	check(is_equal_approx(annual.targets.mining, 12258.0), "year-one mining base is 90%")
	check(is_equal_approx(annual.targets.farming, 252.0), "year-one farming base is 90%")
	check(is_equal_approx(sim.progression.annual_report.ratchet_growth.capital, 1.05 * 0.9), "ratchet from last report is 90%")
	check(is_equal_approx(sim.config.openings.mining_pledge.rules.tribute[0], 1800.0), "physical tribute also drops 10%")
	sim.state.events_v2.next_draw = 99999
	sim.state.contract.licences.append("expedition")
	sim._transfer("external", "public", 200000.0, "TEST expedition", false)
	sim.Population._admit(sim, home, 60, 0)
	for key: String in ["materials", "food", "parts"]:
		sim._produce(home, key, 1000.0, "TEST supplies")
	var mine_kind: String = ""
	var dest: int = -1
	for site: Dictionary in sim.state.world.regions:
		var region: int = int(site.id)
		if sim.Sites.settle_refusal(sim, region, int(home.region), "frontier") != "":
			continue
		for kind: String in ["mine_ore", "mine_copper", "mine_crystal"]:
			if sim.Sites.find_plot(sim, region, kind) >= 0:
				mine_kind = kind
				dest = region
				break
		if dest >= 0:
			break
	if dest < 0:
		failures.append("reachable mine site missing")
		return false
	check(sim.act("settle", {"region": dest, "from": int(home.region), "kind": "frontier"}) == "", "frontier expedition")
	var work: Dictionary = sim.settlement(dest)
	work.arrival = 0
	for structure: Dictionary in work.buildings:
		structure.remaining = 0
	var workers: int = int(work.workers)
	home.workers += workers
	home.population += workers
	work.workers = 0
	work.population -= workers
	work.base_housing = 0
	for key: String in ["materials", "food", "parts"]:
		sim._produce(work, key, 100.0, "TEST delivered stores")
	var mine: Dictionary = sim.Production.new_building(sim, mine_kind, 0)
	mine.plot = sim.Sites.find_plot(sim, dest, mine_kind)
	work.buildings.append(mine)
	var seam: Dictionary = sim.Sites.plot_of(sim, work, mine)
	var reserve: float = float(seam.reserves)
	sim.tick()
	check(is_equal_approx(reserve, seam.reserves) and sim.Commuting.visitors(mine) == 0, "without shuttles the empty mine cannot produce")
	check(sim.Research.grant_by_contract(sim, "logistics"), "dispatch technology unlocked")
	sim.tick()
	check(seam.reserves < reserve and mine.efficiency > 0.0, "real mine extracts with visiting workers")
	check(work.housing == 0 and work.workers == 0, "mining requires no destination beds or resident workforce")
	check(sim.Commuting.visitors(mine) == sim.Production.jobs_for(sim, mine), "shuttles fill mine jobs")
	check(mine.commuters.get(str(home.region), 0) > 0, "mine workers come from the city")
	var wages: float = 0.0
	for entry: Dictionary in sim.state.ledger:
		if entry.key == "wages.public" and entry.detail == mine_kind and int(entry.day) == int(sim.state.day):
			wages += float(entry.amount)
	check(is_equal_approx(wages, sim.Commuting.visitors(mine) * sim.Population.worker_wage(sim)), "every commuter receives exactly one mining wage")
	check(home.commute_out == work.commute_in and home.commute_out <= sim.Commuting.seats(sim), "seats and both ends match")
	var local: int = 0
	for facility: Dictionary in home.buildings:
		local += int(facility.employed)
	check(home.employed_workers == local + home.commute_out and int(home.employed_workers) <= int(home.workers), "workers hold exactly one job")
	check(sim.Commuting.routes(sim, int(home.region)) == sim.Commuting.routes(sim, dest), "both ends show the route")
	check(sim.audit().is_empty(), "money, ore and population balance")
	check(sim.Commuting.validate(sim, sim.state) == "", "daily shuttle records balance")
	var path: String = "user://annual_commute_test.save"
	check(sim.save_game(path) == "", "save writes")
	var loaded: RefCounted = Sim.new()
	var load_error: String = loaded.load_game(path)
	if load_error != "":
		failures.append("load: " + load_error)
		return false
	var reopened: Dictionary = loaded.settlement(dest)
	check(sim.Commuting.routes(sim, dest) == loaded.Commuting.routes(loaded, dest), "routes survive save/reload")
	loaded.act("toggle", {"region": dest, "index": reopened.buildings.size()-1})
	check(reopened.buildings.back().get("commuters", {}).is_empty(), "disabled mine releases its shift")
	check(loaded.Commuting.validate(loaded, loaded.state) == "", "released shifts balance")
	var original_targets: Dictionary = annual.targets.duplicate()
	annual.erase("target_revision")
	annual.targets = {"mining": 1000.0, "farming": 500.0}
	annual.pending = {"targets": annual.targets.duplicate()}
	check(sim.save_game(path) == "", "old quota fixture writes")
	var migrated: RefCounted = Sim.new()
	check(migrated.load_game(path) == "", "old open and pending quotas load")
	check(migrated.state.annual.targets.mining == 900.0 and migrated.state.annual.pending.targets.farming == 450.0, "loaded old quotas fall 10%")
	check(original_targets != migrated.state.annual.targets, "old custom quotas are scaled, not replaced with current stage base")
	sim.AnnualReport.update_open_targets(sim)
	sim.AnnualReport.update_open_targets(sim)
	check(annual.targets.mining == 900.0 and annual.pending.targets.farming == 450.0, "existing open and pending quotas fall exactly once")
	return true
