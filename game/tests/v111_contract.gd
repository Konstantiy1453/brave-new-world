extends SceneTree
## 1.11 phase B: the contract as a document, the company's voice, two meters, two names.
## - the clauses are contract.json `document` in order, numbered, every {placeholder} filled from
##   the rules (deadlines, rewards, overdue distrust, the rating bands, thresholds, windows, the
##   post-award share), and a number changed in data changes the clause;
## - the contract page shows the title with the code, the clauses as 第 N 条, a stamp with its date on
##   each accepted stage, the amendments (none yet) and the sealed Annex VII;
## - company letters are structured (department, subject, CC, body, the liaison's note) from
##   letters.json, name the project by its code, leave no placeholder and log their arrival; the
##   aid letter carries the terms; letters from before 1.11 gain the fields, and a state with them
##   and no code passes the save check after the upgrade every old save goes through;
## - the rating is A-D by the bands in data; 民心 is the population-weighted appeal mapped to 0-100
##   by population.json `morale`, 50 with nobody landed, and the services budget raises it;
## - a new game gets CC-NN from its seed, a 1.10 save gets the same on load, and both survive a save;
## - the HUD pair shows the letter (the number on hover) and 民心, and each half opens its page;
## - the sound cues stub hears a letter and a stamp, and takes only note at the first look;
## - event text names the project by {code} and the colony by {capital} and nothing else; the event
##   view fills both, and the ten events reworded in the company's register keep their mechanics.

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Company = preload("res://simulation/company.gd")
const Contract = preload("res://simulation/contract.gd")
const Population = preload("res://simulation/population.gd")
const Rules = preload("res://simulation/rules.gd")
const SaveIo = preload("res://simulation/save_io.gd")
const ContractPage = preload("res://ui/contract_page.gd")
const LettersView = preload("res://ui/letters_view.gd")
const Gauge = preload("res://ui/distrust_gauge.gd")
const Cues = preload("res://ui/cues.gd")
const Labels = preload("res://ui/labels.gd")
const Events = preload("res://simulation/events_v2.gd")
const SEED: int = 20261029
const OLD_SAVE: String = "res://../docs/v17/placement/save_files/after-1.10.1.save"
const LETTER_FIELDS: Array[String] = ["department", "subject", "cc", "body", "note"]
## The ten events whose wording follows the company's register (1.11 B).
const REWORDED: Array[String] = [
	"company_audit",
	"vp_visit",
	"new_tax_letter",
	"ledger_hole",
	"second_ship",
	"industry",
	"price_window",
	"investor_offer",
	"supply_delay",
	"nw_d_empty_seat",
]

var checks: int = 0
var failures: Array[String] = []


class FakeGame:
	extends Node
	var sim: RefCounted
	var opened: String = ""

	func open_page(page: String) -> void:
		opened = page

	func close_modal() -> void:
		pass


func _initialize() -> void:
	Watchdog.arm(self, 600.0)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func run() -> void:
	_clauses()
	_page_and_stamps()
	_letters()
	_old_letters()
	_rating()
	_morale()
	_code()
	_gauge()
	_cues()
	_event_voice()
	print(
		"V111_CONTRACT_RESULT checks=%d failures=%d %s" % [checks, failures.size(), str(failures)]
	)
	quit(0 if failures.is_empty() else 1)


func _colony(seed_value: int = SEED) -> RefCounted:
	var sim: RefCounted = Sim.new()
	sim.new_game(seed_value, "capital", 1)
	sim.act("settle", {"region": 0})
	sim.state.events_v2.next_draw = 99999
	return sim


func _clauses() -> void:
	var sim: RefCounted = _colony()
	var rule: Dictionary = sim.contract_rules.document
	var rows: Array = ContractPage.clauses(sim)
	var origin: Array = sim.config.openings[str(sim.state.advantage)].get("clauses", [])
	check(
		rows.size() == rule.clauses.size() + origin.size() and rows.size() >= 8,
		"every standard clause and the origin's are written: %d" % rows.size()
	)
	var numbered: bool = true
	var filled: bool = true
	var by_id: Dictionary = {}
	for index: int in range(rows.size()):
		numbered = numbered and int(rows[index].number) == index + 1
		filled = filled and not str(rows[index].text).contains("{")
		by_id[str(rows[index].id)] = str(rows[index].text)
	check(numbered, "numbered in order")
	check(filled, "with every placeholder filled")
	var cfg: Dictionary = sim.progression.company
	var diff: Dictionary = sim.progression.difficulty.normal
	var review: String = str(by_id.get("review", ""))
	var bands: bool = true
	for value: float in [
		float(cfg.rating_a_below),
		float(cfg.review_threshold),
		float(cfg.intervention_threshold),
		float(diff.warning)
	]:
		bands = bands and review.contains("%.0f" % value)
	check(bands, "the review clause names the bands and thresholds in data: " + review)
	check(
		(
			review.contains("%d 日" % int(diff.review_days))
			and review.contains("%d 日" % int(diff.intervention_days))
		),
		"and the windows of the difficulty"
	)
	check(
		str(by_id.get("overdue", "")).contains(str(sim.contract_rules.overdue_distrust_per_day)),
		"the overdue clause names the daily distrust: " + str(by_id.get("overdue", ""))
	)
	var share: float = float(Rules.read("career").management.player_share)
	check(
		str(by_id.get("share", "")).contains("%.0f%%" % (share * 100.0)),
		"the share clause names the post-award share"
	)
	var dated: bool = true
	var paid: bool = true
	for index: int in range(Contract.STAGE_COUNT):
		dated = (
			dated
			and str(by_id.get("stages", "")).contains(
				Labels.date(Contract.deadline(sim, index + 1))
			)
		)
		var reward: float = float(sim.contract_rules.stages[index].reward_cash)
		if reward > 0.0:
			paid = paid and str(by_id.get("rewards", "")).contains("¥ %.0f" % reward)
	check(dated, "the stages clause gives every deadline")
	check(paid, "the rewards clause every reward")
	var before: float = float(cfg.review_threshold)
	cfg.review_threshold = 47.0
	var moved: bool = false
	for row: Dictionary in ContractPage.clauses(sim):
		moved = moved or (str(row.id) == "review" and str(row.text).contains("47"))
	cfg.review_threshold = before
	check(moved, "a threshold changed in data changes the clause")
	var title: String = ContractPage.title(sim)
	check(
		title.begins_with(str(sim.state.contract.code)) and title.contains("对赌协议"),
		"the title names the project by its code: " + title
	)


func _page_texts(sim: RefCounted) -> String:
	var fake := FakeGame.new()
	fake.sim = sim
	var box := VBoxContainer.new()
	root.add_child(box)
	ContractPage.page(fake, box)
	var texts: PackedStringArray = []
	for label: Node in box.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	box.queue_free()
	fake.free()
	return "\n".join(texts)


func _page_and_stamps() -> void:
	var sim: RefCounted = _colony()
	var page: String = _page_texts(sim)
	check(page.contains(ContractPage.title(sim)), "the page carries the title")
	var clauses: int = sim.contract_rules.document.clauses.size()
	check(page.contains("第 1 条") and page.contains("第 %d 条" % clauses), "the clauses as 第 N 条")
	var stamp: String = str(sim.contract_rules.document.stamp)
	check(not page.contains(stamp + " ·"), "no stamp before a stage is accepted")
	check(page.contains("暂无补充协议"), "no amendments yet")
	check(page.contains("附件七") and page.contains("启封"), "Annex VII, sealed")
	for _day: int in range(3):
		sim.tick()
	Contract._complete_stage(sim, 1)
	page = _page_texts(sim)
	var day: int = int(sim.state.contract.completed["1"])
	check(
		page.contains("%s · %s" % [stamp, Labels.short_date(day)]),
		"stage one carries the stamp and its date once accepted"
	)
	check(Contract.document(sim).stages[0].accepted == day, "the document gives the acceptance day")


func _letters() -> void:
	var sim: RefCounted = _colony()
	var code: String = str(sim.state.contract.code)
	var book: Dictionary = Rules.read("letters")
	Company.transition(sim, "review", int(sim.progression.difficulty.normal.review_days), "review")
	var letter: Dictionary = sim.state.company.letters.back()
	var template: Dictionary = book.letters.review
	check(
		str(letter.department) == str(book.departments[template.department]),
		"a review letter comes from %s" % str(letter.department)
	)
	check(
		str(letter.subject).contains(code), "its subject names the project: " + str(letter.subject)
	)
	var copied: bool = true
	for department: String in template.cc:
		copied = copied and str(book.departments[department]) in letter.cc
	check(copied and not letter.cc.is_empty(), "it copies in the departments: %s" % str(letter.cc))
	check(
		(
			str(letter.body).contains("%.0f" % float(sim.progression.company.review_threshold))
			and str(letter.body).contains("%d" % int(sim.state.company.deadline))
		),
		"its body gives the threshold and the deadline day"
	)
	check(str(letter.note) != "", "and the liaison adds a note")
	var logged: bool = false
	for line: Variant in sim.state.log:
		logged = logged or str(line).contains("公司来信 · %s：" % str(letter.department))
	check(logged, "its arrival is logged")
	var values: Dictionary = {
		"aid_name": "测试援助", "arrival_days": 2, "repayment": "100", "surcharge_pct": "8"
	}
	var clean: bool = true
	for kind: String in book.letters:
		Company.letter(sim, kind, values)
		var made: Dictionary = sim.state.company.letters.back()
		for field: String in ["subject", "body", "note"]:
			clean = clean and not str(made[field]).contains("{")
		clean = clean and str(made.department) != "" and str(made.kind) == kind
	check(clean, "every letter of letters.json is written with no placeholder left")
	sim.state.company.stage = "warning"
	var offer: Dictionary = sim.progression.company.offers.liquidity
	check(Company.accept(sim, "liquidity") == "", "an aid offer is signed")
	var aid: Dictionary = sim.state.company.letters.back()
	check(
		(
			str(aid.kind) == "aid_signed"
			and str(aid.body).contains(str(offer.name))
			and str(aid.body).contains("%.0f" % float(offer.repayment))
			and str(aid.body).contains("%.0f%%" % (float(offer.surcharge) * 100.0))
		),
		"and its letter carries the terms: " + str(aid.body)
	)
	Company.letter(sim, "no_such_kind", {"reason": "一行旧式通知"})
	var plain: Dictionary = sim.state.company.letters.back()
	check(
		str(plain.subject) == "一行旧式通知" and str(plain.body) == "一行旧式通知",
		"a kind with no template still makes a letter of its line"
	)
	var fake := FakeGame.new()
	fake.sim = sim
	var box := VBoxContainer.new()
	root.add_child(box)
	LettersView.list(fake, box, sim.state.company.letters)
	var shown: PackedStringArray = []
	for label: Node in box.find_children("*", "Label", true, false):
		shown.append((label as Label).text)
	box.queue_free()
	fake.free()
	var listing: String = "\n".join(shown)
	check(
		(
			listing.contains(str(aid.subject))
			and listing.contains("抄送：")
			and listing.contains("联络人附言")
		),
		"the company page lists them with copies and the liaison's note"
	)


func _old_letters() -> void:
	var state: Dictionary = {
		"company":
		{"letters": [{"day": 3, "kind": "review", "reason": "正式整改：解决当前原因。", "deadline": 40}]}
	}
	Company.ensure_state(state)
	var letter: Dictionary = state.company.letters[0]
	var fields: bool = true
	for field: String in LETTER_FIELDS:
		fields = fields and letter.has(field)
	check(fields, "a letter from before 1.11 gains the structured fields")
	check(
		str(letter.subject) == "正式整改：解决当前原因。" and str(letter.body) == str(letter.subject),
		"its one line becomes subject and body"
	)
	# A save from before 1.11 holds one-line letters and no company code: the upgrade every old save
	# goes through on load (ensure_systems) makes it pass the save check.
	var sim: RefCounted = _colony()
	Company.transition(sim, "warning", 0, "warning")
	Company.transition(sim, "review", 30, "review")
	var candidate: Dictionary = sim.state.duplicate(true)
	for entry: Dictionary in candidate.company.letters:
		for field: String in LETTER_FIELDS:
			entry.erase(field)
	candidate.contract.erase("code")
	check(
		SaveIo.validate(sim, candidate) != "",
		"the save check refuses them as they are (the validator knows the new fields)"
	)
	Sim.ensure_systems(candidate)
	check(
		SaveIo.validate(sim, candidate) == "",
		"a state with one-line letters and no code passes the save check once upgraded"
	)
	var upgraded: bool = true
	for entry: Dictionary in candidate.company.letters:
		upgraded = upgraded and str(entry.subject) == str(entry.reason) and entry.cc is Array
	check(
		upgraded and candidate.company.letters.size() == 2,
		"its %d letters keep their line as subject" % candidate.company.letters.size()
	)
	check(
		str(candidate.contract.code) == Contract.code_for(candidate),
		"and it gets the code of its seed"
	)


func _rating() -> void:
	var sim: RefCounted = _colony()
	var cfg: Dictionary = sim.progression.company
	var a: float = float(cfg.rating_a_below)
	var review: float = float(cfg.review_threshold)
	var intervention: float = float(cfg.intervention_threshold)
	var cases: Array = [
		[0.0, "A"],
		[a - 0.1, "A"],
		[a, "B"],
		[review - 0.1, "B"],
		[review, "C"],
		[intervention - 0.1, "C"],
		[intervention, "D"],
		[100.0, "D"],
	]
	var wrong: Array = []
	for row: Array in cases:
		sim.state.company.distrust = float(row[0])
		if Company.rating(sim) != str(row[1]):
			wrong.append("%.1f -> %s" % [float(row[0]), Company.rating(sim)])
	check(wrong.is_empty(), "the rating follows the bands in data (A < %.0f): %s" % [a, str(wrong)])


func _morale() -> void:
	var empty: RefCounted = Sim.new()
	empty.new_game(SEED, "capital", 1)
	check(is_equal_approx(Population.morale(empty), 50.0), "民心 is 50 before anyone has landed")
	var sim: RefCounted = _colony()
	for _day: int in range(20):
		sim.tick()
	var rule: Dictionary = sim.pop_rules.morale
	var people: float = 0.0
	var weighted: float = 0.0
	for s: Dictionary in sim.state.settlements:
		if int(s.arrival) > 0 or int(s.population) <= 0:
			continue
		people += float(s.population)
		weighted += float(Population.attractiveness(sim, s).value) * float(s.population)
	var span: float = float(rule.appeal_ceiling) - float(rule.appeal_floor)
	var expected: float = (
		clampf((weighted / people - float(rule.appeal_floor)) / span, 0.0, 1.0) * 100.0
	)
	var mood: float = Population.morale(sim)
	check(
		is_equal_approx(mood, expected) and mood >= 0.0 and mood <= 100.0,
		"民心 is the population-weighted appeal mapped to 0-100: %.1f" % mood
	)
	var ceiling: float = float(rule.appeal_ceiling)
	rule.appeal_ceiling = float(rule.appeal_floor) + span * 2.0
	var wider: float = Population.morale(sim)
	rule.appeal_ceiling = ceiling
	check(
		is_equal_approx(wider, clampf(expected / 2.0, 0.0, 100.0)),
		"the mapping is the one in population.json: %.1f with a range twice as wide" % wider
	)
	sim.state.policy.services = int(sim.pop_rules.services.levels)
	sim.state.policy.services_paid_day = int(sim.state.day)
	check(
		Population.morale(sim) > mood,
		"the services budget raises it: %.1f" % Population.morale(sim)
	)


func _code() -> void:
	var sim: RefCounted = _colony()
	var expected: String = "CC-%02d" % (posmod(SEED, 99) + 1)
	check(str(sim.state.contract.code) == expected, "a new game is %s, from its seed" % expected)
	var other: RefCounted = _colony(SEED + 1)
	check(
		str(other.state.contract.code) != expected,
		"another seed, another code: %s" % str(other.state.contract.code)
	)
	sim.tick()
	check(sim.save_game("user://v111_contract.save") == "", "it saves")
	var again: RefCounted = Sim.new()
	check(
		(
			again.load_game("user://v111_contract.save") == ""
			and str(again.state.contract.code) == expected
		),
		"and loads with the same code"
	)
	var path: String = ProjectSettings.globalize_path(OLD_SAVE)
	if not FileAccess.file_exists(path):
		return
	var old: RefCounted = Sim.new()
	old.load_game(path)
	var given: String = str(old.state.contract.get("code", ""))
	check(
		given == Contract.code_for(old.state) and given.begins_with("CC-"),
		"a 1.10 save gets the code of its seed on load: " + given
	)
	check(old.save_game("user://v111_contract_old.save") == "", "it saves as 1.11")
	var reread: RefCounted = Sim.new()
	check(
		(
			reread.load_game("user://v111_contract_old.save") == ""
			and str(reread.state.contract.code) == given
		),
		"and keeps its code"
	)
	check(reread.audit().is_empty(), "the audit holds: %s" % str(reread.audit()))


func _gauge() -> void:
	var sim: RefCounted = _colony()
	var fake := FakeGame.new()
	fake.sim = sim
	root.add_child(fake)
	var gauge: PanelContainer = Gauge.new()
	gauge.setup(fake)
	fake.add_child(gauge)
	sim.state.company.distrust = 35.0
	sim.state.company.delta = 0.42
	gauge.show_pair(sim)
	check(gauge.rating_label.text == Company.rating(sim), "the pair shows the rating letter")
	check(gauge.tooltip_text.contains("35.0"), "with the number on hover")
	check(gauge.delta_label.text == "+0.42 /日", "and the change of the day")
	check(
		gauge.morale_label.text == "%.0f" % Population.morale(sim),
		"民心 beside it: " + gauge.morale_label.text
	)
	check(gauge.morale_box.tooltip_text.contains("公共服务预算"), "whose hover names its lever")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	gauge._gui_input(press)
	check(fake.opened == "company", "the rating opens the company page")
	gauge._morale_input(press)
	check(fake.opened == "population", "民心 the population page")
	fake.queue_free()


func _cues() -> void:
	var sim: RefCounted = _colony()
	var cues: RefCounted = Cues.new()
	check(cues.observe(sim).is_empty(), "the first look at a game only takes note")
	Company.transition(sim, "warning", 0, "warning")
	var heard: Array[String] = cues.observe(sim)
	check(heard.size() == 1 and heard[0] == Cues.LETTER, "a letter arrives with its cue")
	Contract._complete_stage(sim, 1)
	heard = cues.observe(sim)
	check(heard.size() == 1 and heard[0] == Cues.STAMP, "a stamp with its own")
	check(cues.observe(sim).is_empty(), "and nothing plays twice")
	var loaded: RefCounted = _colony()
	Company.transition(loaded, "warning", 0, "warning")
	check(cues.observe(loaded).is_empty(), "another game is only noted")


func _event_voice() -> void:
	var defs: Dictionary = Events.definitions().definitions
	var unknown: Array = []
	var placeholder := RegEx.create_from_string("\\{[^}]*\\}")
	for id: String in defs:
		for key: String in defs[id].nodes:
			var node: Dictionary = defs[id].nodes[key]
			for found: RegExMatch in placeholder.search_all(str(node.text)):
				if not found.get_string() in ["{code}", "{capital}"]:
					unknown.append("%s/%s %s" % [id, key, found.get_string()])
			if str(node.title).contains("{"):
				unknown.append("%s/%s title" % [id, key])
	check(unknown.is_empty(), "event text names only {code} and {capital}: %s" % str(unknown))
	var departments: Array = Rules.read("letters").departments.values()
	var voiced: int = 0
	var quiet: Array = []
	for id: String in REWORDED:
		var words: String = ""
		for key: String in defs[id].nodes:
			words += str(defs[id].nodes[key].text)
		var company: bool = words.contains("公司")
		for department: String in departments:
			company = company or words.contains(department)
		if not company:
			quiet.append(id)
		voiced += 1 if words.contains("{code}") else 0
	check(quiet.is_empty(), "each reworded event lets the company speak: %s" % str(quiet))
	check(voiced >= 8, "and most name the project by its code: %d of 10" % voiced)
	var sim: RefCounted = _colony()
	sim.state.settlements[0].name = "望潮"
	Events._open(sim, "company_audit", 0)
	var shown: String = ""
	for row: Dictionary in Events.view(sim).pending:
		if str(row.id) == "company_audit":
			shown = str(row.text)
	check(
		shown.contains(str(sim.state.contract.code) + " 项目") and shown.contains("望潮的财务室"),
		"the event view fills the code and the capital's name"
	)
	check(shown != "" and not shown.contains("{"), "and leaves no placeholder")
