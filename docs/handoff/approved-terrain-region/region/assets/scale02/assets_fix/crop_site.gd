extends RefCounted
const DIR: String="res://assets/scale02/assets_fix/"
const IDS=["crew_quarters","habitat","lab","clinic","apartment"]
static var replacements:Dictionary={}

# Call on a placed and metre-calibrated instance. The previous datum, pivot and transform survive.
static func apply(node:MeshInstance3D,id:String)->bool:
	if not IDS.has(id):return false
	var previous:ArrayMesh=node.mesh
	var slots:Dictionary={}
	for i in previous.get_surface_count():slots[previous.surface_get_name(i)]=node.get_active_material(i)
	if not replacements.has(id):replacements[id]=ResourceLoader.load(DIR+id+".res")
	var replacement:ArrayMesh=replacements[id]
	if replacement==null:push_error("Missing cropped resource: "+id);return false
	for i in replacement.get_surface_count():
		if not slots.has(replacement.surface_get_name(i)):push_error("Missing retained material in "+id);return false
	node.mesh=replacement
	for i in replacement.get_surface_count():node.set_surface_override_material(i,slots[replacement.surface_get_name(i)])
	return true
