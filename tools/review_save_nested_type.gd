extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const SaveFixture = preload("res://tests/support/save_fixture.gd")


func _initialize() -> void:
	Watchdog.arm(self)
	var s = Sim.new()
	s.new_game(20261029, "capital", 1)
	s.act("settle", {"region": 0})
	var before: PackedByteArray = var_to_bytes(s.state)
	var candidate: Dictionary = s.state.duplicate(true)
	candidate.settlements[0].stock = 5
	SaveFixture.write_state("user://review_nested_bad.save", candidate)
	var result: Variant = s.load_game("user://review_nested_bad.save")
	var out: Dictionary = {
		"scope": "controlled malformed nested stock type with correct outer checksum",
		"load_result": result,
		"state_unchanged": before == var_to_bytes(s.state)
	}
	(
		FileAccess
		. open("D:/勇敢新世界/evidence/v17/tests/save_nested_type_review.json", FileAccess.WRITE)
		. store_string(JSON.stringify(out, "\t"))
	)
	print(JSON.stringify(out))
	quit(0)
