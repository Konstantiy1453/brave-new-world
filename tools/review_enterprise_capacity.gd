extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")


func _initialize() -> void:
	Watchdog.arm(self)
	var s = Sim.new()
	s.new_game(20261029, "capital", 1)
	s.act("settle", {"region": 0})
	var place: Dictionary = s.settlement(0)
	# Deliberately scoped capacity fixture, not a naturally played 24-building run.
	while place.buildings.size() < 24:
		place.buildings.append(s._building("habitat", 0))
	s.state.day = 15
	s.state.exports_total = 100.0
	var before: String = JSON.stringify(s.state, "", true, true)
	var result: Dictionary = {
		"scope": "controlled 24-building capacity fixture, not manual gameplay",
		"buildings_before": place.buildings.size(),
		"enterprise_result": s.act("enterprise", {"region": 0})
	}
	result.buildings_after = place.buildings.size()
	result.rejected_unchanged = before == JSON.stringify(s.state, "", true, true)
	(
		FileAccess
		. open("D:/勇敢新世界/evidence/v17/tests/enterprise_capacity_review.json", FileAccess.WRITE)
		. store_string(JSON.stringify(result, "\t"))
	)
	print(JSON.stringify(result))
	quit(0)
