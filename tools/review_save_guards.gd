extends SceneTree
const Watchdog = preload("res://tests/support/watchdog.gd")
const Sim = preload("res://simulation/sim.gd")
const SaveFixture = preload("res://tests/support/save_fixture.gd")
var out: Dictionary = {
	"scope": "independent bounded malformed-save and exact-snapshot checks", "checks": []
}
var s
var baseline: PackedByteArray
var original: PackedByteArray


func reject(label: String, writer: Callable) -> void:
	var path: String = "user://review_malformed_save.save"
	writer.call(path)
	var result: String = s.load_game(path)
	out.checks.append(
		{
			"name": label,
			"error": result,
			"rejected": result != "",
			"state_unchanged": var_to_bytes(s.state) == baseline
		}
	)


func _write_state(path: String, value: Variant) -> void:
	SaveFixture.write_state(path, value)


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	FileAccess.open(path, FileAccess.WRITE).store_buffer(bytes)


func _initialize() -> void:
	Watchdog.arm(self)
	s = Sim.new()
	s.new_game(20261029, "capital", 1)
	s.act("settle", {"region": 0})
	s.act("build", {"region": 0, "kind": "mine_ore"})
	s.act("build", {"region": 0, "kind": "mine_copper"})
	for d in range(17):
		s.tick()
	s.save_game("user://review_exact_snapshot.save")
	original = FileAccess.get_file_as_bytes("user://review_exact_snapshot.save")
	baseline = var_to_bytes(s.state)
	var t = Sim.new()
	var load_error: String = t.load_game("user://review_exact_snapshot.save")
	out.checks.append(
		{
			"name": "valid_binary_roundtrip",
			"error": load_error,
			"pass": load_error == "" and var_to_bytes(t.state) == baseline
		}
	)
	var flipped: PackedByteArray = original.duplicate()
	flipped[flipped.size() - 1] = flipped[flipped.size() - 1] ^ 0xff
	reject("bad_payload_hash", _write_bytes.bind(flipped))
	var bad_magic: PackedByteArray = original.duplicate()
	bad_magic[0] = 0
	reject("bad_magic", _write_bytes.bind(bad_magic))
	reject("truncated", _write_bytes.bind(original.slice(0, original.size() / 2)))
	reject("binary_primitive", _write_state.bind(42))
	reject("binary_missing_fields", _write_state.bind({"schema": 1}))
	var candidate: Dictionary = s.state.duplicate(true)
	candidate.cash += 1.0
	reject("cash_conservation_rejection", _write_state.bind(candidate))
	candidate = s.state.duplicate(true)
	candidate.world = []
	reject("wrong_world_type", _write_state.bind(candidate))
	candidate = s.state.duplicate(true)
	candidate.world.hash = "not the world this seed generates"
	reject("world_hash_mismatch", _write_state.bind(candidate))
	# A harmless native Resource is encoded only to check object-disabled decoding.
	reject(
		"object_encoded_snapshot",
		func(path: String) -> void:
			SaveFixture.write_raw(path, var_to_bytes_with_objects(Resource.new()))
	)
	var failures: int = 0
	for check in out.checks:
		if not bool(
			check.get("pass", check.get("rejected", false) and check.get("state_unchanged", false))
		):
			failures += 1
	out.failures = failures
	(
		FileAccess
		. open("D:/勇敢新世界/evidence/v17/tests/save_guard_review.json", FileAccess.WRITE)
		. store_string(JSON.stringify(out, "\t"))
	)
	print(JSON.stringify(out))
	quit(1 if failures else 0)
