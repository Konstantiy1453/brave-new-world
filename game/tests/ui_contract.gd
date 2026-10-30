extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")


func _initialize():
	Watchdog.arm(self)
	if not FileAccess.file_exists("res://ui/main.gd"):
		print("FAIL: runnable main UI absent")
		quit(1)
		return
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.has_method("advance_time"))
	scene.set_process(false)
	scene.close_modal()
	scene.sim.act("settle", {"region": 0})
	var day = scene.sim.state.day
	scene.paused = true
	scene.advance_time(200)
	assert(scene.sim.state.day == day, "Paused UI advanced economy")
	scene.paused = false
	scene.speed = 1
	scene.advance_time(20)
	var baseline = JSON.stringify(scene.sim.state)
	scene.sim.new_game(260129, "capital", 1)
	scene.sim.act("settle", {"region": 0})
	scene.speed = 4
	scene.advance_time(5)
	assert(
		JSON.stringify(scene.sim.state) == baseline, "speed changed equal-duration economic result"
	)
	var unchanged = JSON.stringify(scene.sim.state)
	for view in ["planet", "flat", "region", "planet"]:
		scene.navigate(view)
		await process_frame
		assert(
			JSON.stringify(scene.sim.state) == unchanged,
			"Map view switch mutated economic/world state"
		)
	var has_save = false
	var has_load = false
	for button in scene.ui.find_children("*", "Button", true, false):
		if button.text == "存档":
			has_save = true
		if button.text == "读档":
			has_load = true
	assert(
		has_save and has_load,
		"Persistent save and load entries must exist outside scrolling navigation"
	)
	for page in [
		"build",
		"economy",
		"research",
		"transport",
		"enterprise",
		"events",
		"contract",
		"save",
		"guide",
		"world"
	]:
		scene.open_page(page)
		await process_frame
	assert(scene.paused, "management panel must pause for accessible decisions")
	print(
		"PASS: UI boots; pause and 1x/4x exact equality; sphere/flat/region preserve state; persistent save/load; ten management pages build"
	)
	quit(0)
