extends RefCounted
## CC-GEO-2.3. The planet and its drainage sample this surface at the same coordinates.
## The tiles encode only local elevation residuals from the three terrain-study DEM samples.
const FILE := "res://assets/terrain_v3/relief.bin"
const SIDE := 256
const TILE_AREA := SIDE * SIDE
const TO_SIGMA := 2.7 / 127.0
const SHA256 := "bec3322194fc028902ea2a59b2c352eb1a1d52086490dca205c8e933f6612c68"
static var tiles := PackedByteArray()


## Run on the main thread before publishing a plate context to a render worker.
static func initialize() -> bool:
	if not tiles.is_empty():
		return true
	if not FileAccess.file_exists(FILE):
		return false
	var data := FileAccess.get_file_as_bytes(FILE)
	if data.size() != 4 + 3 * TILE_AREA or data.slice(0, 4).get_string_from_ascii() != "BNR1":
		return false
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(data)
	if digest.finish().hex_encode() != SHA256:
		return false
	tiles = data
	return true


## Different seeds project the source relief from different directions on their own continents.
static func configure(ctx: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ctx.seed) * 1000003 + 0x27D4EB
	var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
	ctx.detail_basis = Basis(axis.normalized() if axis.length_squared() > 0.0001 else Vector3.UP, rng.randf_range(0, TAU))
	ctx.detail_phase = Vector3(rng.randf_range(0, 510), rng.randf_range(0, 510), rng.randf_range(0, 510))


## Signed displacement in three-space removes a longitude seam and keeps both poles continuous.
static func margin_fields(p: Vector3, n: FastNoiseLite) -> Vector4:
	var a := 2.4 * n.get_noise_3dv(p * 2.8 + Vector3(9, -4, 6))
	var b := 2.4 * n.get_noise_3dv(p * 3.6 + Vector3(-11, 7, 2))
	var c := 2.3 * n.get_noise_3dv(p * 9.8 + Vector3(-5, 12, 7))
	var d := 2.3 * n.get_noise_3dv(p * 14.0 + Vector3(8, -3, 11))
	return Vector4(a, b, c, d)


static func displace(p: Vector3, f: Vector4, rough: float, n: FastNoiseLite) -> Vector3:
	var fine := Vector3(
		n.get_noise_3dv(p * 46.0 + Vector3(4, 13, -8)),
		n.get_noise_3dv(p * 68.0 + Vector3(12, -2, 9)),
		n.get_noise_3dv(p * 56.0 + Vector3(2, -6, -11))
	)
	var shift := Vector3(f.x, f.y, f.x * -0.46 + f.y * 0.7) * 0.019
	shift += Vector3(f.z, f.w, f.z * 0.69 + f.w * 0.28) * 0.008
	shift += fine * lerpf(0.0015, 0.010, rough)
	return (p + shift - p * p.dot(shift)).normalized()


## Bilinear interpolation in a mirror-tiled source. Adjacent tiles share their edge value.
static func tile_value(tile: int, x: float, y: float) -> float:
	var u := 255.0 - absf(fposmod(x, 510.0) - 255.0)
	var v := 255.0 - absf(fposmod(y, 510.0) - 255.0)
	var i := int(u)
	var j := int(v)
	var row := 4 + tile * TILE_AREA + j * SIDE
	var bottom := row + SIDE if j < SIDE - 1 else row
	var next := mini(i + 1, SIDE - 1)
	var north := lerpf(tiles[row + i], tiles[row + next], u - i)
	var south := lerpf(tiles[bottom + i], tiles[bottom + next], u - i)
	return (lerpf(north, south, v - j) - 128.0) * TO_SIGMA


static func triplanar(tile: int, pos: Vector3, w: Vector3) -> float:
	return (
		tile_value(tile, pos.x, pos.y) * w.z
		+ tile_value(tile, pos.y, pos.z) * w.x
		+ tile_value(tile, pos.z, pos.x) * w.y
	)


## Matches the study's ridge/fold/basin blend and broad highland compression. Strength fades
## into the shore so narrow peninsulas, shallow water and buildable land agree at every scale.
static func elevations(
	p: Vector3, ctx: Dictionary, f: Vector4, metres: float, ridge: float
) -> Vector2:
	if metres <= 0.0:
		return Vector2(metres, 0)
	var strength := smoothstep(0.0, 590.0, metres)
	var coord: Vector3 = ctx.detail_basis * p
	var weights := coord * coord
	weights *= weights
	weights /= maxf(0.00001, weights.x + weights.y + weights.z)
	var phase: Vector3 = ctx.detail_phase
	var warp := Vector3(f.z * 5 + f.w * 2, f.w * 4 - f.x * 2, f.x * 3 + f.y * 2)
	var basin := triplanar(2, coord * 883.33 + phase + warp, weights)
	var belt := clampf(0.72 * smoothstep(0.02, 0.56, ridge) + 0.42 * smoothstep(600, 1600, metres), 0.0, 1.0)
	belt *= 0.65 + 0.35 * smoothstep(-1.1, 0.7, f.z)
	var divide := triplanar(0, coord * 437.5 + phase + warp, weights)
	var fold := triplanar(1, coord * 816.67 + phase - warp, weights)
	divide = lerpf(divide, fold, smoothstep(-0.68, 0.73, f.x * 0.68 + f.w * 0.29))
	var relief := divide * (95.0 + 780.0 * belt) + basin * (50.0 + 125.0 * (1.0 - belt))
	var backbone := metres - 0.42 * maxf(0.0, metres - 780.0)
	var height := backbone + strength * (relief + 240.0 * belt * (0.5 + 0.5 * f.z))
	return Vector2(maxf(metres * 0.06, height), divide * belt)
