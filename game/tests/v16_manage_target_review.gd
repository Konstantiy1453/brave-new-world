extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
## Real simulation and production manage page; minimal page context, no main-scene claim.
const Sim = preload("res://simulation/sim.gd")
const Pages = preload("res://ui/progression_pages.gd")
const Labels = preload("res://ui/labels.gd")


class PageContext:
	extends RefCounted
	var sim
	var selected: int = 0

	func settlement() -> Dictionary:
		return sim.settlement(selected)

	func act(action: String, args: Dictionary = {}) -> String:
		return sim.act(action, args)


var result: Dictionary = {
	"scope":
	"headless production manage page and real simulation; read and reapply values, no rendering or OS input claim",
	"checks": [],
	"failures": []
}


func _initialize():
	Watchdog.arm(self)
	call_deferred("run")


func check(ok: bool, label: String, details: Dictionary = {}):
	result.checks.append({"passed": ok, "label": label, "details": details})
	if not ok:
		result.failures.append(label)


func run():
	var context = PageContext.new()
	context.sim = Sim.new()
	var error: String = context.sim.load_game("res://data/v16/acceptance_governor.json")
	check(error.is_empty(), "fixture loads", {"error": error})
	var settlement: Dictionary = context.settlement()
	result.population = settlement.population
	for mode in [
		"dynamic_default", "custom_above_5000", "custom_precision", "range_and_micro_precision"
	]:
		if mode == "custom_above_5000":
			settlement.targets = {"food": 7012.3, "materials": 8021.7, "parts": 9999.9}
		if mode == "custom_precision":
			settlement.targets = {"food": 201.65, "materials": 160.25, "parts": 40.125}
		if mode == "range_and_micro_precision":
			settlement.targets = {"food": 0.0, "materials": 10000.0, "parts": 201.6501234}
		var expected: Array = []
		for key in ["food", "materials", "parts"]:
			expected.append(context.sim._target(settlement, key))
		var box = VBoxContainer.new()
		root.add_child(box)
		var frozen: PackedByteArray = var_to_bytes(context.sim.state)
		Pages.manage(context, box)
		await process_frame
		check(
			var_to_bytes(context.sim.state) == frozen,
			mode + " opening page preserves simulation bytes"
		)
		var amounts = box.find_children("*", "SpinBox", true, false)
		check(amounts.size() == 3, mode + " three inputs")
		# 1.9: the page shows tonnes, the rules keep hundreds of tonnes (economy.json display).
		var scale: float = Labels.tonnes_per_unit()
		for index in range(mini(3, amounts.size())):
			check(
				absf(amounts[index].value - expected[index] * scale) <= 0.000001 * scale,
				mode + " target within microton precision " + str(index),
				{"expected": expected[index] * scale, "actual": amounts[index].value}
			)
			check(
				is_equal_approx(amounts[index].custom_arrow_step, 0.1 * scale),
				mode + " arrow step 0.1 unit " + str(index)
			)
		for button in box.find_children("*", "Button", true, false):
			if button.text == "设置目标":
				button.pressed.emit()
		for index in range(3):
			var key: String = ["food", "materials", "parts"][index]
			check(
				absf(context.sim._target(settlement, key) - expected[index]) <= 0.000001,
				mode + " reapply within microton precision " + key,
				{"expected": expected[index], "actual": context.sim._target(settlement, key)}
			)
		box.queue_free()
		await process_frame
	var page_script: Script = Pages
	result.runtime_page_source_hash = page_script.source_code.sha256_text()
	var output: String = "res://../evidence/v17/tests/manage_target_review_red.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):
			output = arg.trim_prefix("--qa-output=")
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("MANAGE_TARGET_REVIEW ", JSON.stringify(result))
	quit(0 if result.failures.is_empty() else 1)
