extends SceneTree
const Sim=preload("res://simulation/sim.gd")
func _initialize()->void:
	var s=Sim.new()
	s.new_game(20261029,"capital",1)
	s.act("settle",{"region":0})
	var before:PackedByteArray=var_to_bytes(s.state)
	s.save_game("user://review_nested_source.json")
	var e:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://review_nested_source.json"))
	var candidate:Dictionary=s.state.duplicate(true)
	candidate.settlements[0].stock=5
	e.binary=Marshalls.raw_to_base64(var_to_bytes(candidate))
	e.binary_checksum=e.binary.sha256_text()
	FileAccess.open("user://review_nested_bad.json",FileAccess.WRITE).store_string(JSON.stringify(e))
	var result:Variant=s.load_game("user://review_nested_bad.json")
	var out:Dictionary={"scope":"controlled malformed nested stock type with correct outer checksum","load_result":result,"state_unchanged":before==var_to_bytes(s.state)}
	FileAccess.open("D:/勇敢新世界/docs/evidence/save_nested_type_review.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print(JSON.stringify(out))
	quit(0)
