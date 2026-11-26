extends RefCounted
const ReferenceIO = preload("res://reference_io.gd")
const DIR := "res://assets/surface07/soil/"
const ENV := "res://assets/artpreview/env/"
const FRINGE := "res://assets/surface07/fringe/road_fringe.png"

static func _tile(path:String) -> Texture2D:
	return ReferenceIO.texture(path)

static func make_material() -> ShaderMaterial:
	var result:=ShaderMaterial.new()
	var shader:=ReferenceIO.shader(DIR+"soil07.gdshader")
	result.shader=shader
	result.set_shader_parameter("soil_patch",_tile(DIR+"weathered_loam.png"))
	result.set_shader_parameter("meadow_patch",_tile(DIR+"sparse_turf.png"))
	result.set_shader_parameter("scrub",_tile(ENV+"scrub_noise.png"))
	result.set_shader_parameter("old_soil",_tile(ENV+"soil_basecolor.jpg"))
	result.set_shader_parameter("old_rock",_tile(ENV+"rock_basecolor.jpg"))
	result.set_shader_parameter("roads",_tile(FRINGE))
	return result
