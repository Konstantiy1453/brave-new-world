extends "res://tests/balance/bots/balanced_bot.gd"
## The balanced bot that reports every line of the annual report as exceeded (1.11 D): more money
## early, steeper targets and an open gap later. Compared with the balanced bot on the same seeds.


func _init() -> void:
	super._init()
	report_policy = "exceed"
