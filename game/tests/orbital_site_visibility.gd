extends SceneTree
const Map = preload("res://world/map_view.gd")
const Sim = preload("res://simulation/sim.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sim = Sim.new()
	sim.new_game(260129, "capital", 1, "normal")
	var map = Map.new()
	root.add_child(map)
	map.setup(sim.geo)
	map.sync_state(sim.state)
	var valid: bool = map._labelled_sites().is_empty()
	map.selected_region = 1
	valid = valid and not map._marker_shown(sim.geo.regions[1])
	map.show_flat()
	valid = valid and map._labelled_sites().is_empty()
	for reg in sim.geo.regions:
		if sim.settle_refusal(reg.id) == "":
			valid = valid and sim.act("settle", {"site": reg.id}) == ""
			break
	map.sync_state(sim.state)
	valid = valid and map._labelled_sites().size() == 1
	map.show_planet()
	valid = valid and map._labelled_sites().size() == 1
	valid = valid and map.cloud_shader.get_shader_parameter("cyclone_pattern") != null
	valid = valid and map.flat_shader.get_shader_parameter("cyclone_pattern") != null
	print("ORBITAL_SITE_VISIBILITY ", "PASS" if valid else "FAIL")
	quit(0 if valid else 1)
