extends RefCounted
## The weather page (1.11 F): the systems coming for the colony's towns, with the days of warning
## each town gets and a button to pay for preparation; the disasters of the last weeks, each with
## a force majeure claim while it can still be filed; and which towns a weather station covers.
## Functional; a later interface pass restyles it.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
const Weather = preload("res://simulation/weather.gd")


static func page(g, b) -> void:
	var sim: RefCounted = g.sim
	var rules: Dictionary = Weather.rules()
	if not Weather.active(sim):
		D.label(b, "这局游戏的天气只是外观，不影响经营。", 17, D.MUTED)
		return
	D.label(
		b,
		(
			"天气系统在开阔的海面、干旱的内陆、寒冷的高纬和河谷里生成，每天移动。预计抵达前会发出预警：气象站覆盖的据点提前天数加倍。灾害发生后 %d 日内可以申请不可抗力。"
			% int(rules.get("claim_days", 15))
		),
		16,
		D.MUTED
	)
	_coming(g, b)
	_struck(g, b)
	_stations(g, b)


static func _coming(g, b) -> void:
	var sim: RefCounted = g.sim
	D.heading(b, "预警")
	var any: bool = false
	for system: Dictionary in Weather.view(sim):
		for key: Variant in system.warned:
			var region: int = int(str(key))
			if system.struck.has(str(key)):
				continue
			var town: Dictionary = sim.settlement(region)
			if town.is_empty():
				continue
			any = true
			var card: VBoxContainer = D.card(b)
			var name: String = str(Weather.rules().kinds[system.kind].name)
			D.label(
				card,
				(
					"%s正在逼近%s（%s发出预警）"
					% [name, str(town.name), Labels.short_date(int(system.warned[key]))]
				),
				18,
				D.GOLD
			)
			if system.prepared.has(str(key)):
				D.label(card, "已做好防灾准备：灾害造成的物资损失会减少。", 15, D.TEAL)
				continue
			var system_id: int = int(system.id)
			D.button(
				card,
				"防灾准备 · ¥%.0f" % Weather.prepare_cost(sim),
				func(): g.act("weather_prepare", {"system": system_id, "region": region}),
				"加固、转移和储备：这次灾害造成的物资损失减半。",
				"Prepare_%d_%d" % [system_id, region]
			)
	if not any:
		D.label(b, "现在没有天气系统逼近你的据点。", 16, D.MUTED)


static func _struck(g, b) -> void:
	var sim: RefCounted = g.sim
	var w: Dictionary = sim.state.get("weather", {})
	var claim_days: int = int(Weather.rules().get("claim_days", 15))
	var recent: Array = []
	for strike: Dictionary in w.get("strikes", []):
		if int(sim.state.day) - int(strike.day) <= claim_days:
			recent.append(strike)
	if recent.is_empty():
		return
	D.heading(b, "近期灾害")
	for strike: Dictionary in recent:
		var town: Dictionary = sim.settlement(int(strike.region))
		var name: String = str(Weather.rules().kinds[strike.kind].name)
		var card: VBoxContainer = D.card(b)
		D.label(
			card,
			"%s · %s · %s" % [name, str(town.get("name", "")), Labels.short_date(int(strike.day))],
			17,
			D.INK
		)
		var claimed: bool = false
		for row: Dictionary in w.get("claims", []):
			claimed = (
				claimed
				or (int(row.system) == int(strike.system) and int(row.region) == int(strike.region))
			)
		if claimed:
			D.label(card, "已申请不可抗力。", 15, D.MUTED)
			continue
		var evidence: bool = bool(strike.covered) or bool(strike.warned)
		var region: int = int(strike.region)
		var claim: Button = D.button(
			card,
			"申请不可抗力",
			func(): g.act("force_majeure", {"region": region}),
			"有气象站记录或预警在案：期限顺延，本年度报告相应一项不计未达标。" if evidence else "既无气象站记录也无预警在案，申请会被驳回。",
			"Claim_%d_%d" % [int(strike.system), region]
		)
		claim.disabled = false


static func _stations(g, b) -> void:
	var sim: RefCounted = g.sim
	D.heading(b, "气象站覆盖")
	for town: Dictionary in sim.state.settlements:
		var covered: bool = Weather.covered(sim, town)
		D.label(
			b,
			(
				"%s：%s，预警提前 %d 日"
				% [str(town.name), "已覆盖" if covered else "未覆盖", Weather.warning_days(sim, town)]
			),
			15,
			D.TEAL if covered else D.MUTED
		)
