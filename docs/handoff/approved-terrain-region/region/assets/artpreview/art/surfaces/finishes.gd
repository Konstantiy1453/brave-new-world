extends RefCounted
const ReferenceIO = preload("res://reference_io.gd")
const BASE="res://assets/artpreview/art/"
var _shader:Shader
var _patina:Texture2D
var _registry:Dictionary
const ROLE={
	"paint":0,"wall":1,"roof":2,"door":3,"roof_metal":4,"metal":5,"glass":6,"salon_glass":7,
	"window_warm":8,"window_cool":8,"window_dim":8,"rubber":10,"accent":11,"skirt":12,"dark":13,"rim":14}
const BASES={
	"paint":["859596",.51,.22], "wall":["929b91",.63,.14],"door":["647876",.56,.26],
	"roof":["78857d",.66,.21],"roof_metal":["747e80",.47,.48],"metal":["657278",.43,.53],
	"glass":["254351",.18,.34],"salon_glass":["28505b",.20,.22],"window_warm":["534f45",.23,.20],
	"window_dim":["2e4249",.21,.27],"window_cool":["355763",.19,.31],"rubber":["262726",.84,.01],
	"accent":["a07d51",.54,.24],"skirt":["45504e",.61,.22],"dark":["39474a",.58,.30],"rim":["98a5a4",.38,.65]}
const PAINT={"vehicle_bus":"7a9d92","vehicle_truck":"ac7a54","vehicle_van":"adbaae","habitat":"8d9d91","commerce":"ada08a","apartment":"a29a8e","clinic":"9aaea6","lab":"82969d","school":"b0a188","crew_quarters":"929f8e","processor":"889698","depot":"8b9589","power":"8a9c99"}
const ROOF={"habitat":"798479","commerce":"858781","apartment":"7b827d","clinic":"778a83","lab":"6e858b","school":"867d71","crew_quarters":"788378"}
func _init():
	_shader=ReferenceIO.shader(BASE+"surfaces/architectural.gdshader")
	_patina=ReferenceIO.texture(BASE+"surfaces/patina.png")
	_registry=JSON.parse_string(FileAccess.get_file_as_string(BASE+"model_units.json"))
func supports(slot:String)->bool:return ROLE.has(slot)
func make(id:String,slot:String)->Material:
	var m:=ShaderMaterial.new()
	m.resource_name=id+"/"+slot
	m.shader=_shader
	var spec:Array=BASES[slot]
	var colour:String=spec[0]
	var veh:=id.begins_with("vehicle_")
	var rough:float=spec[1]
	var metal:float=spec[2]
	if slot in ["paint","wall"]:colour=PAINT.get(id,colour)
	if slot=="door":
		if veh:colour=PAINT.get(id,colour)
		elif id=="commerce":colour="6d7971"
	if slot=="roof":colour=ROOF.get(id,colour)
	if slot=="accent" and veh:colour={"vehicle_bus":"b3a168","vehicle_truck":"af8347","vehicle_van":"547b77"}.get(id,colour)
	if veh and slot=="paint":rough=.41;metal=.30
	var energy:Dictionary={"window_warm":["e8b17b",.30],"window_dim":["b38968",.025],"window_cool":["8bacbc",.15],"salon_glass":["97b2a8",.047]}
	m.set_shader_parameter("patina",_patina)
	m.set_shader_parameter("coat",Color(colour))
	m.set_shader_parameter("metal_fraction",metal)
	m.set_shader_parameter("micro_roughness",rough)
	m.set_shader_parameter("treatment",ROLE[slot])
	m.set_shader_parameter("automobile",veh)
	m.set_shader_parameter("local_to_metres",1./maxf(float(_registry[id]),.001))
	if slot in energy:
		m.set_shader_parameter("glow",Color(energy[slot][0]))
		m.set_shader_parameter("warmth",energy[slot][1])
	return m
func shader_uniforms()->Array:return _shader.get_shader_uniform_list()
