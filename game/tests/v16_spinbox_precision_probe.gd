extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")


func _initialize():
	Watchdog.arm(self)
	call_deferred("run")


func run():
	var amount = SpinBox.new()
	amount.max_value = 10000
	amount.step = 0
	amount.value = 201.65
	root.add_child(amount)
	await process_frame
	var properties: Array = []
	for p in amount.get_property_list():
		if "step" in p.name:
			properties.append(p.name)
	print(
		"SPINBOX_PRECISION ",
		JSON.stringify(
			{
				"value": amount.value,
				"text": amount.get_line_edit().text,
				"step_properties": properties
			}
		)
	)
	amount.queue_free()
	await process_frame
	quit()
