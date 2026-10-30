extends SceneTree
const Watchdog=preload("res://tests/support/watchdog.gd")
const Sim=preload("res://simulation/sim.gd")
var checks:int=0
var failures:Array=[]
var rows:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func _init()->void:
	Watchdog.arm(self)
	var base=Sim.new()
	base.new_game(260129,"capital",1)
	check(base.act("settle",{"region":0})=="","land first colony")
	check(base.act("settle",{"region":1})=="","deploy second colony")
	check(base.act("connect",{"a":0,"b":1})=="","construct real shared road")
	base.state.events_v2.next_draw=99999
	for i in range(10): base.tick()
	# Drain routine consignments that daily automatic dispatch already created;
	# the boundary cases below add exactly one controlled shipment each.
	for i in range(20):
		if base.state.shipments.is_empty(): break
		base._advance_shipments()
	check(base.state.shipments.is_empty() and base.settlement(1).arrival==0,"expedition actually arrives before boundary fixture")
	var snapshot:Dictionary=base.state.duplicate(true)
	for day in [4,5,6]:
		var s=Sim.new()
		s.state=snapshot.duplicate(true)
		s.state.day=day # Controlled cutoff fixture, not a chronology/save test.
		s.state.route.blocked_until=5
		var src:Dictionary=s.settlement(0)
		var dst:Dictionary=s.settlement(1)
		src.stock.materials-=3.0
		s.state.shipments.append({"from":0,"to":1,"resource":"materials","amount":3.0,"remaining":1,"total_days":2,"expedition":false})
		var before:float=float(dst.stock.materials)
		s._advance_shipments()
		var blocked:bool=day<=5
		check(is_equal_approx(float(dst.stock.materials)-before,0.0 if blocked else 3.0),"arrival cutoff day %d" % day)
		check(s.state.shipments.size()==(1 if blocked else 0),"in-transit cargo retained exactly until inclusive cutoff day %d" % day)
		check(bool(s.contract_progress().connected)==not blocked,"contract connectivity cutoff day %d" % day)
		check(s.audit().is_empty(),"arrival conservation day %d" % day)
		var arrival_delta:float=float(dst.stock.materials)-before
		var dispatch=Sim.new()
		dispatch.state=snapshot.duplicate(true)
		dispatch.state.day=day
		dispatch.state.route.blocked_until=5
		for place in dispatch.state.settlements: dispatch._produce(place,"food",500.0,"F12 controlled surplus fixture")
		dispatch._consume(dispatch.settlement(1),"materials",float(dispatch.settlement(1).stock.materials))
		dispatch._dispatch()
		var sent:float=dispatch._incoming(1,"materials")
		check((sent==0) if blocked else (sent>0),"dispatch cutoff day %d" % day)
		check(dispatch.audit().is_empty(),"dispatch conservation day %d" % day)
		rows.append({"day":day,"blocked_until":5,"arrival_delta":arrival_delta,"outbound_materials":sent,"connected":s.contract_progress().connected})
	var report:Dictionary={"scope":"actual shipment advance, dispatch and contract functions at controlled local days 4/5/6; separate graphical label/material test is world_v16_region","checks":checks,"failures":failures,"rows":rows}
	FileAccess.open("res://../evidence/v17/tests/f12_transport.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("F12_TRANSPORT_RESULT checks=",checks," failures=",failures.size()," rows=",JSON.stringify(rows))
	quit(0 if failures.is_empty() else 1)
