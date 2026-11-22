extends RefCounted
## The planet's radius on the new-game screens (1.10): a slider from 0.70 to 1.30 Earth radii in
## steps of 0.05, centred on 1.00 (geography.json `planet_radius`). The readout gives the radius in
## Earth radii and in km, and beside it the surface gravity such a planet would have at Earth's mean
## density, named as gravity, so the two are not taken for each other. Distances, travel days,
## route costs and the coverage of orbital readings all follow the radius (world `radius_km`).

const D = preload("res://ui/design.gd")
const Rules = preload("res://simulation/rules.gd")


static func rules() -> Dictionary:
	return Rules.read("geography").planet_radius


## The radius of one of the three old sizes (tutorial data, saves and careers that name a size).
static func of_size(size: int) -> float:
	return [0.6, 1.0, 1.3][clampi(size, 0, 2)]


## Kilometres for a radius in Earth radii.
static func km(radius: float) -> float:
	return radius * float(rules().earth_km)


## The words under the slider.
static func words(radius: float) -> String:
	return "星球半径 %.2f 地球半径（%.0f km）· 表面重力约 %.2f g（按地球平均密度估算，重力不影响玩法）" % [radius, km(radius), radius]


## A slider and its readout in `parent`; `fn` gets the radius in Earth radii on each change.
static func add(
	parent: Control, key: String, radius: float, enabled: bool, fn: Callable = Callable()
) -> HSlider:
	var r: Dictionary = rules()
	var line: HBoxContainer = D.row(parent)
	var readout: Label = D.label(line, words(radius), 15, D.MUTED, false)
	D.named(readout, key + "Words")
	var slider: HSlider = D.slider(
		line,
		key,
		float(r.min),
		float(r.max),
		float(r.step),
		radius,
		func(value: float):
			readout.text = words(value)
			if fn.is_valid():
				fn.call(value)
	)
	slider.editable = enabled
	slider.tooltip_text = "星球大小只改变距离：路程、运输天数、线路造价和轨道观测的覆盖范围都按半径计算"
	return slider
