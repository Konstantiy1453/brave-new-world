extends SceneTree
## 1.11 phase H: the merged technologies.
## - conservation: every effect key adds up to what it did before the merge (frozen content left
##   out), and a merged technology costs its parts x merge_cost_factor;
## - every technology's requirements exist, none loops, every researchable one can be reached;
## - saves: a merged technology is finished when all its parts were, otherwise their points are
##   its progress; projects and offers move to it; the converted state validates and reloads;
## - the contract's tier goals count technologies at a tier or above; bots read old ids.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Rules = preload("res://simulation/rules.gd")
const Sim = preload("res://simulation/sim.gd")
const Research = preload("res://simulation/research.gd")
const Contract = preload("res://simulation/contract.gd")
const Features = preload("res://simulation/features.gd")
const Labels = preload("res://ui/labels.gd")
const Bot = preload("res://tests/balance/bots/bot.gd")
const SEED: int = 20261125
## Every effect key's total over the technologies before the merge (techs.json at 4a4e12d,
## nickel_metallurgy, superalloys and seabed_mining left out as frozen), with J's rebalance on top:
## the later mine bonuses cut (mine_output 0.75 to 0.55, mine_jobs -0.65 to -0.35, DECISIONS.md).
const TOTALS: Dictionary = {
	"absorption": 2.3,
	"admin": -0.15,
	"alloy_output": 0.2,
	"appeal": 0.42,
	"births": 0.3,
	"build_cost": -0.18,
	"build_speed": 0.6,
	"cleanup_cost": -0.5,
	"closure": -0.3,
	"copper_output": 0.15,
	"crystal_output": 0.55,
	"departure": 0.5,
	"expedition_cost": -0.25,
	"export_price": 0.1,
	"factory_jobs": -0.75,
	"factory_output": 0.65,
	"farm_output": 1.4,
	"farm_water": -0.3,
	"food_need": -0.1,
	"foodworks": 0.25,
	"frontier_output": 0.1,
	"great_cost": -0.15,
	"great_speed": 0.25,
	"hydro_output": 0.5,
	"immigration": 0.5,
	"market_depth": 1.0,
	"mine_jobs": -0.35,
	"mine_output": 0.55,
	"mine_upkeep": -0.2,
	"offers": 1.0,
	"offshore_survey": 0.5,
	"ore_output": 0.15,
	"pollution": -0.68,
	"port_capacity": 0.4,
	"power_output": 0.4,
	"power_use": -0.53,
	"processor_output": 0.3,
	"recruit_price": -0.2,
	"research_speed": 0.8,
	"road_build": 0.8,
	"road_capacity": 1.1,
	"road_cost": -0.2,
	"road_speed": 0.7,
	"sea_capacity": 1.2,
	"sea_speed": 0.75,
	"survey_cost": -0.2,
	"training_speed": 1.0,
	"transport_fee": -0.2,
	"upkeep": -0.2,
	"water_output": 0.1,
	"water_use": -0.35,
	"weather_losses": -0.3,
	"weather_warning": 2.0,
}

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	Watchdog.arm(self, 600.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_conservation()
	_reachable()
	_migration()
	_goals()
	_bots()
	print("V111_TECHS_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _frozen() -> Dictionary:
	var out: Dictionary = {}
	for content: Dictionary in Rules.read("progression").features.get("content", {}).values():
		for key: Variant in content.get("techs", []):
			out[str(key)] = true
	return out


func _conservation() -> void:
	var data: Dictionary = Rules.read("techs")
	var frozen: Dictionary = _frozen()
	var totals: Dictionary = {}
	for key: String in data.techs:
		if frozen.has(key):
			continue
		var effects: Dictionary = data.techs[key].get("effects", {})
		for name: String in effects:
			totals[name] = float(totals.get(name, 0.0)) + float(effects[name])
	var wrong: Array = []
	for name: String in TOTALS:
		if absf(float(totals.get(name, 0.0)) - float(TOTALS[name])) > 0.000001:
			wrong.append("%s %s != %s" % [name, totals.get(name, 0.0), TOTALS[name]])
	for name: String in totals:
		if not TOTALS.has(name):
			wrong.append("new key " + name)
	check(wrong.is_empty(), "every effect adds up to what it did before the merge: %s" % str(wrong))
	var priced: bool = true
	var merged: int = 0
	for key: String in data.techs:
		var tech: Dictionary = data.techs[key]
		if not tech.has("merged_from"):
			continue
		merged += 1
		var parts: float = 0.0
		for part: String in tech.merged_from:
			parts += float(tech.part_costs[part])
		priced = priced and absf(float(tech.cost) - parts * float(data.merge_cost_factor)) < 0.11
	check(
		priced and merged > 0,
		"%d merged technologies cost their parts x %.1f" % [merged, float(data.merge_cost_factor)]
	)
	var researchable: int = 0
	for key: String in data.techs:
		if not bool(data.techs[key].get("gift", false)) and not frozen.has(key):
			researchable += 1
	print("  technologies: %d, researchable %d" % [data.techs.size(), researchable])
	check(data.techs.size() < 136, "fewer technologies than the 136 before")


func _reachable() -> void:
	var techs: Dictionary = Rules.read("techs").techs
	var frozen: Dictionary = _frozen()
	var missing: Array = []
	for key: String in techs:
		for need: Variant in techs[key].get("requires", []):
			if not techs.has(str(need)):
				missing.append("%s needs %s" % [key, need])
	check(missing.is_empty(), "every requirement exists: %s" % str(missing))
	var reached: Dictionary = {}
	var grew: bool = true
	while grew:
		grew = false
		for key: String in techs:
			if reached.has(key) or bool(techs[key].get("gift", false)):
				continue
			var ready: bool = true
			for need: Variant in techs[key].get("requires", []):
				ready = ready and reached.has(str(need))
			if ready:
				reached[key] = true
				grew = true
	var stuck: Array = []
	for key: String in techs:
		if not bool(techs[key].get("gift", false)) and not frozen.has(key) and not reached.has(key):
			stuck.append(key)
	check(
		stuck.is_empty(),
		"every researchable technology can be reached, none loops: %s" % str(stuck)
	)


func _colony() -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1)
	for reg: Dictionary in sim.state.world.regions:
		if sim.settle_refusal(int(reg.id)) == "":
			sim.act("settle", {"region": int(reg.id)})
			break
	sim.state.events_v2.next_draw = 99999
	return sim


func _migration() -> void:
	var data: Dictionary = Rules.read("techs")
	var farming: Dictionary = data.techs.agriculture_1_merged
	var building: Dictionary = data.techs.construction_1_merged
	var sim: RefCounted = _colony()
	var r: Dictionary = sim.state.research
	var farm_before: float = Research.bonus(sim, "farm_output")
	r.completed.append_array(farming.merged_from)
	r.completed.append_array(["prefab_modules", "survey_drones"])
	r.projects["road_crews"] = {"staff": 4, "work": 50.0, "effective": 0, "rate": 0.0, "reason": ""}
	r.offers["industry"] = ["ore_sorting", "survey", "drill_bits"]
	check(
		Research.validate(sim, sim.state) == "", "an old save naming merged parts still validates"
	)
	Research.convert_merged(sim.state)
	check(
		r.completed.has("agriculture_1_merged") and not r.completed.has("irrigation"),
		"all its parts finished: the merged technology is finished"
	)
	var points: float = (
		float(building.part_costs.prefab_modules) + float(building.part_costs.survey_drones) + 50.0
	)
	var project: Dictionary = r.projects.get("construction_1_merged", {})
	check(
		(
			not r.completed.has("construction_1_merged")
			and not project.is_empty()
			and is_equal_approx(float(project.work), minf(points, float(building.cost) - 1.0))
			and int(project.staff) == 4
			and not r.projects.has("road_crews")
		),
		"some parts finished: their points and the running part's work are its progress"
	)
	check(
		r.offers.industry == ["industry_1_merged", "survey"],
		"offers name the merged technology once: %s" % str(r.offers.industry)
	)
	check(
		r.offers.construction.has("construction_1_merged"),
		"a converted project's card is on the table: %s" % str(r.offers.construction)
	)
	check(
		Research.allocate(sim, "construction_1_merged", 4) == "", "so a team can take it up again"
	)
	sim.tech_effects_count = -1
	check(
		is_equal_approx(
			Research.bonus(sim, "farm_output") - farm_before,
			float(farming.effects.get("farm_output", 0.0))
		),
		"and the finished group's effects apply"
	)
	check(Research.validate(sim, sim.state) == "", "the converted state validates")
	var bytes: PackedByteArray = var_to_bytes(r)
	Research.convert_merged(sim.state)
	check(var_to_bytes(r) == bytes, "converting again changes nothing")
	check(sim.save_game("user://v111_techs.save") == "", "it saves")
	var again: RefCounted = Sim.new()
	check(
		(
			again.load_game("user://v111_techs.save") == ""
			and var_to_bytes(again.state.research) == var_to_bytes(sim.state.research)
		),
		"and reloads as it was"
	)
	check(
		(
			Research.current_id("field_notes") == "society_1_merged"
			and Research.current_id("survey") == "survey"
		),
		"an old id reads as the technology that replaced it; a kept one as itself"
	)


func _goals() -> void:
	var sim: RefCounted = _colony()
	sim.state.research.completed.append_array(["agriculture_2_merged", "survey"])
	var tiers: int = Research.researched_from_tier(sim.state, 2)
	check(
		int(Contract.goal_value(sim, "techs_tier_2")) == tiers and tiers >= 1,
		"a tier goal counts technologies at that tier or above (%d)" % tiers
	)
	var text: String = str(Labels.goal({"key": "techs_tier_2", "value": 1, "target": 3}).text)
	check(text.contains("2 级及以上"), "and says so: " + text)


func _bots() -> void:
	var bot: RefCounted = Bot.new()
	var order: Array[String] = ["survey", "irrigation", "education"]
	check(
		bot.tech_rank(order, "agriculture_1_merged") == 1 and bot.tech_rank(order, "survey") == 0,
		"a bot's plan reads old ids as the merged technology"
	)
