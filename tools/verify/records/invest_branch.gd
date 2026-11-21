extends SceneTree
## Matched branches from one save: --branch=invest orders --kind in the capital on the save's day,
## --branch=skip does not; both then run --days days answering communications only. Records the
## public cash each day, and (invest) the order screen's estimate.
const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
var options: Dictionary = {
	"save": "", "out": "", "branch": "invest", "kind": "processor", "days": "400"
}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	create_timer(900.0).timeout.connect(
		func():
			printerr("WATCHDOG")
			quit(2)
	)
	call_deferred("run")


func run() -> void:
	var sim: RefCounted = Sim.new()
	printerr("LOAD ", sim.load_game(str(options.save)), " day ", sim.state.day)
	var s: Dictionary = sim.state.settlements[0]
	var region: int = int(s.region)
	var kind: String = str(options.kind)
	var record: Dictionary = {
		"day": int(sim.state.day), "branch": options.branch, "cash": [], "estimate": {}
	}
	var forecast: Dictionary = sim.build_forecast(region, kind)
	record.old_payback = float(forecast.payback_days)
	record.old_net = float(forecast.net_per_day)
	record.old_cost = float(forecast.cost)
	if sim.has_method("checkout"):
		var order: Dictionary = sim.checkout(region, kind)
		var benefit: Dictionary = order.benefit
		record.estimate = {
			"cash_now": order.cash_now,
			"in_service": order.in_service,
			"net_low": benefit.net_low,
			"net_high": benefit.net_high,
			"payback_order": benefit.payback_order,
			"payback_start": benefit.payback_start,
			"outlay": benefit.outlay,
			"replaces": benefit.replaces_imports,
			"receipts": benefit.export_receipts,
			"input_cost": benefit.input_cost,
			"wages": benefit.wages,
			"upkeep": benefit.upkeep,
			"input_share": benefit.input_share,
			"staffed": benefit.staffed
		}
		printerr("ESTIMATE ", JSON.stringify(record.estimate))
	printerr(
		(
			"OLD forecast payback=%.0f net=%.1f cost=%.0f"
			% [record.old_payback, record.old_net, record.old_cost]
		)
	)
	if str(options.branch) == "invest":
		printerr("BUILD ", sim.act("build", {"site": region, "kind": kind}))
	var bot: RefCounted = Bot.new()
	bot.begin(sim, int(sim.state.world.seed))
	record.stage = []
	record.worth = []
	record.rewards = []
	record.operating = []
	record.event_money = []
	var events_total: float = 0.0
	var mark: Variant = sim.state.ledger.back() if not sim.state.ledger.is_empty() else null
	for _d: int in range(int(options.days)):
		bot.answer_events()
		var stage_before: int = int(sim.state.contract.stage)
		var cash_before: float = float(sim.state.cash)
		sim.tick()
		record.cash.append(snappedf(float(sim.state.cash), 0.01))
		# Money communications paid or cost (loans, rewards, fees, upkeep), including what an answer
		# paid before the day ran, kept apart: when they come differs by branch.
		# The ledger keeps its last 1,800 entries: walk back to the last one already counted.
		var index: int = sim.state.ledger.size() - 1
		while index >= 0 and not is_same(sim.state.ledger[index], mark):
			var entry: Variant = sim.state.ledger[index]
			if entry is Dictionary and str(entry.get("key", "")).begins_with("event."):
				var amount: float = float(entry.get("amount", 0.0))
				if str(entry.get("to", "")) == "public":
					events_total += amount
				elif str(entry.get("from", "")) == "public":
					events_total -= amount
			index -= 1
		mark = sim.state.ledger.back() if not sim.state.ledger.is_empty() else null
		record.event_money.append(snappedf(events_total, 0.01))
		# Cash plus every town's stock at today's selling price: what the colony is worth.
		var goods: float = 0.0
		for town: Dictionary in sim.state.settlements:
			for good: String in town.stock:
				if sim.config.prices.has(good):
					goods += float(town.stock[good]) * float(sim.Market.price(sim, good))
		record.worth.append(snappedf(float(sim.state.cash) + goods, 0.01))
		record.stage.append(int(sim.state.contract.stage))
		record.operating.append(snappedf(float(sim.state.get("operating_net", 0.0)), 0.01))
		if int(sim.state.contract.stage) != stage_before:
			var reward: float = float(
				sim.contract_rules.stages[stage_before - 1].get("reward_cash", 0.0)
			)
			record.rewards.append(
				{
					"day": int(sim.state.day),
					"stage": stage_before,
					"reward": reward,
					"cash_jump": snappedf(float(sim.state.cash) - cash_before, 0.01)
				}
			)
	var file: FileAccess = FileAccess.open(str(options.out), FileAccess.WRITE)
	file.store_string(JSON.stringify(record))
	file.close()
	printerr("DONE ", options.branch)
	quit(0)
