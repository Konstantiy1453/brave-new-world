extends RefCounted
## Sound cues (1.11). `play(id)` is where a later audio pass puts the sounds; it does nothing yet.
## The interface plays a cue when a ship arrives, a stage receives its acceptance stamp, a
## signature is made, a company letter arrives, a storm is forecast and the game ends. `observe`
## looks at the state on each refresh and plays the cue of whatever arrived since the last look;
## the first look at a game (a new game or a load) only takes note.

const LETTER: String = "letter"
const STAMP: String = "stamp"
const SHIP: String = "ship"
const SIGNATURE: String = "signature"
const STORM: String = "storm"
const ENDING: String = "ending"

var _state: Dictionary = {}
var _seen: Dictionary = {}


static func play(_id: String) -> void:
	pass


## Plays the cues of what changed since the last call for the same game, and returns their ids.
func observe(sim: RefCounted) -> Array[String]:
	var now: Dictionary = marks(sim.state)
	var played: Array[String] = []
	if not is_same(sim.state, _state):
		_state = sim.state
		_seen = now
		return played
	if str(now[LETTER]) != str(_seen.get(LETTER, "")):
		played.append(LETTER)
	if int(now[STAMP]) > int(_seen.get(STAMP, 0)):
		played.append(STAMP)
	if str(now[ENDING]) != "" and str(now[ENDING]) != str(_seen.get(ENDING, "")):
		played.append(ENDING)
	if str(now[SHIP]) != "" and str(now[SHIP]) != str(_seen.get(SHIP, "")):
		played.append(SHIP)
	if int(now[SIGNATURE]) > int(_seen.get(SIGNATURE, 0)):
		played.append(SIGNATURE)
	if str(now[STORM]) != "" and str(now[STORM]) != str(_seen.get(STORM, "")):
		played.append(STORM)
	_seen = now
	for id: String in played:
		play(id)
	return played


## What the cues watch: the newest letter, how many stages are accepted, how the game ended, the
## annual report waiting for a signature, and how many reports and amendments are signed.
static func marks(state: Dictionary) -> Dictionary:
	var letters: Array = state.get("company", {}).get("letters", [])
	var newest: String = ""
	if not letters.is_empty():
		var last: Dictionary = letters.back()
		newest = (
			"%d|%d|%s" % [letters.size(), int(last.get("day", 0)), str(last.get("subject", ""))]
		)
	var status: String = str(state.get("status", ""))
	var annual: Dictionary = state.get("annual", {})
	var pending: Dictionary = annual.get("pending", {})
	var signed: int = (
		annual.get("history", []).size() + state.get("contract", {}).get("amendments", []).size()
	)
	return {
		LETTER: newest,
		STAMP: state.get("contract", {}).get("completed", {}).size(),
		ENDING:
		(
			"%s|%s" % [status, str(state.get("ending", {}).get("kind", ""))]
			if status in ["success", "failed"]
			else ""
		),
		SHIP: "" if pending.is_empty() else str(pending.get("year", "")),
		SIGNATURE: signed,
		STORM: _warning_mark(state),
	}


## The newest weather warning for a town (1.11 F): system id, town and day, or "".
static func _warning_mark(state: Dictionary) -> String:
	var mark: String = ""
	var latest: int = -1
	for system: Dictionary in state.get("weather", {}).get("systems", []):
		for key: Variant in system.get("warned", {}):
			var day: int = int(system.warned[key])
			if day > latest or (day == latest and mark < "%d|%s" % [int(system.id), str(key)]):
				latest = day
				mark = "%d|%s" % [int(system.id), str(key)]
	return "" if latest < 0 else "%s|%d" % [mark, latest]


## The newest warning in words, for the notice.
static func newest_warning(sim: RefCounted) -> String:
	var mark: String = _warning_mark(sim.state)
	if mark == "":
		return ""
	var parts: PackedStringArray = mark.split("|")
	for system: Dictionary in sim.state.weather.systems:
		if int(system.id) == int(parts[0]):
			var rule: Dictionary = sim.Weather.rules().kinds[system.kind]
			var town: Dictionary = sim.settlement(int(parts[1]))
			return "%s正在逼近%s：可在天气页做防灾准备。" % [str(rule.name), str(town.get("name", ""))]
	return ""
