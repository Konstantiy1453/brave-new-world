extends RefCounted
## Landmarks an event leaves at a place (events_v2 `landmark`), drawn in the town view from plain
## shapes: each of the eight kinds looks different, about the size of a small building, with a
## warm light where one belongs. Drawn at the root's origin, which stands on the ground.

const STONE: Color = Color("b9b2a3")
const DARK: Color = Color("4c5257")
const METAL: Color = Color("8f9aa3")
const LIGHT: Color = Color("ffd38a")
const GRASS: Color = Color("5f8f4e")
const LEAF: Color = Color("3f7a3a")
const RUST: Color = Color("8a5a3c")
const HAZARD: Color = Color("d8b14a")
## How bright a landmark's light glows.
const GLOW: float = 2.2


static func draw(map: Node3D, root: Node3D, kind: String) -> void:
	var stone: Material = map._mat("landmark_stone", STONE, 0.0, 0.85)
	var dark: Material = map._mat("landmark_dark", DARK, 0.3, 0.6)
	var metal: Material = map._mat("landmark_metal", METAL, 0.6, 0.4)
	var light: Material = map._mat("landmark_light", LIGHT, 0.0, 1.0, GLOW)
	match kind:
		"monument":
			map._box(root, Vector3(0, 0.15, 0), Vector3(1.4, 0.3, 1.4), stone)
			map._box(root, Vector3(0, 1.45, 0), Vector3(0.5, 2.3, 0.5), stone)
		"station":
			map._cylinder(root, Vector3(0, 0.3, 0), 1.0, 0.6, metal)
			map._sphere(root, Vector3(0, 0.6, 0), 0.85, metal)
			map._cylinder(root, Vector3(0, 2.0, 0), 0.06, 2.2, dark, 8)
			map._sphere(root, Vector3(0, 3.15, 0), 0.14, light, 8, 4)
		"seal":
			map._cylinder(root, Vector3(0, 0.12, 0), 1.1, 0.24, dark)
			var hazard: Material = map._mat("landmark_hazard", HAZARD, 0.0, 0.8)
			for side: int in range(4):
				var angle: float = PI / 4.0 + side * PI / 2.0
				var bar: MeshInstance3D = map._box(
					root,
					Vector3(cos(angle) * 1.6, 0.3, sin(angle) * 1.6),
					Vector3(0.9, 0.5, 0.12),
					hazard
				)
				bar.rotation.y = -angle + PI / 2.0
		"garden":
			map._cylinder(
				root, Vector3(0, 0.04, 0), 1.8, 0.08, map._mat("landmark_grass", GRASS), 20
			)
			var leaf: Material = map._mat("landmark_leaf", LEAF, 0.0, 0.9)
			for tree: int in range(5):
				var angle: float = tree * TAU / 5.0
				map._cone(root, Vector3(cos(angle) * 1.0, 0.7, sin(angle) * 1.0), 0.45, 1.3, leaf)
		"beacon":
			map._cylinder(root, Vector3(0, 0.15, 0), 0.6, 0.3, dark)
			map._cylinder(root, Vector3(0, 2.15, 0), 0.12, 4.0, metal, 8)
			map._sphere(root, Vector3(0, 4.3, 0), 0.25, light, 10, 5)
		"archive":
			map._box(root, Vector3(0, 0.6, 0), Vector3(2.4, 1.2, 1.6), stone)
			map._box(root, Vector3(0, 1.35, 0), Vector3(2.6, 0.3, 1.8), dark)
			map._box(root, Vector3(0, 0.45, 0.82), Vector3(0.5, 0.9, 0.05), light)
		"wreck":
			var rust: Material = map._mat("landmark_rust", RUST, 0.4, 0.7)
			var hull: MeshInstance3D = map._cylinder(root, Vector3(0, 0.3, 0), 0.6, 3.2, rust, 10)
			hull.rotation = Vector3(0.0, 0.6, PI / 2.0 - 0.25)
			map._box(root, Vector3(1.1, 0.3, 0.6), Vector3(0.8, 0.6, 0.1), rust)
		"ruin":
			var heights: Array[float] = [1.8, 1.1, 1.5, 0.7]
			for stone_index: int in range(heights.size()):
				var angle: float = stone_index * TAU / heights.size() + 0.4
				map._box(
					root,
					Vector3(cos(angle) * 0.9, heights[stone_index] / 2.0, sin(angle) * 0.9),
					Vector3(0.5, heights[stone_index], 0.5),
					stone
				)
		_:
			map._box(root, Vector3(0, 0.5, 0), Vector3(1, 1, 1), stone)
