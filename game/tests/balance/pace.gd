extends RefCounted
## The pace measure (1.11 J): the longest stretch of days in which a bot took no meaningful
## decision. Meaningful (DECISIONS.md): an accepted action that commits money, people or ground, or
## changes the colony's course: building, upgrading, demolishing, founding, roads and links, an
## enterprise, starting a research topic (the first allocation to it; re-staffing is not),
## reshuffling the offers, research contracts and commissions, crews, recruitment, the wage, an
## event choice other than deferring, the annual report, the Annex VII answer, weather preparation
## and claims, and the endings' buyout, autonomy and transfer. Stock targets are not.

const MEANINGFUL: Array[String] = [
	"build",
	"upgrade",
	"demolish",
	"settle",
	"connect",
	"upgrade_road",
	"enterprise",
	"research_allocate",
	"research_reshuffle",
	"research_contract",
	"research_commission",
	"recruit",
	"crew_train",
	"crew_send",
	"policy",
	"event_v2",
	"annual_report",
	"annex_answer",
	"weather_prepare",
	"force_majeure",
	"buyout",
	"declare_autonomy",
	"career_transfer",
	"company",
]


## The days of the meaningful decisions in a bot's action log, in order.
static func decision_days(actions: Array) -> Array:
	var days: Array = []
	var started: Dictionary = {}
	for row: Dictionary in actions:
		var action: String = str(row.action)
		if str(row.get("error", "")) != "" or not action in MEANINGFUL:
			continue
		var args: Dictionary = row.get("args", {})
		if action == "event_v2" and str(args.get("choice", "")) == "defer":
			continue
		if action == "research_allocate":
			var tech: String = str(args.get("tech", ""))
			if started.has(tech):
				continue
			started[tech] = true
		days.append(int(row.day))
	return days


## The longest stretch between the landing, the decisions and the last day of the run.
static func longest_quiet(actions: Array, final_day: int) -> int:
	var longest: int = 0
	var last: int = 0
	for day: Variant in decision_days(actions):
		longest = maxi(longest, int(day) - last)
		last = int(day)
	return maxi(longest, final_day - last)
