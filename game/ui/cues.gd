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
	_seen = now
	for id: String in played:
		play(id)
	return played


## What the cues watch: the newest letter, how many stages are accepted, and how the game ended.
static func marks(state: Dictionary) -> Dictionary:
	var letters: Array = state.get("company", {}).get("letters", [])
	var newest: String = ""
	if not letters.is_empty():
		var last: Dictionary = letters.back()
		newest = (
			"%d|%d|%s" % [letters.size(), int(last.get("day", 0)), str(last.get("subject", ""))]
		)
	var status: String = str(state.get("status", ""))
	return {
		LETTER: newest,
		STAMP: state.get("contract", {}).get("completed", {}).size(),
		ENDING: status if status in ["success", "failed"] else "",
	}
