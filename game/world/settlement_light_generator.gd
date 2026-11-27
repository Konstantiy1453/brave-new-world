extends RefCounted
## Orbital neighbourhoods grow through reachable land parcels from the landing.
## Parcel order, its streets and their illumination are fixed for the life of
## this site. Stage changes expose more of that same plan, including in replay.

const Ground = preload("res://world/settlement_light_ground.gd")
const BLOCKS = preload("res://assets/textures/settlement_light_blocks.webp")
const GRID := 35
## The 105-sample local footprint leaves room to filter fine streets when
## projecting them onto the shared planetary atlas.
const BLOCK := 3
const SIZE := GRID * BLOCK
const HALF_SPAN := 3.65
const ADJACENT := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1)
]
## Stage 2/4 and 3/4 occupied-area ratios in the five approved light sheets.
## The final stage advances the same mean equivalent width as the preceding two.
const AREA_SHARES := [
	Vector2(.103, .384), Vector2(.143, .465), Vector2(.162, .525), Vector2(.130, .396), Vector2(.249, .531)
]
const MATURE_PARCELS := 180
const CACHE_LIMIT := 64
static var _world: Dictionary
static var _cache := {}
static var _samples: Image
static var _block_mip: Image


## Returns an RGB8 square with north at its top; half_span is the azimuthal
## equidistant radius in degrees from its centre to the middle of any edge.
static func generate(world: Dictionary, town: Dictionary, stage: int) -> Dictionary:
	if not is_same(_world, world):
		_world = world
		_cache.clear()
	var lat := clampf(float(town.get("lat", 0.0)), -90.0, 90.0)
	var lon := wrapf(float(town.get("lon", 0.0)), -180, 180)
	var key := Vector2(lat, lon)
	if not _cache.has(key):
		if _cache.size() >= CACHE_LIMIT:
			_cache.erase(_cache.keys()[0])
		var reg: Dictionary = {}
		var region := int(town.get("region", -1))
		var regions: Array = world.get("regions", [])
		if region >= 0 and region < regions.size():
			reg = regions[region]
		_cache[key] = _plan(world, key, reg)
	stage = 0 if bool(town.get("frontier", false)) or town.get("kind", "") == "frontier" else clampi(stage, 0, 4)
	var plan: Dictionary = _cache[key]
	var frames: Dictionary = plan.frames
	if not frames.has(stage):
		var rgb: PackedByteArray = plan.rgb.duplicate()
		var birth: PackedByteArray = plan.birth
		var tight: bool = plan.tight
		for i in birth.size():
			if birth[i] > stage:
				rgb[3 * i] = 0
				rgb[3 * i + 1] = 0
				rgb[3 * i + 2] = 0
			elif tight:
				# On a sub-pixel shoal growth can only intensify its existing camp.
				var intensity := .58 + .105 * stage
				for c in 3:
					rgb[3 * i + c] = roundi(rgb[3 * i + c] * intensity)
		frames[stage] = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, rgb)
	return {"image": frames[stage], "half_span": HALF_SPAN}


static func _center(i: int) -> Vector2i:
	return Vector2i((i % GRID) * BLOCK + BLOCK / 2, (i / GRID) * BLOCK + BLOCK / 2)


static func _plan(world: Dictionary, ll: Vector2, reg: Dictionary) -> Dictionary:
	if _samples == null:
		_samples = BLOCKS.get_image()
		_block_mip = _samples.duplicate()
		_block_mip.resize(96, 120, Image.INTERPOLATE_BILINEAR)
	var ground := Ground.new(world, ll, HALF_SPAN, SIZE)
	var heights := PackedFloat32Array()
	heights.resize(GRID * GRID)
	var wet_count := 0
	var max_height := -INF
	var min_height := INF
	for i in heights.size():
		heights[i] = ground.elevation(_center(i))
		if heights[i] < 0.0:
			wet_count += 1
		else:
			min_height = minf(min_height, heights[i])
			max_height = maxf(max_height, heights[i])
	var form := _environment(reg, wet_count, max_height - min_height, ground.river_here)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(world.get("seed", 0)), roundi(ll.x * 100000), roundi(ll.y * 100000)])
	var fabric_angle := rng.randf_range(0.0, PI)
	var salt := Vector2(rng.randf_range(0, 1000), rng.randf_range(0, 1000))
	var variation := FastNoiseLite.new()
	variation.seed = rng.randi()
	variation.frequency = 0.145
	var start := _landing(heights)
	var origin := _center(start) if start >= 0 else Vector2i(SIZE / 2, SIZE / 2)
	if start < 0 or origin != Vector2i(SIZE / 2, SIZE / 2):
		# A dry sliver of shore can fit between every coarse centre while the
		# player-selected anchor touches a narrow river. Recover its nearest bank.
		var best := INF if start < 0 else float(origin.distance_squared_to(Vector2i(SIZE / 2, SIZE / 2)))
		var best_height := heights[start] if start >= 0 else 0.0
		for y in range(SIZE / 2 - 2 * BLOCK, SIZE / 2 + 2 * BLOCK + 1):
			for x in range(SIZE / 2 - 2 * BLOCK, SIZE / 2 + 2 * BLOCK + 1):
				var p := Vector2i(x, y)
				var d := float(p.distance_squared_to(Vector2i(SIZE / 2, SIZE / 2)))
				if d >= best:
					continue
				var h := ground.elevation(p)
				if h >= 0.0:
					best = d
					origin = p
					start = (y / BLOCK) * GRID + x / BLOCK
					best_height = h
		if start >= 0:
			heights[start] = best_height
	var order := _spread(ground, heights, start, fabric_angle, variation)
	var limits := _limits(form)
	var birth := PackedByteArray()
	birth.resize(SIZE * SIZE)
	birth.fill(255)
	var rgb := PackedByteArray()
	rgb.resize(SIZE * SIZE * 3)
	var tight := false
	if start >= 0:
		var fabric := {"form": form, "angle": fabric_angle, "offset": salt, "noise": variation}
		tight = _paint(ground, order, limits, origin, fabric, birth, rgb)
	return {"rgb": rgb, "birth": birth, "frames": {}, "tight": tight}


static func _environment(reg: Dictionary, wet: int, relief: float, river: bool) -> int:
	var shape := str(reg.get("archetype", ""))
	var coast := bool(reg.get("coast", false)) or wet > GRID * GRID / 7
	if coast and relief > .25:
		return 3
	if coast:
		return 0
	if shape == "arid" or float(reg.get("rainfall", .50)) < .23:
		return 4
	if relief > .22 or shape == "highland_mining":
		return 2
	return 1 if river or bool(reg.get("river", false)) or shape == "fertile_valley" else 0


static func _limits(form: int) -> PackedInt32Array:
	var share: Vector2 = AREA_SHARES[form]
	var capital := MATURE_PARCELS * pow((3.0 - sqrt(share.x)) * .5, 2.0)
	return PackedInt32Array(
		[3, roundi(MATURE_PARCELS * share.x), roundi(MATURE_PARCELS * share.y), MATURE_PARCELS, roundi(capital)]
	)


static func _landing(heights: PackedFloat32Array) -> int:
	var mid := GRID / 2
	var best := -1
	var best_d := INF
	# A legal site can lie on a narrow river centreline. Its first streets start
	# at the nearest dry bank in the immediate surroundings, never across the map.
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var i := (mid + dy) * GRID + mid + dx
			var d := float(dx * dx + dy * dy)
			if heights[i] >= 0.0 and d < best_d:
				best = i
				best_d = d
	return best


static func _heap_push(heap: Array[Vector2], entry: Vector2) -> void:
	var i := heap.size()
	heap.append(entry)
	while i > 0:
		var parent := (i - 1) / 2
		if heap[parent].x <= entry.x:
			break
		heap[i] = heap[parent]
		i = parent
	heap[i] = entry


static func _heap_pop(heap: Array[Vector2]) -> Vector2:
	var root := heap[0]
	var last: Vector2 = heap.pop_back()
	if not heap.is_empty():
		var i := 0
		while i * 2 + 1 < heap.size():
			var child := i * 2 + 1
			if child + 1 < heap.size() and heap[child + 1].x < heap[child].x:
				child += 1
			if last.x <= heap[child].x:
				break
			heap[i] = heap[child]
			i = child
		heap[i] = last
	return root


static func _spread(
	ground: Ground, heights: PackedFloat32Array, start: int, angle: float, variation: FastNoiseLite
) -> PackedInt32Array:
	var count := GRID * GRID
	var order := PackedInt32Array()
	order.resize(count)
	order.fill(count)
	if start < 0:
		return order
	var cost := PackedFloat64Array()
	cost.resize(count)
	cost.fill(INF)
	cost[start] = 0.0
	var heap: Array[Vector2] = [Vector2(0.0, start)]
	var rank := 0
	var trunk := Vector2.from_angle(angle)
	while not heap.is_empty() and rank < 350:
		var entry := _heap_pop(heap)
		var i := int(entry.y)
		if order[i] < count:
			continue
		order[i] = rank
		rank += 1
		var cell := Vector2i(i % GRID, i / GRID)
		for step: Vector2i in ADJACENT:
			var next := cell + step
			if next.x < 0 or next.y < 0 or next.x >= GRID or next.y >= GRID:
				continue
			var j := next.y * GRID + next.x
			if heights[j] < 0.0 or order[j] < count:
				continue
			var diagonal := step.x != 0 and step.y != 0
			if diagonal and (heights[cell.y * GRID + next.x] < 0.0 or heights[next.y * GRID + cell.x] < 0.0):
				continue
			# Similar elevations are inexpensive even on a high plateau. A cliff
			# cannot be traversed simply because its summit is another dry cell.
			var rise := absf(heights[i] - heights[j])
			var distance := sqrt(2.0) if diagonal else 1.0
			if rise > .135 * distance:
				continue
			var blocked := false
			for k in range(1, BLOCK):
				if ground.channel_at(_center(i) + step * k):
					blocked = true
					break
			if blocked:
				continue
			var patch := variation.get_noise_2dv(Vector2(next)) * 1.75
			var along := absf(Vector2(step).normalized().dot(trunk.rotated(.75 * patch)))
			var margin := mini(mini(next.x, GRID - 1 - next.x), mini(next.y, GRID - 1 - next.y))
			var fringe := 1.0 + 1.65 * exp(-float(margin) * .72)
			var friction := (1.48 - .66 * along) * exp(patch) * (distance + 24.0 * rise) * fringe
			var candidate := cost[i] + friction
			if candidate < cost[j]:
				cost[j] = candidate
				_heap_push(heap, Vector2(candidate, j))
	return order


static func _paint(
	ground: Ground,
	order: PackedInt32Array,
	limits: PackedInt32Array,
	origin: Vector2i,
	fabric: Dictionary,
	births: PackedByteArray,
	rgb: PackedByteArray
) -> bool:
	var start := (origin.y / BLOCK) * GRID + origin.x / BLOCK
	var variation: FastNoiseLite = fabric.noise
	var salt: Vector2 = fabric.offset
	var angle: float = fabric.angle
	var form: int = fabric.form
	var sequence := PackedInt32Array()
	sequence.resize(SIZE * SIZE)
	sequence.fill(-1)
	var histogram := PackedInt32Array()
	histogram.resize((limits[4] + 1) * 32)
	# Offset the block outlines by less than half a parcel. Neighbour links and
	# water checks remain in the original physical chart.
	for y in SIZE:
		for x in SIZE:
			var p := Vector2i(x, y)
			var gx := x / BLOCK
			var gy := y / BLOCK
			var physical := gy * GRID + gx
			if order[physical] >= GRID * GRID:
				continue
			var wx := floori((x + .93 * sin(y * .25 + salt.x) + .42 * sin(x * .51 + y * .10)) / BLOCK)
			var wy := floori((y + .75 * sin(x * .25 + salt.y)) / BLOCK)
			var i := clampi(wy, 0, GRID - 1) * GRID + clampi(wx, 0, GRID - 1)
			if p == origin:
				i = start
			if order[i] >= limits[4]:
				continue
			var rank := order[i]
			if not ground.dry(p):
				continue
			var v := variation.get_noise_2d(gx * .68, gy * .68)
			var local_angle := angle + .72 * v
			var streets := Vector2(p - origin).rotated(local_angle) * 2.25 + salt
			var district := floori(streets.x / 34.0) + 5 * floori(streets.y / 29.0)
			var col := posmod(district, 2)
			if rank > 12 and (rank > 110 or posmod(district, 4) > 0):
				col += 2
			var tx := posmod(floori(streets.x + 3.2 * sin(streets.y * .065)), 48)
			var ty := posmod(floori(streets.y + 2.5 * sin(streets.x * .059)), 48)
			var sample := _block_mip.get_pixel(24 * col + tx / 2, 24 * form + ty / 2).lerp(
				_samples.get_pixel(48 * col + tx, 48 * form + ty), .35
			)
			var glow := 2.3 if col < 2 else 2.85
			var dist2 := float(p.distance_squared_to(origin))
			var landing := exp(-dist2 / 2.0)
			var pos := y * SIZE + x
			rgb[3 * pos] = clampi(roundi(255.0 * maxf(sample.r * glow, .95 * landing)), 0, 255)
			rgb[3 * pos + 1] = clampi(roundi(255.0 * maxf(sample.g * glow, .78 * landing)), 0, 255)
			rgb[3 * pos + 2] = clampi(roundi(255.0 * maxf(sample.b * glow, .46 * landing)), 0, 255)
			var district_center := _center(i)
			var toward := Vector2(district_center - origin).normalized()
			var phase := Vector2(p - district_center).dot(toward) * 3.0 + 15.5
			if i == start:
				phase = 1.2 * dist2
			var priority := rank * 32 + clampi(roundi(phase), 0, 31)
			sequence[pos] = priority
			if rgb[3 * pos] > 5:
				histogram[priority] += 1
	var count := _phase_by_capacity(sequence, histogram, limits, births)
	_connect_to_landing(origin, births)
	# A very thin inlet can disappear between coarse parcel centres and leave
	# an entire candidate district on an unreachable bank. Count only the
	# streets that are connected to this landing when allocating those phases.
	var stages := PackedInt32Array([0, 0, 0, 0, 0])
	for pos in births.size():
		if births[pos] < 5 and rgb[pos * 3] > 5:
			stages[births[pos]] += 1
	var occupied := 0
	for added in stages:
		occupied += added
	if occupied < count * 0.85 or (occupied >= 5 and stages.has(0)):
		_rephase_bank(origin, sequence, rgb, limits, occupied, births)
	return occupied <= 32


## An island, a narrow riverbank or a mountain terrace can run out of connected
## ground long before a mainland capital. Divide its *actual* illuminated blocks
## over the five stages. Within-block order also gives very small sites room to grow.
static func _phase_by_capacity(
	sequence: PackedInt32Array, hist: PackedInt32Array, limits: PackedInt32Array, births: PackedByteArray
) -> int:
	var total := 0
	for quantity in hist:
		total += quantity
	if total == 0:
		return 0
	var cut := PackedInt32Array()
	var stage := 0
	var seen := 0
	for k in hist.size():
		seen += hist[k]
		while stage < 4:
			var target := maxi(1, roundi(float(total) * limits[stage] / limits[4]))
			if stage == 0:
				target = maxi(target, mini(14, total / 5))
			if seen < target:
				break
			cut.append(k)
			stage += 1
	for pos in sequence.size():
		var key := sequence[pos]
		if key < 0:
			continue
		var step := 0
		while step < cut.size() and key > cut[step]:
			step += 1
		births[pos] = step
	return total


## A sub-parcel creek may split an otherwise reachable neighbourhood in two.
## Light each bank only when a dry path through this stage's street blocks
## connects it to the original settlement.
static func _connect_to_landing(origin: Vector2i, births: PackedByteArray) -> void:
	var n := SIZE * SIZE
	var start := origin.y * SIZE + origin.x
	if births[start] == 255:
		return
	var connected := PackedByteArray()
	connected.resize(n)
	connected.fill(255)
	var seen := PackedByteArray()
	seen.resize(n)
	seen.fill(255)
	var queue := PackedInt32Array()
	queue.resize(n)
	for stage in 5:
		var head := 0
		var tail := 1
		queue[0] = start
		seen[start] = stage
		while head < tail:
			var i := queue[head]
			head += 1
			connected[i] = mini(connected[i], stage)
			var x := i % SIZE
			for d: int in [-1, 1, -SIZE, SIZE]:
				var j := i + d
				if j < 0 or j >= n or (d == -1 and x == 0) or (d == 1 and x == SIZE - 1):
					continue
				if seen[j] == stage or births[j] > stage:
					continue
				queue[tail] = j
				tail += 1
				seen[j] = stage
	for i in n:
		births[i] = connected[i]


## On severely fragmented land, expand from the existing frontage in original
## parcel order, distributing only the reachable lamps over the five stages.
static func _rephase_bank(
	origin: Vector2i,
	sequence: PackedInt32Array,
	rgb: PackedByteArray,
	limits: PackedInt32Array,
	occupied: int,
	births: PackedByteArray
) -> void:
	var start := origin.y * SIZE + origin.x
	if occupied == 0 or births[start] == 255:
		return
	var queued := PackedByteArray()
	queued.resize(births.size())
	var heap: Array[Vector2] = [Vector2(sequence[start], start)]
	queued[start] = 1
	var exposed := 0
	var stage := 0
	while not heap.is_empty():
		var i := int(_heap_pop(heap).y)
		births[i] = stage
		if rgb[3 * i] > 5:
			exposed += 1
			if stage < 4:
				var quota := roundi(float(occupied) * limits[stage] / limits[4])
				quota = clampi(quota, stage + 1, maxi(stage + 1, occupied - 4 + stage))
				if exposed >= quota:
					stage += 1
		var x := i % SIZE
		for d: int in [-1, 1, -SIZE, SIZE]:
			var j := i + d
			if j < 0 or j >= births.size() or (d == -1 and x == 0) or (d == 1 and x == SIZE - 1):
				continue
			if queued[j] or births[j] == 255:
				continue
			queued[j] = 1
			_heap_push(heap, Vector2(sequence[j], j))
