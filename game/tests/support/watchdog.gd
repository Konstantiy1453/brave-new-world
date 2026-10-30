extends RefCounted
## Ends a SceneTree test with exit code 2 when it overruns, so a script error that
## aborts the test body can never leave the headless process running forever.

const DEFAULT_SECONDS: float = 540.0
const SECONDS_ARGUMENT: String = "--watchdog="


static func arm(tree: SceneTree, seconds: float = DEFAULT_SECONDS) -> void:
	var limit: float = seconds
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SECONDS_ARGUMENT):
			limit = float(argument.trim_prefix(SECONDS_ARGUMENT))
	var timer: SceneTreeTimer = tree.create_timer(limit, true, false, true)
	timer.timeout.connect(_on_timeout.bind(tree, limit))


static func _on_timeout(tree: SceneTree, limit: float) -> void:
	print("WATCHDOG_TIMEOUT after %.0f s" % limit)
	tree.quit(2)
