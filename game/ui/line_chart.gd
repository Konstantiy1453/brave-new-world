extends Control
## A small line chart for the economy page. Each series gets its own scale, so a cash line in the
## thousands and a daily net in the tens can share one frame; the labels give the real figures.

const PADDING: float = 6.0

var series: Array = []


func set_series(rows: Array) -> void:
	series = rows
	queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2(PADDING, PADDING), size - Vector2.ONE * PADDING * 2.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color("0c1925"))
	for row: Dictionary in series:
		var values: PackedFloat32Array = row.values
		if values.size() < 2:
			continue
		var low: float = 0.0
		var high: float = 1.0
		for value: float in values:
			low = minf(low, value)
			high = maxf(high, value)
		var span: float = maxf(high - low, 0.001)
		if low < 0.0:
			var zero: float = area.end.y - (0.0 - low) / span * area.size.y
			draw_line(
				Vector2(area.position.x, zero), Vector2(area.end.x, zero), Color("304756"), 1.0
			)
		var points := PackedVector2Array()
		for index: int in range(values.size()):
			var x: float = area.position.x + area.size.x * index / float(values.size() - 1)
			var y: float = area.end.y - (values[index] - low) / span * area.size.y
			points.append(Vector2(x, y))
		draw_polyline(points, row.color, 2.0, true)
