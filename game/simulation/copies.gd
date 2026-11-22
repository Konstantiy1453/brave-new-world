extends RefCounted
## Copies of a building kind across the colony (1.9). Further copies cost more to build, and
## fixed-income buildings earn less per copy because their buyers are limited. No dependencies, so
## production and logistics can both use it.


## Buildings of a kind standing or under way, in every settlement.
static func count_kind(sim: RefCounted, kind: String) -> int:
	var count: int = 0
	for place: Dictionary in sim.state.settlements:
		for building: Dictionary in place.buildings:
			if str(building.kind) == kind:
				count += 1
	return count


## What a building earns relative to the first of its kind: each working copy beyond `free` earns
## `factor` of the one before. Order is settlement order, then build order, so the same state always
## gives the same answer.
static func factor_for(sim: RefCounted, building: Dictionary, factor: float, free: int) -> float:
	var rank: int = 0
	for place: Dictionary in sim.state.settlements:
		for other: Dictionary in place.buildings:
			if is_same(other, building):
				return pow(factor, maxi(0, rank + 1 - free))
			if str(other.kind) == str(building.kind) and bool(other.get("active", false)):
				rank += 1
	return 1.0


## The same factor for one more copy, as the build forecast needs it.
static func next_factor(sim: RefCounted, kind: String, factor: float, free: int) -> float:
	var working: int = 0
	for place: Dictionary in sim.state.settlements:
		for other: Dictionary in place.buildings:
			if str(other.kind) == kind and bool(other.get("active", false)):
				working += 1
	return pow(factor, maxi(0, working + 1 - free))
