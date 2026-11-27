extends SceneTree

const Sim = preload("res://simulation/sim.gd")

var failures: Array[String] = []


func _initialize() -> void:
	if not _exercise():
		failures.append("test did not finish")
	for message: String in failures:
		push_error(message)
	print("FIRST_YEAR_DISTRUST ", "PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _exercise() -> bool:
	var sim: RefCounted = Sim.new()
	var start: String = sim.new_game(260129, "capital", 1, "normal")
	if start != "":
		failures.append(start)
		return false
	check(sim.act("settle", {"site": 0}) == "", "capital can land")
	var town: Dictionary = sim.state.settlements[0]
	var year: int = sim.AnnualReport.year_days()
	sim.state.day = year - 1
	sim._transfer("public", "external", sim.state.cash, "test exhaustion", false)
	sim._public_expense(100.0, "test overdue invoice", "external")
	sim.state.grace_days = year - 1
	sim.Company.tick(sim)
	check(sim.state.company.distrust == 0.0, "unpaid bills on the last day of year one are exempt")
	check(sim.state.company.stage == "normal", "a protected colony stays outside review")
	var option: Dictionary = {"distrust": 5.0, "set_wage": 1.1}
	sim.EventsV2._apply_colony(sim, town, option)
	check(sim.state.company.distrust == 0.0, "event distrust is exempt while paused")
	check(is_equal_approx(float(sim.state.policy.wage), 1.1), "the rest of the event still applies")
	var old: Dictionary = sim.state.duplicate(true)
	old.company.distrust = 75.0
	old.company.stage = "intervention"
	old.company.deadline = year - 1
	old.company.delta = 1.0
	old.company.sources = {"economic": {"rate": 1.0, "days": 10, "reason": "未付账款"}}
	var recovered: RefCounted = Sim.new()
	check(sim.SaveIo.adopt(recovered, old, sim.blobs.duplicate(true)) == "", "active old state loads")
	var company: Dictionary = recovered.state.company
	check(company.distrust == 0.0 and company.delta == 0.0, "old first-year penalties clear on load")
	check(company.stage == "normal" and company.deadline == -1, "old first-year intervention ends")
	check(recovered.state.debt == sim.state.debt, "the actual debt survives the exemption")
	sim.state.day = year
	sim.Company.tick(sim)
	check(sim.state.company.distrust > 0.0, "unpaid bills count on the first day of year two")
	var before: float = float(sim.state.company.distrust)
	sim.EventsV2._apply_colony(sim, town, option)
	check(is_equal_approx(float(sim.state.company.distrust), before + 5.0), "year-two event counts")
	return true
