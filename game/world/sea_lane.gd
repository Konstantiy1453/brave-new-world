extends RefCounted
## Computes the visible journey between two coastal warehouses from the actual map texture.
## All searches and curves use continuous atlas pixel coordinates. Longitude wraps at the seam.
const Routes = preload("res://world/routes.gd")
const GRID_WIDTH := 384
const NEIGHBORS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP,
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
## Leaves room for legacy maps' coastline noise and for filtered coast pixels.
const MAX_SEA_ALPHA := 0.47
var texture: Texture2D
var ocean: Image
var size: Vector2i
var grid: Vector2i
var lanes: Dictionary = {}


func setup(atlas: Texture2D) -> void:
	if atlas == texture:
		return
	texture = atlas
	lanes.clear()
	ocean = atlas.get_image() if atlas != null else null
	if ocean != null:
		size = ocean.get_size()
		grid = Vector2i(mini(size.x, GRID_WIDTH), mini(size.y, GRID_WIDTH / 2))


func coordinates(from: Vector2, to: Vector2) -> Array[Vector2]:
	if ocean == null:
		return []
	var key := Vector4(from.x, from.y, to.x, to.y)
	if not lanes.has(key):
		lanes[key] = _plan(_pixel(from), _pixel(to))
	return lanes[key]


func _pixel(ll: Vector2) -> Vector2:
	return Vector2((ll.y / 360.0 + 0.5) * size.x - 0.5, (0.5 - ll.x / 180.0) * size.y - 0.5)


func _geographic(p: Vector2) -> Vector2:
	return Vector2((0.5 - (p.y + 0.5) / size.y) * 180.0,
		wrapf((p.x + 0.5) / size.x * 360.0 - 180.0, -180.0, 180.0))


func _near(from: Vector2, to: Vector2) -> Vector2:
	return Vector2(from.x + wrapf(to.x - from.x, -0.5 * size.x, 0.5 * size.x), to.y)


## All four atlas samples which can contribute to this pixel must be on the sea side.
func _wet(p: Vector2) -> bool:
	var y := floori(p.y)
	if y < 0 or y + 1 >= size.y:
		return false
	var x := posmod(floori(p.x), size.x)
	var east := (x + 1) % size.x
	return (ocean.get_pixel(x, y).a < MAX_SEA_ALPHA and ocean.get_pixel(east, y).a < MAX_SEA_ALPHA
		and ocean.get_pixel(x, y + 1).a < MAX_SEA_ALPHA and ocean.get_pixel(east, y + 1).a < MAX_SEA_ALPHA)


## Visit every bilinear pixel cell the straight segment crosses, including both sides of a corner.
func _clear(a: Vector2, b: Vector2) -> bool:
	var point := Vector2i(floori(a.x), floori(a.y))
	var end := Vector2i(floori(b.x), floori(b.y))
	var delta := b - a
	var step := Vector2i(signi(end.x - point.x), signi(end.y - point.y))
	var stride := Vector2(absf(1.0 / delta.x) if step.x else INF, absf(1.0 / delta.y) if step.y else INF)
	var t := Vector2(INF, INF)
	if step.x:
		t.x = (float(point.x + int(step.x > 0)) - a.x) / delta.x
	if step.y:
		t.y = (float(point.y + int(step.y > 0)) - a.y) / delta.y
	while _wet(Vector2(point)):
		if point == end:
			return true
		if is_equal_approx(t.x, t.y) and point.x != end.x and point.y != end.y:
			if not _wet(Vector2(point + Vector2i(step.x, 0))) or not _wet(Vector2(point + Vector2i(0, step.y))):
				return false
			point += step
			t += stride
		elif point.y == end.y or (point.x != end.x and t.x < t.y):
			point.x += step.x
			t.x += stride.x
		else:
			point.y += step.y
			t.y += stride.y
	return false


func _center(cell: int) -> Vector2:
	return (Vector2(cell % grid.x, cell / grid.x) + Vector2(0.5, 0.5)) * Vector2(size) / Vector2(grid) - Vector2(0.5, 0.5)


## A warehouse may stand inland within its coastal cell. Start at the closest water-side berth.
func _berth(p: Vector2) -> int:
	var guess := Vector2i((p + Vector2(0.5, 0.5)) * Vector2(grid) / Vector2(size))
	var best := -1
	var distance := INF
	for radius in range(0, maxi(5, ceili(grid.x / 30.0)) + 1):
		for y in range(maxi(0, guess.y - radius), mini(grid.y, guess.y + radius + 1)):
			for offset in range(-radius, radius + 1):
				if maxi(absi(offset), absi(y - guess.y)) != radius:
					continue
				var cell := y * grid.x + posmod(guess.x + offset, grid.x)
				var point := _near(p, _center(cell))
				var here := p.distance_squared_to(point)
				if here < distance and _wet(point):
					best = cell
					distance = here
		if best >= 0 and (radius - 1) * float(size.x) / grid.x > sqrt(distance):
			break
	return best


func _search(start: int, finish: int) -> Array[Vector2]:
	var scores := PackedFloat64Array()
	scores.resize(grid.x * grid.y)
	scores.fill(INF)
	var prior := PackedInt32Array()
	prior.resize(scores.size())
	prior.fill(-1)
	var closed := PackedByteArray()
	closed.resize(scores.size())
	var costs := PackedFloat64Array()
	var cells := PackedInt32Array()
	scores[start] = 0.0
	Routes._push(costs, cells, 0.0, start)
	var goal := _center(finish)
	while not cells.is_empty():
		var cell := Routes._pop(costs, cells)
		if cell == finish:
			var points: Array[Vector2] = []
			while cell >= 0:
				points.append(_center(cell))
				cell = prior[cell]
			points.reverse()
			for i in range(1, points.size()):
				points[i] = _near(points[i - 1], points[i])
			return points
		if closed[cell]:
			continue
		closed[cell] = 1
		var here := _center(cell)
		for offset: Vector2i in NEIGHBORS:
			var row: int = cell / grid.x + offset.y
			if row < 0 or row >= grid.y:
				continue
			var next := row * grid.x + posmod(cell % grid.x + offset.x, grid.x)
			if closed[next]:
				continue
			var dest := _near(here, _center(next))
			var cost := scores[cell] + here.distance_to(dest)
			if cost < scores[next] and _clear(here, dest):
				scores[next] = cost
				prior[next] = cell
				Routes._push(costs, cells, cost + dest.distance_to(_near(dest, goal)), next)
	return []


## Bow each open-water leg gently. Test both sides and smaller bows in a narrow passage.
func _arc(a: Vector2, b: Vector2, side: float) -> Array[Vector2]:
	var delta := b - a
	var length := delta.length()
	var steps := maxi(5, ceili(length / maxf(1.0, size.x / 900.0)))
	var normal := delta.orthogonal().normalized()
	for scale: float in [1.0, -1.0, 0.4, -0.4, 0.12, -0.12, 0.0]:
		var points: Array[Vector2] = []
		var previous := a
		for i in range(1, steps + 1):
			var t := float(i) / steps
			var point := a.lerp(b, t) + normal * (length * 0.11 * side * scale * sin(PI * t))
			if not _clear(previous, point):
				break
			points.append(point)
			previous = point
		if points.size() == steps:
			return points
	return []


func _plan(from: Vector2, to: Vector2) -> Array[Vector2]:
	var standard := grid
	var result := _plan_at_resolution(from, to)
	# Narrow straits and adjacent harbours can disappear between coarse grid centres.
	# Retry with smaller cells while checking each segment against the same full-resolution coast.
	while result.is_empty() and grid != size:
		grid = Vector2i(mini(grid.x * 2, size.x), mini(grid.y * 2, size.y))
		result = _plan_at_resolution(from, to)
	grid = standard
	return result


func _plan_at_resolution(from: Vector2, to: Vector2) -> Array[Vector2]:
	var start := _berth(from)
	var finish := _berth(to)
	if start < 0 or finish < 0:
		return []
	var path := _search(start, finish)
	if path.size() < 2:
		return []
	var plotted: Array[Vector2] = [_geographic(path[0])]
	var i := 0
	var side := 1.0 if ((start ^ finish) & 1) == 0 else -1.0
	while i < path.size() - 1:
		var next := mini(i + 24, path.size() - 1)
		while next > i + 1 and not _clear(path[i], path[next]):
			next -= 1
		var arc := _arc(path[i], path[next], side)
		if arc.is_empty():
			return []
		for point: Vector2 in arc:
			plotted.append(_geographic(point))
		i = next
	return plotted
