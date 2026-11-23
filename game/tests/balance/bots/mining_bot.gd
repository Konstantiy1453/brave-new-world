extends "res://tests/balance/bots/balanced_bot.gd"
## The balanced bot as a mining pledge (矿权抵押) is meant to be played (1.11 C): mines first, their
## payback counted at 0.6 of the forecast when choosing what to build, for the ore the ship takes.


func _init() -> void:
	super._init()
	mine_payback_factor = 0.6
