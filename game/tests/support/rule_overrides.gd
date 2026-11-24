extends RefCounted
## Tuning (1.11 J): `--set=<file>.<path>=<value>` on a test tool's command line changes a number in
## the shared rule cache for this process only, before any game is made, e.g.
## `--set=population.immigration.jobless_free_share=0.25` (repeatable). Games read the change
## because `Sim` takes its rules from the cache when it is made. Returns what was set.

const Rules = preload("res://simulation/rules.gd")


static func apply(arguments: PackedStringArray) -> PackedStringArray:
	var applied: PackedStringArray = []
	for argument: String in arguments:
		if not argument.begins_with("--set="):
			continue
		var pair: PackedStringArray = argument.trim_prefix("--set=").split("=", true, 1)
		var path: PackedStringArray = pair[0].split(".")
		var node: Dictionary = Rules.read(path[0])
		for index: int in range(1, path.size() - 1):
			node = node[path[index]]
		node[path[path.size() - 1]] = float(pair[1])
		applied.append("%s = %s" % [pair[0], pair[1]])
	return applied
