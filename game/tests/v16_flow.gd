extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const C = preload("res://simulation/career.gd")
const E = preload("res://simulation/events_v2.gd")
var report: Dictionary = {
	"scope":
	"automatic production act/tick paths; no injected resources, population, awards or dates",
	"protocol":
	"fixed seeds 260129/20261029/42; 3 openings x 3 difficulties; baseline scheduled strategy through180days",
	"cases": [],
	"failures": [],
	"career": {},
	"actions": []
}
var recording: bool = false


func _initialize():
	Watchdog.arm(self)
	call_deferred("run")


func act(s, action: String, args: Dictionary):
	var error: String = s.act(action, args)
	if recording:
		report.actions.append(
			{
				"world": s.state.career.active_id,
				"day": s.state.day,
				"action": action,
				"args": args,
				"error": error
			}
		)
	return error


func resolve(s):
	for n in E.view(s).pending:
		var choices: Array = n.choices
		# Survey water, preserve archaeological records, take small industrial order.
		var preferred: String = ""
		if n.id == "water":
			preferred = {"start": "survey", "plan": "conserve", "inspection": "careful"}.get(
				n.node, ""
			)
		if n.id == "archaeology":
			preferred = (
				{
					"start": "survey",
					"records": "protect",
					"findings": "apply",
					"sale_report": "close"
				}
				. get(n.node, "")
			)
		if n.id == "industry":
			preferred = {"start": "small", "review": "reduce", "delivered": "standard"}.get(
				n.node, ""
			)
		var chosen: String = ""
		for ch in choices:
			if ch.id == preferred and ch.enabled:
				chosen = ch.id
				break
		if chosen == "":
			for ch in choices:
				if ch.id != "defer" and ch.enabled:
					chosen = ch.id
					break
		if chosen != "":
			act(s, "event_v2", {"instance_id": n.instance_id, "choice": chosen})


func opening(s):
	act(s, "settle", {"region": 0})
	act(s, "build", {"region": 0, "kind": "mine_ore"})
	act(s, "build", {"region": 0, "kind": "mine_copper"})
	if s.state.advantage == "science":
		act(s, "build", {"region": 0, "kind": "lab"})
		act(s, "research_allocate", {"tech": "survey", "staff": 10})


func step(s):
	var day: int = int(s.state.day) + 1
	if day == 16:
		act(s, "enterprise", {"region": 0})
	if day == 24:
		act(s, "settle", {"region": 1})
		act(s, "connect", {"a": 0, "b": 1, "mountain": false})
	if (
		day >= 28
		and day <= 40
		and not s.settlement(1).is_empty()
		and not has_building(s, 1, "farm")
	):
		act(s, "build", {"region": 1, "kind": "farm"})
	if (
		day >= 45
		and day <= 120
		and not has_building(s, 0, "processor")
		and float(s.state.cash) >= float(s.config.buildings.processor.cost) + 300.0
	):
		act(s, "build", {"region": 0, "kind": "processor"})
	if day == 60 and s.state.advantage != "science":
		act(s, "build", {"region": 0, "kind": "lab"})
		act(s, "research_allocate", {"tech": "adaptation", "staff": 4})
	resolve(s)
	s.tick()


func has_building(s, region: int, kind: String) -> bool:
	for b in s.settlement(region).get("buildings", []):
		if b.kind == kind:
			return true
	return false


func run():
	var fixture_mode: bool = OS.get_cmdline_user_args().has("--fixtures")
	var destination: String = "res://../evidence/v17/tests/flow_initial.json"
	for seed_value in [260129] if fixture_mode else [260129, 20261029, 42]:
		for advantage in ["capital"] if fixture_mode else ["capital", "workers", "science"]:
			for difficulty in ["normal"] if fixture_mode else ["normal", "easy", "hard"]:
				var s = Sim.new()
				s.new_game(seed_value, advantage, 1, difficulty)
				C.capture_checkpoint(s)
				recording = fixture_mode
				opening(s)
				var row: Dictionary = {
					"seed": seed_value,
					"opening": advantage,
					"difficulty": difficulty,
					"award_day": -1,
					"first_research": -1,
					"min_cash": s.state.cash,
					"audit_failures": [],
					"stages": [],
					"events": 0
				}
				for i in range(180):
					step(s)
					if fixture_mode and s.state.day == 37:
						s.save_game("res://data/v16/acceptance_pre_award.json")
					row.min_cash = minf(float(row.min_cash), float(s.state.cash))
					if not s.audit().is_empty():
						row.audit_failures.append({"day": s.state.day, "issues": s.audit()})
					if row.first_research < 0 and not s.state.research.completed.is_empty():
						row.first_research = s.state.day
					if not s.state.company.stage in row.stages:
						row.stages.append(s.state.company.stage)
					if s.state.status == "success" and row.award_day < 0:
						row.award_day = s.state.day
						if fixture_mode:
							DirAccess.make_dir_recursive_absolute(
								ProjectSettings.globalize_path("res://data/v16")
							)
							var er: String = s.save_game("res://data/v16/acceptance_governor.json")
							if er != "":
								report.failures.append(er)
							break
					if s.state.status == "failed":
						break
				row.final_day = s.state.day
				row.status = s.state.status
				row.cash = s.state.cash
				row.events = s.state.events_v2.history.size()
				row.progress = s.contract_progress()
				report.cases.append(row)
				print("FLOW_CASE ", JSON.stringify(row))
				if fixture_mode and s.state.status == "success":
					report.career.preview = C.preview(s)
					var er: String = C.handover(
						s, 260130, "capital", "normal", "user://full_career.json"
					)
					if er != "":
						report.failures.append(er)
					else:
						opening(s)
						for i in range(36):
							step(s)
						report.career.global_day = s.state.career.global_day
						report.career.local_day = s.state.day
						report.career.dividend = s.state.career.balance
						report.career.audit = s.audit()
						if s.state.career.balance <= 0:
							report.failures.append("second world no actual dividend")
						var paid: float = s.state.career.balance
						var net: float = s.state.operating_net
						C.invest(s, minf(100, paid))
						report.career.invest_does_not_change_profit = s.state.operating_net == net
						er = s.save_game("res://data/v16/acceptance_second_dividend.json")
						if er != "":
							report.failures.append(er)
						var loaded = Sim.new()
						er = loaded.load_game("res://data/v16/acceptance_second_dividend.json")
						report.career.roundtrip = (
							er == "" and var_to_bytes(s.state) == var_to_bytes(loaded.state)
						)
						for i in range(3):
							resolve(s)
							resolve(loaded)
							s.tick()
							loaded.tick()
						report.career.continuation = (
							var_to_bytes(s.state) == var_to_bytes(loaded.state)
						)
	if fixture_mode:
		destination = "res://../evidence/v17/tests/acceptance_flow.json"
		var crisis = Sim.new()
		crisis.new_game(260129, "capital", 1, "normal")
		C.capture_checkpoint(crisis)
		act(crisis, "settle", {"region": 0})
		for i in range(240):
			resolve(crisis)
			crisis.tick()
			if crisis.state.company.stage == "review":
				break
		report.crisis = {
			"day": crisis.state.day,
			"stage": crisis.state.company.stage,
			"cash": crisis.state.cash,
			"debt": crisis.state.debt,
			"audit": crisis.audit()
		}
		var er: String = crisis.save_game("res://data/v16/acceptance_crisis.json")
		if er != "":
			report.failures.append(er)
	FileAccess.open(destination, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("FLOW_RESULT cases=%d failures=%d" % [report.cases.size(), report.failures.size()])
	quit(0 if report.failures.is_empty() else 1)
