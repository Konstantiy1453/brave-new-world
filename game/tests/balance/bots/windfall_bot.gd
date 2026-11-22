extends "res://tests/balance/bots/balanced_bot.gd"
## The harness's windfall case (1.9 plan A2.8): the balanced bot handed ¥1,000,000 on day 1,080,
## booked as outside funding. Compared with the balanced bot on the same seeds.

const WINDFALL_DAY: int = 1080
const WINDFALL: float = 1000000.0


func on_day() -> void:
	if today() == WINDFALL_DAY and not sim.state.settlements.is_empty():
		sim._transfer("external", "public", WINDFALL, "test.windfall", false)
	super.on_day()
