extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const R = preload("res://simulation/research.gd")
const C = preload("res://simulation/company.gd")
var report: Dictionary = {
	"scope":
	"independent integrated staffing and save mutation regressions; four scientist immigrants and lab funding are explicitly injected fixture inputs",
	"checks": [],
	"failures": []
}


func check(ok: bool, label: String, details: Dictionary = {}):
	report.checks.append({"label": label, "passed": ok, "details": details})
	if not ok:
		report.failures.append(label)


func _initialize():
	Watchdog.arm(self)
	call_deferred("run")


func run():
	var sim = Sim.new()
	var err: String = sim.load_game("res://data/acceptance_success.json")
	check(err == "", "legacy active infrastructure loads", {"error": err})
	if err != "":
		quit(1)
		return
	var first: Dictionary = sim.settlement(0)
	var second: Dictionary = sim.settlement(1)
	second.scientists += 4
	second.population += 4
	sim.state.immigrants_total += 4
	sim._transfer("external", "public", 2000.0, "review fixture investment", false)
	sim._produce(second, "materials", 40.0, "review fixture lab supplies")
	sim._produce(second, "parts", 10.0, "review fixture lab supplies")
	check(
		sim.act("build", {"region": 1, "kind": "lab"}) == "",
		"remote-only lab construction accepted"
	)
	for i in range(5):
		sim.tick()
	check(
		sim.act("research_allocate", {"tech": "survey", "staff": 4}) == "",
		"allocate four researchers"
	)
	sim.tick()
	check(
		int(sim.state.research.projects.survey.effective) == 4,
		"remote lab has four actual researchers"
	)
	check(
		int(first.employed_scientists) == 0 and int(second.employed_scientists) == 4,
		"research employment and wages assigned to lab's actual colony",
		{
			"region0_employed": first.employed_scientists,
			"region1_employed": second.employed_scientists,
			"effective": sim.state.research.projects.survey.effective
		}
	)
	sim._reconcile_jobs(second)
	check(
		int(second.employed_scientists) == 4,
		"demographic job reconciliation retains paid laboratory employment",
		{"region1_employed_after_reconcile": second.employed_scientists}
	)
	check(sim.audit().is_empty(), "staffing fixture retains audited resources and money")
	var idx: int = 0
	check(bool(first.buildings[idx].active), "power facility active before toggle")
	sim.act("toggle", {"region": 0, "index": idx})
	check(
		not first.buildings[idx].enabled and not first.buildings[idx].active,
		"paused disable immediately clears active presentation state",
		{"enabled": first.buildings[idx].enabled, "active": first.buildings[idx].active}
	)
	var over: Dictionary = sim.state.duplicate(true)
	over.research.projects.survey.staff = 999
	check(R.validate(sim, over) != "", "save rejects scientific allocations beyond real population")
	var fraction: Dictionary = sim.state.duplicate(true)
	fraction.research.projects.survey.staff = 3.5
	check(R.validate(sim, fraction) != "", "save rejects fractional persons")
	sim.state.company.stage = "warning"
	check(C.accept(sim, "liquidity") == "", "company aid fixture accepted")
	var bad_aid: Dictionary = sim.state.duplicate(true)
	bad_aid.company.aid[0].cash = -1000
	check(C.validate(sim, bad_aid) != "", "save rejects negative promised aid cash")
	bad_aid = sim.state.duplicate(true)
	bad_aid.company.aid[0].surcharge = -0.5
	check(C.validate(sim, bad_aid) != "", "save rejects negative aid levy")
	bad_aid = sim.state.duplicate(true)
	bad_aid.company.aid[0].arrival_day = -1
	check(C.validate(sim, bad_aid) != "", "save rejects invalid aid delivery chronology")
	var before_work: float = sim.state.research.projects.survey.work
	check(
		R.reserve_investigation(sim, "review-field", 6) == "",
		"investigation can reassign existing researchers"
	)
	var allocated: int = R.investigating(sim)
	for project in sim.state.research.projects.values():
		allocated += int(project.staff)
	check(
		allocated <= R.total(sim) and sim.state.research.projects.survey.work == before_work,
		"investigation priority shrinks allocation without losing work",
		{"registered": allocated, "population": R.total(sim)}
	)
	var output: String = "res://../evidence/v17/tests/research_company_review_red.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.trim_prefix("--report=")
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("RESEARCH_COMPANY_REVIEW ", JSON.stringify(report))
	quit(0 if report.failures.is_empty() else 1)
