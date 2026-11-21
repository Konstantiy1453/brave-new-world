extends RefCounted
## "Advance to the next decision" (1.11): the normal simulation runs day by day until the milestone
## the player chose is reached, or earlier, before the player would lose a meaningful choice: a
## communication that waits for an answer, an open one whose deadline is about to apply its default,
## a supply order about to lapse short, a stage deadline near with the stage not on its way, cash for
## less than a fortnight, the company's patience turning, a town going hungry, idle research teams.
## Routine news is gathered into a summary instead of stopping the clock. The interface calls
## `stop_reason` after each tick and `summary` at the end; neither changes the state.

const Outlook = preload("res://simulation/outlook.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const Research = preload("res://simulation/research.gd")

const MILESTONES: Array[String] = ["decision", "stage", "project", "delivery", "days30", "days90"]
const NAMES: Dictionary = {
	"decision": "下一个需要我决定的时刻",
	"stage": "合同阶段完成",
	"project": "下一项工程完工",
	"delivery": "下一批出口或交付",
	"days30": "30 天后",
	"days90": "90 天后",
}
const LIMIT_DAYS: int = 360
const LOW_COVER_DAYS: float = 14.0
const LAPSE_WARNING_DAYS: int = 3
const DEADLINE_WARNING_DAYS: int = 20


## What the run starts from, so stops can tell what changed.
static func begin(sim: RefCounted, milestone: String) -> Dictionary:
	var built: int = 0
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if int(b.remaining) <= 0:
				built += 1
	return {
		"milestone": milestone if milestone in MILESTONES else "decision",
		"day": int(sim.state.day),
		"cash": float(sim.state.cash),
		"exports": float(sim.state.exports_total),
		"population": sim.Contract.population_total(sim),
		"stage": int(sim.state.contract.stage),
		"built": built,
		"techs": Research.researched(sim.state),
		"log_from": sim.state.log.size(),
		"log_day": int(sim.state.day),
		"company": str(sim.state.get("company", {}).get("stage", "normal")),
		"idle_teams": int(Research.assignable(sim).teams),
	}


## Why the run should stop after today's tick, or "" to go on.
static func stop_reason(sim: RefCounted, run: Dictionary) -> String:
	var day: int = int(sim.state.day)
	if sim.state.status == "failed":
		return "经营终止"
	if sim.state.status == "success" and int(run.stage) <= sim.Contract.STAGE_COUNT:
		if int(sim.state.contract.stage) > int(run.stage):
			return "合同履约完成"
	var reached: String = _milestone(sim, run)
	if reached != "":
		return reached
	var choice: String = _choice_at_stake(sim, run)
	if choice != "":
		return choice
	if day - int(run.day) >= LIMIT_DAYS:
		return "已经推进了 %d 天" % LIMIT_DAYS
	return ""


static func _milestone(sim: RefCounted, run: Dictionary) -> String:
	var day: int = int(sim.state.day)
	match str(run.milestone):
		"stage":
			if int(sim.state.contract.stage) > int(run.stage):
				return "合同第 %d 阶段完成" % int(run.stage)
		"project":
			var built: int = 0
			for s: Dictionary in sim.state.settlements:
				for b: Dictionary in s.buildings:
					if int(b.remaining) <= 0:
						built += 1
			if built > int(run.built):
				return "有工程完工"
		"delivery":
			if float(sim.state.exports_total) > float(run.exports) + 0.01:
				return "一批出口或交付到账"
		"days30":
			if day - int(run.day) >= 30:
				return "推进了 30 天"
		"days90":
			if day - int(run.day) >= 90:
				return "推进了 90 天"
	return ""


## A choice the player would lose by letting another day pass.
static func _choice_at_stake(sim: RefCounted, run: Dictionary) -> String:
	var day: int = int(sim.state.day)
	if EventsV2.pause_required(sim):
		return "通讯在等你的答复"
	for inst: Dictionary in sim.state.get("events_v2", {}).get("instances", []):
		if str(inst.status) in ["pending", "deferred"] and int(inst.deadline) - day <= 1:
			return "通讯明天到期，到期按默认处理"
	for order: Dictionary in sim.state.get("supply", {}).get("orders", []):
		if str(order.status) != "open":
			continue
		if (
			int(order.due_day) - day <= LAPSE_WARNING_DAYS
			and float(order.delivered) < float(order.size)
		):
			return (
				"供货合同 %d 天后到期，还差 %.0f t"
				% [int(order.due_day) - day, sim.tonnes(float(order.size) - float(order.delivered))]
			)
	var stage: int = int(sim.state.contract.stage)
	if stage <= sim.Contract.STAGE_COUNT and sim.state.status == "active":
		var deadline: int = sim.Contract.deadline(sim, stage)
		if deadline - day == DEADLINE_WARNING_DAYS:
			var outlook: Dictionary = Outlook.view(sim)
			if int(outlook.eta) < 0 or int(outlook.eta) > deadline:
				return "合同第 %d 阶段 %d 天后到期，照现在的安排完不成" % [stage, DEADLINE_WARNING_DAYS]
	if float(sim.cash_cover()) < LOW_COVER_DAYS and float(run.cash) > 0.0:
		var cover: float = float(sim.cash_cover())
		if float(sim.state.cash) < float(run.cash) * 0.5:
			return "现金只够约 %.0f 天开支" % cover
	var company: String = str(sim.state.get("company", {}).get("stage", "normal"))
	if company != str(run.company) and company in ["warning", "review", "intervention"]:
		return "公司态度变化：" + company
	for s: Dictionary in sim.state.settlements:
		if int(s.get("starvation", 0)) == 1:
			return "%s 开始断粮" % str(s.name)
	var teams: int = int(Research.assignable(sim).teams)
	if teams >= 3 and teams > int(run.idle_teams) and not Research.idle_categories(sim).is_empty():
		return "有 %d 支研究团队空出来，可以挑下一个课题" % teams
	return ""


## What happened over the run, for the summary dialog: figures and the routine news in order.
static func summary(sim: RefCounted, run: Dictionary, reason: String) -> Dictionary:
	var lines: Array = []
	var log: Array = sim.state.log
	for entry: Dictionary in log:
		if int(entry.day) > int(run.log_day):
			lines.append("%d · %s" % [int(entry.day), str(entry.text)])
	var built: int = 0
	for s: Dictionary in sim.state.settlements:
		for b: Dictionary in s.buildings:
			if int(b.remaining) <= 0:
				built += 1
	return {
		"from": int(run.day),
		"to": int(sim.state.day),
		"reason": reason,
		"cash": float(sim.state.cash) - float(run.cash),
		"exports": float(sim.state.exports_total) - float(run.exports),
		"population": sim.Contract.population_total(sim) - int(run.population),
		"built": built - int(run.built),
		"techs": Research.researched(sim.state) - int(run.techs),
		"stage": int(sim.state.contract.stage),
		"lines": lines,
	}
