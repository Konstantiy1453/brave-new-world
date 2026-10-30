extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")


func _initialize() -> void:
	Watchdog.arm(self)
	var out: Dictionary = {"source": "independent reviewer edge probes", "results": []}
	var s = Sim.new()
	s.new_game(20261029, "capital", 1)
	out.results.append({"settle": s.act("settle", {"region": 0})})
	for kind in ["mine_ore", "mine_copper", "mine_crystal", "lab", "farm"]:
		out.results.append({"build": kind, "result": s.act("build", {"region": 0, "kind": kind})})
	for d in range(30):
		s.tick()
		if not s.audit().is_empty():
			out.results.append(
				{
					"day": s.state.day,
					"audit": s.audit(),
					"workers": s.state.settlements[0].workers,
					"employed_workers": s.state.settlements[0].employed_workers,
					"scientists": s.state.settlements[0].scientists,
					"employed_scientists": s.state.settlements[0].employed_scientists
				}
			)
	var path := "user://independent_review_save.json"
	var save_error: String = s.save_game(path)
	var t = Sim.new()
	var load_error: String = t.load_game(path)
	out.results.append(
		{
			"save": save_error,
			"load": load_error,
			"canonical_equal":
			JSON.stringify(s.state, "", true, true) == JSON.stringify(t.state, "", true, true)
		}
	)
	if load_error == "":
		for d in range(15):
			s.tick()
			t.tick()
		out.results.append(
			{
				"after_15_days_equal":
				JSON.stringify(s.state, "", true, true) == JSON.stringify(t.state, "", true, true),
				"audits": [s.audit(), t.audit()]
			}
		)
	var a = Sim.new()
	a.new_game(20261029, "capital", 1)
	a.act("settle", {"region": 0})
	a.state.settlements[0].workers = 10
	a.state.settlements[0].population = 26
	var before: String = JSON.stringify(a.state, "", true, true)
	var error: String = a.act("settle", {"region": 1})
	out.results.append(
		{
			"rejected_outpost_error": error,
			"rejected_outpost_unchanged": before == JSON.stringify(a.state, "", true, true)
		}
	)
	var file := FileAccess.open(
		"D:/勇敢新世界/evidence/v17/tests/simulation_review_probe.json", FileAccess.WRITE
	)
	file.store_string(JSON.stringify(out, "\t"))
	print(JSON.stringify(out))
	quit(0)
