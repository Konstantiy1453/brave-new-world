extends "res://tests/balance/bots/bot.gd"
## Builds only mines; ignores food, housing and events.

const MINES: Array[String] = ["mine_ore", "mine_copper", "mine_crystal"]


func on_day() -> void:
	if today() == 1:
		act("settle", {"region": 0})
	for kind: String in MINES:
		if building_count(0, kind) < 3:
			act("build", {"region": 0, "kind": kind})
	defer_events()
