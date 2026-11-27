extends SceneTree
## Event cards, follow-up arrivals, and the fleet purchase across two warehouses.
const Watchdog = preload("res://tests/support/watchdog.gd")
const Events = preload("res://simulation/events_v2.gd")
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	Watchdog.arm(self)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func words(node: Node) -> String:
	var lines: PackedStringArray = []
	for label: Label in node.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			lines.append(label.text)
	return "\n".join(lines)


func option_button(scene: Node, label: String) -> Button:
	for text: Label in scene.modal_box.find_children("*", "Label", true, false):
		if text.text.begins_with(label):
			return text.get_parent().get_child(text.get_index() + 1) as Button
	return null


func run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.close_modal()
	var sim: RefCounted = scene.sim
	var pair: Array = sim.geo.playability.pairs[0]
	var first: int = int(pair[0])
	var second: int = int(pair[1])
	check(sim.act("settle", {"site": first}) == "", "land the capital")
	sim._transfer("external", "public", 200000.0, "test", false)
	sim.state.contract.licences.append("expedition")
	check(sim.act("settle", {"site": second}) == "", "found the second warehouse")
	var host: Dictionary = sim.settlement(first)
	var other: Dictionary = sim.settlement(second)
	if other.is_empty():
		quit(1)
		return
	other.arrival = 0
	sim.state.events_v2.next_draw = 99999
	scene._announce_new_events()
	var freight: Dictionary = Events._open(sim, "retired_freighters", first)
	var trial: Dictionary = Events._open(sim, "red_ball_loop", first)
	var serial: int = int(sim.state.events_v2.next_id)
	var count: int = scene.notices.get_child_count()
	scene._announce_new_events()
	check(scene.notices.get_child_count() == count + 1, "simultaneous arrivals raise a popup")
	var arrival: Node = scene.notices.get_child(-1)
	var text: String = words(arrival)
	check(text.contains("船名下的两道旧漆") and text.contains("红漆尚未开封"), "both new titles appear")
	scene._announce_new_events()
	check(scene.notices.get_child_count() == count + 1, "the same chapters appear once")
	Events._enter(sim, trial, "adopted")
	scene._announce_new_events()
	check(
		int(sim.state.events_v2.next_id) == serial and words(scene.notices).contains("红球下方的小字"),
		"a later chapter appears without allocating a new instance"
	)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	arrival.gui_input.emit(click)
	check(scene.current_page == "events", "clicking the arrival opens communications")
	for store: Dictionary in [host, other]:
		sim._consume(store, "parts", float(store.stock.parts))
	sim._produce(host, "parts", 18.0, "test")
	sim._produce(other, "parts", 11.0, "test")
	scene.populate_current_page()
	var offer: Button = option_button(scene, "支付交接费用接收快船")
	check(is_instance_valid(offer) and offer.disabled, "2,900 t across both places falls short")
	check(words(scene.modal_box).contains("现有 2900 t"), "the exact warehouse shortage is visible")
	var cash: float = float(sim.state.cash)
	check(
		sim.act("event_v2", {"instance_id": freight.instance_id, "choice": "tow"}) != ""
		and is_equal_approx(cash, float(sim.state.cash)) and is_equal_approx(host.stock.parts, 18.0),
		"a refused payment changes neither cash nor stock"
	)
	sim._produce(other, "parts", 14.48, "test")
	scene.panel_pause = false
	scene.paused = false
	scene.speed = 1
	scene.advance_time(float(sim.progression.time.seconds_per_day))
	offer = option_button(scene, "支付交接费用接收快船")
	check(is_instance_valid(offer) and not offer.disabled, "an open event panel enables on the next day")
	var quote: float = 0.0
	for pending: Dictionary in Events.view(sim).pending:
		if pending.instance_id == freight.instance_id:
			quote = float(pending.choices[0].cost)
	var total: float = float(host.stock.parts) + float(other.stock.parts)
	cash = float(sim.state.cash)
	if is_instance_valid(offer) and not offer.disabled:
		offer.pressed.emit()
	check(is_equal_approx(total - host.stock.parts - other.stock.parts, 30.0), "exactly 3,000 t leave stores")
	check(is_equal_approx(cash - float(sim.state.cash), quote), "public cash is charged the displayed quote")
	check(freight.ending == "高速货轮入列" and sim.state.research.completed.has("fast_freighters"), "the fleet arrives")
	check(sim.act("event_v2", {"instance_id": freight.instance_id, "choice": "tow"}) != "", "one purchase only")
	scene.close_modal()
	scene.paused = false
	scene.act("policy", {"event_pause": "all"})
	var urgent: Dictionary = Events._open(sim, "water", first)
	scene._announce_new_events()
	check(urgent.pause_required and scene.paused and scene.current_page == "events", "mandatory decisions still pause")
	root.remove_child(scene)
	scene.free()
	print("V112_EVENT_FEEDBACK checks=%d failures=%d %s" % [checks, failures.size(), str(failures)])
	quit(0 if failures.is_empty() else 1)
