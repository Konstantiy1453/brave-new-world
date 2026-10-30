extends RefCounted
## Writes deliberately malformed schema 3 saves with a correct outer checksum, so a test reaches
## the validator instead of stopping at the checksum.

const SaveIo = preload("res://simulation/save_io.gd")


static func write_state(path: String, state: Variant) -> void:
	write_raw(path, var_to_bytes(state))


static func write_raw(path: String, raw: PackedByteArray) -> void:
	SaveIo.write_snapshot(
		{"path": path, "raw": raw, "header": {"version": SaveIo.SCHEMA}, "blobs": []}
	)
