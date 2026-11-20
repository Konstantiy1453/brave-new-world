extends RefCounted
## Why a town grows or does not (1.10 brief): the net change over 30 days, how many people want to
## come against how many the town can take in, and the one thing holding it back, with what fixes
## it. Reads the population view; changes nothing.

const D = preload("res://ui/design.gd")

## Below this many would-be arrivals a month, the town's appeal is what holds it back.
const LOW_DEMAND: float = 3.0
## Fewer days of food than this and food is the worry.
const FOOD_DAYS: float = 10.0


## The main limit on a town's growth: {key, text, remedy}. Keys: housing, jobs, food, appeal, none.
static func limit(sim: RefCounted, s: Dictionary, v: Dictionary) -> Dictionary:
	var demand: float = float(v.get("arrivals_per_month", 0.0))
	var room: int = int(v.get("free_beds", 0))
	var prospects: float = float(v.get("prospects", 1.0))
	if room <= 0:
		var home: Dictionary = sim.config.buildings.get("habitat", {})
		return {
			"key": "housing",
			"text": "住房已满：每月约 %.0f 人想来，但没有空床位" % demand,
			"remedy":
			(
				"建住房：%s（+%d 床，¥%.0f）"
				% [
					str(home.get("name", "住房")),
					int(home.get("housing", 0)),
					float(home.get("cost", 0))
				]
			)
		}
	if prospects < 0.999:
		var stop: int = roundi(100.0 * float(sim.pop_rules.immigration.jobless_stop_share))
		return {
			"key": "jobs",
			"text": "失业的人多：就业前景 %.0f%%，失业达 %d%% 时没人再来" % [prospects * 100.0, stop],
			"remedy": "增加岗位：建矿场、工厂或农场，或把人派往缺工的据点"
		}
	if float(s.get("food_days", 99.0)) < FOOD_DAYS:
		return {
			"key": "food", "text": "存粮只够 %.0f 天" % float(s.food_days), "remedy": "建农场或进口食品，提高食品储备"
		}
	if demand < LOW_DEMAND:
		return {
			"key": "appeal",
			"text": "吸引力低：每月只有约 %.1f 人想来" % demand,
			"remedy": "提高工资、建诊所与公共服务、让食品与住房充足"
		}
	return {"key": "none", "text": "没有明显的限制", "remedy": ""}


## What made a town's change: immigration, departures, births, people moved with expeditions,
## crews and workers following jobs, and anything the records do not name.
static func _change_parts(change: Dictionary) -> String:
	var parts: PackedStringArray = [
		"迁入 +%d" % int(change.arrivals),
		"离开 −%d" % int(change.departures),
		"出生 +%d" % int(change.births),
		"远征、工程队与调动 %+d" % int(change.moves),
	]
	if int(change.other) != 0:
		parts.append("其他 %+d" % int(change.other))
	return " · ".join(parts)


## The growth lines for the people page: change, demand against room, and the limit.
static func growth(sim: RefCounted, b: Control, s: Dictionary, v: Dictionary) -> void:
	var change: Dictionary = v.get("change", {})
	if bool(change.get("known", false)):
		var net: int = int(change.net)
		var head: Label = D.label(
			b,
			"近 %d 日净变化 %+d 人（%d → %d）" % [int(change.days), net, int(change.then), int(change.now)],
			18,
			D.TEAL if net > 0 else (D.GOLD if net == 0 else D.RED)
		)
		D.named(head, "PopulationNet")
		D.label(b, "　" + _change_parts(change), 16, D.MUTED)
	else:
		D.label(
			b,
			(
				"近 30 日迁入 %d 人，离开 %d 人（完整的人口变化记录从下个月开始）"
				% [int(v.get("arrived_30", 0)), int(v.get("departed_30", 0))]
			),
			17
		)
	var demand: float = float(v.get("arrivals_per_month", 0.0))
	var room: int = maxi(0, int(v.get("free_beds", 0)))
	D.label(
		b,
		(
			"每月约 %.1f 人想来 · 能住下 %d 人（空床位已扣除招募预留 %d）· 预计 30 天迁入约 %d 人"
			% [demand, room, int(v.get("in_transit", 0)), int(v.get("expected_30", 0))]
		),
		17
	)
	(
		D
		. label(
			b,
			(
				"失业率 %.0f%%：超过 %.0f%% 想来的人开始减少，达到 %.0f%% 时没人再来"
				% [
					100.0 * float(v.get("jobless_share", 0.0)),
					100.0 * float(v.get("jobless_free", 0.0)),
					100.0 * float(v.get("jobless_stop", 0.0)),
				]
			),
			16,
			D.MUTED
		)
	)
	var main: Dictionary = limit(sim, s, v)
	D.label(b, "主要限制：" + str(main.text), 17, D.TEAL if str(main.key) == "none" else D.GOLD)
	if str(main.remedy) != "":
		D.label(b, "　→ " + str(main.remedy), 16, D.MUTED)
