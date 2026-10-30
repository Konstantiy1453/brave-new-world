extends "res://tests/balance/bots/bot.gd"
## Lands, then does nothing. Measures how long neglect takes to fail.


func on_day() -> void:
	if today() == 1:
		act("settle", {"region": 0})
	defer_events()
