extends RefCounted
var faces:PackedVector3Array
var safe_height:Callable

func setup(scene:Node3D,h:Callable)->void:
	safe_height=h
	var road:MeshInstance3D=scene.get_node("Streets/Asphalt")
	faces=road.mesh.get_faces()

func surface_at(x:float,z:float)->float:
	var p:=Vector2(x,z)
	for i in range(0,faces.size(),3):
		var a:=faces[i]; var b:=faces[i+1];var c:=faces[i+2]
		var u:=Vector2(b.x-a.x,b.z-a.z)
		var v:=Vector2(c.x-a.x,c.z-a.z)
		var d:=p-Vector2(a.x,a.z)
		var det:=u.cross(v)
		if absf(det)<.00001:continue
		var s:=d.cross(v)/det
		var t:=u.cross(d)/det
		if s>=-.0001 and t>=-.0001 and s+t<=1.0001:
			return a.y+(b.y-a.y)*s+(c.y-a.y)*t
	return float(safe_height.call(x,z))+.115

func align_to_road(parent:Node3D,p:Vector3,yaw:float,length_m:float)->Node3D:
	var forward:=Vector3.FORWARD.rotated(Vector3.UP,yaw)
	var right:=Vector3.RIGHT.rotated(Vector3.UP,yaw)
	var long:=length_m*.33
	var front:=surface_at(p.x+forward.x*long,p.z+forward.z*long)
	var rear:=surface_at(p.x-forward.x*long,p.z-forward.z*long)
	var east:=surface_at(p.x+right.x*.8,p.z+right.z*.8)
	var west:=surface_at(p.x-right.x*.8,p.z-right.z*.8)
	var rise:=forward*((front-rear)/(2.*long))+right*((east-west)/1.6)
	var up:=Vector3(-rise.x,1.,-rise.z).normalized()
	var pivot:=Node3D.new()
	parent.add_child(pivot)
	pivot.position=Vector3(p.x,(front+rear)*.5-.012,p.z)
	pivot.basis=Basis(Quaternion(Vector3.UP,up))
	var mesh:=PlaneMesh.new()
	mesh.size=Vector2(2.03,length_m*.86)
	var shadow:=MeshInstance3D.new()
	var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled; void fragment(){vec2 a=abs(UV*2.-1.);float fall=(1.-smoothstep(.30,1.,a.x))*(1.-smoothstep(.42,1.,a.y));ALBEDO=vec3(.015,.013,.011);ALPHA=.28*fall;}"
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	shadow.material_override=mat
	shadow.mesh=mesh
	shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(shadow)
	shadow.position.y=.028
	shadow.rotation.y=yaw
	return pivot
