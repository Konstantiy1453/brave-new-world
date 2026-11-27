extends RefCounted
## Annex VII (1.11 E): a sealed annex to the contract, its variant drawn from the seed when the game
## starts (old saves draw it on load), opened by the company's letter when stage four is accepted.
## The contractor answers once: 照办 (comply), 周旋 (manoeuvre) or 公开 (disclose). The answer sets
## the ending the colony leans to (loyal, buyout, autonomy), adds the variant's late goal to the
## contract, and moves distrust and 民心 by amounts in contract.json `document.annex`. Each
## variant asks for one great work and has one rule of its own:
## - terraform_trial: a bonus per terraforming level finished by the last stage's deadline;
## - rights_sale: a year after opening, the buyer takes the two most productive mines, unless the
##   stated ore has been exported since or the exchange stands;
## - secret_station: while the shipyard is being built and not disclosed, a monthly chance the
##   colonists find out (民心 falls); disclosing ends the checks;
## - beneath: monthly finds from the dig go to the company (cash, trust) or to the public (民心,
##   research), as the contractor directs.
## The stories tied to the variant come more often once it is open.

const Rules = preload("res://simulation/rules.gd")
const Megaprojects = preload("res://simulation/megaprojects.gd")
const VARIANTS: Array[String] = ["terraform_trial", "rights_sale", "secret_station", "beneath"]
const ANSWERS: Dictionary = {"comply": "loyal", "maneuver": "buyout", "disclose": "autonomy"}
const OPEN_STAGE: int = 4


static func rules(sim: RefCounted) -> Dictionary:
	return sim.contract_rules.get("document", {}).get("annex", {})


static func ensure_state(state: Dictionary) -> void:
	if state.has("annex"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:annex" % str(state.get("world", {}).get("seed", 0)))
	state.annex = {
		"variant": VARIANTS[rng.randi_range(0, VARIANTS.size() - 1)],
		"opened_day": -1,
		"answer": "",
		"answered_day": -1,
		"ore_exported": 0.0,
		"mines_taken": false,
		"found_out": false,
		"disclosed": false,
		"finds": 0,
		"finds_to": "company",
		"bonus_paid": 0.0,
		"morale_shift": 0.0,
	}
	if not state.has("ending_lean"):
		state.ending_lean = ""


static func variant_rule(sim: RefCounted) -> Dictionary:
	return rules(sim).get("variants", {}).get(str(sim.state.annex.variant), {})


static func is_open(sim: RefCounted) -> bool:
	return int(sim.state.get("annex", {}).get("opened_day", -1)) >= 0


static func waiting(sim: RefCounted) -> bool:
	return is_open(sim) and str(sim.state.annex.answer) == ""


## Stage four is accepted: the annex is opened by the company's letter.
static func open(sim: RefCounted) -> void:
	ensure_state(sim.state)
	if is_open(sim):
		return
	sim.state.annex.opened_day = int(sim.state.day)
	sim.Company.letter(sim, "annex_" + str(sim.state.annex.variant), {})
	sim._log("附件七启封：%s" % str(variant_rule(sim).get("title", "")))


## The contractor's one answer. Returns the refusal, "" when given.
static func answer(sim: RefCounted, choice: String) -> String:
	ensure_state(sim.state)
	if not is_open(sim):
		return "附件七尚未启封"
	if str(sim.state.annex.answer) != "":
		return "附件七已经答复"
	if not ANSWERS.has(choice):
		return "无效的答复"
	var a: Dictionary = sim.state.annex
	var moves: Dictionary = rules(sim).get("answers", {}).get(choice, {})
	a.answer = choice
	a.answered_day = int(sim.state.day)
	sim.state.ending_lean = str(ANSWERS[choice])
	sim.Company.apply_distrust(sim, float(moves.get("distrust", 0.0)))
	a.morale_shift = float(a.morale_shift) + float(moves.get("morale", 0.0))
	if choice == "disclose":
		a.disclosed = true
		a.finds_to = "public"
	sim._log("附件七答复：%s" % str(moves.get("name", choice)))
	return ""


## Where the dig's finds go (beneath): "company" or "public".
static func direct_finds(sim: RefCounted, to: String) -> String:
	ensure_state(sim.state)
	if not to in ["company", "public"]:
		return "无效的去向"
	sim.state.annex.finds_to = to
	return ""


## The secret made public by the contractor (secret_station): the checks end.
static func disclose(sim: RefCounted) -> String:
	ensure_state(sim.state)
	if not is_open(sim) or str(sim.state.annex.variant) != "secret_station":
		return "没有可以公开的设施"
	if bool(sim.state.annex.disclosed):
		return "已经公开"
	sim.state.annex.disclosed = true
	sim.state.annex.morale_shift = (
		float(sim.state.annex.morale_shift) + float(variant_rule(sim).get("disclose_morale", 0.0))
	)
	sim._log("秘密设施已向居民公开。")
	return ""


## Ore exported since the annex opened (rights_sale): Logistics books every export through here.
static func exported(sim: RefCounted, good: String, amount: float) -> void:
	var a: Dictionary = sim.state.get("annex", {})
	if a.is_empty() or int(a.opened_day) < 0 or good != "ore":
		return
	a.ore_exported = float(a.ore_exported) + amount


## Each day after opening: the variant's own rule.
static func daily(sim: RefCounted) -> void:
	ensure_state(sim.state)
	if not is_open(sim):
		return
	var a: Dictionary = sim.state.annex
	var rule: Dictionary = variant_rule(sim)
	var since: int = int(sim.state.day) - int(a.opened_day)
	var month: int = int(Rules.read("career").calendar.month_days)
	match str(a.variant):
		"terraform_trial":
			_terraform_bonus(sim, rule)
		"rights_sale":
			if since == int(rule.get("buyer_days", 360)) and not bool(a.mines_taken):
				_rights_sale(sim, rule)
		"secret_station":
			if since > 0 and since % month == 0:
				_secret_check(sim, rule)
		"beneath":
			if since > 0 and since % month == 0:
				_find(sim, rule)


## terraform_trial: on the last stage's deadline, a bonus per terraforming level then standing.
static func _terraform_bonus(sim: RefCounted, rule: Dictionary) -> void:
	var a: Dictionary = sim.state.annex
	if float(a.bonus_paid) > 0.0:
		return
	if int(sim.state.day) != sim.Contract.deadline(sim, sim.Contract.STAGE_COUNT):
		return
	var levels: int = Megaprojects.level(sim, "terraforming")
	var bonus: float = float(rule.get("bonus_per_level", 0.0)) * levels
	if bonus <= 0.0:
		a.bonus_paid = -1.0
		return
	sim._transfer("external", "public", bonus, "annex.bonus", false)
	a.bonus_paid = bonus
	sim._log("改造试验：%d 级改造如期完成，公司支付奖金 ¥%.0f。" % [levels, bonus])


## rights_sale: unless the ore was delivered or the exchange stands, the buyer takes the two mines
## that produce the most.
static func _rights_sale(sim: RefCounted, rule: Dictionary) -> void:
	var a: Dictionary = sim.state.annex
	a.mines_taken = true
	if float(a.ore_exported) >= float(rule.get("ore", 0.0)) or Megaprojects.active(sim, "exchange"):
		a.mines_taken = false
		sim._log("矿权转卖：买方已收到约定的矿石，矿场保留。")
		return
	var mines: Array = []
	for s: Dictionary in sim.state.settlements:
		for index: int in range(s.buildings.size()):
			var b: Dictionary = s.buildings[index]
			if sim.Production.role_of(sim, b.kind) == "mine" and int(b.remaining) <= 0:
				var rate: float = float(sim.config.buildings[b.kind].get("rate", 0.0))
				mines.append([rate, int(s.region), int(b.get("uid", -1))])
	mines.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var taken: int = 0
	for row: Array in mines.slice(0, int(rule.get("mines", 2))):
		var s: Dictionary = sim.settlement(int(row[1]))
		for index: int in range(s.buildings.size()):
			if int(s.buildings[index].get("uid", -2)) == int(row[2]):
				s.buildings[index].enabled = false
				s.buildings[index].sold = true
				taken += 1
				break
	sim._log("矿权转卖：买方接手了 %d 座产量最高的矿场。" % taken)


## secret_station: while the shipyard is being built and nothing is disclosed, a chance each month
## that the colonists find out.
static func _secret_check(sim: RefCounted, rule: Dictionary) -> void:
	var a: Dictionary = sim.state.annex
	if bool(a.disclosed) or bool(a.found_out) or not _building(sim, "shipyard"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:secret:%d" % [str(sim.state.world.seed), int(sim.state.day)])
	if rng.randf() >= float(rule.get("monthly_chance", 0.0)):
		return
	a.found_out = true
	a.morale_shift = float(a.morale_shift) + float(rule.get("found_morale", 0.0))
	sim._log("居民发现了轨道上的秘密设施，民心下降。")


static func _building(sim: RefCounted, kind: String) -> bool:
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if str(b.kind) == kind and int(b.remaining) > 0:
				return true
	return false


## beneath: a find each month while the annex is open; to the company it is cash and trust, to the
## public 民心 and research.
static func _find(sim: RefCounted, rule: Dictionary) -> void:
	var a: Dictionary = sim.state.annex
	if int(a.finds) >= int(rule.get("finds", 0)):
		return
	a.finds = int(a.finds) + 1
	if str(a.finds_to) == "public":
		a.morale_shift = float(a.morale_shift) + float(rule.get("find_morale", 0.0))
		sim.Research.add_progress(sim, float(rule.get("find_research", 0.0)))
		sim._log("地下的发现向居民公开：民心与科研各有所得。")
		return
	sim._transfer("external", "public", float(rule.get("find_cash", 0.0)), "annex.finds", false)
	sim.Company.apply_distrust(sim, -float(rule.get("find_trust", 0.0)))
	sim._log("地下的发现交给了公司：资金到账，公司更信任你。")


## Weight on the stories tied to the open annex.
static func event_weight(sim: RefCounted, id: String) -> float:
	if not is_open(sim):
		return 1.0
	if id in variant_rule(sim).get("events", []):
		return float(rules(sim).get("event_weight", 1.0))
	return 1.0


static func view(sim: RefCounted) -> Dictionary:
	ensure_state(sim.state)
	var a: Dictionary = sim.state.annex.duplicate(true)
	a.rule = variant_rule(sim)
	a.open = is_open(sim)
	a.waiting = waiting(sim)
	return a


static func validate(_sim: RefCounted, candidate: Dictionary) -> String:
	var annex: Variant = candidate.get("annex")
	if not annex is Dictionary:
		return "存档缺少附件七"
	for key: String in ["variant", "opened_day", "answer", "ore_exported", "morale_shift"]:
		if not annex.has(key):
			return "附件七缺少字段：" + key
	if not str(annex.variant) in VARIANTS:
		return "附件七类型无效"
	return ""
