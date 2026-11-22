extends RefCounted
## Visual time for the map: the planet's spin, the sun and its seasons, the wind that moves the
## clouds and the storms that cross them. Cosmetic only: nothing here reaches the simulation, so
## saves and replays stay byte-identical at any speed, and every number has its own RNG.

## One turn of the planet takes this many seconds at 1×.
const SPIN_PERIOD_S: float = 240.0
## How fast visual time runs while the game is paused, and at each game speed.
const IDLE_RATE: float = 0.3
const SPEED_RATES: Dictionary = {1: 1.0, 2: 1.4, 3: 1.7, 4: 2.0, 5: 2.3, 6: 2.6}
## After the player touches the globe, the spin eases out and waits this long before resuming.
const HOLD_SECONDS: float = 9.0
const EASE_PER_SECOND: float = 1.6
## Sun to the east of the opening view, so the first site starts its morning.
const SUN_LEAD_RADIANS: float = 0.8
const AXIAL_TILT_DEGREES: float = 18.0
const YEAR_DAYS: float = 360.0
const STORM_COUNT: int = 3
const STORM_LIFE_S: Vector2 = Vector2(110.0, 240.0)
const STORM_RADIUS: Vector2 = Vector2(0.11, 0.19)

var spin: float = 0.0
var spin_enabled: bool = true
var weather_enabled: bool = true
## Captures and window tests hold the picture still: nothing advances.
var frozen: bool = false
## Seconds of weather: drives wind and storm motion.
var weather_time: float = 0.0
var rate: float = IDLE_RATE
## Whether the game clock is running: town traffic stops while the game is paused.
var running: bool = false
var hold: float = 0.0
var spin_factor: float = 1.0
var day: int = 0
var day_fraction: float = 0.0
var sun_yaw: float = SUN_LEAD_RADIANS
var storms: Array = []
var _rng := RandomNumberGenerator.new()


## Starts the clock for a world. The sun goes where the opening view will see it rising.
func reset(seed_value: int, view_yaw: float) -> void:
	spin = 0.0
	weather_time = 0.0
	hold = 0.0
	spin_factor = 1.0
	sun_yaw = view_yaw + SUN_LEAD_RADIANS
	_rng.seed = seed_value * 7919 + 17
	storms.clear()
	for index: int in range(STORM_COUNT):
		var storm: Dictionary = _new_storm()
		# Staggered so they do not all grow and fade together.
		storm.age = float(storm.life) * float(index) / float(STORM_COUNT)
		storms.append(storm)


## What the game clock is doing this frame.
func set_clock(clock_running: bool, speed: int, game_day: int, fraction: float) -> void:
	running = clock_running
	rate = float(SPEED_RATES.get(speed, 1.0 + 0.3 * float(speed))) if running else IDLE_RATE
	day = game_day
	day_fraction = clampf(fraction, 0.0, 1.0)


## The player is looking at something on the globe: let the spin come to rest for a while.
func hold_spin(seconds: float = HOLD_SECONDS) -> void:
	hold = maxf(hold, seconds)


func advance(delta: float) -> void:
	if frozen:
		return
	var step: float = maxf(delta, 0.0) * rate
	hold = maxf(0.0, hold - maxf(delta, 0.0))
	var wanted: float = 1.0 if spin_enabled and hold <= 0.0 else 0.0
	spin_factor = move_toward(spin_factor, wanted, maxf(delta, 0.0) * EASE_PER_SECOND)
	spin = wrapf(spin + step * TAU / SPIN_PERIOD_S * spin_factor, 0.0, TAU)
	if weather_enabled:
		weather_time += step
		for index: int in range(storms.size()):
			var storm: Dictionary = storms[index]
			storm.age = float(storm.age) + step
			storm.lat = clampf(float(storm.lat) + float(storm.drift_lat) * step, -62.0, 62.0)
			storm.lon = wrapf(float(storm.lon) + float(storm.drift_lon) * step, -180.0, 180.0)
			if float(storm.age) >= float(storm.life):
				storms[index] = _new_storm()


## Declination of the sun: the year turns the terminator and moves the ice edges.
func declination() -> float:
	var year: float = (float(day) + day_fraction) / YEAR_DAYS
	return deg_to_rad(AXIAL_TILT_DEGREES) * sin(TAU * year)


## -1 deep northern winter, +1 deep northern summer.
func season() -> float:
	return sin(TAU * (float(day) + day_fraction) / YEAR_DAYS)


## The sun in world space. It does not turn with the planet.
func sun_world() -> Vector3:
	var tilt: float = declination()
	return Vector3(cos(tilt) * sin(sun_yaw), sin(tilt), cos(tilt) * cos(sun_yaw)).normalized()


## The sun in the planet's own frame, which is what every map shader works in.
func sun_local() -> Vector3:
	return sun_world().rotated(Vector3.UP, -spin)


## Storms as shader uniforms: centre on the unit sphere (planet frame) and signed strength.
## Positive turns anticlockwise seen from above: northern cyclones; southern ones are negative.
func storm_vectors() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for storm: Dictionary in storms:
		var life: float = maxf(float(storm.life), 1.0)
		var grow: float = sin(PI * clampf(float(storm.age) / life, 0.0, 1.0))
		var lat: float = deg_to_rad(float(storm.lat))
		var lon: float = deg_to_rad(float(storm.lon))
		var centre := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
		var turn: float = 1.0 if float(storm.lat) >= 0.0 else -1.0
		out.append(Vector4(centre.x, centre.y, centre.z, turn * grow * float(storm.power)))
	while out.size() < STORM_COUNT:
		out.append(Vector4(0.0, 1.0, 0.0, 0.0))
	return out


func storm_radii() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for storm: Dictionary in storms:
		out.append(float(storm.radius))
	while out.size() < STORM_COUNT:
		out.append(0.2)
	return out


## Tropical storms form in the trade-wind belts, drift west and curve towards the pole.
func _new_storm() -> Dictionary:
	var north: bool = _rng.randf() < 0.5
	var lat: float = _rng.randf_range(9.0, 26.0) * (1.0 if north else -1.0)
	return {
		"lat": lat,
		"lon": _rng.randf_range(-180.0, 180.0),
		"drift_lat": _rng.randf_range(0.015, 0.05) * signf(lat),
		"drift_lon": -_rng.randf_range(0.04, 0.11),
		"age": 0.0,
		"life": _rng.randf_range(STORM_LIFE_S.x, STORM_LIFE_S.y),
		"radius": _rng.randf_range(STORM_RADIUS.x, STORM_RADIUS.y),
		"power": _rng.randf_range(0.7, 1.0),
	}
