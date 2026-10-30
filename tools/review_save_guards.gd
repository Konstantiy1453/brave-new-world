extends SceneTree
const Watchdog=preload("res://tests/support/watchdog.gd")
const Sim=preload("res://simulation/sim.gd")
var out:Dictionary={"scope":"independent bounded malformed-save and exact-snapshot checks","checks":[]}
var s
var baseline:PackedByteArray
var original:Dictionary
func envelope(value:Variant)->Dictionary:
	var e:Dictionary=original.duplicate(true)
	e.binary=Marshalls.raw_to_base64(var_to_bytes(value))
	e.binary_checksum=e.binary.sha256_text()
	return e
func reject(label:String,e:Dictionary)->void:
	var path:String="user://review_malformed_save.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(e))
	var result:String=s.load_game(path)
	out.checks.append({"name":label,"error":result,"rejected":result!="","state_unchanged":var_to_bytes(s.state)==baseline})
func _initialize()->void:
	Watchdog.arm(self)
	s=Sim.new()
	s.new_game(20261029,"capital",1)
	s.act("settle",{"region":0})
	s.act("build",{"region":0,"kind":"mine_ore"})
	s.act("build",{"region":0,"kind":"mine_copper"})
	for d in range(17): s.tick()
	s.save_game("user://review_exact_snapshot.json")
	original=JSON.parse_string(FileAccess.get_file_as_string("user://review_exact_snapshot.json"))
	baseline=var_to_bytes(s.state)
	var t=Sim.new()
	var load_error:String=t.load_game("user://review_exact_snapshot.json")
	out.checks.append({"name":"valid_binary_roundtrip","error":load_error,"pass":load_error=="" and var_to_bytes(t.state)==baseline})
	var e:Dictionary=original.duplicate(true)
	e.checksum="broken"
	reject("bad_payload_hash",e)
	e=original.duplicate(true)
	e.binary_checksum="broken"
	reject("bad_binary_hash",e)
	reject("binary_primitive",envelope(42))
	reject("binary_missing_fields",envelope({"schema":1}))
	var candidate:Dictionary=s.state.duplicate(true)
	candidate.cash+=1.0
	reject("cash_conservation_rejection",envelope(candidate))
	candidate=s.state.duplicate(true)
	candidate.world=[]
	reject("wrong_world_type",envelope(candidate))
	# A harmless native Resource is encoded only to check object-disabled decoding.
	e=original.duplicate(true)
	e.binary=Marshalls.raw_to_base64(var_to_bytes_with_objects(Resource.new()))
	e.binary_checksum=e.binary.sha256_text()
	reject("object_encoded_snapshot",e)
	var failures:int=0
	for check in out.checks:
		if not bool(check.get("pass",check.get("rejected",false) and check.get("state_unchanged",false))): failures+=1
	out.failures=failures
	FileAccess.open("D:/勇敢新世界/evidence/v17/tests/save_guard_review.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print(JSON.stringify(out))
	quit(1 if failures else 0)
