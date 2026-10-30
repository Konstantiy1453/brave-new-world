extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")


func _initialize() -> void:
	Watchdog.arm(self)
	var root := "D:/勇敢新世界/"
	var names := [
		"ore",
		"copper",
		"crystal",
		"food",
		"materials",
		"parts",
		"habitat",
		"power",
		"water",
		"farm",
		"processor",
		"lab",
		"port",
		"warning"
	]
	var atlas := Image.create(7 * 96, 2 * 96, false, Image.FORMAT_RGBA8)
	atlas.fill(Color("132333"))
	for i in range(names.size()):
		var img := Image.new()
		var err := img.load(root + "game/assets/icons/" + names[i] + ".svg")
		if err != OK:
			push_error("SVG_DECODE_FAIL " + names[i])
			quit(1)
			return
		img.convert(Image.FORMAT_RGBA8)
		atlas.blend_rect(img, Rect2i(0, 0, 64, 64), Vector2i((i % 7) * 96 + 16, (i / 7) * 96 + 16))
	atlas.save_png(root + "evidence/v17/tests/icon_atlas.png")
	print("ASSET_RENDER_PASS 14 SVG decoded by Godot 4.5.1 and rendered to atlas")
	quit(0)
