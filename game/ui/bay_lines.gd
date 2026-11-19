extends RefCounted
## The bay on a coastal town's panel (1.10 plan C): its offshore signal, what is known of it, and
## the survey boat a working harbour can send. Reads the simulation; acts through `g.act`.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")


static func offshore(g, b: Control, s: Dictionary) -> void:
	var bay: Variant = g.sim.get("Bay")
	if bay == null:
		return
	var reading: Dictionary = bay.offshore_signal(g.sim, int(s.region))
	if reading.is_empty():
		return
	var good: String = str(g.sim.config.resources.get(reading.good, reading.good))
	var rule: Dictionary = bay.rules(g.sim)
	if bool(reading.surveyed):
		if bool(reading.rich):
			D.label(
				b, "近海信号：海底%s富矿，约 %s（待海底开采技术）" % [good, Labels.t(float(reading.tonnes))], 15, D.TEAL
			)
		else:
			D.label(b, "近海信号：只是含%s的沉积层，不值得开采" % good, 15, D.MUTED)
		return
	if int(reading.survey_until) >= 0:
		D.label(
			b,
			"近海信号：测量船出海中，%d 天后回来" % maxi(0, int(reading.survey_until) - int(g.sim.state.day)),
			15,
			D.GOLD
		)
		return
	# The words wrap and the button takes its own line: the town panel is narrow.
	D.label(b, "近海信号：疑似%s矿体，规模不明" % good, 15, D.GOLD)
	var region: int = int(s.region)
	var send: Button = D.button(
		b,
		(
			"派测量船 · ¥ %.0f · %d 天"
			% [float(rule.get("survey_cost", 0)), int(rule.get("survey_days", 0))]
		),
		func(): g.act("survey_offshore", {"site": region}),
		"需要一座运转的小型码头；查明后，富矿留待海底开采技术，贫矿也不影响码头",
		"SurveyOffshore"
	)
	D.font_size(send, D.CAPTION)
	send.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	send.disabled = not bool(bay.harbor_working(g.sim, s))
