extends RefCounted
## New games on a seed's CC-GEO-2.2 world (1.12). New expeditions draw CC-GEO-2.3; suites whose
## checks were written against the 2.2 geography of their fixed seeds, and test a system rather
## than the world (dispatch order, a farm's jobs, the labs, the weather's determinism), start on
## the same 2.2 world they always had, the way a 1.11 save does (world_gen.gd `bind`).

const WorldGen = preload("res://world/world_gen.gd")
const VERSION: String = "CC-GEO-2.2"


## The record a save keeps of its world, for `Sim.new_game`'s checkpoint argument.
static func record(seed_value: int, size: int = 1) -> Dictionary:
	var built: Dictionary = WorldGen.new().build(seed_value, size, VERSION)
	return {
		"seed": seed_value,
		"size": size,
		"version": VERSION,
		"hash": built.hash,
		"regions": built.regions,
		"radius_km": built.radius_km,
		"candidates": built.get("candidates", []),
	}


static func new_game(
	sim: RefCounted,
	seed_value: int,
	advantage: String,
	size: int = 1,
	difficulty: String = "normal",
	radius: float = 0.0
) -> String:
	return sim.new_game(seed_value, advantage, size, difficulty, radius, record(seed_value, size))
