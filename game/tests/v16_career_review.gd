extends SceneTree
const Watchdog=preload("res://tests/support/watchdog.gd")
const Sim=preload("res://simulation/sim.gd")
const Career=preload("res://simulation/career.gd")
var report:Dictionary={"scope":"controlled financial ledger and mutation regressions; appointment status is an explicit test fixture, not a gameplay qualification run","checks":[],"failures":[]}
func check(ok:bool,label:String,details:Dictionary={}):
	report.checks.append({"label":label,"passed":ok,"details":details})
	if not ok:report.failures.append(label)
func _initialize():
	Watchdog.arm(self)
	call_deferred("run")
func run():
	var sim=Sim.new()
	sim.new_game(260129,"capital")
	# Before appointment, no governor tax has occurred. Observed expenses=20.
	sim.state.day=1
	sim.state.income_daily=0.0;sim.state.expense_daily=0.0;sim.state.operating_net=0.0
	sim._transfer("external","public",100.0,"review recurring revenue",true)
	sim._public_expense(20.0,"review normal operating cost","external")
	sim.state.operating_history=[{"day":1,"income":sim.state.income_daily,"expense":sim.state.expense_daily,"net":sim.state.operating_net}]
	var first:Dictionary=Career.preview(sim)
	check(is_equal_approx(first.daily_cost,20.0),"untaxed preappointment history must not deduct fictional governor tax",{"expected":20.0,"actual":first.daily_cost})
	# Follow actual Sim order: governor levy then Company aid levy, both operating expenses.
	sim.state.status="success";sim.state.day=31;sim.state.success_day=30
	sim.state.income_daily=0.0;sim.state.expense_daily=0.0;sim.state.operating_net=0.0
	sim._transfer("external","public",100.0,"review recurring revenue",true)
	sim._public_expense(20.0,"review normal operating cost","external")
	var base:float=sim.state.operating_net*float(sim.config.contract.company_tax_rate)
	sim._public_expense(base,"公司总督分成","external")
	var surcharge:float=sim.state.operating_net*0.1
	sim._public_expense(surcharge,"援助追加经营分成 · review","external")
	sim.state.company.aid=[{"status":"active","surcharge":0.1,"end_day":61}]
	sim.state.operating_history=[{"day":31,"income":sim.state.income_daily,"expense":sim.state.expense_daily,"net":sim.state.operating_net}]
	var second:Dictionary=Career.preview(sim)
	check(is_equal_approx(second.daily_cost,20.0),"managed operating cost excludes both already-paid governor and aid levies",{"expected":20.0,"actual":second.daily_cost,"governor_levy":base,"aid_levy":surcharge,"observed_expense":sim.state.expense_daily})
	var asset=Sim.new();asset.new_game(42,"capital")
	asset.state.status="success";asset.state.success_day=0
	Career.capture_checkpoint(asset)
	var path:String="res://../evidence/v17/tests/career_review_fixture.json"
	var err:String=Career.handover(asset,43,"capital","normal",path)
	check(err=="","construct valid managed fixture",{"error":err})
	if err=="":
		check(Career.validate(asset.state)=="","unmutated managed fixture validates")
		var missing:Dictionary=asset.state.duplicate(true);missing.career.archives=[]
		check(Career.validate(missing)!="","managed asset cannot lose complete world archive")
		var duplicate:Dictionary=asset.state.duplicate(true);duplicate.career.archives.append(duplicate.career.archives[0].duplicate(true))
		check(Career.validate(duplicate)!="","complete world archive identity must be unique")
		var corrupt:Dictionary=asset.state.duplicate(true);corrupt.career.archives[0].snapshot="not a valid complete snapshot"
		check(Career.validate(corrupt)!="","archive must decode to complete saved world")
	var output:String="res://../evidence/v17/tests/career_review_red.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CAREER_REVIEW ",JSON.stringify(report))
	quit(0 if report.failures.is_empty() else 1)
