extends RefCounted
## The colony's two names (1.11). The company calls the project by its code, CC-NN (contract.gd
## `code_for`); its people call the colony by the capital's name. Text written in either voice may
## hold {code} and {capital}, and this fills them. Display only: no rule reads either name.

const FALLBACK_CAPITAL: String = "首府"


static func fill(sim: RefCounted, text: String) -> String:
	if not text.contains("{"):
		return text
	return text.replace("{code}", code(sim)).replace("{capital}", capital(sim))


static func code(sim: RefCounted) -> String:
	return str(sim.state.get("contract", {}).get("code", ""))


static func capital(sim: RefCounted) -> String:
	var towns: Array = sim.state.get("settlements", [])
	if towns.is_empty() or str(towns[0].get("name", "")) == "":
		return FALLBACK_CAPITAL
	return str(towns[0].name)
