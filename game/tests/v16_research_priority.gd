extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Flow = preload("res://tests/v16_flow.gd")


func _init():
	Watchdog.arm(self)
	var runner = Flow.new()
	var s = Sim.new()
	s.new_game(260129, "science", 1, "normal")
	runner.recording = true
	runner.opening(s)
	var completed: int = -1
	var errors: Array = []
	for day in range(100):
		runner.step(s)
		if int(s.state.day) == 30:
			# Shipped fixtures change only under an explicit --fixtures flag.
			var fixture: bool = OS.get_cmdline_user_args().has("--fixtures")
			var error: String = s.save_game(
				(
					"res://data/v16/acceptance_research.json"
					if fixture
					else "user://acceptance_research.json"
				)
			)
			if error != "":
				errors.append(error)
			(
				FileAccess
				. open(
					"res://../evidence/v17/tests/research_fixture_actions.json", FileAccess.WRITE
				)
				. store_string(
					(
						JSON
						. stringify(
							{
								"scope":
								"normal science opening through30days; only production act/tick; no injected state",
								"seed": 260129,
								"day": s.state.day,
								"actions": runner.report.actions,
								"research": s.research_view(),
								"audit": s.audit()
							},
							"\t"
						)
					)
				)
			)
		if not s.audit().is_empty():
			errors.append(s.audit())
		if completed < 0 and s.state.research.completed.has("survey"):
			completed = s.state.day
	print(
		"RESEARCH_STAFF_PRIORITY completed=",
		completed,
		" audit=",
		errors,
		" snapshot=",
		s.research_view()
	)
	runner.free()
	quit(0 if completed > 0 and errors.is_empty() else 1)
