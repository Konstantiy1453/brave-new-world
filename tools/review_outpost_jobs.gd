extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")


func _initialize() -> void:
	Watchdog.arm(self)
	var s = Sim.new()
	s.new_game(20261029, "capital", 1)
	s.state.contract.licences.append("expedition")
	s.act("settle", {"region": 0})
	for kind in ["mine_ore", "mine_copper", "mine_crystal"]:
		s.act("build", {"region": 0, "kind": kind})
	for d in range(7):
		s.tick()
	var result: Dictionary = {
		"before":
		{"workers": s.settlement(0).workers, "employed": s.settlement(0).employed_workers},
		"settle": s.act("settle", {"region": 1})
	}
	result.after = {
		"workers": s.settlement(0).workers,
		"employed": s.settlement(0).employed_workers,
		"audit": s.audit()
	}
	result.save = s.save_game("user://outpost_review.json")
	var t = Sim.new()
	result.load = t.load_game("user://outpost_review.json")
	(
		FileAccess
		. open("D:/勇敢新世界/evidence/v17/tests/outpost_jobs_review.json", FileAccess.WRITE)
		. store_string(JSON.stringify(result, "\t"))
	)
	print(JSON.stringify(result))
	quit(0)
