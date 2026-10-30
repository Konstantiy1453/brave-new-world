extends "res://world/region_view.gd"
## The flat equirectangular world map.


func _flat_point(lat: float, lon: float) -> Vector3:
	return Vector3(lon / 20.0, lat / 20.0, .035)


func _build_flat() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D atlas:source_color,filter_linear_mipmap,repeat_disable;
void fragment(){
 vec4 tex=texture(atlas,UV);
 vec2 step_uv=1.0/vec2(textureSize(atlas,0));
 float relief=clamp((texture(atlas,UV-vec2(step_uv.x,0)).a-texture(atlas,UV+vec2(step_uv.x,0)).a+texture(atlas,UV-vec2(0,step_uv.y)).a-texture(atlas,UV+vec2(0,step_uv.y)).a)*26.0,-.24,.24);
 relief*=smoothstep(.50,.57,tex.a);
 ALBEDO=tex.rgb*(.76+relief);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("atlas", geography_atlas)
	flat_shader = material
	var sheet := QuadMesh.new()
	sheet.size = Vector2(18, 9)
	_mesh(flat_world, sheet, Vector3.ZERO, material)
	# A restrained cartographic frame, not the regional construction grid.
	var frame: Array[Vector3] = [
		Vector3(-9, -4.5, .02),
		Vector3(9, -4.5, .02),
		Vector3(9, 4.5, .02),
		Vector3(-9, 4.5, .02),
		Vector3(-9, -4.5, .02)
	]
	_line(flat_world, frame, Color("5a8491"), .15)
	for lon in range(-180, 181, 60):
		var p := _flat_point(90, lon)
		_line(flat_world, [p, p + Vector3(0, .12, 0)], Color("718e9c"), .1)
		_flat_label(flat_world, Vector3(p.x, 4.78, .03), "%d°" % lon, Color("8da6b4"), .0065, 26)
	for lat in [-60, -30, 0, 30, 60]:
		_flat_label(
			flat_world, Vector3(-9.38, lat / 20.0, .03), "%d°" % lat, Color("8da6b4"), .0065, 26
		)
	_flat_label(flat_world, Vector3(0, -4.9, .03), "全球勘察图  /  等距经纬投影", Color("90aeb9"), .0068, 30)
	flat_marker_root = Node3D.new()
	flat_world.add_child(flat_marker_root)
	flat_transport_root = Node3D.new()
	flat_world.add_child(flat_transport_root)
	_build_global_water(flat_world, true)
	_update_flat_markers()
	_update_flat_transport()


func _flat_label(
	parent: Node3D,
	pos: Vector3,
	text: String,
	color: Color,
	pixel_size: float = .003,
	font_size: int = 36
) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = label_font
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.position = pos
	label.no_depth_test = true
	label.modulate = color
	label.outline_modulate = Color("071623")
	label.outline_size = 7
	parent.add_child(label)
	return label


func _update_flat_markers() -> void:
	if flat_marker_root == null or not is_instance_valid(flat_marker_root):
		return
	for child in flat_marker_root.get_children():
		flat_marker_root.remove_child(child)
		child.queue_free()
	for reg in world.regions:
		var settled: bool = false
		for settlement in state.get("settlements", []):
			if int(settlement.region) == int(reg.id):
				settled = true
		var color := Color("edc779") if settled else Color("7ae0d6")
		if int(reg.id) == selected_region:
			color = Color("fff2bd")
		var point := _flat_point(reg.lat, reg.lon)
		var ring: Array[Vector3] = []
		for i in range(41):
			var angle := float(i) / 40.0 * TAU
			ring.append(
				(
					point
					+ (
						Vector3(cos(angle), sin(angle), 0)
						* (.085 if int(reg.id) == selected_region else .055)
					)
				)
			)
		var holder := Node3D.new()
		flat_marker_root.add_child(holder)
		_line(holder, ring, color, .8)
		_sphere(
			holder,
			point,
			.025,
			_mat("flatdot" + str(reg.id) + str(selected_region) + str(settled), color, 0, 1, 1.3),
			8,
			4
		)
		# Fixed cartographic offsets keep the clustered starting candidates readable.
		var label_offset: Vector3 = Vector3(.65, .26, .03)
		if int(reg.id) == 0:
			label_offset = Vector3(-.80, .3, .03)
		if int(reg.id) == 3:
			label_offset = Vector3(-.90, -.20, .03)
		if int(reg.id) == 2:
			label_offset = Vector3(.65, .48, .03)
		if int(reg.id) == 1:
			label_offset = Vector3(.90, -.15, .03)
		if int(reg.id) == 5:
			label_offset = Vector3(.40, -.25, .03)
		var label_position: Vector3 = point + label_offset
		label_position.x = clampf(label_position.x, -8.0, 8.0)
		_flat_label(
			holder,
			label_position,
			("◆ " if settled else "%02d " % (int(reg.id) + 1)) + str(reg.name),
			color,
			.0068,
			40
		)


func _update_flat_transport() -> void:
	if flat_transport_root == null or not is_instance_valid(flat_transport_root):
		return
	for child in flat_transport_root.get_children():
		flat_transport_root.remove_child(child)
		child.queue_free()
	var route: Dictionary = state.get("route", {})
	if not route.get("reachable", false):
		return
	var route_color := (
		Color("d77963") if Geo.road_blocked(route, int(state.get("day", 0))) else Color("e7bb75")
	)
	var coordinates: Array = route.get("coordinates", []).duplicate()
	if coordinates.is_empty():
		for index in route.get("path", []):
			var ll: Vector2 = Geo.cell_coordinate(int(index))
			coordinates.append([ll.x, ll.y])
	var points: Array[Vector3] = []
	var segment: Array[Vector3] = []
	for ll in coordinates:
		var point := _flat_point(float(ll[0]), float(ll[1])) + Vector3(0, 0, .02)
		if not segment.is_empty() and absf(point.x - segment.back().x) > 9:
			_line(flat_transport_root, segment, route_color, 1.1)
			segment.clear()
		segment.append(point)
		points.append(point)
	_line(flat_transport_root, segment, route_color, 1.1)
	for shipment in state.get("shipments", []):
		if points.is_empty():
			continue
		var progress: float = clampf(
			(
				1.0
				- (
					float(shipment.get("remaining", 1))
					/ maxf(float(shipment.get("total_days", 1)), 1.0)
				)
			),
			0,
			1
		)
		if int(shipment.get("from", -1)) == int(route.get("b", -2)):
			progress = 1.0 - progress
		var index: int = clampi(int(progress * (points.size() - 1)), 0, points.size() - 1)
		_sphere(
			flat_transport_root,
			points[index] + Vector3(0, 0, .03),
			.031,
			_mat("flatshipment", Color("fff0bd"), 0, 1, 2),
			8,
			4
		)


func _build_global_water(parent: Node3D, flat: bool) -> void:
	# This overlay reads the same persisted river paths as the regional view.
	for river in render_rivers:
		var coordinates: Array = river.coordinates
		var points: Array[Vector3] = []
		for ll in coordinates:
			var point: Vector3 = (
				_flat_point(float(ll[0]), float(ll[1]))
				if flat
				else Geo.unit_point(float(ll[0]), float(ll[1])) * 3.009
			)
			if flat and not points.is_empty() and absf(point.x - points.back().x) > 9:
				_line(parent, points, Color("397f91"), .05)
				points.clear()
			points.append(point)
		_line(parent, points, Color("397f91"), .05)
	for lake in world.get("lakes", []):
		var lat: float = float(lake.lat)
		var lon: float = float(lake.lon)
		var radius: float = float(lake.get("radius_degrees", .45))
		var center: Vector3 = _flat_point(lat, lon) if flat else Geo.unit_point(lat, lon) * 3.013
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(32):
			var angle_a: float = TAU * float(i) / 32
			var angle_b: float = TAU * float(i + 1) / 32
			var la: Vector2 = Vector2(
				clampf(lat + cos(angle_a) * radius, -89.95, 89.95),
				wrapf(lon + sin(angle_a) * radius / maxf(cos(deg_to_rad(lat)), .15), -180, 180)
			)
			var lb: Vector2 = Vector2(
				clampf(lat + cos(angle_b) * radius, -89.95, 89.95),
				wrapf(lon + sin(angle_b) * radius / maxf(cos(deg_to_rad(lat)), .15), -180, 180)
			)
			var a: Vector3 = _flat_point(la.x, la.y) if flat else Geo.unit_point(la.x, la.y) * 3.013
			var b: Vector3 = _flat_point(lb.x, lb.y) if flat else Geo.unit_point(lb.x, lb.y) * 3.013
			if flat and (absf(center.x - a.x) > 9 or absf(center.x - b.x) > 9):
				continue
			for point in [center, a, b]:
				st.add_vertex(point)
		st.generate_normals()
		var material := _mat("global_lake", Color("327c91"), .1, .4, .12)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh(parent, st.commit(), Vector3.ZERO, material)


func _prepare_render_rivers() -> void:
	# Round only the corners of the persisted coarse-grid channels. The same
	# subcell centerline and monotone height interpolation feed all three views.
	render_rivers.clear()
	var metadata: Array = world.get("river_metadata", [])
	var rivers: Array = world.get("rivers", [])
	for river_index in range(rivers.size()):
		var raw = rivers[river_index]
		var coordinates: Array = raw.get("coordinates", []) if raw is Dictionary else raw
		var heights: Array = (
			metadata[river_index].get("heights", []) if river_index < metadata.size() else []
		)
		var samples: Array[Vector3] = []
		for i in range(coordinates.size()):
			var ll = coordinates[i]
			var h: float = (
				float(heights[i])
				if i < heights.size()
				else float(
					Geo.sample_geo(float(ll[0]), float(ll[1]), noise, str(world.version)).height
				)
			)
			var lon: float = float(ll[1])
			if not samples.is_empty():
				lon = samples.back().x + wrapf(lon - samples.back().x, -180, 180)
			samples.append(Vector3(lon, float(ll[0]), h))
		if samples.size() < 2:
			continue
		var rounded: Array[Vector3] = [samples[0]]
		for i in range(1, samples.size() - 1):
			var a: Vector3 = samples[i - 1].lerp(samples[i], .76)
			var b: Vector3 = samples[i].lerp(samples[i + 1], .24)
			rounded.append(a)
			for step in range(1, 7):
				var t: float = float(step) / 6
				rounded.append(a.lerp(samples[i], t).lerp(samples[i].lerp(b, t), t))
		rounded.append(samples.back())
		var output: Array = []
		var output_heights: Array = []
		for point in rounded:
			output.append([point.y, wrapf(point.x, -180, 180)])
			output_heights.append(point.z)
		render_rivers.append(
			{"coordinates": output, "heights": output_heights, "river_index": river_index}
		)
