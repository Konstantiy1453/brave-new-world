extends "res://world/building_models.gd"
## The regional terrain, water, nature and colony scene.


func _ground(x: float, z: float) -> float:
	var ll := _local_coordinate(x, z)
	var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
	return _ground_from_geo(x, z, g, ll)


func _ground_from_geo(x: float, z: float, g: Dictionary, ll: Vector2) -> float:
	var reg: Dictionary = world.regions[selected_region]
	if not bool(g.land):
		return (
			-1.0 + float(g.height) * 30.0
			if str(world.version) == "CC-GEO-1.4"
			else (float(g.height) - region_ground) * 30.0
		)
	var detail: float = noise.get_noise_2d(x * .65, z * .65) * .33
	var raw: float = (float(g.height) - region_ground) * 30.0 + detail
	# Planned development terraces blend smoothly into the actual regional relief.
	var town_center := Vector2(12.0 if reg.river else 0.0, 0)
	var d: float = Vector2(x, z).distance_to(town_center)
	var blend: float = smoothstep(9.0, 18.0, d)
	var height: float = lerpf(.25, raw, blend)
	if reg.river and str(world.version) == "CC-GEO-1.4":
		var river_x: float = (Geo.river_lon(ll.x) - float(reg.lon)) * 4.0
		var river_dist: float = absf(x - river_x)
		if river_dist < 2.8:
			height = lerpf(-.55, height, smoothstep(.9, 2.8, river_dist))
	elif str(world.version) != "CC-GEO-1.4":
		var p := Vector2(x, z)
		for segment in local_river_segments:
			var a: Vector2 = segment.a
			var b: Vector2 = segment.b
			var t: float = clampf((p - a).dot(b - a) / maxf(a.distance_squared_to(b), .001), 0, 1)
			var distance: float = p.distance_to(a.lerp(b, t))
			var width: float = segment.width
			if distance < width * 2:
				var water: float = lerpf(segment.ya, segment.yb, t)
				height = lerpf(water - .28, height, smoothstep(width * .72, width * 2, distance))
		for lake in local_lakes:
			var distance: float = p.distance_to(lake.center)
			if distance < lake.radius * 1.25:
				height = lerpf(
					lake.height - .4,
					height,
					smoothstep(lake.radius * .8, lake.radius * 1.25, distance)
				)
	return height


func _water_height_at(x: float, z: float, margin: float = 1.0) -> float:
	var point := Vector2(x, z)
	var result: float = -INF
	for segment in local_river_segments:
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var t: float = clampf((point - a).dot(b - a) / maxf(a.distance_squared_to(b), .001), 0, 1)
		if point.distance_to(a.lerp(b, t)) < float(segment.width) * margin:
			result = maxf(result, lerpf(segment.ya, segment.yb, t))
	for lake in local_lakes:
		if point.distance_to(lake.center) < float(lake.radius) * margin:
			result = maxf(result, lake.height)
	return result


func _local_coordinate(x: float, z: float) -> Vector2:
	var reg: Dictionary = world.regions[selected_region]
	var lat: float = float(reg.get("canonical_lat", reg.lat)) - z / 4.0
	var lon: float = float(reg.get("canonical_lon", reg.lon)) + x / 4.0
	return Geo.project_coordinate(lat, lon, world)


func _point_to_local(lat: float, lon: float) -> Vector2:
	var reg: Dictionary = world.regions[selected_region]
	var ll: Vector2 = Geo.unproject_coordinate(lat, lon, world)
	return Vector2(
		wrapf(ll.y - float(reg.get("canonical_lon", reg.lon)), -180, 180) * 4.0,
		(float(reg.get("canonical_lat", reg.lat)) - ll.x) * 4.0
	)


func _clip_segment(a: Vector2, b: Vector2) -> Vector2:
	# Liang-Barsky against the exact local ground bounds; returns segment t's.
	var d := b - a
	var low: float = 0
	var high: float = 1
	var p: Array = [-d.x, d.x, -d.y, d.y]
	var q: Array = [a.x + 28.5, 28.5 - a.x, a.y + 23.5, 23.5 - a.y]
	for i in range(4):
		if absf(float(p[i])) < .000001:
			if float(q[i]) < 0:
				return Vector2(-1, -1)
		else:
			var t: float = float(q[i]) / float(p[i])
			if float(p[i]) < 0:
				low = maxf(low, t)
			else:
				high = minf(high, t)
			if low > high:
				return Vector2(-1, -1)
	return Vector2(low, high)


func _prepare_local_rivers() -> void:
	local_river_segments.clear()
	local_lakes.clear()
	var reg: Dictionary = world.regions[selected_region]
	region_ground = float(Geo.sample_geo(reg.lat, reg.lon, noise, str(world.version)).height)
	if str(world.version) == "CC-GEO-1.4":
		return
	var rivers: Array = render_rivers
	for river_index in range(rivers.size()):
		var river = rivers[river_index]
		var coordinates: Array = river.coordinates
		var heights: Array = river.heights
		for i in range(coordinates.size() - 1):
			var ca = coordinates[i]
			var cb = coordinates[i + 1]
			var a := _point_to_local(float(ca[0]), float(ca[1]))
			var b := _point_to_local(float(cb[0]), float(cb[1]))
			if a.distance_to(b) > 60:
				continue
			var clip := _clip_segment(a, b)
			if clip.x < 0:
				continue
			var ha: float = (
				float(heights[i])
				if i < heights.size()
				else float(
					Geo.sample_geo(float(ca[0]), float(ca[1]), noise, str(world.version)).height
				)
			)
			var hb: float = (
				float(heights[i + 1])
				if i + 1 < heights.size()
				else float(
					Geo.sample_geo(float(cb[0]), float(cb[1]), noise, str(world.version)).height
				)
			)
			var wa: float = (
				.45 + .18 * float(i) / maxi(1, coordinates.size() - 1) + .035 * sin(float(i) * .51)
			)
			var wb: float = (
				.45
				+ .18 * float(i + 1) / maxi(1, coordinates.size() - 1)
				+ .035 * sin(float(i + 1) * .51)
			)
			local_river_segments.append(
				{
					"a": a.lerp(b, clip.x),
					"b": a.lerp(b, clip.y),
					"ya": (lerpf(ha, hb, clip.x) - region_ground) * 30.0 + .04,
					"yb": (lerpf(ha, hb, clip.y) - region_ground) * 30.0 + .04,
					"width": maxf(wa, wb),
					"width_a": wa,
					"width_b": wb,
					"river_index": river_index
				}
			)
	for lake in world.get("lakes", []):
		var center := _point_to_local(float(lake.lat), float(lake.lon))
		var radius: float = float(lake.get("radius_degrees", .45)) * 4.0
		if absf(center.x) > 28.5 - radius or absf(center.y) > 23.5 - radius:
			continue
		var h: float = float(lake.get("height", float(lake.get("elevation", 0)) / 4300.0))
		local_lakes.append(
			{"center": center, "radius": radius, "height": (h - region_ground) * 30.0 + .04}
		)


func _build_terrain(token: int) -> bool:
	var reg: Dictionary = world.regions[selected_region]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var resolution: int = 86
	var vertices: PackedVector3Array = []
	var colors: PackedColorArray = []
	vertices.resize((resolution + 1) * (resolution + 1))
	colors.resize(vertices.size())
	terrain_unique_samples = 0
	for iz in range(resolution + 1):
		for ix in range(resolution + 1):
			var x: float = (float(ix) / resolution - .5) * 57.0
			var z: float = (float(iz) / resolution - .5) * 47.0
			var ll := _local_coordinate(x, z)
			var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
			terrain_unique_samples += 1
			var color := _geo_color(g, ll.x, ll.y)
			if reg.river:
				color = color.lerp(Color("59704e"), .4)
			else:
				color = color.lerp(Color("777566"), .35)
			color = color.darkened(maxf(noise.get_noise_2d(x * 2.5, z * 2.5) * .25, 0))
			if is_finite(_water_height_at(x, z, 1.9)):
				color = color.lerp(Color("354e43"), .48)
			var index: int = iz * (resolution + 1) + ix
			colors[index] = color
			vertices[index] = Vector3(x, _ground_from_geo(x, z, g, ll), z)
		if iz % 2 == 0:
			region_progress.emit(true, float(iz) / resolution * .45)
			await get_tree().process_frame
			if token != region_load_token:
				return false
	# Preserve the original triangles and flat normals; only sampling is shared.
	for iz in range(resolution):
		for ix in range(resolution):
			for corner in [
				Vector2i(0, 0),
				Vector2i(1, 0),
				Vector2i(0, 1),
				Vector2i(1, 0),
				Vector2i(1, 1),
				Vector2i(0, 1)
			]:
				var index: int = (iz + corner.y) * (resolution + 1) + ix + corner.x
				st.set_color(colors[index])
				st.add_vertex(vertices[index])

	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	var material := _mat("terrain", Color.WHITE, 0, 1)
	material.vertex_color_use_as_albedo = true
	terrain.material_override = material
	surface.add_child(terrain)
	# Geological section of a floating regional cutaway, deliberately no debug grid.
	var border := SurfaceTool.new()
	border.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges: Array = [
		Vector2(-28.5, -23.5), Vector2(28.5, -23.5), Vector2(28.5, 23.5), Vector2(-28.5, 23.5)
	]
	for e in range(4):
		for k in range(80):
			var a: Vector2 = edges[e].lerp(edges[(e + 1) % 4], float(k) / 80)
			var b: Vector2 = edges[e].lerp(edges[(e + 1) % 4], float(k + 1) / 80)
			var top_a := Vector3(a.x, _ground(a.x, a.y), a.y)
			var top_b := Vector3(b.x, _ground(b.x, b.y), b.y)
			var bottom: float = minf(-4.0, minf(top_a.y, top_b.y) - 3.0)
			for v in [
				top_a,
				Vector3(a.x, bottom, a.y),
				top_b,
				top_b,
				Vector3(a.x, bottom, a.y),
				Vector3(b.x, bottom, b.y)
			]:
				border.add_vertex(v)
	border.generate_normals()
	var skirt := MeshInstance3D.new()
	skirt.mesh = border.commit()
	skirt.material_override = _mat("strata", Color("283a3e"), .15, .95)
	surface.add_child(skirt)
	_build_river()
	if not await _build_sea(token):
		return false
	_build_nature()
	# Thin survey corner lights frame the playable terrain without a grid.
	for x in [-27.5, 27.5]:
		for z in [-22.5, 22.5]:
			var h: float = _ground(x, z)
			_cylinder(
				surface,
				Vector3(x, h + .35, z),
				.065,
				.7,
				_mat("survey", Color("71ccbe"), .3, .6, .8),
				8
			)

	return true


func _build_river() -> void:
	if str(world.version) == "CC-GEO-1.4":
		if world.regions[selected_region].river:
			_build_legacy_river()
		return
	for segment in local_river_segments:
		var a: Vector2 = segment.a
		var b: Vector2 = segment.b
		var normal: Vector2 = (b - a).normalized().orthogonal()
		var side_a: Vector2 = normal * float(segment.width_a)
		var side_b: Vector2 = normal * float(segment.width_b)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var aa := Vector3(a.x - side_a.x, segment.ya, a.y - side_a.y)
		var ab := Vector3(a.x + side_a.x, segment.ya, a.y + side_a.y)
		var ba := Vector3(b.x - side_b.x, segment.yb, b.y - side_b.y)
		var bb := Vector3(b.x + side_b.x, segment.yb, b.y + side_b.y)
		for vertex in [aa, ab, ba, ab, bb, ba]:
			st.add_vertex(vertex)
		st.generate_normals()
		var material := _mat("river_authoritative", Color("224f59"), .08, .36)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh(surface, st.commit(), Vector3.ZERO, material)
	for lake in local_lakes:
		_cylinder(
			surface,
			Vector3(lake.center.x, lake.height, lake.center.y),
			lake.radius,
			.025,
			_mat("lakewater", Color("2e798a"), .32, .2),
			40
		)


func _build_legacy_river() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var reg: Dictionary = world.regions[selected_region]
	for i in range(94):
		var z: float = -23.5 + i * .5
		var nz: float = z + .5
		var x: float = (Geo.river_lon(float(reg.lat) - z / 4.0) - float(reg.lon)) * 4.0
		var nx: float = (Geo.river_lon(float(reg.lat) - nz / 4.0) - float(reg.lon)) * 4.0
		for v in [
			Vector3(x - 1.35, -.24, z),
			Vector3(x + 1.35, -.24, z),
			Vector3(nx - 1.35, -.24, nz),
			Vector3(x + 1.35, -.24, z),
			Vector3(nx + 1.35, -.24, nz),
			Vector3(nx - 1.35, -.24, nz)
		]:
			st.add_vertex(v)
	st.generate_normals()
	var river := MeshInstance3D.new()
	river.mesh = st.commit()
	river.material_override = _mat("river", Color("2a818b"), .42, .19)
	surface.add_child(river)
	for lane in [-.7, .25, .85]:
		var points: Array[Vector3] = []
		for i in range(94):
			var z: float = -23.5 + i * .5
			var x: float = (Geo.river_lon(float(reg.lat) - z / 4.0) - float(reg.lon)) * 4.0 + lane
			points.append(Vector3(x, -.225, z))
		_line(surface, points, Color(.4, .7, .72, .4), .2)


func _build_sea(token: int) -> bool:
	var reg: Dictionary = world.regions[selected_region]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	var sea_height: float = (
		-.72 if str(world.version) == "CC-GEO-1.4" else -region_ground * 30.0 + .04
	)
	for iz in range(94):
		for ix in range(114):
			var x: float = -28.5 + ix * .5
			var z: float = -23.5 + iz * .5
			var ll := _local_coordinate(x, z)
			var g: Dictionary = Geo.sample_geo(ll.x, ll.y, noise, str(world.version))
			if g.land:
				continue
			for v in [
				Vector3(x, sea_height, z),
				Vector3(x + .51, sea_height, z),
				Vector3(x, sea_height, z + .51),
				Vector3(x + .51, sea_height, z),
				Vector3(x + .51, sea_height, z + .51),
				Vector3(x, sea_height, z + .51)
			]:
				st.add_vertex(v)
			count += 1
		if iz % 2 == 0:
			region_progress.emit(true, .45 + float(iz) / 94.0 * .5)
			await get_tree().process_frame
			if token != region_load_token:
				return false
	if count == 0:
		return true
	st.generate_normals()
	var sea := MeshInstance3D.new()
	sea.mesh = st.commit()
	sea.material_override = _mat("sea", Color("285e76"), .4, .2)
	surface.add_child(sea)

	return true


func _build_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world.seed) + selected_region * 173
	var reg: Dictionary = world.regions[selected_region]
	for i in range(160):
		var x: float = rng.randf_range(-27, 27)
		var z: float = rng.randf_range(-22, 22)
		var center := Vector2(12 if reg.river else 0, 0)
		if (
			Vector2(x, z).distance_to(center) < 13.0
			or _ground(x, z) < -.4
			or is_finite(_water_height_at(x, z, 1.8))
		):
			continue
		var height: float = rng.randf_range(.55, 1.8)
		var location := Vector3(x, _ground(x, z), z)
		var local_geo: Dictionary = Geo.local_geo(world, selected_region, x, z, noise)
		if not bool(local_geo.land):
			continue
		var forest_chance: float = (
			clampf((float(local_geo.rainfall) - .23) * 1.45, 0, .86)
			* smoothstep(-2, 10, float(local_geo.temperature))
		)
		if str(local_geo.get("biome", "")) in ["alpine", "desert", "tundra"]:
			forest_chance = 0
		if rng.randf() < forest_chance:
			_cylinder(
				surface,
				location + Vector3(0, height * .25, 0),
				.055,
				height * .5,
				_mat("wood", Color("4d4b3a")),
				6
			)
			var tree := _cone(
				surface,
				location + Vector3(0, height * .65, 0),
				height * .35,
				height,
				_mat("foliage" + str(i % 4), Color("304f45").lightened(float(i % 4) * .035))
			)
			tree.rotation.y = rng.randf() * TAU
		else:
			var rock := _sphere(
				surface,
				location + Vector3(0, height * .17, 0),
				height * .38,
				_mat("rock", Color("7c8174"), .1, .95),
				6,
				3
			)
			rock.scale = Vector3(1.3, .6, 1)
			rock.rotation_degrees = Vector3(0, rng.randf() * 360, rng.randf() * 25)
	# A visible geological exposure marks actual mineral-bearing ground.
	if float(reg.deposits.ore) > 6000:
		for i in range(16):
			var x: float = -16 + rng.randf_range(-3.4, 3.4)
			var z: float = -10 + rng.randf_range(-2.5, 2.5)
			var rock := _sphere(
				surface,
				Vector3(x, _ground(x, z) + .3, z),
				rng.randf_range(.4, 1.2),
				_mat("oreseam", Color("9b735a"), .33, .7),
				6,
				4
			)
			rock.scale = Vector3(1.5, .55, 1)


func _building_signature() -> String:
	for settlement in state.get("settlements", []):
		if int(settlement.region) == selected_region:
			var visible_status: Array = []
			for building in settlement.get("buildings", []):
				visible_status.append(
					[
						building.kind,
						building.get("enabled", true),
						building.get("active", false),
						int(building.get("remaining", 0)) > 0
					]
				)
			var route: Dictionary = state.get("route", {})
			var route_state: Array = [
				route.get("reachable", false),
				route.get("a", -1),
				route.get("b", -1),
				hash(route.get("path", [])),
				Geo.road_blocked(route, int(state.get("day", 0)))
			]
			return (
				JSON.stringify(visible_status)
				+ JSON.stringify(route_state)
				+ str(settlement.get("base_housing", 0))
			)
	return "unsettled"


func _build_colony() -> void:
	if buildings_root != null and is_instance_valid(buildings_root):
		if buildings_root.get_parent() != null:
			buildings_root.get_parent().remove_child(buildings_root)
		buildings_root.queue_free()
	buildings_root = Node3D.new()
	buildings_root.name = "LiveSettlementBuildings"
	surface.add_child(buildings_root)
	var settlement: Dictionary = {}
	for s in state.get("settlements", []):
		if int(s.region) == selected_region:
			settlement = s
	if settlement.is_empty():
		# Survey lander is survey equipment, not an operating settlement.
		var landing_x: float = 12.0 if world.regions[selected_region].river else 0.0
		_lander(buildings_root, Vector3(landing_x, _ground(landing_x, 0) + .1, 0))
		return
	var offset: float = 12.0 if world.regions[selected_region].river else 0.0
	if int(settlement.get("base_housing", 0)) > 0:
		_build_base_housing(offset, int(settlement.base_housing))
	var slots: Array[Vector2] = [
		Vector2(-3, -3),
		Vector2(3, -3),
		Vector2(-3, 3),
		Vector2(3, 3),
		Vector2(-9, -3),
		Vector2(9, -3),
		Vector2(-9, 3),
		Vector2(9, 3),
		Vector2(-3, -9),
		Vector2(3, -9),
		Vector2(-3, 9),
		Vector2(3, 9),
		Vector2(-9, -9),
		Vector2(9, -9),
		Vector2(-9, 9),
		Vector2(9, 9)
	]
	var buildings: Array = settlement.get("buildings", [])
	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		var slot: Vector2 = slots[i % slots.size()] + Vector2(offset, 0)
		if i >= slots.size():
			var extra: int = i - slots.size()
			slot = (
				Vector2(-9.0 + (extra % 4) * 6.0, -15.0 if extra < 4 else 15.0) + Vector2(offset, 0)
			)
		var root := Node3D.new()
		root.position = Vector3(slot.x, _ground(slot.x, slot.y), slot.y)
		buildings_root.add_child(root)
		var complete: bool = int(b.get("remaining", b.get("days_left", 0))) <= 0
		var active: bool = b.get("enabled", true) and b.get("active", true) and complete
		_build_facility(root, str(b.kind), active)
		if not complete:
			_construction_frame(root)
		_road(Vector3(offset, 0, slot.y), Vector3(slot.x, 0, slot.y))
	_road(Vector3(offset, 0, -12), Vector3(offset, 0, 12))
	for z in [-10, -5, 0, 5, 10]:
		var p := Vector3(offset + 1.1, _ground(offset + 1.1, z), z)
		_cylinder(
			buildings_root,
			p + Vector3(0, .8, 0),
			.05,
			1.6,
			_mat("metal", Color("73818a"), .6, .4),
			8
		)
		_box(
			buildings_root,
			p + Vector3(0, 1.6, 0),
			Vector3(.35, .06, .16),
			_mat("lamps", Color("c4eee1"), .2, .4, 1.3)
		)
	_build_outbound_route(offset)


func _build_base_housing(offset: float, capacity: int) -> void:
	var root := Node3D.new()
	root.name = "LandingLivingCapsules"
	root.set_meta("base_housing", capacity)
	root.position = Vector3(offset - 6.0, _ground(offset - 6.0, 0), 0)
	buildings_root.add_child(root)
	var shell := _mat("basehousing", Color("c4b69a"), .45, .55)
	var dark := _mat("darkmetal", Color("354954"), .65, .38)
	var light := _mat("baselight", Color("f1d896"), .3, .4, .45)
	var count: int = 2 if capacity >= 80 else 1
	_cylinder(root, Vector3(0, .1, 0), 1.65, .2, dark, 8)
	for i in range(count):
		var x: float = (float(i) - float(count - 1) * .5) * 1.05
		var capsule := CapsuleMesh.new()
		capsule.radius = .44
		capsule.height = 2.45
		capsule.radial_segments = 16
		capsule.rings = 5
		var pod := _mesh(root, capsule, Vector3(x, .78, 0), shell)
		pod.rotation_degrees.x = 90
		for z in [-.65, 0, .65]:
			_box(root, Vector3(x, 1.20, z), Vector3(.55, .03, .22), dark)
			_box(root, Vector3(x, 1.22, z + .12), Vector3(.57, .02, .025), light)
		for z in [-.85, .85]:
			_box(root, Vector3(x, .32, z), Vector3(.7, .34, .14), dark)
	_box(root, Vector3(0, .37, 1.28), Vector3(1.2, .13, .5), shell)
	var label := Label3D.new()
	label.text = "登陆生活舱 · " + str(capacity) + " 人"
	label.font = label_font
	label.font_size = 36
	label.pixel_size = .009
	label.modulate = Color("e7d3a5")
	label.outline_modulate = Color("091621")
	label.position = Vector3(0, 1.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	_road(Vector3(offset, 0, 0), Vector3(offset - 6.0, 0, 0))


func _build_outbound_route(offset: float) -> void:
	var route: Dictionary = state.get("route", {})
	if not route.get("reachable", false):
		return
	var a: int = int(route.get("a", -1))
	var b: int = int(route.get("b", -1))
	if selected_region != a and selected_region != b:
		return
	var destination: int = b if selected_region == a else a
	var reg: Dictionary = world.regions[selected_region]
	var to: Dictionary = world.regions[destination]
	var direction := _point_to_local(float(to.lat), float(to.lon)).normalized()
	var coordinates: Array = route.get("coordinates", [])
	if coordinates.size() > 2:
		var adjacent: Array = (
			coordinates[2] if selected_region == a else coordinates[coordinates.size() - 3]
		)
		direction = _point_to_local(float(adjacent[0]), float(adjacent[1])).normalized()
	# The global route is a four-neighbour corridor. Its local gateway follows
	# the dominant outgoing direction and uses the clear central service lane.
	direction = (
		Vector2(signf(direction.x), 0)
		if absf(direction.x) > absf(direction.y)
		else Vector2(0, signf(direction.y))
	)
	var start := Vector2(offset, 0)
	var finish := start + direction * 24.0
	finish.x = clampf(finish.x, -26.5, 26.5)
	finish.y = clampf(finish.y, -21.5, 21.5)
	for i in range(28):
		var p: Vector2 = start.lerp(finish, float(i) / 28.0)
		var q: Vector2 = start.lerp(finish, float(i + 1) / 28.0)
		_road(Vector3(p.x, 0, p.y), Vector3(q.x, 0, q.y))
	var gate := Vector3(finish.x, _ground(finish.x, finish.y), finish.y)
	var steel := _mat("routegate", Color("bcb28d"), .55, .5)
	for x in [-.85, .85]:
		_tube(buildings_root, gate + Vector3(x, 0, 0), gate + Vector3(x, 2, 0), .09, steel)
	_box(buildings_root, gate + Vector3(0, 2, 0), Vector3(2, .35, .24), steel)
	var label := Label3D.new()
	var blocked: bool = Geo.road_blocked(route, int(state.get("day", 0)))
	label.text = (
		("停运 · " if blocked else "陆运 · ") + str(to.name) + " / " + str(route.get("days", 0)) + "天"
	)
	label.font = label_font
	label.font_size = 42
	label.pixel_size = .012
	label.modulate = Color("ead49d")
	label.outline_modulate = Color("091621")
	label.position = gate + Vector3(0, 2.9, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	buildings_root.add_child(label)


func _road(a: Vector3, b: Vector3) -> void:
	# Short actual service-road sections follow the regional height field; the
	# same service path crosses channels as a raised bridge, without fake exits.
	var count: int = maxi(1, ceili(a.distance_to(b) / 1.6))
	for i in range(count):
		_road_section(a.lerp(b, float(i) / count), a.lerp(b, float(i + 1) / count))


func _road_section(a: Vector3, b: Vector3) -> void:
	a.y = _ground(a.x, a.z) + .16
	b.y = _ground(b.x, b.z) + .16
	a.y = maxf(a.y, _water_height_at(a.x, a.z, 1.5) + .24)
	b.y = maxf(b.y, _water_height_at(b.x, b.z, 1.5) + .24)
	var midpoint: Vector3 = (a + b) * .5
	var road := _box(
		buildings_root,
		midpoint,
		Vector3(.72, .045, a.distance_to(b) + .4),
		_mat("road", Color("3c4848"), .15, .9)
	)
	if a.distance_to(b) > .01:
		road.look_at(b, Vector3.UP)
	var points: Array[Vector3] = [a + Vector3(0, .03, 0), b + Vector3(0, .03, 0)]
	_line(buildings_root, points, Color("b8b28c"), .25)


func _lander(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var material := _mat("lander", Color("bdccce"), .6, .4)
	_cylinder(root, Vector3(0, 1, 0), .7, 1.35, material, 8)
	_cone(root, Vector3(0, 1.9, 0), .7, .5, material)
	for i in range(3):
		var t: float = i * TAU / 3
		_tube(
			root,
			Vector3(sin(t) * .5, .8, cos(t) * .5),
			Vector3(sin(t) * 1.3, .08, cos(t) * 1.3),
			.07,
			material
		)
		_cylinder(root, Vector3(sin(t) * 1.3, .09, cos(t) * 1.3), .25, .08, material, 8)
	_tube(root, Vector3(0, 1.8, 0), Vector3(0, 3.3, 0), .035, material)
	_sphere(root, Vector3(0, 3.3, 0), .08, _mat("beacon", Color("76dace"), 0, .4, 1), 8, 4)
	var ring: Array[Vector3] = []
	for i in range(65):
		var t := float(i) / 64 * TAU
		var x := cos(t) * 4.2
		var z := sin(t) * 4.2
		ring.append(Vector3(x, _ground(x, z) - pos.y + .04, z))
	_line(root, ring, Color("77c9be"), .5)
