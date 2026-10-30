extends SceneTree
const Sim=preload("res://simulation/sim.gd")
func _initialize()->void:
	var s=Sim.new()
	s.new_game(20261029,"capital",1)
	s.act("settle",{"region":0})
	var p:Dictionary=s.settlement(0)
	var initial_children:int=p.children
	var initial_workers:int=p.workers
	var initial_population:int=p.population
	var out:Dictionary={"scope":"controlled population clock boundary checks; not a continuous long-duration economy or manual run","checks":[]}
	s.state.day=359
	s._population()
	out.checks.append({"name":"no_birth_before_360","pass":p.children==initial_children})
	s.state.day=360
	s._population()
	out.checks.append({"name":"one_birth_at_360","pass":p.children==initial_children+1 and p.population==initial_population+1 and s.state.births_total==1})
	s.state.day=2879
	s._population()
	out.checks.append({"name":"initial_children_not_mature_early","pass":p.workers==initial_workers})
	# Disable this day's separate newborn trigger to isolate the maturation boundary.
	s.config.economy.birth_period=1000000
	s.state.day=2880
	s._population()
	out.checks.append({"name":"initial_child_cohort_matures_at_2880","pass":p.workers==initial_workers+initial_children and p.children==1 and p.population==initial_population+1})
	s.state.day=6119
	s._population()
	out.checks.append({"name":"newborn_not_mature_early","pass":p.children==1})
	s.state.day=6120
	s._population()
	out.checks.append({"name":"newborn_matures_after_5760_days","pass":p.children==0 and p.workers==initial_workers+initial_children+1 and p.population==initial_population+1})
	out.checks.append({"name":"population_and_accounts_audit","pass":s.audit().is_empty(),"issues":s.audit()})
	var failures:int=0
	for check in out.checks:
		if not check.pass: failures+=1
	out.failures=failures
	FileAccess.open("D:/勇敢新世界/docs/evidence/population_boundary_review.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print(JSON.stringify(out))
	quit(1 if failures else 0)
