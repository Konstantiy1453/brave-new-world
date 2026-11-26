extends RefCounted

static var materials: Dictionary = {}
static var sphere: SphereMesh

static func _pigment(code: String) -> StandardMaterial3D:
	if not materials.has(code):
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color(code)
		material.roughness=.84
		materials[code]=material
	return materials[code]

static func _oval(node:Node3D,at:Vector3,dimensions:Vector3,colour:String)->MeshInstance3D:
	if sphere==null:
		sphere=SphereMesh.new()
		sphere.radial_segments=16
		sphere.rings=9
	var part:=MeshInstance3D.new()
	part.mesh=sphere
	part.material_override=_pigment(colour)
	part.position=at
	part.scale=dimensions
	node.add_child(part)
	return part

static func _limb(node:Node3D,a:Vector3,b:Vector3,r:float,colour:String)->void:
	var capsule:=CapsuleMesh.new()
	capsule.radius=r
	capsule.height=a.distance_to(b)+r*1.20
	capsule.radial_segments=12
	capsule.rings=4
	var part:=MeshInstance3D.new()
	part.mesh=capsule
	part.material_override=_pigment(colour)
	part.position=(a+b)*.5
	part.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	node.add_child(part)

static func _person(parent:Node3D,p:Vector3,yaw:float,index:int,step:float)->void:
	var node:=Node3D.new()
	parent.add_child(node)
	node.name="Resident_%02d"%index
	node.position=p
	node.rotation.y=yaw
	node.scale=Vector3.ONE*[.96,1.03,1.,.94,1.06,.98][index%6]
	var coat:String=["aa7248","476374","657254","937a65","ad8b51","697b89","62665d","8c6556"][index%8]
	var pants:String=["3d4447","525755","454b55"][index%3]
	var skin:String=["b48468","986851","c69975","8d6856"][(index*3)%4]
	var hair:String=["40372f","343337","67605b"][index%3]
	for signum in [-1.,1.]:
		var sign_f:=float(signum)
		var hip:=Vector3(sign_f*.102,.88,0)
		var knee:=Vector3(sign_f*.104,.53,sign_f*step*.46-.025)
		var ankle:=Vector3(sign_f*.105,.136,sign_f*step*.82)
		_limb(node,hip,knee,.085,pants)
		_limb(node,knee,ankle,.070,pants)
		_oval(node,ankle+Vector3(0,-.059,-.075),Vector3(.145,.125,.276),"383b38")
		var shoulder:=Vector3(sign_f*.202,1.38,0)
		var elbow:=Vector3(sign_f*.241,1.15,-sign_f*step*.35+.035)
		var wrist:=Vector3(sign_f*.223,.965,-sign_f*step*.65-.037)
		_limb(node,shoulder,elbow,.078,coat)
		_limb(node,elbow,wrist,.061,coat)
		_oval(node,wrist+Vector3.DOWN*.047,Vector3(.085,.142,.092),skin)
	_oval(node,Vector3(0,.92,.008),Vector3(.36,.33,.26),pants)
	_oval(node,Vector3(0,1.18,0),Vector3(.439,.57,.301),coat)
	_oval(node,Vector3(0,1.29,.022),Vector3(.413,.355,.298),coat)
	_limb(node,Vector3(0,1.386,0),Vector3(0,1.54,0),.069,skin)
	_oval(node,Vector3(0,1.582,-.015),Vector3(.215,.30,.216),skin)
	_oval(node,Vector3(0,1.673,-.003),Vector3(.223,.141,.224),hair)
	if index%3==1:
		_oval(node,Vector3(0,1.69,-.025),Vector3(.245,.13,.26),"6c6b5b")
		_oval(node,Vector3(0,1.68,-.11),Vector3(.18,.032,.17),"6c6b5b")
	if index%3==0:
		_oval(node,Vector3(0,1.23,.179),Vector3(.29,.37,.18),"645746")

static func build(parent:Node3D,roads:Array,street:Variant,h:Callable)->void:
	var locations=[
		[0,.499,1,1.16,.09,.025],[0,.511,1,1.26,-.52,.02],[0,.524,1,1.36,.9,.12],
		[0,.445,-1,.80,-1.2,.26],[0,.448,-1,1.43,.35,.18],
		[0,.578,-1,.83,-.82,.27],[1,.53,1,.85,.2,.20],[2,.425,1,.7,1.4,.14]
	]
	for i in locations.size():
		var rec:Array=locations[i]
		var road:Dictionary=roads[rec[0]]
		var f:Dictionary=street._frame(road,float(rec[1]))
		var at:Vector3=f.p + f.side*float(rec[2])*(float(road.width)*.5+float(rec[3]))
		at.y=float(h.call(at.x,at.z))+.17
		var axis:Vector3=f.dir
		var yaw:=atan2(-axis.x,-axis.z)+float(rec[4])
		_person(parent,at,yaw,i,float(rec[5]))
