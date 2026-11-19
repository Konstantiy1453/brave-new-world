extends RefCounted
## What events leave behind, shown where it acts (docs/v17/EVENTS_DIAGNOSIS.md, step 3): on a
## town's panel, the effects acting there and the landmarks standing there; on the economy page,
## every effect acting in the colony.

const D = preload("res://ui/design.gd")
const Events = preload("res://simulation/events_v2.gd")


## The effects acting at this place (and those reaching the whole colony), with the days left, and
## the landmarks standing here.
static func marks(g, b, region: int) -> void:
	var effects: Array[Dictionary] = Events.place_effects(g.sim, region)
	if not effects.is_empty():
		D.label(b, "事件影响", 14, D.TEAL)
		for effect: Dictionary in effects:
			D.label(b, line(effect, false), 15, D.TEAL if effect.factor >= 1.0 else D.RED)
	var standing: Array[Dictionary] = Events.landmarks_at(g.sim, region)
	if not standing.is_empty():
		D.label(b, "地标", 14, D.TEAL)
		for mark: Dictionary in standing:
			D.label(b, "◆ %s · %s" % [str(mark.name), str(mark.text)], 15, D.GOLD)


## Every effect acting in the colony, with its place, for the economy page.
static func colony(g, b) -> void:
	var effects: Array[Dictionary] = Events.colony_effects(g.sim)
	if effects.is_empty():
		return
	D.label(b, "仍生效的事件影响", 20, D.TEAL)
	for effect: Dictionary in effects:
		D.label(b, line(effect, true), 16, D.TEAL if effect.factor >= 1.0 else D.RED)


## 「瓦斯限速 · 采矿 ×0.75 · 还剩 63 日」, with the place in front, or 「（全殖民地）」 after.
static func line(effect: Dictionary, with_place: bool) -> String:
	var left: String = "长期" if int(effect.days_left) < 0 else "还剩 %d 日" % int(effect.days_left)
	var text: String = (
		"%s · %s ×%.2f · %s" % [str(effect.name), str(effect.what), float(effect.factor), left]
	)
	if with_place:
		return str(effect.get("place", "")) + " · " + text
	return text + ("（全殖民地）" if bool(effect.colony) else "")
