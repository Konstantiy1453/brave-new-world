extends SceneTree
## Needs a real window and is meant for the player's own GPU. Plays a colony with the balanced bot,
## then times frames with vsync off on the moving map: the globe by day and at night, the flat map,
## and a region by day and at night, with every effect on and again with clouds off. Writes
## frame_times.json (mean and 95th percentile milliseconds, frames per second) to --out.
## Options: --seed=260129 --days=900 --frames=240 --size=1920x1080
##   --out=res://../evidence/v17/perf

const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const Bot = preload("res://tests/balance/bots/balanced_bot.gd")
const Map = preload("res://world/map_view.gd")
const WARM_FRAMES: int = 30

var options: Dictionary = {
	"seed": "260129",
	"days": "900",
	"frames": "240",
	"size": "1920x1080",
	"out": "res://../evidence/v17/perf",
}
var map: Node3D
var report: Dictionary = {"views": [], "adapter": "", "driver": ""}


func _initialize() -> void:
	Watchdog.arm(self, 1200.0)
	call_deferred("run")


func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var size: PackedStringArray = str(options.size).split("x")
	root.size = Vector2i(int(size[0]), int(size[1]))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	report.adapter = RenderingServer.get_video_adapter_name()
	report.driver = RenderingServer.get_video_adapter_api_version()
	report.size = str(options.size)
	var sim: RefCounted = Sim.new()
	sim.new_game(int(options.seed), "capital", 1, "normal")
	var bot: RefCounted = Bot.new()
	bot.begin(sim, int(options.seed))
	for _day: int in range(int(options.days)):
		bot.on_day()
		sim.tick()
	map = Map.new()
	root.add_child(map)
	map.setup(sim.geo)
	map.sync_state(sim.state)
	while map.atlas_refining:
		await process_frame
	var home: Dictionary = sim.geo.regions[int(sim.state.settlements[0].region)]
	for clouds: bool in [true, false]:
		map.set_visual_options(true, true, clouds)
		var suffix: String = "" if clouds else " (clouds off)"
		map.show_planet()
		_local_time(home, 0.55)
		await _measure("globe day" + suffix)
		_local_time(home, PI)
		await _measure("globe night" + suffix)
		map.show_flat()
		await _measure("flat map" + suffix)
		map.show_region(int(home.id))
		while map.region_busy:
			await process_frame
		_local_time(home, 0.35)
		await _measure("region day" + suffix)
		_local_time(home, PI)
		await _measure("region night" + suffix)
	var folder: String = ProjectSettings.globalize_path(str(options.out))
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder + "/frame_times.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	for view: Dictionary in report.views:
		print(
			(
				"FRAME_TIME %-26s mean %.2f ms  p95 %.2f ms  %.0f fps"
				% [view.name, view.mean_ms, view.p95_ms, view.fps]
			)
		)
	print("FRAME_TIME_RESULT views=%d adapter=%s" % [report.views.size(), report.adapter])
	quit(0)


## Hour angle 0 is local noon at the site, PI local midnight.
func _local_time(site: Dictionary, hour_angle: float) -> void:
	map.sky.spin = wrapf(map.sky.sun_yaw - deg_to_rad(float(site.lon)) + hour_angle, 0.0, TAU)


func _measure(name: String) -> void:
	for _frame: int in range(WARM_FRAMES):
		await process_frame
	var times: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for _frame: int in range(int(options.frames)):
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	var total: float = 0.0
	for value: float in times:
		total += value
	var sorted: Array[float] = times.duplicate()
	sorted.sort()
	var mean: float = total / maxi(1, times.size())
	var p95: float = sorted[clampi(int(sorted.size() * 0.95), 0, sorted.size() - 1)]
	report.views.append(
		{"name": name, "mean_ms": mean, "p95_ms": p95, "fps": 1000.0 / maxf(mean, 0.001)}
	)
