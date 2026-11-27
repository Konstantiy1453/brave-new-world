extends RefCounted
## The district's parcel survey, in display units. Saved plot indexes continue to identify
## resources and buildings; this layout provides their surveyed positions and the local shoreline.

const Plan = preload("res://world/district/district_plan.gd")
const PARCEL_PITCH: float = 6.55
const SAVED_PITCH: float = 6.0
## Largest reviewed footprint's circumscribed radius, bend, lot offset and a dry verge.
const DRY_RADIUS: float = 6.0
const MODEL_SHORE_SLOPE: float = 0.17


static func shore_depth(at: Vector2, shore: Dictionary) -> float:
	var out: Vector2 = shore.out
	var t: float = at.dot(out.orthogonal())
	var p: Vector2 = shore.phase
	var bends: float = 5.1 * sin(t * 0.063 + p.x) + 2.05 * sin(t * 0.151 + p.y)
	bends += 0.70 * sin(t * 0.293 + p.x - p.y)
	return float(shore.reach) + bends - at.dot(out)


static func shore_height(at: Vector2, shore: Dictionary, sea: float, natural: float) -> float:
	var depth: float = shore_depth(at, shore)
	var bank: float = sea + depth * MODEL_SHORE_SLOPE
	if depth < 0.0:
		return maxf(sea - 5.0, bank)
	var dry: float = maxf(sea + 1.0, natural)
	return lerpf(bank, dry, smoothstep(3.0, 14.0, depth))


static func survey(plots: Array, shore: Dictionary, lakes: Array, half: Vector2, reserve: int) -> Dictionary:
	var candidates: Array[Vector2] = []
	var nx: int = floori((half.x - DRY_RADIUS - 1.0) / PARCEL_PITCH)
	var nz: int = floori((half.y - DRY_RADIUS - 1.0) / PARCEL_PITCH)
	for row: int in range(-nz, nz + 1):
		for col: int in range(-nx, nx + 1):
			if col == 0:
				continue
			var at := Vector2(col, row) * PARCEL_PITCH
			if not shore.is_empty():
				# shore_depth measures along the outward normal. Its largest tangent slope is 0.84.
				if shore_depth(at, shore) < DRY_RADIUS * 1.32:
					continue
			var clear: bool = true
			for lake: Dictionary in lakes:
				if at.distance_to(lake.center) < float(lake.radius) + DRY_RADIUS:
					clear = false
					break
			if clear:
				candidates.append(at)
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.length_squared() < b.length_squared() if a.length_squared() != b.length_squared() else a < b
	)
	var slots: Array[Vector2] = []
	slots.resize(plots.size())
	var remaining: Array[int] = []
	for index: int in range(plots.size()):
		var p: Dictionary = plots[index]
		var desired := Vector2(float(p.x), float(p.z)) * (PARCEL_PITCH / SAVED_PITCH)
		var exact: int = candidates.find(desired.snapped(Vector2.ONE * PARCEL_PITCH))
		if exact >= 0:
			slots[index] = candidates[exact]
			candidates.remove_at(exact)
		else:
			remaining.append(index)
	for index: int in remaining:
		var p: Dictionary = plots[index]
		var desired := Vector2(float(p.x), float(p.z)) * (PARCEL_PITCH / SAVED_PITCH)
		var best: int = -1
		var nearest: float = INF
		for i: int in range(candidates.size()):
			var gap: float = candidates[i].distance_squared_to(desired)
			if gap < nearest:
				nearest = gap
				best = i
		if best < 0:
			# The region builder expands the field and repeats the survey for large old colonies.
			return {}
		slots[index] = candidates[best]
		candidates.remove_at(best)
	if candidates.size() < reserve + 1:
		return {}
	var camp: Vector2 = candidates.pop_front()
	return {"plots": slots, "camp": camp, "spares": candidates, "shore": shore, "half": half}
