extends "res://world/map_base.gd"
## Mesh primitives, materials and the facility models.


func _mat(
	key: String, color: Color, metallic: float = 0.0, roughness: float = .75, emission: float = 0.0
) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	mats[key] = m
	return m


func _clear_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		remove_child(node)
		node.queue_free()


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, pos, material)


func _sphere(
	parent: Node3D,
	pos: Vector3,
	radius: float,
	material: Material,
	segments: int = 16,
	rings: int = 8
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = segments
	mesh.rings = rings
	return _mesh(parent, mesh, pos, material)


func _cylinder(
	parent: Node3D,
	pos: Vector3,
	radius: float,
	height: float,
	material: Material,
	segments: int = 16
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return _mesh(parent, mesh, pos, material)


func _cone(
	parent: Node3D, pos: Vector3, radius: float, height: float, material: Material
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 9
	return _mesh(parent, mesh, pos, material)


func _torus(
	parent: Node3D, pos: Vector3, radius: float, width: float, material: Material
) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width
	mesh.outer_radius = radius + width
	mesh.rings = 24
	mesh.ring_segments = 8
	return _mesh(parent, mesh, pos, material)


func _tube(
	parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material
) -> MeshInstance3D:
	var tube := _cylinder(parent, (a + b) * .5, radius, a.distance_to(b), material, 7)
	var up: Vector3 = (b - a).normalized()
	var axis: Vector3 = Vector3.UP.cross(up)
	if axis.length() > .001:
		tube.quaternion = Quaternion(axis.normalized(), acos(clampf(Vector3.UP.dot(up), -1, 1)))
	return tube


func _line(parent: Node3D, points: Array[Vector3], color: Color, energy: float = 1.0) -> void:
	if points.size() < 2:
		return
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for p in points:
		mesh.surface_add_vertex(p)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


func _build_facility(root: Node3D, kind: String, active: bool) -> void:
	var shell := _mat("shell", Color("bec9cb"), .48, .43)
	var dark := _mat("darkmetal", Color("354954"), .65, .38)
	var metal := _mat("metal", Color("73818a"), .6, .4)
	var accent := _mat(
		"accent" + str(active),
		Color("75d6cc") if active else Color("d18061"),
		.3,
		.35,
		.7 if active else .12
	)
	# Working buildings light their windows after dark; idle ones stay dark.
	var glass := _window_mat(active)
	var gold := _mat("industrial", Color("c7a36b"), .4, .5)
	_cylinder(root, Vector3(0, .08, 0), 2.30, .16, _mat("pad", Color("43545a"), .3, .85), 6)
	match kind:
		"habitat":
			# Two pressure barrels, elevated floor, connecting vestibule and roof vents.
			for x in [-.86, .86]:
				var capsule := CapsuleMesh.new()
				capsule.radius = .64
				capsule.height = 3.15
				capsule.radial_segments = 16
				capsule.rings = 5
				var pod := _mesh(root, capsule, Vector3(x, 1.0, 0), shell)
				pod.rotation_degrees.x = 90
				for z in [-.9, -.3, .3, .9]:
					_box(root, Vector3(x, 1.58, z), Vector3(.62, .035, .25), glass)
					_box(root, Vector3(x, 1.60, z + .13), Vector3(.64, .025, .035), accent)
				for z in [-1, 1]:
					_box(root, Vector3(x, .35, z), Vector3(.88, .6, .18), dark)
			_box(root, Vector3(0, .7, .1), Vector3(.7, .8, .95), dark)
			_box(root, Vector3(0, .4, 1.7), Vector3(.85, .18, .9), shell)
		"power":
			# Tilted photovoltaic banks and central capacitor tower.
			_cylinder(root, Vector3(0, .72, 0), .45, 1.3, shell, 16)
			_cylinder(root, Vector3(0, 1.42, 0), .49, .12, accent, 16)
			for x in [-1.15, 1.15]:
				for z in [-.88, .88]:
					_box(root, Vector3(x, .45, z), Vector3(.12, .8, .12), metal)
					var panel := Node3D.new()
					panel.position = Vector3(x, .95, z)
					panel.rotation_degrees.x = -22
					root.add_child(panel)
					_box(panel, Vector3.ZERO, Vector3(1.35, .08, 1.48), dark)
					for col in range(4):
						for row in range(5):
							_box(
								panel,
								Vector3(-.48 + col * .32, .052, -.56 + row * .28),
								Vector3(.29, .012, .25),
								_mat("solar", Color("285d83"), .75, .2)
							)
		"water":
			for x in [-.86, .86]:
				_cylinder(root, Vector3(x, .9, 0), .65, 1.65, shell, 24)
				_sphere(root, Vector3(x, 1.72, 0), .65, metal, 20, 8).scale.y = .35
				for y in [.25, 1.1, 1.55]:
					_torus(root, Vector3(x, y, 0), .65, .055, accent if y > 1 else dark)
			_tube(root, Vector3(-.86, .35, 1), Vector3(.86, .35, 1), .12, metal)
			_box(root, Vector3(0, .48, 1.1), Vector3(.6, .7, .5), glass)
		"mine_ore", "mine_copper", "mine_crystal":
			var ore_color: Color = (
				Color("ac7755")
				if kind == "mine_ore"
				else (Color("ba9c57") if kind == "mine_copper" else Color("7ba0bd"))
			)
			_cylinder(root, Vector3(0, .18, 0), 1.35, .18, dark, 20)
			for x in [-.85, .85]:
				for z in [-.65, .65]:
					_tube(root, Vector3(x, .3, z), Vector3(x * .7, 3.2, z * .7), .10, gold)
			for y in [1.0, 2.0, 3.0]:
				_tube(root, Vector3(-.85, y, -.65), Vector3(.85, y, .65), .055, metal)
				_tube(root, Vector3(.85, y, -.65), Vector3(-.85, y, .65), .055, metal)
			_box(root, Vector3(0, 3.25, 0), Vector3(1.8, .3, 1.35), shell)
			_cylinder(root, Vector3(0, 1.5, 0), .14, 2.7, accent, 10)
			_box(root, Vector3(1.45, .6, .6), Vector3(.65, .95, 1.6), dark)
			var conveyor := _box(root, Vector3(.35, .42, 1.45), Vector3(1.0, .17, 1.7), metal)
			conveyor.rotation_degrees.x = 13
			for i in range(6):
				_sphere(
					root,
					Vector3(-.3 + (i % 3) * .3, .65, 1.1 + (i / 3) * .4),
					.19,
					_mat(kind + "raw", ore_color, .45, .7),
					5,
					3
				)
		"farm":
			# Two glazed growing tunnels with individually visible planting beds.
			for x in [-.9, .9]:
				_box(root, Vector3(x, .26, 0), Vector3(1.48, .25, 3.3), shell)
				for row in range(7):
					_box(
						root,
						Vector3(x, .44, -1.3 + row * .42),
						Vector3(1.21, .18, .25),
						_mat("crops", Color("719650"), 0, .85)
					)
				for z in [-1.5, -.75, 0, .75, 1.5]:
					var arch: Array[Vector3] = []
					for k in range(13):
						var angle: float = float(k) / 12 * PI
						arch.append(Vector3(x + cos(angle) * .74, .5 + sin(angle) * .88, z))
					for k in range(arch.size() - 1):
						_tube(root, arch[k], arch[k + 1], .035, shell)
				_box(root, Vector3(x, 1.38, 0), Vector3(.09, .08, 3.1), accent)
				for side in [-1, 1]:
					_box(root, Vector3(x + side * .7, .68, 0), Vector3(.04, .3, 3.1), glass)
		"processor":
			_box(root, Vector3(-.5, .72, 0), Vector3(2.2, 1.2, 2.8), shell)
			var roof := _cylinder(root, Vector3(-.5, 1.31, 0), 1.1, 2.8, metal, 12)
			roof.rotation_degrees.x = 90
			roof.scale.y = 1
			roof.scale.z = .5
			for z in [-.8, .75]:
				_cylinder(root, Vector3(1.05, 1.05, z), .4, 1.9, dark, 16)
				_torus(root, Vector3(1.05, 1.7, z), .4, .055, gold)
			_cylinder(root, Vector3(-1, 2.2, -.6), .18, 2.1, metal, 12)
			_box(root, Vector3(-.5, .9, 1.42), Vector3(1.7, .25, .04), accent)
		"lab":
			_cylinder(root, Vector3(0, .55, 0), 1.5, .9, shell, 12)
			_cylinder(root, Vector3(0, 1.0, 0), 1.55, .12, accent, 12)
			var dome := _sphere(root, Vector3(0, 1, 0), 1.3, glass, 28, 12)
			dome.scale.y = .65
			for a in range(6):
				var t: float = a * TAU / 6
				_box(root, Vector3(sin(t) * 1.1, .5, cos(t) * 1.1), Vector3(.25, .6, .25), dark)
			_tube(root, Vector3(-1.7, .2, -.9), Vector3(-1.7, 2.7, -.9), .055, metal)
			var dish := _sphere(root, Vector3(-1.7, 2.6, -.9), .48, shell, 16, 8)
			dish.scale = Vector3(1, .18, 1)
			dish.rotation_degrees.z = -30
			_sphere(root, Vector3(-1.7, 2.95, -.9), .075, accent, 8, 4)
		"port":
			_cylinder(root, Vector3(0, .2, 0), 1.9, .2, dark, 8)
			_torus(root, Vector3(0, .32, 0), 1.65, .045, accent)
			_box(root, Vector3(0, .33, 0), Vector3(1.4, .025, .12), shell)
			_box(root, Vector3(0, .33, 0), Vector3(.12, .025, 1.4), shell)
			for z in [-1.5, 1.5]:
				_box(root, Vector3(-1.9, .6, z * .7), Vector3(.6, .9, .95), gold)
				_box(root, Vector3(-1.9, .7, z * .7 + .48), Vector3(.52, .08, .025), accent)
			_cylinder(root, Vector3(1.8, 1.2, -1), .16, 2.2, metal, 12)
			_box(root, Vector3(1.8, 2.3, -1), Vector3(.55, .35, .55), glass)
		"clinic":
			# A low ward with a lit cross on the roof.
			_box(root, Vector3(0, .62, 0), Vector3(2.6, 1.0, 2.0), shell)
			_box(root, Vector3(0, 1.17, 0), Vector3(.9, .1, .28), accent)
			_box(root, Vector3(0, 1.17, 0), Vector3(.28, .1, .9), accent)
			for x in [-.85, 0, .85]:
				_box(root, Vector3(x, .72, 1.02), Vector3(.5, .4, .04), glass)
		"hydroponic_farm":
			# Stacked sealed growing racks under strip lighting; no soil.
			for level in range(3):
				var y: float = .4 + level * .75
				_box(root, Vector3(0, y, 0), Vector3(2.9, .1, 2.5), metal)
				_box(
					root,
					Vector3(0, y + .13, 0),
					Vector3(2.65, .15, 2.25),
					_mat("crops", Color("719650"), 0, .85)
				)
				_box(root, Vector3(0, y + .55, 0), Vector3(2.5, .04, .16), accent)
			for x in [-1.42, 1.42]:
				for z in [-1.2, 1.2]:
					_box(root, Vector3(x, 1.25, z), Vector3(.1, 2.3, .1), dark)
		"component_plant":
			# A clean-room block with a filter stack on the roof.
			_box(root, Vector3(0, .85, 0), Vector3(3.0, 1.45, 2.3), shell)
			_box(root, Vector3(0, 1.0, 1.17), Vector3(2.4, .32, .04), glass)
			_box(root, Vector3(0, .62, 1.18), Vector3(2.4, .05, .03), accent)
			for x in [-.9, 0, .9]:
				_cylinder(root, Vector3(x, 1.85, -.4), .24, .55, metal, 12)
				_torus(root, Vector3(x, 2.12, -.4), .24, .04, gold)
		"university":
			# A ring of teaching halls around a tall domed library.
			_cylinder(root, Vector3(0, .5, 0), 2.0, .85, shell, 16)
			_cylinder(root, Vector3(0, 1.45, 0), 1.15, 1.2, shell, 16)
			_torus(root, Vector3(0, 2.08, 0), 1.15, .06, gold)
			var dome := _sphere(root, Vector3(0, 2.1, 0), 1.0, glass, 28, 12)
			dome.scale.y = .7
			for a in range(8):
				var turn: float = a * TAU / 8
				_box(
					root, Vector3(sin(turn) * 2.02, .6, cos(turn) * 2.02), Vector3(.2, .7, .2), dark
				)
			_cylinder(root, Vector3(0, 2.95, 0), .05, .55, accent, 8)
		"lift_port":
			# A tapered lift tower climbing out of a loading ring.
			_cylinder(root, Vector3(0, .25, 0), 2.1, .3, dark, 16)
			_torus(root, Vector3(0, .42, 0), 1.85, .06, accent)
			for x in [-.55, .55]:
				for z in [-.55, .55]:
					_tube(
						root,
						Vector3(x * 2.0, .4, z * 2.0),
						Vector3(x * .35, 8.0, z * .35),
						.09,
						gold
					)
			for y in [2.0, 4.0, 6.0]:
				_torus(root, Vector3(0, y, 0), .95 - y * .09, .05, metal)
			_box(root, Vector3(0, 3.0, 0), Vector3(.5, .7, .5), accent)
			_box(root, Vector3(-1.8, .7, 1.1), Vector3(.8, .9, .9), gold)
			_box(root, Vector3(1.8, .7, 1.1), Vector3(.8, .9, .9), gold)
		"climate_regulator":
			# Twin atmospheric stacks venting from a sealed turbine hall.
			_box(root, Vector3(0, .6, 0), Vector3(3.2, 1.0, 2.2), shell)
			for x in [-.9, .9]:
				_cylinder(root, Vector3(x, 2.3, 0), .55, 3.0, metal, 20)
				_torus(root, Vector3(x, 3.85, 0), .55, .07, accent)
				_torus(root, Vector3(x, 1.6, 0), .56, .05, gold)
			_box(root, Vector3(0, .75, 1.12), Vector3(2.4, .3, .04), glass)
		"commerce", "service":
			_cylinder(root, Vector3(0, .65, 0), 1.6, 1.0, shell, 6)
			_cone(root, Vector3(0, 1.4, 0), 1.8, .65, gold)
			for x in [-.8, 0, .8]:
				_box(root, Vector3(x, .7, 1.2), Vector3(.6, .5, .08), glass)
			_box(root, Vector3(0, 1.16, 1.25), Vector3(2, .16, .12), accent)
		_:
			_cylinder(root, Vector3(0, .8, 0), 1.1, 1.4, shell, 8)
			_cone(root, Vector3(0, 1.6, 0), 1.15, .6, metal)
	# A physical status beacon is attached to every facility.
	_cylinder(root, Vector3(1.8, .35, -1.7), .045, .5, metal, 6)
	_sphere(root, Vector3(1.8, .64, -1.7), .09, accent, 8, 4)


## Window glass. The lit variant carries an emission the map turns up at night.
func _window_mat(lit: bool) -> StandardMaterial3D:
	var material := _mat("glass_on" if lit else "glass", Color("204e62"), .55, .16)
	if lit and not material.emission_enabled:
		material.emission_enabled = true
		material.emission = Color("ffc976")
		material.emission_energy_multiplier = 0.0
	return material


## A town vehicle, front towards +Z, wheels on y = 0. Kinds: truck, van, bus.
func _build_vehicle(root: Node3D, kind: String) -> void:
	var paints: Dictionary = {
		"truck": Color("d9a441"), "van": Color("dfe6e8"), "bus": Color("4fb3a9")
	}
	var paint := _mat("vehicle_" + kind, paints.get(kind, Color("dfe6e8")), .35, .45)
	var dark := _mat("darkmetal", Color("354954"), .65, .38)
	var screen := _mat("vehicle_glass", Color("1b3a49"), .5, .15)
	var tyre := _mat("tyre", Color("1d2327"), 0, .9)
	var head := _mat("headlight", Color("fff1c8"), 0, .4, 0.4)
	var tail := _mat("taillight", Color("e0523f"), 0, .4, 0.6)
	var length: float = 1.1
	var wheels: Array = [.36, -.1, -.38]
	match kind:
		"truck":
			_box(root, Vector3(0, .17, 0), Vector3(.4, .1, length), dark)
			_box(root, Vector3(0, .36, .38), Vector3(.4, .3, .3), paint)
			_box(root, Vector3(0, .43, .535), Vector3(.34, .12, .02), screen)
			var cargo := _mat("cargo", Color("8a9aa3"), .3, .6)
			_box(root, Vector3(0, .39, -.17), Vector3(.42, .34, .72), cargo)
		"bus":
			length = 1.3
			wheels = [.42, -.4]
			_box(root, Vector3(0, .34, 0), Vector3(.42, .4, length), paint)
			for side: float in [-.212, .212]:
				_box(root, Vector3(side, .43, 0), Vector3(.01, .12, length - .25), screen)
			_box(root, Vector3(0, .43, length * .5 + .004), Vector3(.34, .14, .01), screen)
		_:
			length = .8
			wheels = [.24, -.24]
			_box(root, Vector3(0, .31, 0), Vector3(.38, .32, length), paint)
			_box(root, Vector3(0, .41, length * .5 - .02), Vector3(.32, .12, .05), screen)
	for z: float in wheels:
		for x: float in [-.2, .2]:
			var wheel := _cylinder(root, Vector3(x, .09, z), .085, .06, tyre, 10)
			wheel.rotation_degrees.z = 90
	for x: float in [-.13, .13]:
		_box(root, Vector3(x, .25, length * .5 + .006), Vector3(.07, .045, .012), head)
		_box(root, Vector3(x, .25, -length * .5 - .006), Vector3(.06, .04, .012), tail)


func _construction_frame(root: Node3D) -> void:
	var material := _mat("construction", Color("dfb46b"), .4, .5, .3)
	for x in [-1.9, 1.9]:
		for z in [-1.9, 1.9]:
			_tube(root, Vector3(x, .2, z), Vector3(x, 2.9, z), .055, material)
	for z in [-1.9, 1.9]:
		_tube(root, Vector3(-1.9, 2.9, z), Vector3(1.9, 2.9, z), .055, material)
