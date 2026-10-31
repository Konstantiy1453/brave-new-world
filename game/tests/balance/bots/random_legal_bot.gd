extends "res://tests/balance/bots/bot.gd"
## Random affordable legal actions, for crash and audit fuzzing.
## Illegal picks simply return an error from Sim.act(), which is itself under test.


func on_day() -> void:
	if today() == 1:
		act("settle", {"region": rng.randi_range(0, sim.state.world.regions.size() - 1)})
	if sim.state.settlements.is_empty():
		act("settle", {"region": rng.randi_range(0, sim.state.world.regions.size() - 1)})
	for _attempt: int in range(rng.randi_range(0, 2)):
		_random_action()
	_random_event_answer()


func _random_action() -> void:
	var places: Array = sim.state.settlements
	if places.is_empty():
		return
	var place: Dictionary = places[rng.randi_range(0, places.size() - 1)]
	var region: int = int(place.region)
	match rng.randi_range(0, 9):
		0, 1, 2, 3:
			var kinds: Array = sim.config.buildings.keys()
			act("build", {"region": region, "kind": kinds[rng.randi_range(0, kinds.size() - 1)]})
		4:
			var count: int = sim.state.world.regions.size()
			var settle_kind: String = "frontier" if rng.randf() < 0.5 else "residential"
			act("settle", {"region": rng.randi_range(0, count - 1), "kind": settle_kind})
		5:
			if places.size() >= 2:
				act(
					"connect",
					{
						"a": int(places[0].region),
						"b": int(places[1].region),
						"mountain": rng.randf() < 0.5,
					}
				)
		6:
			var techs: Array = sim.config.techs.keys()
			var tech: String = techs[rng.randi_range(0, techs.size() - 1)]
			act("research_allocate", {"tech": tech, "staff": rng.randi_range(0, 10)})
			for hand: Array in sim.state.research.offers.values():
				if not hand.is_empty():
					var card: String = str(hand[rng.randi_range(0, hand.size() - 1)])
					act("research_allocate", {"tech": card, "staff": rng.randi_range(0, 12)})
			if rng.randf() < 0.05:
				act("research_reshuffle", {"category": "industry"})
			if rng.randf() < 0.1 and not place.buildings.is_empty():
				act(
					"demolish",
					{"region": region, "index": rng.randi_range(0, place.buildings.size() - 1)}
				)
		7:
			act("enterprise", {"region": region})
		8:
			if not place.buildings.is_empty():
				act(
					"toggle",
					{"region": region, "index": rng.randi_range(0, place.buildings.size() - 1)}
				)
		9:
			act(
				"policy",
				{"tax": rng.randf_range(0.0, 0.5), "food_reserve": rng.randf_range(3.0, 25.0)}
			)


func _random_event_answer() -> void:
	for node: Dictionary in EventsV2.view(sim).pending:
		var choices: Array = node.choices
		if choices.is_empty():
			continue
		var choice: Dictionary = choices[rng.randi_range(0, choices.size() - 1)]
		act("event_v2", {"instance_id": node.instance_id, "choice": choice.id})
