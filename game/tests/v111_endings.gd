extends SceneTree
## 1.11 phase E: Annex VII and three endings.
## - the variant is drawn from the seed (the same seed, the same variant; a 1.10 save draws one);
## - sealed until stage four is accepted, then opened by the company's letter;
## - one answer: 照办, 周旋 or 公开 set the lean (loyal, buyout, autonomy) and move distrust and 民心;
## - each variant's rule: the terraforming bonus, the buyer taking two mines (unless the ore went
##   out), the secret found out or disclosed, the finds to the company or the public;
## - endings after the award: the buyout's price and the career fund, autonomy's terms (and the
##   disclosed path), the company's share and process ended; the loyal ending at the award; the
##   takeover;
## - the settlement statement, a save round trip, and the screens.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Rules = preload("res://simulation/rules.gd")
const Sim = preload("res://simulation/sim.gd")
const Annex = preload("res://simulation/annex.gd")
const Endings = preload("res://simulation/endings.gd")
const Contract = preload("res://simulation/contract.gd")
const Population = preload("res://simulation/population.gd")
const ContractPage = preload("res://ui/contract_page.gd")
const SettlementPage = preload("res://ui/settlement_page.gd")
const SEED: int = 20261029
const OLD_SAVE: String = "res://../docs/v17/placement/save_files/after-1.10.1.save"

var checks: int = 0
var failures: Array[String] = []


class FakeGame:
	extends Node
	var sim: RefCounted
	var acted: Array = []

	func act(action: String, args: Dictionary) -> String:
		acted.append([action, args])
		return sim.act(action, args)

	func open_page(_page: String) -> void:
		pass

	func close_modal() -> void:
		pass

	func populate_current_page() -> void:
		pass


func _initialize() -> void:
	Watchdog.arm(self, 900.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_drawn()
	_opening()
	_answers()
	_terraform()
	_rights_sale()
	_secret()
	_beneath()
	_buyout()
	_autonomy()
	_loyal_and_takeover()
	_saved()
	_screens()
	print("V111_ENDINGS_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)


func _colony(variant: String = "") -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(SEED, "capital", 1)
	for reg: Dictionary in sim.state.world.regions:
		if sim.settle_refusal(int(reg.id)) == "":
			sim.act("settle", {"region": int(reg.id)})
			break
	sim.state.events_v2.next_draw = 99999
	sim._transfer("external", "public", 300000.0, "TEST funds", false)
	if variant != "":
		sim.state.annex.variant = variant
	return sim


## Accepts stages one to `last` at once (their rewards paid, as in play).
func _accept(sim: RefCounted, last: int) -> void:
	for stage: int in range(int(sim.state.contract.stage), last + 1):
		Contract._complete_stage(sim, stage)


func _drawn() -> void:
	var one: RefCounted = _colony()
	var two: RefCounted = _colony()
	check(
		(
			str(one.state.annex.variant) in Annex.VARIANTS
			and str(one.state.annex.variant) == str(two.state.annex.variant)
		),
		"the same seed draws the same variant: %s" % str(one.state.annex.variant)
	)
	var seen: Dictionary = {}
	for offset: int in range(24):
		var state: Dictionary = {"world": {"seed": SEED + offset}}
		Annex.ensure_state(state)
		seen[str(state.annex.variant)] = true
	check(
		seen.size() == Annex.VARIANTS.size(),
		"every variant comes up over seeds: %s" % str(seen.keys())
	)
	var path: String = ProjectSettings.globalize_path(OLD_SAVE)
	if FileAccess.file_exists(path):
		var old: RefCounted = Sim.new()
		check(
			old.load_game(path) == "" and str(old.state.annex.variant) in Annex.VARIANTS,
			"a 1.10 save draws one on load: %s" % str(old.state.get("annex", {}).get("variant", ""))
		)


func _opening() -> void:
	var sim: RefCounted = _colony()
	_accept(sim, 3)
	check(not Annex.is_open(sim), "sealed through stage three")
	_accept(sim, 4)
	check(Annex.is_open(sim) and Annex.waiting(sim), "opened when stage four is accepted")
	var letter: Dictionary = sim.state.company.letters.back()
	check(
		str(letter.kind) == "annex_" + str(sim.state.annex.variant) and str(letter.note) != "",
		"by the company's letter, with the liaison's note"
	)
	var goal: String = ContractPage.annex_goal(Annex.variant_rule(sim))
	check(goal != "" and not goal.contains("{"), "its late goal is written from data: " + goal)


func _answers() -> void:
	var rule: Dictionary = Rules.read("contract").document.annex.answers
	for id: String in ["comply", "maneuver", "disclose"]:
		var sim: RefCounted = _colony()
		_accept(sim, 4)
		sim.state.company.distrust = 30.0
		var mood: float = Population.morale(sim)
		check(sim.act("annex_answer", {"answer": id}) == "", "answered %s" % id)
		check(
			str(sim.state.ending_lean) == str(Annex.ANSWERS[id]),
			"%s leans to %s" % [id, str(sim.state.ending_lean)]
		)
		check(
			is_equal_approx(float(sim.state.company.distrust), 30.0 + float(rule[id].distrust)),
			"and moves distrust by %+.0f" % float(rule[id].distrust)
		)
		var shift: float = float(rule[id].morale)
		check(
			is_equal_approx(Population.morale(sim), clampf(mood + shift, 0.0, 100.0)),
			"and 民心 by %+.0f" % shift
		)
		check(sim.act("annex_answer", {"answer": "comply"}) != "", "a second answer is refused")


func _terraform() -> void:
	var sim: RefCounted = _colony("terraform_trial")
	_accept(sim, 4)
	sim.act("annex_answer", {"answer": "comply"})
	var town: Dictionary = sim.state.settlements[0]
	town.buildings.append({"kind": "terraforming", "remaining": 0, "enabled": true, "level": 2})
	var rule: Dictionary = Annex.variant_rule(sim)
	var cash: float = float(sim.state.cash)
	sim.state.day = Contract.deadline(sim, Contract.STAGE_COUNT)
	Annex._terraform_bonus(sim, rule)
	check(
		is_equal_approx(float(sim.state.cash) - cash, 2.0 * float(rule.bonus_per_level)),
		"改造试验 pays per terraforming level on the last deadline"
	)
	town.buildings.pop_back()


func _mines(sim: RefCounted) -> void:
	var town: Dictionary = sim.state.settlements[0]
	for kind: String in ["mine_ore", "mine_ore_heavy", "mine_copper"]:
		var b: Dictionary = sim._building(kind, 0)
		b.remaining = 0
		b.uid = 9000 + town.buildings.size()
		town.buildings.append(b)


func _rights_sale() -> void:
	var sim: RefCounted = _colony("rights_sale")
	_accept(sim, 4)
	_mines(sim)
	var rule: Dictionary = Annex.variant_rule(sim)
	Annex._rights_sale(sim, rule)
	var sold: int = 0
	for b: Dictionary in sim.state.settlements[0].buildings:
		sold += 1 if bool(b.get("sold", false)) else 0
	check(sold == int(rule.mines), "矿权转卖: with no ore delivered, the buyer takes %d mines" % sold)
	var kept: RefCounted = _colony("rights_sale")
	_accept(kept, 4)
	_mines(kept)
	Annex.exported(kept, "ore", float(rule.ore))
	Annex.exported(kept, "copper", 99999.0)
	Annex._rights_sale(kept, rule)
	var none: int = 0
	for b: Dictionary in kept.state.settlements[0].buildings:
		none += 1 if bool(b.get("sold", false)) else 0
	check(none == 0, "with the ore exported (copper does not count), the mines stay")


func _secret() -> void:
	var sim: RefCounted = _colony("secret_station")
	_accept(sim, 4)
	sim.act("annex_answer", {"answer": "comply"})
	var rule: Dictionary = Annex.variant_rule(sim)
	var forced: Dictionary = rule.duplicate()
	forced.monthly_chance = 1.0
	var yard: Dictionary = sim._building("shipyard", 30)
	sim.state.settlements[0].buildings.append(yard)
	var before: float = float(sim.state.annex.morale_shift)
	Annex._secret_check(sim, forced)
	check(
		(
			bool(sim.state.annex.found_out)
			and is_equal_approx(
				float(sim.state.annex.morale_shift) - before, float(rule.found_morale)
			)
		),
		"秘密设施: the colonists find out while it is built, and 民心 falls"
	)
	var other: RefCounted = _colony("secret_station")
	_accept(other, 4)
	other.act("annex_answer", {"answer": "maneuver"})
	other.state.settlements[0].buildings.append(other._building("shipyard", 30))
	check(other.act("annex_disclose", {}) == "", "the contractor can disclose it")
	Annex._secret_check(other, forced)
	check(not bool(other.state.annex.found_out), "and then nobody has to find out")


func _beneath() -> void:
	var sim: RefCounted = _colony("beneath")
	_accept(sim, 4)
	sim.act("annex_answer", {"answer": "comply"})
	var rule: Dictionary = Annex.variant_rule(sim)
	sim.state.company.distrust = 20.0
	var cash: float = float(sim.state.cash)
	Annex._find(sim, rule)
	check(
		(
			is_equal_approx(float(sim.state.cash) - cash, float(rule.find_cash))
			and is_equal_approx(float(sim.state.company.distrust), 20.0 - float(rule.find_trust))
		),
		"地下的东西: a find for the company brings cash and trust"
	)
	check(sim.act("annex_finds", {"to": "public"}) == "", "the finds can go to the public")
	var shift: float = float(sim.state.annex.morale_shift)
	Annex._find(sim, rule)
	check(
		is_equal_approx(float(sim.state.annex.morale_shift) - shift, float(rule.find_morale)),
		"and then 民心 rises"
	)
	check(sim.audit().is_empty(), "the audit holds: %s" % str(sim.audit()))


func _buyout() -> void:
	var sim: RefCounted = _colony()
	check(sim.act("buyout", {}) != "", "no buyout before the award")
	_accept(sim, 5)
	check(str(sim.state.status) == "success", "the award")
	check(str(sim.state.ending.kind) == Endings.LOYAL, "is the loyal ending until another follows")
	var price: float = Endings.buyout_price(sim)
	var rule: Dictionary = Rules.read("career").buyout
	check(price >= float(rule.floor), "the price is at least the floor: ¥%.0f" % price)
	sim.state.career.balance = price * 0.5
	check(sim.act("buyout", {}).contains("不足"), "a fund short of the price is refused")
	sim.state.career.balance = price + 10.0
	check(sim.act("buyout", {}) == "", "a fund that covers it buys the company out")
	check(
		(
			str(sim.state.ending.kind) == Endings.BUYOUT
			and is_equal_approx(float(sim.state.career.balance), 10.0)
		),
		"paid from the career fund"
	)
	check(is_zero_approx(Contract.company_rate(sim)), "the company's share ends")
	sim.state.company.distrust = 50.0
	sim.tick()
	check(is_equal_approx(float(sim.state.company.distrust), 50.0), "and its process stops")
	check(sim.act("declare_autonomy", {}) != "", "one ending only")


func _autonomy() -> void:
	var sim: RefCounted = _colony()
	_accept(sim, 5)
	var terms: Dictionary = Endings.autonomy_terms(sim)
	check(
		not bool(terms.ok),
		(
			"a young colony cannot declare autonomy (民心 %.0f, %d people)"
			% [float(terms.morale), int(terms.population)]
		)
	)
	check(sim.act("declare_autonomy", {}) != "", "and is refused")
	var open: RefCounted = _colony()
	_accept(open, 4)
	open.act("annex_answer", {"answer": "disclose"})
	_accept(open, 5)
	open.state.annex.morale_shift = 100.0
	check(bool(Endings.autonomy_terms(open).ok), "after disclosing Annex VII, 民心 alone is enough")
	check(open.act("declare_autonomy", {}) == "", "autonomy is declared")
	check(
		(
			str(open.state.ending.kind) == Endings.AUTONOMY
			and is_zero_approx(Contract.company_rate(open))
		),
		"and the company's share ends"
	)


func _loyal_and_takeover() -> void:
	var sim: RefCounted = _colony()
	sim._fail("TEST takeover")
	check(str(sim.state.ending.kind) == Endings.TAKEOVER, "a takeover is recorded as the ending")
	var report: Dictionary = Endings.statement(sim)
	check(
		(
			report.stages.size() == Contract.STAGE_COUNT
			and str(report.ending.kind) == Endings.TAKEOVER
		),
		"and has its settlement statement"
	)


func _saved() -> void:
	var sim: RefCounted = _colony("beneath")
	_accept(sim, 4)
	sim.act("annex_answer", {"answer": "disclose"})
	check(sim.save_game("user://v111_endings.save") == "", "a game with Annex VII open saves")
	var again: RefCounted = Sim.new()
	check(again.load_game("user://v111_endings.save") == "", "and loads")
	check(
		str(again.state.annex.answer) == "disclose" and str(again.state.ending_lean) == "autonomy",
		"with its answer and lean"
	)
	check(again.audit().is_empty(), "the audit holds: %s" % str(again.audit()))


func _texts(box: Node) -> String:
	var texts: PackedStringArray = []
	for node: Node in box.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	for node: Node in box.find_children("*", "Button", true, false):
		texts.append((node as Button).text)
	return "\n".join(texts)


func _screens() -> void:
	var sim: RefCounted = _colony()
	var fake := FakeGame.new()
	fake.sim = sim
	root.add_child(fake)
	var box := VBoxContainer.new()
	fake.add_child(box)
	ContractPage.page(fake, box)
	check(_texts(box).contains("第四阶段验收后启封"), "the contract shows the annex sealed")
	box.queue_free()
	_accept(sim, 4)
	box = VBoxContainer.new()
	fake.add_child(box)
	ContractPage.page(fake, box)
	check(box.find_child("Annex_disclose", true, false) != null, "then its three answers")
	box.queue_free()
	_accept(sim, 5)
	box = VBoxContainer.new()
	fake.add_child(box)
	SettlementPage.page(fake, box)
	var shown: String = _texts(box)
	check(
		(
			shown.contains("结算单")
			and shown.contains("阶段")
			and box.find_child("EndingBuyout", true, false) != null
		),
		"the award's settlement statement offers the endings that can follow"
	)
	fake.queue_free()
