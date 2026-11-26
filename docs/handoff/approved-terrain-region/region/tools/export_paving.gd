extends SceneTree
var out_dir: String
const BASE="res://assets/space06/"
const HORIZONTAL=4.68
var hills=load("res://assets/surface07/terrain07.gd")
func metric_h(x:float,z:float)->float:
	return 2.4*float(hills.height_at(x/HORIZONTAL,z/HORIZONTAL))
func _initialize()->void:
	call_deferred("collect")
func collect()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1:
		push_error("Supply the output directory after --")
		quit(2)
		return
	out_dir=ProjectSettings.globalize_path(args[0])
	if DirAccess.make_dir_recursive_absolute(out_dir)!=OK:
		push_error("Could not create " + out_dir)
		quit(3)
		return
	var scene:=Node3D.new()
	root.add_child(scene)
	var street_system=load(BASE+"streets06.gd")
	var plan=street_system.plan()
	var normalized:Array=[]
	for lot:Dictionary in plan.lots:
		var l:=lot.duplicate()
		l.pos=Vector3(lot.pos)/HORIZONTAL
		l.extent=Vector2(lot.extent)/HORIZONTAL
		l.frontage=Vector3(lot.frontage)/HORIZONTAL
		normalized.append(l)
	hills.set_foundations(normalized)
	street_system.build(scene,plan.roads,plan.lots,Callable(self,"metric_h"))
	var groups:Dictionary={}
	var total:=0
	for node in scene.get_node("Streets").get_children():
		var n:=str(node.name).to_lower()
		if n not in ["asphalt","walk","yard","sand","dirt","gravel","edge"]:continue
		var vertices:PackedVector3Array=node.mesh.get_faces()
		var projected:=PackedVector2Array()
		for k in range(0,vertices.size(),3):
			var pa:Vector3 = node.global_transform*vertices[k]
			var pb:Vector3 = node.global_transform*vertices[k+1]
			var pc:Vector3 = node.global_transform*vertices[k+2]
			var a:=Vector2(pa.x,pa.z);var b:=Vector2(pb.x,pb.z);var c:=Vector2(pc.x,pc.z)
			if absf((b-a).cross(c-a))<.0000001*HORIZONTAL*HORIZONTAL: continue
			projected.append_array(PackedVector2Array([a,b,c]))
		var f:=FileAccess.open(out_dir.path_join(n+".xy"),FileAccess.WRITE)
		f.store_buffer(projected.to_byte_array())
		f.close()
		groups[n]=int(projected.size()/3)
		total+=groups[n]
	FileAccess.open(out_dir.path_join("pavement_counts.json"),FileAccess.WRITE).store_string(JSON.stringify(groups))
	print("Actual pavement triangles ",total," ",groups)
	root.remove_child(scene);scene.free()
	quit(0 if total>0 else 2)
