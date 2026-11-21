extends SceneTree
## For each recommended site: the world generator's plots and deposits (what markers and filters
## show) against the site founding at its coordinate gives (Placement.site_for).
const Sim = preload("res://simulation/sim.gd")
var options: Dictionary = {"seed": "1", "limit": "40"}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	create_timer(600.0).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _counts(plots: Array) -> Dictionary:
	var c: Dictionary = {}
	for plot: Dictionary in plots:
		var k: String = (
			str(plot.kind)
			if str(plot.kind) != "deposit"
			else "dep_" + str(plot.get("resource", "?"))
		)
		c[k] = int(c.get(k, 0)) + 1
	return c


func _run() -> void:
	var sim: RefCounted = Sim.new()
	sim.new_game(int(options.seed), "capital", 1, "normal")
	var same: int = 0
	var differ: int = 0
	for reg: Dictionary in sim.state.world.regions.slice(0, int(options.limit)):
		var site: Dictionary = sim.Placement.site_for(sim, float(reg.lat), float(reg.lon))
		var a: Dictionary = _counts(reg.get("plots", []))
		var b: Dictionary = _counts(site.get("plots", []))
		var da: Dictionary = {}
		for k: String in reg.get("deposits", {}):
			da[k] = snappedf(float(reg.deposits[k]), 1.0)
		var db: Dictionary = {}
		for k: String in site.get("deposits", {}):
			db[k] = snappedf(float(site.deposits[k]), 1.0)
		var ok: bool = JSON.stringify(a) == JSON.stringify(b)
		if ok:
			same += 1
		else:
			differ += 1
		printerr(
			(
				"R%d %s plots %s | site %s ; deposits %s | %s"
				% [
					int(reg.id),
					"SAME" if ok else "DIFF",
					JSON.stringify(a),
					JSON.stringify(b),
					JSON.stringify(da),
					JSON.stringify(db)
				]
			)
		)
	printerr("SUMMARY same=%d differ=%d" % [same, differ])
	quit(0)
