extends RefCounted
## Loads and validates the rule data in res://data/v17. Rules, UI text and tests read the same
## values. A malformed file fails loudly in debug builds.

const FILES: Dictionary = {
	"economy": "res://data/v17/economy.json",
	"progression": "res://data/v17/progression.json",
	"career": "res://data/v17/career.json",
	"events": "res://data/v17/events.json",
	"population": "res://data/v17/population.json",
	"contract": "res://data/v17/contract.json",
	"market": "res://data/v17/market.json",
	"geography": "res://data/v17/geography.json",
}
const REQUIRED: Dictionary = {
	"economy":
	[
		"version",
		"units",
		"resources",
		"prices",
		"economy",
		"openings",
		"buildings",
		"techs",
		"contract"
	],
	"progression": ["version", "units", "difficulty", "research", "company", "production", "time"],
	"career": ["version", "units", "calendar", "management"],
	"events": ["version", "units", "sampling", "definitions"],
	"population":
	[
		"version",
		"units",
		"housing",
		"immigration",
		"attractiveness",
		"wage",
		"recruitment",
		"departure",
		"births",
		"migration"
	],
	"contract":
	[
		"version",
		"units",
		"scaled_goals",
		"difficulty_scale",
		"deadlines",
		"settlement_cap",
		"stages",
		"milestones"
	],
	"market": ["version", "units", "decay_per_day", "depth", "floor", "scale"],
	"geography":
	[
		"version",
		"units",
		"land_fraction",
		"continents",
		"attempts",
		"site_count",
		"archetypes",
		"validator",
		"plots",
		"survey",
		"names"
	],
}

static var _loaded: Dictionary = {}


static func read(name: String) -> Dictionary:
	if not _loaded.has(name):
		_loaded[name] = _load_file(name)
	return _loaded[name]


## A private copy, so tests that adjust a number cannot leak into another simulation.
static func economy() -> Dictionary:
	return read("economy").duplicate(true)


static func progression() -> Dictionary:
	return read("progression").duplicate(true)


static func _load_file(name: String) -> Dictionary:
	var path: String = FILES[name]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_complain("%s is not a JSON object" % path)
		return {}
	var data: Dictionary = parsed
	for key: String in REQUIRED[name]:
		if not data.has(key):
			_complain("%s is missing '%s'" % [path, key])
	return data


static func _complain(message: String) -> void:
	push_error("RULES: " + message)
	assert(false, "RULES: " + message)
