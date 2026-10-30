extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
## Explicit boundary fixtures; end-to-end accepted saves are built separately.
const Sim = preload("res://simulation/sim.gd")
const C = preload("res://simulation/career.gd")
var checks: int = 0
var failures: Array = []


func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func _initialize():
	Watchdog.arm(self)
	call_deferred("run")


func run():
	var s = Sim.new()
	check(s.load_game("res://data/acceptance_success.json") == "", "load legacy governor fixture")
	# This deliberately changes only the fixture date to isolate age/global clocks.
	s.state.day = 359
	s.state.career.global_day = 359
	s.state.career.last_local_day = 359
	check(
		C.handover(s, 260130, "capital", "normal", "user://career_boundary.json") == "",
		"handover after first contract deadline"
	)
	check(
		s.state.day == 0 and s.state.career.global_day == 359,
		"second contract starts at local zero after global deadline"
	)
	check(
		s.state.company.stage == "normal" and s.state.company.distrust == 0,
		"new world has clean local contract review"
	)
	if s.state.has("events_v2"):
		check(
			s.state.events_v2.next_draw == 6 and s.state.events_v2.instances.is_empty(),
			"second world events schedule by local age"
		)
	s.act("settle", {"region": 0})
	var local_cash: float = s.state.cash
	s.tick()
	check(
		s.state.day == 1 and s.state.career.global_day == 360 and s.state.status != "failed",
		"year rollover keeps second contract active"
	)
	check(s.state.career.history.size() == 1, "month boundary creates one report")
	var paid: float = s.state.career.balance
	check(paid > 0, "boundary payout is actually positive")
	var before: String = JSON.stringify(s.state.career)
	C.tick(s)
	check(
		JSON.stringify(s.state.career) == before, "repeated year boundary never duplicates payout"
	)
	var error: String = s.save_game("user://career_boundary.json")
	var loaded = Sim.new()
	check(
		error == "" and loaded.load_game("user://career_boundary.json") == "",
		"save and reload exactly at payment date"
	)
	before = JSON.stringify(loaded.state.career)
	C.tick(loaded)
	check(JSON.stringify(loaded.state.career) == before, "load cannot trigger another payout")
	var active_before: PackedByteArray = var_to_bytes(s.state)
	check(
		(
			C.restart(s, "easy", "Z:/absent/restart.json") != ""
			and var_to_bytes(s.state) == active_before
		),
		"failed restart save preserves complete attempt"
	)
	check(
		C.restart(s, "easy", "user://career_boundary.json") == "",
		"changing difficulty restores pre-attempt career"
	)
	var easy_cash: float = (
		float(s.config.openings.capital.cash) * float(s.progression.difficulty.easy.capital)
	)
	check(
		(
			s.state.day == 0
			and s.state.career.global_day == 359
			and s.state.career.balance == 0
			and is_equal_approx(float(s.state.cash), easy_cash)
		),
		"easy restart applies funding once and removes attempt dividend"
	)
	check(
		(
			C.restart(s, "easy", "user://career_boundary.json") == ""
			and is_equal_approx(float(s.state.cash), easy_cash)
		),
		"repeat difficulty restart cannot stack funding"
	)
	check(
		s.state.career.managed.size() == 1 and s.state.career.history.is_empty(),
		"checkpoint keeps old governorship and reverts this attempt history"
	)
	s.act("settle", {"region": 0})
	var old: Dictionary = s.state.career.managed[0]
	for stream in old.mining_streams:
		stream.remaining = minf(float(stream.remaining), float(stream.rate) * 0.5)
	old.nonmining_income = 0.0
	var active_net_before: float = s.state.cash
	s.tick()
	check(old.mine_remaining == 0, "each operated ore deposit exhausts independently")
	var ore_income: float = old.income_total
	s.tick()
	check(
		old.income_total == ore_income, "exhausted mines generate no permanent continuation income"
	)
	check(C.validate(s.state) == "", "all boundary accounting remains valid")
	print(
		"CAREER_BOUNDARY_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)]
	)
	quit(0 if failures.is_empty() else 1)
