extends "res://tests/balance/bots/balanced_bot.gd"
## The balanced bot as a resettlement contract (移民安置) is meant to be played (1.11 C): beds come
## before anything else, a fifth of them kept free, so every resident can earn the subsidy.


func _init() -> void:
	super._init()
	housing_slack = 0.2
