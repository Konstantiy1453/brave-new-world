extends SceneTree
const Watchdog=preload("res://tests/support/watchdog.gd")
## Managed-account projection only: local economy intentionally not simulated.
const Sim=preload("res://simulation/sim.gd")
const C=preload("res://simulation/career.gd")
func _initialize():
	Watchdog.arm(self)
	call_deferred("run")
func run():
	var result:Dictionary={"scope":"controlled 3600-day managed-model projection from fresh v1.6 governor; active local economy excluded; not a playthrough", "rows":[],"failures":[]}
	for share in [0.4,0.6,0.8]:
		var s=Sim.new()
		var error:String=s.load_game("res://data/v16/acceptance_governor.json")
		if error!="":result.failures.append(error);continue
		error=C.handover(s,42,"capital","normal","user://projection.json")
		if error!="":result.failures.append(error);continue
		var old:Dictionary=s.state.career.managed[0]
		old.player_share=share
		var row:Dictionary={"share":share,"first_year_player":0.0,"first_exhaustion_day":-1,"all_exhaustion_day":-1,"last_month_player":0.0}
		for i in range(3600):
			s.state.day+=1
			C.tick(s)
			if i==359:row.first_year_player=old.player_total
			for stream in old.mining_streams:
				if stream.remaining==0 and row.first_exhaustion_day<0:row.first_exhaustion_day=i+1
			if old.mine_remaining==0 and row.all_exhaustion_day<0:row.all_exhaustion_day=i+1
		row.total_player=old.player_total;row.manager=old.manager_total;row.company=old.company_total;row.reserve=old.reserve;row.debt=old.debt;row.last_month_player=old.last_dividend;row.remaining_mine=old.mine_remaining;row.retained_reports=s.state.career.history.size()
		if C.validate(s.state)!="":result.failures.append(C.validate(s.state))
		result.rows.append(row)
		print("MANAGED_BALANCE ",JSON.stringify(row))
	FileAccess.open("res://../evidence/v17/tests/managed_balance.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if result.failures.is_empty() else 1)
