extends RefCounted
## Developer measure on the player's own machine: save, load, autosave frames, page opens and cold
## region loads, with sample counts. Run the source project or the exported EXE with
## --dev --dev-script=<this file> --perf-out=<folder> --perf-save=<a save file>.
## Writes perf_report.json to the folder.

const Sim = preload("res://simulation/sim.gd")
const SAVE_SAMPLES: int = 20
const AUTOSAVE_SAMPLES: int = 12
const AUTOSAVE_FRAMES: int = 45
const PAGE_SAMPLES: int = 8
const REGION_SAMPLES: int = 8
const SETTLE_FRAMES: int = 10
const PAGES: Array[String] = [
	"economy", "build", "research", "contract", "transport", "population", "company", "events"
]


static func run(g) -> void:
	var folder: String = ""
	var fixture: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--perf-save="):
			fixture = argument.trim_prefix("--perf-save=")
		if argument.begins_with("--perf-out="):
			folder = argument.trim_prefix("--perf-out=")
	DirAccess.make_dir_recursive_absolute(folder)
	var report: Dictionary = {
		"kind": "exported EXE" if OS.has_feature("template") else "source-project window",
		"adapter": RenderingServer.get_video_adapter_name(),
		"cpu": OS.get_processor_name(),
		"threads": OS.get_processor_count(),
		"window": str(DisplayServer.window_get_size()),
		"fixture": fixture,
		"failures": [],
	}
	var error: String = g.sim.load_game(fixture)
	if error != "":
		report.failures.append(fixture + ": " + error)
	else:
		g.load_path(fixture)
		g.paused = true
		await _settle(g)
		report.day = int(g.sim.state.day)
		report.saves = _saves(g)
		report.autosave = await _autosave(g)
		report.pages = await _pages(g)
		report.regions = await _regions(g)
	var file: FileAccess = FileAccess.open(folder + "/perf_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("V17_PERF_RESULT ", JSON.stringify(report))
	g.get_tree().quit(0 if report.failures.is_empty() else 1)


static func _saves(g) -> Dictionary:
	var path: String = "user://perf_probe.save"
	var writes: Array = []
	for _i: int in range(SAVE_SAMPLES):
		var start: int = Time.get_ticks_usec()
		g.sim.save_game(path)
		writes.append((Time.get_ticks_usec() - start) / 1000.0)
	var reads: Array = []
	var other: RefCounted = Sim.new()
	for _i: int in range(SAVE_SAMPLES):
		var start: int = Time.get_ticks_usec()
		other.load_game(path)
		reads.append((Time.get_ticks_usec() - start) / 1000.0)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var size: int = file.get_length()
	file.close()
	return {
		"bytes": size,
		"save_ms": _spread(writes),
		"load_ms": _spread(reads),
		"samples": SAVE_SAMPLES,
	}


## The worst frame while an autosave runs, next to the worst frame without one.
static func _autosave(g) -> Dictionary:
	var quiet: Array = await _frames(g, AUTOSAVE_FRAMES)
	var during: Array = []
	var finish_frames: Array = []
	for _i: int in range(AUTOSAVE_SAMPLES):
		g._begin_autosave()
		var frames: Array = await _frames(g, AUTOSAVE_FRAMES)
		during.append(frames.max())
		finish_frames.append(g.autosave_task < 0)
	return {
		"quiet_worst_frame_ms": quiet.max(),
		"autosave_worst_frame_ms": _spread(during),
		"samples": AUTOSAVE_SAMPLES,
		"frames_per_sample": AUTOSAVE_FRAMES,
		"all_finished": not finish_frames.has(false),
	}


## From the call to the first frame on screen with the page in it.
static func _pages(g) -> Dictionary:
	var result: Dictionary = {}
	for page: String in PAGES:
		g.close_modal()
		await _settle(g)
		var first: float = await _open(g, page)
		var warm: Array = []
		for _i: int in range(PAGE_SAMPLES):
			g.close_modal()
			await _settle(g)
			warm.append(await _open(g, page))
		result[page] = {"cold_ms": first, "warm_ms": _spread(warm), "samples": PAGE_SAMPLES}
	g.close_modal()
	return result


static func _open(g, page: String) -> float:
	var start: int = Time.get_ticks_usec()
	g.open_page(page)
	await RenderingServer.frame_post_draw
	return (Time.get_ticks_usec() - start) / 1000.0


## Each site's first opening, with the worst frame on the way.
static func _regions(g) -> Dictionary:
	var loads: Array = []
	var worst: Array = []
	var sites: Array = g.sim.state.world.regions
	for index: int in range(mini(REGION_SAMPLES, sites.size())):
		g.selected = int(sites[index * 2 % sites.size()].id)
		g.navigate("planet")
		await _settle(g)
		var start: int = Time.get_ticks_usec()
		var slowest: float = 0.0
		g.navigate("region")
		var last: int = Time.get_ticks_usec()
		while bool(g.map.region_busy):
			await g.get_tree().process_frame
			var now: int = Time.get_ticks_usec()
			slowest = maxf(slowest, (now - last) / 1000.0)
			last = now
		await RenderingServer.frame_post_draw
		loads.append((Time.get_ticks_usec() - start) / 1000.0)
		worst.append(slowest)
	g.navigate("planet")
	return {
		"cold_load_ms": _spread(loads),
		"worst_frame_ms": _spread(worst),
		"samples": loads.size(),
	}


static func _frames(g, count: int) -> Array:
	var values: Array = []
	var last: int = Time.get_ticks_usec()
	for _i: int in range(count):
		await g.get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		values.append((now - last) / 1000.0)
		last = now
	return values


static func _settle(g) -> void:
	for _i: int in range(SETTLE_FRAMES):
		await g.get_tree().process_frame


static func _spread(values: Array) -> Dictionary:
	var sorted: Array = values.duplicate()
	sorted.sort()
	return {
		"min": sorted[0],
		"median": sorted[sorted.size() / 2],
		"max": sorted[sorted.size() - 1],
	}
