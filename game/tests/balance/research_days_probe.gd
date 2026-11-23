extends SceneTree
## Research by direction before and after the 1.11 H merge: the balanced bot on the standard
## contract and the quick seeds for 2,880 days; prints, per direction, the median days a team was
## at work and the technologies finished. Run it on the tree before the merge and after it.
##   godot --headless --path game --script res://tests/balance/research_days_probe.gd

const Sim = preload("res://simulation/sim.gd")
const Balanced = preload("res://tests/balance/bots/balanced_bot.gd")
const SEEDS: Array[int] = [260129, 42, 20261029]
const DAYS: int = 2880
const CATEGORIES: Array[String] = ["industry", "agriculture", "construction", "society"]


func _initialize() -> void:
	var days: Dictionary = {}
	var finished: Dictionary = {}
	for category: String in CATEGORIES:
		days[category] = []
		finished[category] = []
	for seed_value: int in SEEDS:
		var sim: RefCounted = Sim.new()
		sim.new_game(seed_value, "capital", 1, "normal")
		var bot: RefCounted = Balanced.new()
		bot.begin(sim, seed_value)
		var counted: Dictionary = {}
		for _day: int in range(DAYS):
			bot.on_day()
			sim.tick()
			var working: Dictionary = {}
			for key: Variant in sim.state.research.projects:
				if int(sim.state.research.projects[key].get("effective", 0)) > 0:
					working[str(sim.config.techs.get(str(key), {}).get("category", "?"))] = true
			for category: String in working:
				counted[category] = int(counted.get(category, 0)) + 1
			if str(sim.state.status) == "failed":
				break
		var done: Dictionary = {}
		for key: Variant in sim.state.research.completed:
			var category: String = str(sim.config.techs.get(str(key), {}).get("category", "?"))
			done[category] = int(done.get(category, 0)) + 1
		for category: String in CATEGORIES:
			days[category].append(int(counted.get(category, 0)))
			finished[category].append(int(done.get(category, 0)))
	var parts: PackedStringArray = []
	for category: String in CATEGORIES:
		var d: Array = days[category]
		var f: Array = finished[category]
		d.sort()
		f.sort()
		parts.append("%s days %d techs %d" % [category, d[d.size() / 2], f[f.size() / 2]])
	print("RESEARCH_DAYS_PROBE " + "; ".join(parts))
	quit(0)
