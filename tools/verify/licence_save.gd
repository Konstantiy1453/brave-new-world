extends SceneTree
## 1.12: a CC-GEO-2.3 game played headless by the balanced bot until the expansion licence arrives,
## saved while the capital is still the only town: the packaged outpost cases' starting point
## (`placement_driver.gd --case=outpost --save=<file>`). Seed 260129 gets it on day 179.
##   godot --headless --path game --script <abs>/licence_save.gd -- --seed=260129 --out=<file>


func _initialize() -> void:
	var args: Dictionary = {"seed": "260129", "out": "", "days": "900"}
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var Sim: GDScript = load("res://simulation/sim.gd")
	var Bot: GDScript = load("res://tests/balance/bots/balanced_bot.gd")
	var sim: RefCounted = Sim.new()
	sim.new_game(int(args.seed), "capital", 1, "normal")
	var bot: RefCounted = Bot.new()
	bot.begin(sim, int(args.seed))
	while not sim.state.contract.licences.has("expedition") and int(sim.state.day) < int(args.days):
		bot.on_day()
		sim.tick()
		if str(sim.state.status) == "failed":
			break
	var towns: int = sim.state.settlements.size()
	var capital: Dictionary = sim.state.settlements[0] if towns > 0 else {}
	print(
		"LICENCE_SAVE seed=",
		args.seed,
		" day=",
		sim.state.day,
		" licence=",
		sim.state.contract.licences.has("expedition"),
		" towns=",
		towns,
		" status=",
		sim.state.status,
		" capital=",
		capital.get("name", ""),
		" region=",
		capital.get("region", -1),
		" buildings=",
		capital.get("buildings", []).size(),
		" coast=",
		(
			sim.state.world.regions[int(capital.get("region", 0))].get("coast", false)
			if towns > 0
			else false
		),
		" version=",
		sim.geo.version
	)
	if sim.state.contract.licences.has("expedition") and towns == 1 and str(args.out) != "":
		print("LICENCE_SAVE saved='", sim.save_game(str(args.out)), "' to ", args.out)
	quit(0)
