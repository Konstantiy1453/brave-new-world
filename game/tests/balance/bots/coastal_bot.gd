extends "res://tests/balance/bots/balanced_bot.gd"
## The balanced bot as an archipelago contract (群岛开发) is meant to be played (1.11 C): every next
## town scores three times as high on the coast, where the sea carries what roads would cost.


func _init() -> void:
	super._init()
	coast_bonus = 3.0
