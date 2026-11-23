extends RefCounted
## The contract types to choose from on the new-game screen (1.11 origins), one card each: the name
## (推荐首局 on the standard contract), the story, gains, costs, the unique rule and the stage-three
## route it favours, from economy.json `openings` with every number filled from the entry. The same
## filling writes an origin's clause on the contract page. Functional; a later interface pass
## restyles it.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
const COLUMNS: int = 3
const GAIN_COLOR: Color = Color("62c7c5")
const COST_COLOR: Color = Color("e48f68")
const RULE_COLOR: Color = Color("d8b16a")


## One card per origin under `parent`; `pick` is called with the id chosen. `locked` shows them
## without letting a choice be made (the tutorial's own contract).
static func cards(
	parent: Node, sim: RefCounted, chosen: String, locked: bool, pick: Callable
) -> void:
	var grid: GridContainer = D.grid(parent, COLUMNS)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var group := ButtonGroup.new()
	for id: String in sim.config.openings:
		var entry: Dictionary = sim.config.openings[id]
		var card: VBoxContainer = D.card(grid, "card_on" if id == chosen else "card")
		card.get_parent().custom_minimum_size.x = 220
		card.add_theme_constant_override("separation", 3)
		var head: HBoxContainer = D.row(card)
		D.label(head, str(entry.name), 18, D.GOLD, false)
		if bool(entry.get("recommended", false)):
			D.tag(head, "推荐首局", D.TEAL, 13)
		D.label(card, str(entry.get("story", "")), 14, D.INK)
		for line: String in lines(sim, entry):
			var color: Color = D.MUTED
			if line.begins_with("＋"):
				color = GAIN_COLOR
			elif line.begins_with("－"):
				color = COST_COLOR
			elif line.begins_with("规则"):
				color = RULE_COLOR
			D.label(card, line, 13, color)
		var button: Button = D.button(card, "选择此合同", pick.bind(id), "", "Origin_" + id, "chip")
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = id == chosen
		button.disabled = locked
		button.custom_minimum_size.y = 32
		D.font_size(button, 14)


## The card's lines after the story: ＋ gains, － costs, the unique rule, the favoured route.
static func lines(sim: RefCounted, entry: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for gain: Variant in entry.get("gains", []):
		out.append("＋ " + fill(sim, entry, str(gain)))
	var costs: Array = entry.get("costs", [])
	if costs.is_empty():
		out.append("－ 无额外代价")
	for cost: Variant in costs:
		out.append("－ " + fill(sim, entry, str(cost)))
	if str(entry.get("rule", "")) != "":
		out.append("规则：" + fill(sim, entry, str(entry.rule)))
	var route: String = str(entry.get("favours", ""))
	if route != "":
		var name: String = str(
			sim.contract_rules.get("routes", {}).get(route, {}).get("name", route)
		)
		out.append("偏向第三阶段路线：" + name)
	return out


## Fills an origin's text from its entry: {cash}, {workers}, {scientists}, {children}, {residents},
## {materials}, {parts}, {food}, {first_expedition_factor}; {rule:key}; {effect:key} as a signed
## percentage; {cut:key} as a reduction; {years:key} for a rule in days; {tech:key} for the name of
## the technology progression.json `research.<key>` names.
static func fill(sim: RefCounted, entry: Dictionary, text: String) -> String:
	var rules: Dictionary = entry.get("rules", {})
	var effects: Dictionary = entry.get("effects", {})
	var residents: int = int(entry.workers) + int(entry.scientists) + int(entry.children)
	var values: Dictionary = {
		"cash": _money(float(entry.cash)),
		"workers": str(int(entry.workers)),
		"scientists": str(int(entry.scientists)),
		"children": str(int(entry.children)),
		"residents": str(residents),
		"materials": Labels.t(float(entry.materials)),
		"parts": Labels.t(float(entry.parts)),
		"food": Labels.t(float(entry.food)),
		"first_expedition_factor": _number(float(entry.get("first_expedition_factor", 1.0))),
	}
	for key: String in rules:
		values["rule:" + key] = _rule_text(rules[key])
		values["years:" + key] = _number(float(rules[key]) / 360.0) if rules[key] is float else ""
	for key: String in effects:
		values["effect:" + key] = "%+.0f%%" % (float(effects[key]) * 100.0)
		values["cut:" + key] = "−%.0f%%" % (float(effects[key]) * 100.0)
	for key: String in sim.progression.get("research", {}):
		var tech: String = str(sim.progression.research[key])
		if sim.config.techs.has(tech):
			values["tech:" + key] = str(sim.config.techs[tech].name)
	for key: String in values:
		text = text.replace("{%s}" % key, str(values[key]))
	return text


## A rule's value as text: goods by stage as tonnes, a factor or count as a person writes it.
static func _rule_text(value: Variant) -> String:
	if value is Array:
		var parts: PackedStringArray = []
		for amount: Variant in value:
			parts.append(Labels.t(float(amount)))
		return " / ".join(parts)
	if value is bool:
		return ""
	return _number(float(value))


static func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return ("%.2f" % value).rstrip("0")


static func _money(value: float) -> String:
	var whole: String = "%d" % roundi(value)
	var out: String = ""
	while whole.length() > 3:
		out = "," + whole.right(3) + out
		whole = whole.left(whole.length() - 3)
	return whole + out
