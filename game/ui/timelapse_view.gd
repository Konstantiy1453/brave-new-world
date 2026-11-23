extends PanelContainer
## The night time-lapse on screen (1.11 G): the globe plays the colony's light record from the
## landing to now (map_view.gd `play_timelapse`), with the date as it goes, a bar and a button to
## skip. At every ending it plays before the settlement statement; the career page plays it too.
## Functional; the interface pass restyles it.

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
## After the last frame the picture holds this long before the time-lapse ends.
const HOLD_SECONDS: float = 1.5

var game: Node
var after: Callable
var caption: Label
var bar: ProgressBar
var held: float = 0.0
## The interface hidden while the globe plays, shown again at the end.
var covered: Array[Control] = []


## Plays the time-lapse over the game `g`, then calls `then` (if valid). Without a record (a save
## from before 1.11 that has not reached its first quarter), `then` runs at once.
static func play(g: Node, then: Callable = Callable()) -> void:
	var snapshots: Array = g.sim.state.get("lights", {}).get("snapshots", [])
	if snapshots.is_empty() or snapshots.back().get("towns", []).is_empty():
		if then.is_valid():
			then.call()
		return
	var view: Node = load("res://ui/timelapse_view.gd").new()
	view.start(g, then, snapshots)


func start(g: Node, then: Callable, snapshots: Array) -> void:
	game = g
	after = then
	g.paused = true
	for child: Node in g.ui.get_children():
		if child is Control and (child as Control).visible:
			covered.append(child)
			(child as Control).visible = false
	g.ui.add_child(self)
	var seconds: float = float(g.sim.progression.get("lights", {}).get("timelapse_seconds", 20.0))
	g.map.play_timelapse(snapshots, seconds)


func _ready() -> void:
	name = "Timelapse"
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -260
	offset_right = 260
	offset_top = 104
	D.panel_style(self, "panel")
	var box: VBoxContainer = D.col(self)
	D.label(box, "殖民地夜景 · 从着陆到今天", 19, D.GOLD)
	caption = D.label(box, "", 16, D.MUTED)
	bar = ProgressBar.new()
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	box.add_child(bar)
	D.button(box, "跳过", finish, "结束回放", "TimelapseSkip")


func _process(delta: float) -> void:
	var progress: float = game.map.timelapse_progress()
	if progress < 0.0:
		finish()
		return
	bar.value = progress
	caption.text = Labels.date(game.map.timelapse_day())
	if progress >= 1.0:
		held += delta
		if held >= HOLD_SECONDS:
			finish()


func finish() -> void:
	if is_queued_for_deletion():
		return
	game.map.stop_timelapse()
	for control: Control in covered:
		if is_instance_valid(control):
			control.visible = true
	queue_free()
	if after.is_valid():
		after.call()
