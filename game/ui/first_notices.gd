extends RefCounted
## The words of the "◆ 第一次" cards (1.10): each first shipment the simulation recorded
## (consignments.gd), with its town, building, good, tonnes and value. Returns {card, title, line},
## or an empty dictionary for a kind with no card.


static func card(sim: RefCounted, kind: String, entry: Dictionary) -> Dictionary:
	var good: String = str(sim.config.resources.get(str(entry.resource), str(entry.resource)))
	var building: String = str(
		sim.config.buildings.get(str(entry.building_kind), {}).get("name", entry.building_kind)
	)
	var tonnes: float = sim.tonnes(float(entry.amount))
	match kind:
		"ore":
			var sold: String = ""
			if int(entry.get("sold_at", entry.region)) != int(entry.region):
				sold = "，经公路运到「%s」" % str(entry.sold_town)
			return {
				"card": "FirstOre",
				"title": "第一车矿石运出营地",
				"line":
				(
					"「%s」%s的矿车把第一车 %.0f 吨%s运到货运站%s，卖出 ¥ %.0f。点这里去「%s」看看。"
					% [entry.town, building, tonnes, good, sold, float(entry.value), entry.town]
				),
			}
		"ship":
			return {
				"card": "FirstShip",
				"title": "第一艘货船靠上新码头",
				"line":
				(
					"「%s」的%s：货船%s %.0f 吨%s，货值 ¥ %.0f。点这里去码头看看，夜里码头会亮起冷色的工作灯。"
					% [
						entry.town,
						building,
						"卸下" if str(entry.direction) == "import" else "装走",
						tonnes,
						good,
						float(entry.value),
					]
				),
			}
		"offshore":
			return {
				"card": "FirstOffshore",
				"title": "第一船海底矿石靠岸",
				"line":
				(
					"「%s」的%s：驳船运回 %.0f 吨%s，价值 ¥ %.0f，可以出口，也可以送去加工。点这里去码头看看。"
					% [entry.town, building, tonnes, good, float(entry.value)]
				),
			}
	return {}
