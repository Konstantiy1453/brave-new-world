extends "res://tests/balance/bots/bot.gd"
## Builds labs early, trains scientists and picks technologies first, money second.
## This version targets the 1.6 rule set and is rewritten as the rules change.

const HOME: int = 0
const OUTPOST: int = 1
const TECH_ORDER: Array[String] = [
	"survey", "adaptation", "irrigation", "logistics", "processing", "education", "efficiency"
]


func on_day() -> void:
	var day: int = today()
	if day == 1:
		act("settle", {"region": HOME})
		act("build", {"region": HOME, "kind": "lab"})
		act("build", {"region": HOME, "kind": "mine_ore"})
	answer_events_first_option()
	if sim.state.settlements.is_empty():
		return
	_staff_research()
	if not has_building(HOME, "mine_copper"):
		act("build", {"region": HOME, "kind": "mine_copper"})
	if day >= 15 and sim.settlement(OUTPOST).is_empty():
		act("settle", {"region": OUTPOST})
	if not sim.settlement(OUTPOST).is_empty():
		if sim.state.route.is_empty():
			act("connect", {"a": HOME, "b": OUTPOST, "mountain": false})
		if int(sim.settlement(OUTPOST).arrival) <= 0 and not has_building(OUTPOST, "farm"):
			act("build", {"region": OUTPOST, "kind": "farm"})
	if sim.state.enterprise.is_empty():
		act("enterprise", {"region": HOME})


func _staff_research() -> void:
	var view: Dictionary = sim.research_view()
	var available: int = int(view.available)
	if available < 3:
		return
	for tech: String in TECH_ORDER:
		if sim.state.research.completed.has(tech):
			continue
		if sim.state.research.get("projects", {}).get(tech, {}).get("staff", 0) > 0:
			continue
		if act("research_allocate", {"tech": tech, "staff": mini(10, available)}) == "":
			return
