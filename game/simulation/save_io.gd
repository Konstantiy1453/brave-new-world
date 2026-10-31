extends RefCounted
## Save schema 4 (3 is read too): "CCS3" | u32 header length | header JSON | zstd(var_to_bytes(state)).
## The header can be read without touching the payload. Landing checkpoint and stewardship
## archives live in sibling files named with their hash. Geography is not saved: it is
## regenerated from the seed and checked against the stored world hash.

const WorldGen = preload("res://world/world_gen.gd")
const Keys = preload("res://simulation/keys.gd")
const Stats = preload("res://simulation/stats.gd")
const Production = preload("res://simulation/production.gd")
const Research = preload("res://simulation/research.gd")
const Company = preload("res://simulation/company.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const Career = preload("res://simulation/career.gd")
const SaveMigration = preload("res://simulation/save_migration.gd")
const SCHEMA: int = 4
## 1.7 saves: same format, older rules. Newer systems arrive through ensure_systems on load.
const OLD_SCHEMA: int = 3
const MAGIC: String = "CCS3"
const HEADER_OFFSET: int = 8
const CHECKPOINT_SUFFIX: String = ".ckpt-"
const ARCHIVE_SUFFIX: String = ".arch"
const RUN_STATUSES: Array[String] = ["planning", "active", "success", "failed"]
const MAX_SITES: int = 64


## Serializes on the calling thread. Returns everything a worker needs to finish the write.
static func snapshot(sim: RefCounted, path: String) -> Dictionary:
	return {
		"path": path,
		"raw": var_to_bytes(sim.state),
		"header": _header(sim.state),
		"blobs": _blob_files(sim, path),
	}


static func save(sim: RefCounted, path: String) -> String:
	if sim.state.is_empty():
		return "无可保存的游戏"
	return write_snapshot(snapshot(sim, path))


## Safe on a worker thread: touches only the snapshot and the file system.
static func write_snapshot(snap: Dictionary) -> String:
	var path: String = snap.path
	for file: Dictionary in snap.blobs:
		if not FileAccess.file_exists(file.path):
			var error: String = _write_atomic(file.path, file.bytes)
			if error != "":
				return error
	var raw: PackedByteArray = snap.raw
	var payload: PackedByteArray = raw.compress(FileAccess.COMPRESSION_ZSTD)
	var header: Dictionary = snap.header
	header.raw_size = raw.size()
	header.sha256 = _sha256(payload)
	var header_bytes: PackedByteArray = JSON.stringify(header).to_utf8_buffer()
	var length: PackedByteArray = PackedByteArray()
	length.resize(4)
	length.encode_u32(0, header_bytes.size())
	var data: PackedByteArray = MAGIC.to_ascii_buffer() + length + header_bytes + payload
	var error: String = _write_atomic(path, data)
	if error != "":
		return error
	_remove_stale_siblings(path, snap.blobs)
	return ""


## A readable copy of the state for a developer. Never read back: saves stay binary.
static func export_json(sim: RefCounted, path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "无法写入 " + path
	file.store_string(JSON.stringify(sim.state, "\t"))
	file.close()
	return ""


static func read_header(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < HEADER_OFFSET:
		return {}
	var prefix: PackedByteArray = file.get_buffer(HEADER_OFFSET)
	if prefix.slice(0, 4).get_string_from_ascii() != MAGIC:
		return {}
	var parsed: Variant = JSON.parse_string(
		file.get_buffer(prefix.decode_u32(4)).get_string_from_utf8()
	)
	return parsed if parsed is Dictionary else {}


static func load_file(sim: RefCounted, path: String) -> String:
	if not FileAccess.file_exists(path):
		return "存档不存在"
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() >= HEADER_OFFSET and bytes.slice(0, 4).get_string_from_ascii() == MAGIC:
		return _load_v3(sim, path, bytes)
	return SaveMigration.load_legacy(sim, bytes)


static func _load_v3(sim: RefCounted, path: String, bytes: PackedByteArray) -> String:
	var header_size: int = bytes.decode_u32(4)
	if HEADER_OFFSET + header_size > bytes.size():
		return "存档已损坏"
	var header: Variant = JSON.parse_string(
		bytes.slice(HEADER_OFFSET, HEADER_OFFSET + header_size).get_string_from_utf8()
	)
	if not header is Dictionary or not int(header.get("version", 0)) in [SCHEMA, OLD_SCHEMA]:
		return "存档格式或版本不兼容"
	var payload: PackedByteArray = bytes.slice(HEADER_OFFSET + header_size)
	if _sha256(payload) != str(header.get("sha256", "")):
		return "存档校验失败"
	var raw_size: int = int(header.get("raw_size", 0))
	if raw_size <= 0:
		return "存档校验失败"
	var candidate: Variant = bytes_to_var(payload.decompress(raw_size, FileAccess.COMPRESSION_ZSTD))
	if int(header.version) == OLD_SCHEMA and candidate is Dictionary:
		_upgrade_old_schema(sim, candidate)
	var error: String = validate(sim, candidate)
	if error != "":
		return error
	var loaded_blobs: Dictionary = _read_blobs(path, candidate)
	return adopt(sim, candidate, loaded_blobs)


static func _upgrade_old_schema(sim: RefCounted, candidate: Dictionary) -> void:
	if int(candidate.get("schema", 0)) != OLD_SCHEMA:
		return
	sim.ensure_systems(candidate)
	candidate.schema = SCHEMA


## Binds a validated state to its geography and commits it. Any failure leaves sim unchanged.
static func adopt(sim: RefCounted, candidate: Dictionary, new_blobs: Dictionary) -> String:
	var bound: Dictionary = WorldGen.new().bind(candidate.world)
	if bound.has("error"):
		return str(bound.error)
	var old_state: Dictionary = sim.state
	var old_geo: Dictionary = sim.geo
	var old_blobs: Dictionary = sim.blobs
	sim.state = candidate
	sim.geo = bound
	sim.blobs = new_blobs
	var issues: Array = sim.audit()
	if not issues.is_empty():
		sim.state = old_state
		sim.geo = old_geo
		sim.blobs = old_blobs
		return "存档不满足守恒约束：" + str(issues)
	return ""


static func validate(sim: RefCounted, candidate: Variant) -> String:
	if not candidate is Dictionary:
		return "存档状态无效"
	var error: String = shape(candidate, _state_shape(sim), "state")
	if error != "":
		return error
	if int(candidate.schema) != SCHEMA:
		return "存档版本或阶段无效"
	if int(candidate.contract.stage) < 1 or int(candidate.contract.stage) > sim.Contract.STAGE_COUNT + 1:
		return "合同阶段无效"
	if float(candidate.policy.get("wage", 0.0)) <= 0.0:
		return "工资政策无效"
	if not candidate.status in RUN_STATUSES or not sim.config.openings.has(candidate.advantage):
		return "存档版本或阶段无效"
	error = _validate_world(candidate)
	if error != "":
		return error
	var site_count: int = candidate.world.regions.size()
	error = _validate_roads(candidate, site_count)
	if error != "":
		return error
	if not candidate.enterprise.is_empty():
		error = shape(candidate.enterprise, _enterprise_shape(), "enterprise")
		if error != "":
			return error
	if not candidate.event.is_empty():
		error = shape(
			candidate.event,
			{
				"id": "",
				"day": 0,
				"title": "",
				"text": "",
				"duration": 0,
				"expires": 0,
				"choices": [{"id": "", "label": ""}]
			},
			"event"
		)
		if error != "":
			return error
	for key: String in candidate.effects:
		error = shape(
			candidate.effects[key], "" if key == "drought_choice" else 0, "effects." + key
		)
		if error != "":
			return error
	error = _validate_settlements(sim, candidate, site_count)
	if error != "":
		return error
	for cargo: Dictionary in candidate.shipments:
		if (
			not cargo.resource in Keys.RESOURCES
			or cargo.amount < 0
			or cargo.total_days < 1
			or cargo.remaining < 0
		):
			return "在途货物数据无效"
		if cargo.from < 0 or cargo.from >= site_count or cargo.to < 0 or cargo.to >= site_count:
			return "货物目的地无效"
	error = EventsV2.validate(candidate)
	if error != "":
		return error
	error = Stats.validate(candidate)
	if error != "":
		return error
	if (
		not candidate.get("difficulty") is String
		or not sim.progression.difficulty.has(candidate.difficulty)
	):
		return "难度配置无效"
	for validator: Variant in [Research, Company]:
		error = validator.validate(sim, candidate)
		if error != "":
			return error
	return Career.validate(candidate)


static func shape(value: Variant, pattern: Variant, path: String) -> String:
	if pattern is Dictionary:
		if not value is Dictionary:
			return "存档字段类型无效：" + path
		for key: Variant in pattern:
			if not value.has(key):
				return "存档缺失字段：" + path + "." + str(key)
			var error: String = shape(value[key], pattern[key], path + "." + str(key))
			if error != "":
				return error
	elif pattern is Array:
		if not value is Array:
			return "存档列表类型无效：" + path
		if not pattern.is_empty():
			for item: Variant in value:
				var error: String = shape(item, pattern[0], path + "[]")
				if error != "":
					return error
	elif pattern is int or pattern is float:
		if not (value is int or value is float):
			return "存档数值类型无效：" + path
		if not is_finite(float(value)):
			return "存档数值无效：" + path
	elif typeof(value) != typeof(pattern):
		return "存档字段类型无效：" + path
	return ""


static func _state_shape(sim: RefCounted) -> Dictionary:
	return {
		"schema": 0,
		"world":
		{
			"seed": 0,
			"version": "",
			"size": 0,
			"radius_km": 0,
			"grid_width": 0,
			"grid_height": 0,
			"hash": "",
			"regions":
			[
				{
					"id": 0,
					"name": "",
					"lat": 0,
					"lon": 0,
					"elevation": 0,
					"fertility": 0,
					"water": 0,
					"temperature": 0,
					"rainfall": 0,
					"deposits": {"ore": 0, "copper": 0, "crystal": 0},
					"grade": {"ore": 0, "copper": 0, "crystal": 0},
					"neighbors": [0],
					"terrain": "",
					"land_fraction": 0,
					"river": false,
					"grid_index": 0,
					"development_multiplier": 0,
					"survey": 0,
					"plots": [{"kind": "", "x": 0, "z": 0}]
				}
			],
			"candidates": [0]
		},
		"day": 0,
		"advantage": "",
		"cash": 0,
		"resident_cash": 0,
		"enterprise_cash": 0,
		"initial_money": 0,
		"external_in": 0,
		"external_out": 0,
		"settlements": [],
		"shipments":
		[
			{
				"from": 0,
				"to": 0,
				"resource": "",
				"amount": 0,
				"remaining": 0,
				"total_days": 0,
				"expedition": false,
				"road": 0
			}
		],
		"stats": {"today": {}, "days": [], "goods_days": []},
		"roads": [_road_shape()],
		"surveys": [{"site": 0, "days": 0}],
		"research":
		{
			"current": "",
			"progress": 0,
			"completed": [""],
			"priority": 0,
			"contract": {"staff": 0, "effective": 0, "earned": 0}
		},
		"enterprise": {},
		"events": [""],
		"event": {},
		"effects": {},
		"ledger":
		[
			{
				"day": 0,
				"key": "",
				"detail": "",
				"amount": 0,
				"from": "",
				"to": "",
				"operating": false
			}
		],
		"log": [{"day": 0, "text": ""}],
		"status": "",
		"streak": 0,
		"operating_net": 0,
		"operating_history": [{"day": 0, "net": 0, "income": 0, "expense": 0}],
		"income_daily": 0,
		"expense_daily": 0,
		"debt": 0,
		"arrears": [{"to": "", "amount": 0, "key": ""}],
		"grace_days": 0,
		"policy": {"tax": 0, "food_reserve": 0, "private_allowed": false},
		"exports_total": 0,
		"imports_total": 0,
		"transported_total": 0,
		"company_tax_total": 0,
		"success_day": 0,
		"failure_reason": "",
		"resource_sources": sim._stock(),
		"resource_sinks": sim._stock(),
		"rng_state": 0,
		"births_total": 0,
		"immigrants_total": 0,
		"contract":
		{
			"stage": 0,
			"stage_started": 0,
			"completed": {},
			"missed": [],
			"licences": [],
			"stage_streak": 0,
			"food_window": [],
			"income_window": [],
			"processing_days": 0,
			"today_food": 0,
			"milestones": []
		},
		"market": {"saturation": {}},
		"pollution": {"load": 0, "emitted": 0, "absorbed": 0, "stage": 0},
		"recruits": [{"region": 0, "kind": "", "count": 0, "arrive_day": 0}],
		"recruit_campaigns": []
	}


static func _enterprise_shape() -> Dictionary:
	return {
		"name": "",
		"region": 0,
		"industry": "",
		"status": "",
		"remaining": 0,
		"employees": 0,
		"profit": 0,
		"sales_total": 0,
		"wages_total": 0,
		"tax_total": 0,
		"loss_days": 0,
		"reason": "",
		"rent": 0,
		"profit_days": 0
	}


static func _validate_world(candidate: Dictionary) -> String:
	var world: Dictionary = candidate.world
	if (
		world.grid_width != WorldGen.GW
		or world.grid_height != WorldGen.GH
		or world.regions.is_empty()
		or world.regions.size() > MAX_SITES
	):
		return "世界网格或地区数量不合法"
	if not world.version in WorldGen.SUPPORTED_VERSIONS:
		return "世界生成器版本不同"
	return WorldGen.world_compatibility_error(world)


static func _road_shape() -> Dictionary:
	return {
		"id": 0,
		"reachable": false,
		"distance": 0,
		"days": 0,
		"cost": 0,
		"path": [0],
		"coordinates": [[0]],
		"mountain": false,
		"variant": "",
		"a": 0,
		"b": 0,
		"capacity": 0,
		"blocked_until": 0,
		"sent_today": 0
	}


static func _validate_roads(candidate: Dictionary, site_count: int) -> String:
	for index: int in range(candidate.roads.size()):
		var road: Dictionary = candidate.roads[index]
		if (
			int(road.id) != index
			or road.days < 1
			or road.a < 0
			or road.a >= site_count
			or road.b < 0
			or road.b >= site_count
		):
			return "运输线路无效"
		for pair: Array in road.coordinates:
			if pair.size() != 2:
				return "运输坐标无效"
	return ""


static func _settlement_shape(sim: RefCounted) -> Dictionary:
	return {
		"region": 0,
		"name": "",
		"kind": "",
		"population": 0,
		"children": 0,
		"workers": 0,
		"scientists": 0,
		"stock": sim._stock(),
		"stock_delta": sim._stock(),
		"buildings": [Production.new_building(sim, "", 0)],
		"jobs": 0,
		"housing": 0,
		"base_housing": 0,
		"food_days": 0,
		"shortages": [{"key": "", "detail": ""}],
		"employed": 0,
		"employed_workers": 0,
		"employed_scientists": 0,
		"power_supply": 0,
		"power_demand": 0,
		"water_supply": 0,
		"water_demand": 0,
		"starvation": 0,
		"arrival": 0,
		"cohorts": [{"count": 0, "mature_day": 0}],
		"port_used": 0,
		"port_capacity": 0,
		"food_consumed": 0,
		"arrival_accrual": 0,
		"science_accrual": 0,
		"birth_accrual": 0,
		"attractiveness": 0,
		"attractiveness_parts": {}
	}


static func _validate_settlements(
	sim: RefCounted, candidate: Dictionary, site_count: int
) -> String:
	if candidate.settlements.size() > int(sim.contract_rules.settlement_cap.after_award):
		return "据点数据不合法"
	var settlement_shape: Dictionary = _settlement_shape(sim)
	for s: Variant in candidate.settlements:
		var error: String = shape(s, settlement_shape, "settlement")
		if error != "":
			return error
		if s.has("exportable"):
			error = shape(s.exportable, {"materials": 0, "parts": 0}, "settlement.exportable")
			if error != "":
				return error
		for key: String in [
			"population",
			"children",
			"workers",
			"scientists",
			"employed_workers",
			"employed_scientists"
		]:
			if s[key] < 0:
				return "人口与岗位不能为负数"
		if int(s.region) < 0 or int(s.region) >= site_count:
			return "据点位置无效"
		for b: Dictionary in s.buildings:
			if b.kind != "service" and not sim.config.buildings.has(b.kind):
				return "建筑数据无效"
		if s.has("targets"):
			if not s.targets is Dictionary:
				return "库存目标类型无效"
			for resource: Variant in s.targets:
				if not resource in Keys.RESOURCES:
					return "库存目标资源无效"
				error = shape(s.targets[resource], 0, "stock_target")
				if error != "":
					return error
		for field: String in ["social_days"]:
			error = shape(s.get(field, 0), 0, "settlement." + field)
			if error != "":
				return error
	return ""


static func _header(state: Dictionary) -> Dictionary:
	return {
		"version": SCHEMA,
		"seed": state.world.seed,
		"planet": "%d" % int(state.world.seed),
		"size": state.world.size,
		"day": state.day,
		"cash": state.cash,
		"difficulty": state.get("difficulty", "normal"),
		"opening": state.advantage,
		"status": state.status,
	}


static func _blob_files(sim: RefCounted, path: String) -> Array:
	var files: Array = []
	var checkpoint: PackedByteArray = sim.blobs.checkpoint
	if not checkpoint.is_empty():
		files.append(
			{"path": path + CHECKPOINT_SUFFIX + _sha256(checkpoint).left(16), "bytes": checkpoint}
		)
	for id: Variant in sim.blobs.archives:
		var bytes: PackedByteArray = sim.blobs.archives[id]
		files.append(
			{
				"path": "%s%s%d-%s" % [path, ARCHIVE_SUFFIX, int(id), _sha256(bytes).left(16)],
				"bytes": bytes
			}
		)
	return files


static func _read_blobs(path: String, candidate: Dictionary) -> Dictionary:
	var result: Dictionary = {"checkpoint": PackedByteArray(), "archives": {}}
	var career: Dictionary = candidate.get("career", {})
	var checkpoint_hash: String = str(career.get("checkpoint", ""))
	if checkpoint_hash != "":
		var checkpoint_path: String = path + CHECKPOINT_SUFFIX + checkpoint_hash.left(16)
		if FileAccess.file_exists(checkpoint_path):
			result.checkpoint = FileAccess.get_file_as_bytes(checkpoint_path)
		else:
			career.checkpoint = ""
	for archive: Dictionary in career.get("archives", []):
		var archive_path: String = (
			"%s%s%d-%s" % [path, ARCHIVE_SUFFIX, int(archive.id), str(archive.hash).left(16)]
		)
		if FileAccess.file_exists(archive_path):
			result.archives[archive.id] = FileAccess.get_file_as_bytes(archive_path)
	return result


static func _remove_stale_siblings(path: String, kept: Array) -> void:
	var folder: String = path.get_base_dir()
	var stem: String = path.get_file()
	var keep: Dictionary = {}
	for file: Dictionary in kept:
		keep[str(file.path).get_file()] = true
	var directory: DirAccess = DirAccess.open(folder)
	if directory == null:
		return
	for name: String in directory.get_files():
		var is_sibling: bool = (
			name.begins_with(stem + CHECKPOINT_SUFFIX) or name.begins_with(stem + ARCHIVE_SUFFIX)
		)
		if is_sibling and not keep.has(name):
			directory.remove(name)


static func _write_atomic(path: String, data: PackedByteArray) -> String:
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return "无法写入临时存档：" + str(FileAccess.get_open_error())
	file.store_buffer(data)
	file.flush()
	file.close()
	if _sha256(FileAccess.get_file_as_bytes(temp)) != _sha256(data):
		return "存档回读校验失败，原存档保留"
	var absolute: String = ProjectSettings.globalize_path(path)
	var temporary: String = ProjectSettings.globalize_path(temp)
	# Same-directory rename provides atomic publish; backup retains last known save.
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK:
			return "无法保留原存档备份"
	var result: Error = DirAccess.rename_absolute(temporary, absolute)
	if result != OK:
		return "存档替换失败，原存档和临时文件保留：" + str(result)
	return ""


static func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
