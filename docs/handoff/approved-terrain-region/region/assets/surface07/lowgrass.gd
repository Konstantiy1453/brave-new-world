extends RefCounted

# Blade vertices are authored in metres. Instance bases invert the terrain parent's scale.
static func _blade(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	for v in [[a, ca], [b, cb], [c, cc]]:
		surface.set_color(v[1])
		surface.set_normal(Vector3.UP)
		surface.add_vertex(v[0])

static func _family(index: int) -> ArrayMesh:
	var rand := RandomNumberGenerator.new()
	rand.seed = 96513 + index * 521
	var surf := SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_col := [Color("#767c50"), Color("#787c57"), Color("#8b8057"), Color("#747a4b"), Color("#8d8564")][index] as Color
	for clump in range(rand.randi_range(4, 8)):
		var ang := rand.randf() * TAU
		var r := rand.randf_range(.03, .38)
		var origin := Vector3(cos(ang) * r, -.015, sin(ang) * r)
		var base_h := rand.randf_range(.09, .25)
		for blade in range(rand.randi_range(6, 12)):
			var yaw := rand.randf() * TAU
			var direction := Vector3(cos(yaw), 0., sin(yaw))
			var side := Vector3(-direction.z, 0., direction.x)
			var height := base_h * rand.randf_range(.58, 1.52)
			var width := rand.randf_range(.005, .012)
			var root := origin + direction * rand.randf_range(.0, .085)
			var bend := height * rand.randf_range(.22, 1.25)
			var middle := root + direction * bend * .34 + Vector3.UP * height * .68
			var tip := root + direction * bend + Vector3.UP * height
			var color := base_col.lerp(Color("#a89b6b"), rand.randf() * .53)
			var bottom := color.darkened(.18)
			var top := color.lightened(rand.randf_range(.04, .15))
			_blade(surf, root - side*width, root + side*width, middle - side*width*.64, bottom, bottom, color)
			_blade(surf, root + side*width, middle + side*width*.64, middle - side*width*.64, bottom, color, color)
			_blade(surf, middle - side*width*.64, middle + side*width*.64, tip, color, color, top)
	return surf.commit()

static func build(parent: Node3D, original: Array, ground: Script) -> Array:
	var keep: Array = []
	var grouped: Array = [[],[],[],[],[]]
	var rand := RandomNumberGenerator.new()
	rand.seed=827441
	var inserted := 0
	var near_ground := 0
	for entry: Array in original:
		var tr: Transform3D=entry[0]
		var c := Vector2(tr.origin.x, tr.origin.z)*4.68
		var transition := 1.-smoothstep(430.,640.,c.length())
		if rand.randf()>transition:
			keep.append(entry)
			continue
		near_ground += 1
		var yaw := rand.randf()*TAU
		var axis:=Vector2(cos(yaw),sin(yaw))
		var across:=Vector2(-axis.y,axis.x)
		var span:=rand.randf_range(.75,2.8)
		var count:=rand.randi_range(3,9)
		for j in count:
			var world := c if j==0 else c + axis*rand.randfn(0.,span*.68) + across*rand.randfn(0.,span*.31)
			var local := world/4.68
			var scale_ := rand.randf_range(.65, 1.35)
			if float(ground._distance(local))*4.68<.62*scale_: continue
			var h := float(ground._on_mesh(local.x,local.y))
			var basis:=Basis(Vector3.UP,rand.randf()*TAU).scaled(Vector3(scale_/4.68,scale_/2.4,scale_/4.68))
			grouped[rand.randi_range(0,4)].append(Transform3D(basis, Vector3(local.x,h,local.y)))
			inserted+=1
	var mat:=ShaderMaterial.new()
	var shader:=Shader.new()
	shader.code="""
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
varying vec3 tint;
void vertex(){ tint=pow(COLOR.rgb,vec3(2.2)); }
void fragment(){
    NORMAL=normalize((VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz);
    ALBEDO=tint*.76;
    BACKLIGHT=tint*.23;
    ROUGHNESS=.94;
    SPECULAR=.15;
}
"""
	mat.shader=shader
	for i in grouped.size():
		if grouped[i].is_empty():continue
		var multi:=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=_family(i)
		multi.instance_count=grouped[i].size()
		for j in grouped[i].size():multi.set_instance_transform(j,grouped[i][j])
		var stem:=MultiMeshInstance3D.new()
		stem.name="DryMeadow%02d" % i
		stem.multimesh=multi
		stem.material_override=mat
		stem.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(stem)
	print("SURFACE07_FINE_GRASS anchors=",near_ground," small_clumps=",inserted," distant_legacy=",keep.size())
	return keep
