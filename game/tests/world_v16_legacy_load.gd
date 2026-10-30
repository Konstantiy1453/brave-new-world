extends SceneTree
const Sim=preload("res://simulation/sim.gd")
var failures:Array=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if not ok:failures.append(label)
func run():
	var path:String="res://data/acceptance_success.json"
	var envelope:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var original:Dictionary=bytes_to_var(Marshalls.base64_to_raw(envelope.binary)) if envelope.has("binary") else JSON.parse_string(envelope.payload)
	var sim=Sim.new()
	sim.new_game(42,"capital")
	var error:String=sim.load_game(path)
	check(error=="","signed32 complete v1.5 save loads through actual simulation")
	check(var_to_bytes(sim.state.world)==var_to_bytes(original.world),"legacy world is byte-preserved through migration")
	var valid:PackedByteArray=var_to_bytes(sim.state)
	var bad=Sim.new();bad.state=sim.state.duplicate(true)
	bad.state.world.seed=4294967297
	var before:PackedByteArray=var_to_bytes(bad.state.world)
	var out:String="res://../evidence/v16/legacy_seed_invalid.json"
	check(bad.save_game(out)=="","invalid-seed mutation fixture written through envelope writer")
	error=sim.load_game(out)
	check(error!="" and error.contains("32"),"actual load rejects ambiguous legacy seed with explanation")
	check(var_to_bytes(sim.state)==valid,"bad legacy load leaves whole current state unchanged")
	check(var_to_bytes(bad.state.world)==before and FileAccess.file_exists(out),"rejected legacy fixture and original geography retained")
	FileAccess.open("res://../evidence/v16/world_legacy_load.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"actual simulation load and migration, full binary legacy world identity, checksummed overflow mutation, in-memory rollback and preserved file","error":error,"failures":failures},"\t"))
	print("WORLD_LEGACY_LOAD ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
