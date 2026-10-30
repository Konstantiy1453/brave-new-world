extends "res://tests/balance/bots/bot.gd"
## The shortest path to the contract; guards the floor in §5.2 (brief Appendix B).


func on_day() -> void:
	var day: int = today()
	if day == 1:
		act("settle", {"region": 0})
		act("build", {"region": 0, "kind": "mine_ore"})
		act("build", {"region": 0, "kind": "mine_copper"})
	if day >= 2 and sim.settlement(1).is_empty():
		act("settle", {"region": 1})
	if not sim.settlement(1).is_empty() and sim.state.route.is_empty():
		act("connect", {"a": 0, "b": 1, "mountain": true})
	var outpost: Dictionary = sim.settlement(1)
	if not outpost.is_empty() and int(outpost.arrival) <= 0 and not has_building(1, "farm"):
		act("build", {"region": 1, "kind": "farm"})
	if day >= 15 and sim.state.enterprise.is_empty():
		act("enterprise", {"region": 0})
	answer_events_first_option()


func finished() -> bool:
	return sim.state.status == "success"
