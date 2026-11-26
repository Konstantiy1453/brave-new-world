extends SceneTree
## Recommended sites must occupy land in both the continuous geography and the displayed atlas.
## These seeds previously recommended one sub-pixel shoal each. Free placement samples the
## continuous field independently. Run with --headless --script res://tests/terrain23_sites.gd.
const Gen = preload("res://world/world_gen.gd")
const Plates = preload("res://world/geo2/plates.gd")
const Hydro = preload("res://world/hydrology.gd")
const ShaderData = preload("res://world/shaders.gd")
const ATLAS := Vector2i(1536, 768)


func _initialize() -> void:
	var failures: Array[String] = []
	var count := 0
	for seed_input: Variant in [260129, "harbor-mist-217"]:
		var world := Gen.new().build(seed_input, 1)
		if world.has("error"):
			failures.append(str(world.error))
			continue
		var noise := FastNoiseLite.new()
		noise.seed = int(world.seed)
		noise.frequency = 1.8
		noise.fractal_octaves = 4
		for region: Dictionary in world.regions:
			var lat: float = region.lat
			var lon: float = region.lon
			var exact := Plates.sample_with_context(lat, lon, noise, world.plates)
			var label := "%s / site %d" % [seed_input, int(region.id)]
			if not exact.land or Hydro.sample_water(world, lat, lon).lake_fraction >= 0.30:
				failures.append(label + " lies on water")
			var uv := Vector2((lon + 180.0) / 360.0, (90.0 - lat) / 180.0)
			var at := uv * Vector2(ATLAS) - Vector2(0.5, 0.5)
			# Use the game's actual Image RGBA8 packing, which determines the coastline.
			var pixels := Image.create(2, 2, false, Image.FORMAT_RGBA8)
			for y in range(2):
				for x in range(2):
					var centre := (at.floor() + Vector2(x + 0.5, y + 0.5)) / Vector2(ATLAS)
					var sample := Plates.sample_with_context(
						90.0 - centre.y * 180.0, centre.x * 360.0 - 180.0, noise, world.plates
					)
					pixels.set_pixel(x, y, ShaderData.encode(sample.height, sample.temperature, sample.rainfall, sample.ridge))
			var frac := at - at.floor()
			var north := lerpf(pixels.get_pixel(0, 0).a, pixels.get_pixel(1, 0).a, frac.x)
			var south := lerpf(pixels.get_pixel(0, 1).a, pixels.get_pixel(1, 1).a, frac.x)
			if lerpf(north, south, frac.y) <= 0.5:
				failures.append(label + " falls on the ocean side of the displayed coastline")
			count += 1
	print("TERRAIN23_SITES ", JSON.stringify({"recommended_sites": count, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
