extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")


func _init() -> void:
	Watchdog.arm(self)
	var sim = load("res://simulation/sim.gd").new()
	var events = load("res://simulation/events_v2.gd")
	sim.new_game(20261029, "science", 1)
	sim.act("settle", {"region": 0})
	sim.state.events_v2.next_draw = 9999  # Explicit event fixture, real economy thereafter.
	for kind in ["mine_ore", "mine_copper", "processor", "power"]:
		sim.act("build", {"region": 0, "kind": kind})
	for d in range(10):
		sim.tick()
	var inst: Dictionary = events._open(sim, "industry", 0)
	events.act(sim, {"instance_id": inst.instance_id, "choice": "small"})
	var trace: Array = []
	for d in range(30):
		if inst.status == "pending":
			events.act(
				sim,
				{
					"instance_id": inst.instance_id,
					"choice": "standard" if inst.node == "delivered" else "continue"
				}
			)
		if inst.status == "resolved":
			break
		sim.tick()
		var s: Dictionary = sim.settlement(0)
		trace.append(
			{
				"day": sim.state.day,
				"stock": s.stock.parts,
				"exportable": s.get("exportable", {}).get("parts", 0),
				"sources": sim.state.resource_sources.parts,
				"dispatched": inst.order.dispatched,
				"delivered": inst.order.delivered,
				"port_capacity": s.port_capacity,
				"port_used": s.port_used
			}
		)
	print(
		"ORDER_PROBE trace=",
		JSON.stringify(trace),
		" ending=",
		inst.ending,
		" paid=",
		inst.order.paid,
		" audit=",
		sim.audit()
	)
	quit(0 if inst.ending == "准时交付" and inst.order.paid == 110 and sim.audit().is_empty() else 1)
