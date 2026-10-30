extends SceneTree
const Sim=preload("res://simulation/sim.gd")
var failures:Array=[]
var checks:int=0
func check(ok:bool,label:String):
	checks+=1
	if not ok: failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func _initialize():
	call_deferred("run")
func run():
	if not FileAccess.file_exists("res://simulation/career.gd"):
		check(false,"career module and atomic handover available")
		print("CAREER_RESULT checks=1 failures=1")
		quit(1)
		return
	var C=load("res://simulation/career.gd")
	var s=Sim.new()
	var loaded:String=s.load_game("res://data/acceptance_success.json")
	check(loaded=="","old success migration: "+loaded)
	if loaded!="":quit(1);return
	C.ensure(s)
	C.capture_checkpoint(s)
	check(s.state.career.global_day==s.state.day,"migration retains local/global time")
	var original=var_to_bytes(s.state)
	check(C.handover(s,42,"capital","normal","Z:/not-present/career.json")!="","failed publication rejected")
	check(var_to_bytes(s.state)==original,"failed handover retains whole active state")
	var folder="user://v16_career_tests"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path=folder+"/career.json"
	var prior_day:int=s.state.career.global_day
	check(C.handover(s,42,"capital","normal",path)=="","governor handover commits")
	check(s.state.day==0 and s.state.career.global_day==prior_day,"new contract age zero while global time retained")
	check(s.state.career.managed.size()==1 and s.state.career.archives.size()==1,"old full world and summary retained")
	var after=var_to_bytes(s.state)
	check(C.handover(s,17,"capital","normal",path)!="" and after==var_to_bytes(s.state),"duplicate handover cannot mint asset")
	s.act("settle",{"region":0})
	for i in range(32):
		s.tick()
		C.tick(s)
	var old_balance:float=s.state.career.balance
	check(old_balance>0.0,"managed colony pays a positive first dividend")
	var totals:float=s.state.career.managed[0].player_total
	check(is_equal_approx(old_balance,totals),"dividend transfers reconcile with managed debit")
	var idempotent=var_to_bytes(s.state.career)
	C.tick(s)
	check(var_to_bytes(s.state.career)==idempotent,"repeated monthly tick pays once")
	var net:float=s.state.operating_net
	check(C.invest(s,minf(old_balance,10.0))=="","legal career funds can invest")
	check(s.state.operating_net==net,"dividend financing never increases operating profit")
	check(s.audit().is_empty(),"local funds and goods conservation after financing")
	check(s.save_game(path)=="","career save succeeds")
	var t=Sim.new()
	check(t.load_game(path)=="" and var_to_bytes(t.state)==var_to_bytes(s.state),"career exact save roundtrip")
	check(C.restart(s,"normal",path)=="","restart full career checkpoint")
	check(s.state.day==0 and s.state.career.global_day==prior_day and s.state.career.balance==0,"restart removes attempt dividends and time")
	check(s.state.career.managed.size()==1,"restart preserves earlier governorship")
	var c=s.state.career.managed[0]
	c.mine_remaining=0.0
	for stream in c.mining_streams:stream.remaining=0.0
	c.nonmining_income=0.0
	c.cost_total+=c.reserve
	c.reserve=0.0
	var cash:float=s.state.cash
	C.settle_month(s,c,99)
	check(s.state.cash==cash and c.last_dividend==0,"depleted loss cannot draw active-world funds")
	check(C.validate(s.state)=="","career validates after all transitions")
	print("CAREER_RESULT checks=%d failures=%d %s"%[checks,failures.size(),str(failures)])
	quit(0 if failures.is_empty() else 1)
