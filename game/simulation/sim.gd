extends RefCounted
## Deterministic one-day economy. Rendering and wall clock never enter state.
const WorldGen = preload("res://world/world_gen.gd")
const Research = preload("res://simulation/research.gd")
const Company = preload("res://simulation/company.gd")
const EventsV2 = preload("res://simulation/events_v2.gd")
const Career = preload("res://simulation/career.gd")
const SAVE_VERSION:int=2
const KEYS:Array=["ore","copper","crystal","food","materials","parts"]
var state:Dictionary={}
var config:Dictionary={}
var progression:Dictionary={}
func _init()->void:
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	progression=JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
func new_game(seed_value:Variant,advantage:String,size:int=1,difficulty:String="normal")->void:
	if not progression.difficulty.has(difficulty): difficulty="normal"
	if not config.openings.has(advantage): advantage="capital"
	state={"schema":SAVE_VERSION,"world":WorldGen.new().generate(seed_value,size),"day":0,"advantage":advantage,"cash":0.0,"resident_cash":0.0,"enterprise_cash":0.0,"initial_money":0.0,"external_in":0.0,"external_out":0.0,"settlements":[],"route":{},"shipments":[],"research":{"current":"","progress":0.0,"completed":[],"priority":1.0},"events":[],"event":{},"effects":{},"log":[],"ledger":[],"status":"planning","streak":0,"operating_net":0.0,"operating_history":[],"income_daily":0.0,"expense_daily":0.0,"debt":0.0,"arrears":[],"grace_days":0,"enterprise":{},"policy":{"tax":0.18,"food_reserve":12.0,"private_allowed":true},"exports_total":0.0,"imports_total":0.0,"transported_total":0.0,"company_tax_total":0.0,"success_day":-1,"failure_reason":"","resource_sources":_stock(),"resource_sinks":_stock(),"rng_state":0,"births_total":0,"immigrants_total":0}
	state.difficulty=difficulty
	state.rng_state=int(state.world.seed)
	Research.ensure(self)
	Company.ensure(self)
	_transfer("external","public",float(config.openings[advantage].cash)*float(progression.difficulty[difficulty].capital),"公司初始资本",false)
	_transfer("external","residents",2200.0,"开拓居民自带积蓄",false)
	_log("合同已签署。请勘察后选择登陆点；铁岬盆地适合双矿开局。")
	Career.ensure(self)
	EventsV2.ensure(self)
func _stock()->Dictionary:
	return {"ore":0.0,"copper":0.0,"crystal":0.0,"food":0.0,"materials":0.0,"parts":0.0}
func settlement(region:int)->Dictionary:
	for s in state.get("settlements",[]):
		if int(s.region)==region: return s
	return {}
func act(action:String,args:Dictionary={})->String:
	if state.is_empty(): return "请先开始新游戏"
	if state.status=="failed": return "本局已经结束，请读取存档或开始新局"
	match action:
		"settle": return _settle(int(args.get("region",-1)))
		"build": return _build(int(args.get("region",-1)),str(args.get("kind","")))
		"connect": return _connect(int(args.get("a",-1)),int(args.get("b",-1)),bool(args.get("mountain",false)))
		"enterprise": return _enterprise(int(args.get("region",-1)))
		"enterprise_recover": return _enterprise_recover(int(args.get("region",-1)))
		"research_allocate": return Research.allocate(self,str(args.get("tech","")),int(args.get("staff",0)))
		"company": return Company.act(self,args)
		"batch_toggle": return _batch_toggle(args)
		"stock_target": return _stock_target(args)
		"policy":
			state.policy.tax=clampf(float(args.get("tax",state.policy.tax)),0.0,0.5)
			state.policy.food_reserve=clampf(float(args.get("food_reserve",state.policy.food_reserve)),3.0,25.0)
			state.policy.private_allowed=bool(args.get("private_allowed",state.policy.private_allowed))
			_log("贸易保留 %.0f 天食品，企业利润税 %.0f%%。" % [state.policy.food_reserve,state.policy.tax*100.0])
			return ""
		"event_v2": return EventsV2.act(self,args)
		"event": return _resolve_event(str(args.get("choice","")))
		"toggle":
			var s:Dictionary=settlement(int(args.get("region",-1)))
			var idx:int=int(args.get("index",-1))
			if s.is_empty() or idx<0 or idx>=s.buildings.size(): return "设施不存在"
			s.buildings[idx].enabled=not bool(s.buildings[idx].get("enabled",true))
			if not s.buildings[idx].enabled:
				s.buildings[idx].active=false
				s.buildings[idx].status="手动停工"
			_refresh(s)
			Research.rebalance(self,false)
			return ""
	return "未知操作"
func _settle(region:int)->String:
	if region<0 or region>=state.world.regions.size(): return "请选择候选地区"
	if not settlement(region).is_empty(): return "此地区已经建立据点"
	if state.settlements.size()>=2: return "本合同最多开发两个地区"
	var first:bool=state.settlements.is_empty()
	var reg:Dictionary=state.world.regions[region]
	if first:
		var expandable:bool=false
		for other in state.world.candidates:
			if int(other)==region: continue
			if WorldGen.new().route(state.world,region,int(other),true).reachable:
				expandable=true
				break
		if not expandable: return "该登陆点没有可达的第二陆地据点，无法履行双据点合同"
	if not first:
		var src:Dictionary=state.settlements[0]
		var road:Dictionary=WorldGen.new().route(state.world,int(src.region),region,false)
		if not road.reachable: road=WorldGen.new().route(state.world,int(src.region),region,true)
		if not road.reachable: return "此地区没有可达陆路；当前不具备海运能力"
		if state.cash<650: return "建立前哨需要 650 资金"
		if src.workers<22: return "首府技术工人不足 22 人"
		if src.stock.materials<35 or src.stock.parts<6 or src.stock.food<100: return "首府需备齐 35 建材、6 部件、100 食品作为前哨远征物资"
		_transfer("public","external",650.0,"前哨部署投资",false)
		_consume(src,"materials",35.0)
		_consume(src,"parts",6.0)
		# Expedition population migrates; food stays physically in its convoy until arrival.
		src.workers-=18
		src.population-=18
		_reconcile_jobs(src)
	var op:Dictionary=config.openings[state.advantage]
	var workers:int=int(op.workers) if first else 18
	var scientists:int=int(op.scientists) if first else 0
	var children:int=int(op.children) if first else 0
	var s:Dictionary={"region":region,"name":reg.name,"population":workers+scientists+children,"children":children,"workers":workers,"scientists":scientists,"stock":_stock(),"stock_delta":_stock(),"buildings":[],"jobs":0,"housing":80 if first else 40,"base_housing":80 if first else 40,"food_days":0.0,"shortages":[],"employed":0,"employed_workers":0,"employed_scientists":0,"power_supply":0.0,"power_demand":0.0,"water_supply":0.0,"water_demand":0.0,"starvation":0,"arrival":0,"cohorts":[],"port_used":0.0,"port_capacity":0.0,"food_consumed":0.0}
	if first:
		for res in ["materials","parts","food"]: _produce(s,res,float(op[res]),"初始公司物资")
		for kind in ["power","water","port"]: s.buildings.append(_building(kind,0))
		# Initial child cohorts age after 8 simulated years, adults are aggregate groups.
		s.cohorts.append({"count":children,"mature_day":2880})
	else:
		var src:Dictionary=state.settlements[0]
		var road:Dictionary=WorldGen.new().route(state.world,int(src.region),region,true)
		s.arrival=int(road.days)
		for kind in ["power","water"]: s.buildings.append(_building(kind,int(road.days)))
		src.stock.food-=100.0
		state.shipments.append({"from":src.region,"to":region,"resource":"food","amount":100.0,"remaining":int(road.days),"total_days":int(road.days),"expedition":true})
		# Construction stores travel in the one-time expedition, funded above.
		# The prefab frame consumed 15 materials + 2 parts; remaining kit travels.
		state.resource_sinks.materials-=20.0
		state.resource_sinks.parts-=4.0
		for pair in [["materials",20.0],["parts",4.0]]:
			state.shipments.append({"from":src.region,"to":region,"resource":pair[0],"amount":pair[1],"remaining":int(road.days),"total_days":int(road.days),"expedition":true})
	state.settlements.append(s)
	state.status="active" if state.status=="planning" else state.status
	_refresh(s)
	_log(("登陆完成：" if first else "远征队出发：")+reg.name+("。建设轻型矿场即可开始出口。" if first else "；物资和人员抵达后开始运行。"))
	return ""
func _building(kind:String,remaining:int)->Dictionary:
	return {"kind":kind,"remaining":remaining,"active":remaining==0,"enabled":true,"status":"建设中" if remaining>0 else "待结算","reason":"","employed":0,"specialists":0,"efficiency":0.0,"owner":"public"}
func build_preview(region:int,kind:String)->Dictionary:
	if not config.buildings.has(kind) or region<0 or region>=state.world.regions.size(): return {}
	var d:Dictionary=config.buildings[kind].duplicate(true)
	d.cost*=float(state.world.regions[region].get("development_multiplier",1.0))
	return d
func _build(region:int,kind:String)->String:
	var s:Dictionary=settlement(region)
	if s.is_empty(): return "请先建立据点"
	if s.arrival>0: return "远征队尚在途中，请等待抵达"
	if not config.buildings.has(kind): return "无此设施"
	if s.buildings.size()>=24: return "本地区已达到 24 处设施的土地开发上限"
	var d:Dictionary=build_preview(region,kind)
	var reg:Dictionary=state.world.regions[region]
	if kind.begins_with("mine_") and float(reg.deposits.get(d.output,0))<=0: return "本地区没有剩余的已探明矿床"
	if kind=="foodworks" and not _has("adaptation"): return "需要作物适配与食品加工技术"
	if kind=="farm" and (reg.fertility<0.20 or reg.temperature< -5) and not _has("adaptation"): return "土地或气温不适合当前温室技术"
	if state.cash<float(d.cost): return "公共资金不足：需要 %.0f" % d.cost
	if s.stock.materials<float(d.materials) or s.stock.parts<float(d.parts): return "本地仓库不足：需要 %.0f 建材 / %.0f 部件；远方库存需运输" % [d.materials,d.parts]
	_transfer("public","external",float(d.cost),"建设投资 · "+d.name,false)
	_consume(s,"materials",float(d.materials))
	_consume(s,"parts",float(d.parts))
	s.buildings.append(_building(kind,int(d.days)))
	_log(s.name+"开始建设"+d.name+"，工期 %d 天。" % int(d.days))
	return ""
func _connect(a:int,b:int,mountain:bool)->String:
	if a==b or settlement(a).is_empty() or settlement(b).is_empty(): return "请选择两个已建立的不同据点"
	if not state.route.is_empty(): return "两地已有运输连接"
	var r:Dictionary=WorldGen.new().route(state.world,a,b,mountain)
	if not r.reachable: return r.get("reason","陆路不可达")
	var s:Dictionary=settlement(a)
	if state.cash<r.cost: return "路线投资需要 %.0f 资金" % r.cost
	if s.stock.materials<12: return "起点仓库需要 12 建材修建装卸设施"
	_transfer("public","external",float(r.cost),"运输网络投资",false)
	_consume(s,"materials",12.0)
	r.blocked_until=0
	r.sent_today=0.0
	state.route=r
	_log("陆路已连接，单程 %d 天，每天双向合计 %.0f 吨。" % [r.days,r.capacity])
	return ""
func research_view()->Dictionary:
	return Research.view(self)
func research_reserve(id:String,staff:int)->String:
	return Research.reserve_investigation(self,id,staff)
func research_release(id:String)->void:
	Research.release_investigation(self,id)
func company_view()->Dictionary:
	return Company.view(self)
func _enterprise(region:int)->String:
	var s:Dictionary=settlement(region)
	if s.is_empty() or s.arrival>0: return "需要已经运转的据点"
	if s.buildings.size()>=24: return "本地区已经达到 24 处设施的土地开发上限"
	if not state.enterprise.is_empty(): return "本 Demo 已有一家民营企业"
	if not state.policy.private_allowed: return "当前政策未允许商业服务业"
	if state.day<15 or state.exports_total<100: return "投资人要求运营至少 15 天且累计出口达到 100"
	if s.stock.materials<8 or s.stock.parts<2: return "企业要向本地仓库购买 8 建材和 2 部件"
	_transfer("external","enterprise",900.0,"民营投资人实缴资本",false)
	var inputs:float=8.0*config.prices.materials+2.0*config.prices.parts
	_transfer("enterprise","public",inputs,"企业购买建设材料",false)
	_consume(s,"materials",8.0)
	_consume(s,"parts",2.0)
	_transfer("enterprise","external",260.0,"企业店面设备投资",false)
	state.enterprise={"name":"远岸生活服务社","region":region,"industry":"service","status":"装修中","remaining":4,"employees":0,"profit":0.0,"sales_total":0.0,"wages_total":0.0,"tax_total":0.0,"loss_days":0,"reason":"自主租用社区商业场地；装修需要 4 天","rent":2.0}
	var b:Dictionary=_building("service",4)
	b.owner="private"
	s.buildings.append(b)
	_log("远岸生活服务社获准落地：私人实缴 900，自主装修、雇人、销售并纳税。")
	return ""
func tick()->void:
	if state.is_empty() or state.status in ["planning","failed"]: return
	state.day+=1
	state.operating_net=0.0
	state.income_daily=0.0
	state.expense_daily=0.0
	var stocks:Dictionary={}
	for s in state.settlements: stocks[str(s.region)]=s.stock.duplicate(true)
	_repay()
	_advance_shipments()
	for s in state.settlements:
		if s.arrival>0: s.arrival-=1
		_run_settlement(s)
	Research.tick(self)
	for s in state.settlements:
		if s.arrival<=0: _trade(s)
	_run_enterprise()
	for s in state.settlements:
		if s.arrival<=0: _feed(s)
	_dispatch()
	_public_expense(float(config.economy.admin),"殖民行政费","external")
	_population()
	Company.social_environment(self)
	_event_tick()
	if state.status=="success" and state.day>state.success_day:
		var tax:float=maxf(0.0,float(state.operating_net))*float(config.contract.company_tax_rate)
		if tax>0:
			_public_expense(tax,"公司总督分成","external")
			state.company_tax_total+=tax
	for s in state.settlements:
		_refresh(s)
		for key in KEYS: s.stock_delta[key]=float(s.stock[key])-float(stocks[str(s.region)][key])
	_contract()
	Company.tick(self)
	state.operating_history.append({"day":state.day,"net":state.operating_net,"income":state.income_daily,"expense":state.expense_daily})
	if state.operating_history.size()>90: state.operating_history.pop_front()
	while state.ledger.size()>1800: state.ledger.pop_front()
	Career.tick(self)
func _run_settlement(s:Dictionary)->void:
	s.shortages=[]
	s.jobs=0
	s.employed_workers=0
	s.employed_scientists=0
	s.port_capacity=0.0
	s.port_used=0.0
	s.power_supply=0.0
	s.water_supply=0.0
	s.power_demand=0.0
	s.water_demand=0.0
	var reg:Dictionary=state.world.regions[int(s.region)]
	var work_order:Array=s.buildings.duplicate()
	var research_requested:bool=false
	for project in state.research.projects.values():
		if int(project.staff)>0: research_requested=true
	if research_requested:
		# A staffed project reserves its lab technicians after essential utilities.
		# This moves actual workers out of extraction, never duplicates personnel.
		work_order.sort_custom(func(a,b):
			var pa:int=0 if a.kind in ["power","water","port"] else (1 if a.kind=="lab" else 2)
			var pb:int=0 if b.kind in ["power","water","port"] else (1 if b.kind=="lab" else 2)
			return pa<pb)
	for b in work_order:
		b.active=false
		b.employed=0
		b.specialists=0
		b.efficiency=0.0
		if b.remaining>0:
			b.remaining-=1
			if b.remaining==0: _log(s.name+" · "+str(config.buildings.get(b.kind,{"name":"社区服务社"}).name)+"竣工。")
		if b.remaining>0:
			b.status="建设中 · 余 %d 天" % b.remaining
			b.reason=b.status
			continue
		if not b.get("enabled",true):
			b.status="手动停工"
			b.reason=b.status
			continue
		if b.kind=="service": continue
		var d:Dictionary=config.buildings[b.kind]
		var private_reserved:int=6 if not state.enterprise.is_empty() and int(state.enterprise.region)==int(s.region) and state.enterprise.status!="停业" else 0
		var required:int=int(d.jobs)
		var special:int=int(d.get("specialists",0))
		s.jobs+=required+special
		b.employed=mini(required,maxi(0,int(s.workers)-private_reserved-int(s.employed_workers)))
		b.specialists=mini(special,maxi(0,int(s.scientists)-int(s.employed_scientists)))
		s.employed_workers+=b.employed
		s.employed_scientists+=b.specialists
		b.efficiency=1.0
		if required>0: b.efficiency=float(b.employed)/required
		if special>0: b.efficiency=minf(b.efficiency,float(b.specialists)/special)
		if b.efficiency<1.0: _short(s,"岗位缺员："+d.name+("（需要研究员）" if special>int(b.specialists) else "（需要工人）"))
		b.active=b.efficiency>0.0
		if b.kind=="power": s.power_supply+=float(d.capacity)*b.efficiency
		if b.kind=="water": s.water_supply+=float(d.capacity)*(0.48+float(reg.water)*0.70)*b.efficiency*_water_factor()*EventsV2.modifier(self,int(s.region),"water")
		var pf:float=0.75 if _has("efficiency") else 1.0
		var wf:float=0.7 if b.kind=="farm" and _has("irrigation") else 1.0
		s.power_demand+=float(d.power)*b.efficiency*pf
		s.water_demand+=float(d.water)*b.efficiency*wf
	var power_ratio:float=minf(1.0,float(s.power_supply)/maxf(0.001,s.power_demand))
	# Pump stations cannot provide free water with no electricity.
	s.water_supply*=power_ratio
	var water_ratio:float=minf(1.0,float(s.water_supply)/maxf(0.001,s.water_demand))
	if power_ratio<0.999: _short(s,"电力不足：生产按供需比例减产")
	if water_ratio<0.999: _short(s,"供水不足：生产按供需比例减产")
	for b in s.buildings:
		if b.kind=="service" or b.remaining>0 or not b.get("enabled",true): continue
		var d:Dictionary=config.buildings[b.kind]
		var eff:float=float(b.efficiency)
		if b.kind.begins_with("mine_") or b.kind in ["processor","farm","foodworks"]: eff*=Company.environmental_factor(s)
		eff*=EventsV2.modifier(self,int(s.region),"mine" if b.kind.begins_with("mine_") else str(b.kind))
		if float(d.power)>0: eff*=power_ratio
		if float(d.water)>0: eff*=water_ratio
		if _ration_active() and (b.kind.begins_with("mine_") or b.kind in ["farm","processor"]): eff*=0.85
		b.efficiency=eff
		b.active=eff>0.001
		b.status="运行 %.0f%%" % (eff*100.0) if b.active else "停工 · 岗位或供应不足"
		b.reason=b.status
		_public_expense(float(b.employed)*config.economy.wage+float(b.specialists)*config.economy.scientist_wage,"公共工资","residents")
		_public_expense(float(d.maintenance)*(0.8 if _has("efficiency") else 1.0),"设施维护","external")
		if eff<=0.001: continue
		match str(b.kind):
			"port": s.port_capacity+=float(d.capacity)*eff
			"mine_ore","mine_copper","mine_crystal":
				var resource:String=d.output
				var amount:float=minf(float(reg.deposits[resource]),float(d.rate)*float(reg.grade.get(resource,1.0))*eff*(1.2 if _has("survey") else 1.0))
				reg.deposits[resource]-=amount
				_produce(s,resource,amount,"矿产开采")
				if amount<=0.001:
					b.active=false
					b.status="已探明储量耗尽"
					b.reason=b.status
					_short(s,d.name+"矿床耗尽")
			"farm":
				var climate:float=clampf(1.0-absf(float(reg.temperature)-20.0)/42.0,0.25,1.0)
				var amount:float=minf(maxf(0,_target(s,"food")-float(s.stock.food)),float(d.rate)*float(reg.fertility)*climate*eff*(1.2 if _has("irrigation") else 1.0))
				_produce(s,"food",amount,"农业生产")
				if amount<=0: b.status="目标库存已满 · 自动停产"
			"processor":
				var scale:float=0.0
				# Coproduct recipe runs when either output has genuine demand; no stock deletion.
				for output in d.outputs:
					var wanted:float=maxf(0,_target(s,output)-float(s.stock[output]))
					wanted=maxf(wanted,EventsV2.reserved(self,int(s.region),output)-float(s.get("exportable",{}).get(output,0)))
					scale=maxf(scale,wanted/(float(d.outputs[output])*(1.3 if _has("processing") else 1.0)))
				scale=minf(eff,scale)
				for key in d.inputs: scale=minf(scale,float(s.stock[key])/float(d.inputs[key]))
				if scale<eff: _short(s,"加工缺少本地铁矿或铜矿")
				for key in d.inputs: _consume(s,key,float(d.inputs[key])*scale)
				for key in d.outputs: _produce(s,key,float(d.outputs[key])*scale*(1.3 if _has("processing") else 1.0),"加工配方")
				if scale<=0:
					b.active=false
					b.status="停工 · 缺少配方原料"
					b.reason=b.status
			"lab": pass
			"foodworks": pass
	s.employed=int(s.employed_workers)+int(s.employed_scientists)
func _trade(s:Dictionary)->void:
	var cap:float=float(s.port_capacity)
	# Recurring external buyer receives real farm input through actual local port.
	for b in s.buildings:
		if b.kind!="foodworks" or not b.active: continue
		var d:Dictionary=config.buildings.foodworks
		var keep:float=float(s.population)*float(config.economy.food_per_person)*(float(state.policy.food_reserve)+1)
		var scale:float=minf(float(b.efficiency),minf(cap/float(d.food_input),maxf(0,float(s.stock.food)-keep)/float(d.food_input)))
		if scale<=0: continue
		_consume(s,"food",float(d.food_input)*scale)
		_transfer("external","public",float(d.daily_payment)*scale,"轨道补给局可再生食品订单",true)
		_public_expense(float(d.daily_payment)*scale*float(config.economy.port_fee),"食品订单港务费","external")
		state.exports_total+=float(d.daily_payment)*scale
		cap-=float(d.food_input)*scale
	# Sell only surplus after promised cross-region stock.
	for key in ["crystal","copper","ore","parts","materials"]:
		var reserve:float=float(config.economy.export_reserve.get(key,0.0))+float(_reserved(s).get(key,0.0))
		var amount:float=minf(cap,maxf(0.0,float(s.stock[key])-reserve))
		if key in ["materials","parts"]: amount=minf(amount,maxf(0.0,float(s.get("exportable",{}).get(key,0.0))-EventsV2.reserved(self,int(s.region),key)))
		if amount<=0: continue
		var price:float=float(config.prices[key])
		if key=="copper" and int(state.day)>=int(state.effects.get("market_start",0)) and int(state.effects.get("market_until",0))>int(state.day): price*=1.35
		var revenue:float=amount*price
		_consume(s,key,amount)
		_transfer("external","public",revenue,"出口 · "+config.resources[key],true)
		_public_expense(revenue*config.economy.port_fee,"出口港务费","external")
		state.exports_total+=revenue
		cap-=amount
		if state.exports_total==revenue: _log("第一笔出口到账：%.0f。所有进出口共用本地港口吞吐。" % revenue)
	var target_food:float=float(s.population)*float(config.economy.food_per_person)*(float(state.policy.food_reserve)+1.0)
	# Incoming consignments are counted against targets, but are never consumable early.
	var arriving_food:float=_incoming(int(s.region),"food")
	for key in ["food","materials","parts"]:
		var target:float=target_food if key=="food" else (35.0 if key=="materials" else 12.0)
		var need:float=maxf(0.0,target-float(s.stock[key])-(arriving_food if key=="food" else _incoming(int(s.region),key)))
		var price:float=float(config.prices[key])*(1.0+float(config.economy.port_fee))
		var amount:float=minf(minf(cap,need),maxf(0.0,float(state.cash))/price)
		if amount<=0: continue
		if key=="food": _public_expense(amount*price,"食品进口及港务","external")
		else: _transfer("public","external",amount*price,"建设库存采购 · "+config.resources[key],false)
		_produce(s,key,amount,"外部进口")
		state.imports_total+=amount*price
		cap-=amount
	s.port_used=float(s.port_capacity)-cap
	if float(s.port_capacity)<=0 and s.stock.food<target_food: _short(s,"无本地货运站；依赖陆路补给")
	if float(s.port_capacity)>0 and cap<=0.01 and (float(s.stock.food)+_incoming(int(s.region),"food")<target_food or float(s.stock.materials)<35 or float(s.stock.parts)<12): _short(s,"港口吞吐不足：存在尚未满足的补给需求")
func _feed(s:Dictionary)->void:
	var need:float=float(s.population)*float(config.economy.food_per_person)
	var amount:float=minf(need,float(s.stock.food))
	_consume(s,"food",amount)
	s.food_consumed=amount
	var paid:float=minf(float(state.resident_cash),amount*float(config.prices.food))
	_transfer("residents","public",paid,"居民购买基本食品",true)
	if amount+0.00001<need:
		s.starvation+=1
		_short(s,"食品供给不足 · 已持续 %d 天" % s.starvation)
	else: s.starvation=0
func _run_enterprise()->void:
	if state.enterprise.is_empty(): return
	var e:Dictionary=state.enterprise
	var s:Dictionary=settlement(int(e.region))
	e.employees=0
	e.profit=0.0
	if e.status=="停业": return
	if e.remaining>0:
		e.remaining-=1
		if e.remaining>0: return
	var b:Dictionary={}
	for item in s.buildings:
		if item.kind=="service": b=item
	if b.is_empty(): return
	s.jobs+=6
	if not b.enabled:
		b.active=false
		e.status="暂停营业"
		e.reason="玩家暂停了服务设施"
		return
	var employees:int=mini(6,maxi(0,int(s.workers)-int(s.employed_workers)))
	var wages:float=employees*float(config.economy.wage)
	var fixed:float=3.0+float(e.rent)
	if float(state.enterprise_cash)<wages+fixed or employees<2:
		e.loss_days+=1
		e.status="经营受限"
		e.reason="可雇用工人不足" if employees<2 else "企业现金不足以支付工资与租金"
		b.active=false
		b.status=e.reason
		b.reason=e.reason
		if e.loss_days>=15:
			e.status="停业"
			_log("服务社已停业："+e.reason+"持续 15 天。")
		return
	e.employees=employees
	s.employed_workers+=employees
	s.employed+=employees
	b.employed=employees
	b.active=true
	b.status="民营营业"
	b.reason=b.status
	_transfer("enterprise","residents",wages,"民营企业工资",false)
	_transfer("enterprise","public",float(e.rent),"商业场地租金",true)
	_transfer("enterprise","external",3.0,"企业设备维护",false)
	# Residents purchase useful aggregate repair / laundry / communication services.
	var demand:float=minf(float(s.population)*0.35,employees*4.2)
	var sales:float=minf(float(state.resident_cash),demand)
	_transfer("residents","enterprise",sales,"居民购买生活服务",false)
	var profit:float=sales-wages-fixed
	var tax:float=maxf(0.0,profit)*float(state.policy.tax)
	_transfer("enterprise","public",tax,"本地企业利润税",true)
	e.profit=profit-tax
	e.sales_total+=sales
	e.wages_total+=wages
	e.tax_total+=tax
	e.loss_days=int(e.loss_days)+1 if profit<0 else 0
	e.status="营业中"
	e.reason="自主经营，无需逐日操作；利润税只对正利润征收"
	if e.loss_days>=15:
		e.status="停业"
		b.active=false
		_log("服务社连续亏损 15 天，停止营业；居民购买力不足。")
func _advance_shipments()->void:
	var keep:Array=[]
	for cargo in state.shipments:
		if not cargo.get("expedition",false) and not state.route.is_empty() and WorldGen.road_blocked(state.route,int(state.day)):
			keep.append(cargo)
			continue
		cargo.remaining-=1
		if cargo.remaining<=0:
			var s:Dictionary=settlement(int(cargo.to))
			s.stock[cargo.resource]+=float(cargo.amount)
			state.transported_total+=float(cargo.amount)
		else: keep.append(cargo)
	state.shipments=keep
func _incoming(region:int,resource:String)->float:
	var amount:float=0.0
	for cargo in state.shipments:
		if int(cargo.to)==region and str(cargo.resource)==resource: amount+=float(cargo.amount)
	return amount
func _dispatch()->void:
	if state.route.is_empty(): return
	var r:Dictionary=state.route
	r.sent_today=0.0
	if WorldGen.road_blocked(r,int(state.day)): return
	var cap:float=float(r.capacity)*(1.4 if _has("logistics") else 1.0)
	for resource in ["food","materials","parts","ore","copper","crystal"]:
		for pair in [[int(r.a),int(r.b)],[int(r.b),int(r.a)]]:
			var src:Dictionary=settlement(pair[0])
			var dst:Dictionary=settlement(pair[1])
			if src.arrival>0 or dst.arrival>0: continue
			var reserve:float=float(config.economy.export_reserve.get(resource,0.0))
			var target:float=reserve
			if resource=="food":
				reserve=float(src.population)*config.economy.food_per_person*(state.policy.food_reserve+1.0)
				target=float(dst.population)*config.economy.food_per_person*(state.policy.food_reserve+float(r.days)+2.0)
			elif resource=="materials": target=35.0
			elif resource=="parts": target=12.0
			elif dst.port_capacity>0: target=80.0
			var surplus:float=maxf(0.0,float(src.stock[resource])-reserve)
			var deficit:float=maxf(0.0,target-float(dst.stock[resource])-_incoming(int(dst.region),resource))
			var amount:float=minf(cap,minf(surplus,deficit))
			var fee:float=float(config.economy.transport_unit_cost)*(0.8 if _has("logistics") else 1.0)
			amount=minf(amount,float(state.cash)/fee)
			if amount<=0.001: continue
			src.stock[resource]-=amount
			_public_expense(amount*fee,"陆路运输费","external")
			state.shipments.append({"from":src.region,"to":dst.region,"resource":resource,"amount":amount,"remaining":int(r.days),"total_days":int(r.days),"expedition":false})
			cap-=amount
			r.sent_today+=amount
func _population()->void:
	for s in state.settlements:
		if s.arrival>0: continue
		_refresh(s)
		if int(state.day)%int(config.economy.immigration_period)==0 and s.housing>=s.population+2 and s.food_days>=7.0 and s.jobs>=s.employed+2:
			s.workers+=2
			s.population+=2
			state.immigrants_total+=2
			_transfer("external","residents",120.0,"新移民携带积蓄",false)
			_log(s.name+"新增 2 名工人移民，自带积蓄 120。")
		if int(state.day)%int(config.economy.birth_period)==0 and s.housing>s.population and s.starvation==0:
			s.children+=1
			s.population+=1
			state.births_total+=1
			s.cohorts.append({"count":1,"mature_day":int(state.day)+int(config.economy.mature_days)})
		var keep:Array=[]
		for cohort in s.cohorts:
			if int(cohort.mature_day)<=int(state.day):
				s.children-=int(cohort.count)
				s.workers+=int(cohort.count)
			else: keep.append(cohort)
		s.cohorts=keep
		var period:int=15 if _has("education") else 30
		var training_capacity:int=0
		for facility in s.buildings:
			if facility.kind=="lab" and facility.enabled and facility.remaining<=0: training_capacity+=int(progression.research.seats_per_lab)
		if int(state.day)%period==0 and s.workers>8 and s.scientists<training_capacity:
			for b in s.buildings:
				if b.kind=="lab" and b.active:
					s.workers-=1
					s.scientists+=1
					_reconcile_jobs(s)
					_log(s.name+"教学研究所完成 1 名工人的科研职业培训。")
					break
func _event_tick()->void:
	if not state.event.is_empty() and not state.event.has("instance_id"):
		if int(state.day)>=int(state.event.get("expires",999999)):
			_resolve_event("ration" if state.event.id=="drought" else "decline")
		return
	EventsV2.tick(self)
func _resolve_event(choice:String)->String:
	if state.event.has("instance_id"): return EventsV2.act(self,{"instance_id":str(state.event.instance_id),"choice":choice})
	if state.event.is_empty(): return "当前没有待处理事件"
	var id:String=state.event.id
	var valid:bool=false
	for c in state.event.choices:
		if c.id==choice: valid=true
	if not valid: return "请选择有效的事件方案"
	match id:
		"drought":
			if choice=="protect":
				if state.cash<160: return "调蓄工程需要 160 资金"
				_transfer("public","external",160.0,"一次性调蓄工程",false)
			state.effects.drought_start=int(state.day)+1
			state.effects.drought_until=int(state.day)+1+int(state.event.duration)
			state.effects.drought_choice=choice
			_log("缺水应对："+("调蓄工程保障供水。" if choice=="protect" else "节水减产 15%，持续 12 天。"))
		"market":
			if choice=="accept":
				if state.cash<120: return "港务协调需要 120 资金"
				_transfer("public","external",120.0,"临时采购协调费",false)
				state.effects.market_start=int(state.day)+1
				state.effects.market_until=int(state.day)+1+int(state.event.duration)
				_log("铜矿报价 +35%，持续 18 天。")
		"talent":
			if choice=="invite":
				var s:Dictionary=state.settlements[0]
				if s.housing<s.population+8: return "首府需要 8 个空闲住房名额"
				if state.cash<180: return "人才安置需要 180 资金"
				_transfer("public","external",180.0,"人才安置投资",false)
				_transfer("external","residents",800.0,"人才移民自带积蓄",false)
				s.workers+=4
				s.scientists+=4
				s.population+=8
				state.immigrants_total+=8
				_log("4 名研究员与 4 名工人入住首府。")
	state.event={}
	return ""
func _water_factor()->float:
	if int(state.day)<int(state.effects.get("drought_start",999999)) or int(state.day)>=int(state.effects.get("drought_until",0)): return 1.0
	return 1.0 if state.effects.get("drought_choice","")=="protect" else 0.8
func _ration_active()->bool:
	return state.effects.get("drought_choice","")=="ration" and int(state.day)>=int(state.effects.get("drought_start",999999)) and int(state.day)<int(state.effects.get("drought_until",0))
func _refresh(s:Dictionary)->void:
	s.housing=int(s.base_housing)
	for b in s.buildings:
		if b.kind=="habitat" and b.remaining<=0 and b.get("enabled",true): s.housing+=int(config.buildings.habitat.housing)
	s.food_days=float(s.stock.food)/maxf(0.001,float(s.population)*config.economy.food_per_person)
	if s.housing<s.population: _short(s,"住房不足")
func contract_progress()->Dictionary:
	var p:Dictionary={"connected":state.settlements.size()>=2 and not state.route.is_empty() and not WorldGen.road_blocked(state.route,int(state.day)),"food":true,"housing":true,"employment":true,"industry":false,"enterprise":not state.enterprise.is_empty() and state.enterprise.get("status","")=="营业中","solvent":state.debt<0.001,"streak":int(state.streak),"required_streak":int(config.contract.streak_days)}
	for s in state.settlements:
		if s.arrival>0 or s.food_days<float(config.contract.food_days): p.food=false
		if s.housing<s.population: p.housing=false
		if float(s.employed)/maxf(1.0,float(s.workers)+float(s.scientists))<float(config.contract.min_employment): p.employment=false
		for b in s.buildings:
			if b.kind in ["farm","processor","foodworks"] and b.active: p.industry=true
	return p
func _contract()->void:
	if state.operating_net>= -0.000001 and state.debt<0.001: state.streak+=1
	else: state.streak=0
	state.grace_days=int(state.grace_days)+1 if state.debt>0.001 else 0
	if state.status=="success": return
	var p:Dictionary=contract_progress()
	if p.connected and p.food and p.housing and p.employment and p.industry and p.enterprise and p.solvent and state.streak>=int(config.contract.streak_days):
		state.status="success"
		state.success_day=state.day
		_log("合同履约完成：总督资格生效。明日起按公共账户正经营结余的 15% 缴纳公司分成；可继续经营。")
func _fail(reason:String)->void:
	state.status="failed"
	state.failure_reason=reason
	_log("经营终止："+reason)
func _has(tech:String)->bool:
	return state.research.completed.has(tech)
## Workers not spoken for by any enabled facility, including those still under construction.
func free_workers(s:Dictionary)->int:
	var committed:int=0
	for b in s.buildings:
		if b.kind=="service" or not b.get("enabled",true): continue
		committed+=int(config.buildings[b.kind].jobs)
	if not state.enterprise.is_empty() and int(state.enterprise.region)==int(s.region) and state.enterprise.status!="停业": committed+=6
	return maxi(0,int(s.workers)-committed)
## Scientists not assigned to facility specialist posts, research projects or field work.
func free_specialists(s:Dictionary)->int:
	var committed:int=0
	for b in s.buildings:
		if b.kind=="service" or not b.get("enabled",true): continue
		committed+=int(config.buildings[b.kind].get("specialists",0))
	return maxi(0,int(s.scientists)-committed-int(s.employed_scientists))
func _reconcile_jobs(s:Dictionary)->void:
	# Rebalance snapshot assignments after migration/training without producing or billing twice.
	var available:int=int(s.workers)
	var building_specialists:int=0
	for building in s.buildings: building_specialists+=int(building.get("specialists",0))
	var research_employed:int=mini(int(s.scientists),maxi(0,int(s.employed_scientists)-building_specialists))
	var specialists:int=int(s.scientists)-research_employed
	s.employed_workers=0
	s.employed_scientists=research_employed
	for b in s.buildings:
		b.employed=mini(int(b.get("employed",0)),available)
		b.specialists=mini(int(b.get("specialists",0)),specialists)
		available-=int(b.employed)
		specialists-=int(b.specialists)
		s.employed_workers+=int(b.employed)
		s.employed_scientists+=int(b.specialists)
		if b.kind=="service" and not state.enterprise.is_empty(): state.enterprise.employees=b.employed
	s.employed=int(s.employed_workers)+int(s.employed_scientists)
func _short(s:Dictionary,message:String)->void:
	if not s.shortages.has(message): s.shortages.append(message)
func _log(message:String)->void:
	state.log.append({"day":state.day,"text":message})
	while state.log.size()>120: state.log.pop_front()
func _account(name:String)->String:
	return {"public":"cash","residents":"resident_cash","enterprise":"enterprise_cash"}.get(name,"")
func _transfer(from:String,to:String,amount:float,category:String,operating:bool)->float:
	if amount<=0: return 0.0
	var source:String=_account(from)
	var dest:String=_account(to)
	if source!="": amount=minf(amount,maxf(0.0,float(state[source])))
	if amount<=0: return 0.0
	if source!="": state[source]-=amount
	else: state.external_in+=amount
	if dest!="": state[dest]+=amount
	else: state.external_out+=amount
	state.ledger.append({"day":state.day,"category":category,"amount":amount,"from":from,"to":to,"operating":operating})
	if operating:
		if to=="public":
			state.operating_net+=amount
			state.income_daily+=amount
		if from=="public":
			state.operating_net-=amount
			state.expense_daily+=amount
	return amount
func _public_expense(amount:float,category:String,to:String)->void:
	if amount<=0: return
	# Operating result includes today's payable bills even if cash cannot settle them.
	var paid:float=_transfer("public",to,amount,category,true)
	var due:float=amount-paid
	if due>0.000001:
		state.operating_net-=due
		state.expense_daily+=due
		state.debt+=due
		state.arrears.append({"to":to,"amount":due,"category":category})
func _repay()->void:
	var keep:Array=[]
	for bill in state.arrears:
		var paid:float=_transfer("public",bill.to,float(bill.amount),"清偿欠款 · "+bill.category,false)
		bill.amount-=paid
		state.debt-=paid
		if bill.amount>0.000001: keep.append(bill)
	state.arrears=keep
	state.debt=maxf(0.0,state.debt)
func _produce(s:Dictionary,resource:String,amount:float,_source:String)->void:
	if amount<=0: return
	s.stock[resource]+=amount
	state.resource_sources[resource]+=amount
	if _source=="加工配方":
		if not s.has("exportable"): s.exportable={"materials":0.0,"parts":0.0}
		s.exportable[resource]+=amount
func _consume(s:Dictionary,resource:String,amount:float)->void:
	amount=minf(maxf(0.0,amount),float(s.stock[resource]))
	s.stock[resource]-=amount
	state.resource_sinks[resource]+=amount
	if s.has("exportable") and s.exportable.has(resource): s.exportable[resource]=maxf(0.0,float(s.exportable[resource])-amount)
func summary()->Dictionary:
	var population:int=0
	var employed:int=0
	var food:float=0.0
	var days:float=999.0
	for s in state.settlements:
		population+=int(s.population)
		employed+=int(s.employed)
		food+=float(s.stock.food)
		days=minf(days,float(s.food_days))
	var net:float=0.0
	var count:int=mini(7,state.operating_history.size())
	for i in range(state.operating_history.size()-count,state.operating_history.size()): net+=float(state.operating_history[i].net)
	if count>0: net/=count
	return {"population":population,"employed":employed,"food":food,"food_days":0.0 if days==999.0 else days,"operating_average":net,"runway":float(state.cash)/(-net) if net< -0.01 else -1.0,"debt":state.debt,"contract":contract_progress()}
func audit()->Array:
	var errors:Array=[]
	var total:float=float(state.cash)+float(state.resident_cash)+float(state.enterprise_cash)
	if absf(total-(float(state.initial_money)+float(state.external_in)-float(state.external_out)))>0.00001: errors.append("cash conservation")
	var holdings:Dictionary=_stock()
	for s in state.settlements:
		if int(s.population)!=int(s.children)+int(s.workers)+int(s.scientists): errors.append("population partition")
		if s.employed_workers>s.workers or s.employed_scientists>s.scientists: errors.append("duplicate job allocation")
		for key in KEYS:
			if s.stock[key]< -0.00001: errors.append("negative stock "+key)
			holdings[key]+=float(s.stock[key])
	for cargo in state.shipments: holdings[cargo.resource]+=float(cargo.amount)
	for key in KEYS:
		if absf(float(holdings[key])-float(state.resource_sources[key])+float(state.resource_sinks[key]))>0.00001: errors.append("material conservation "+key)
	return errors
func save_game(path:String)->String:
	if state.is_empty(): return "无可保存的游戏"
	var payload:String=JSON.stringify(state,"",true,true)
	# Godot's decimal parser can round 64-bit floats by one ULP. Keep an exact,
	# object-free Variant snapshot beside readable JSON for identical continuation.
	var binary:String=Marshalls.raw_to_base64(var_to_bytes(state))
	var envelope:Dictionary={"version":SAVE_VERSION,"checksum":payload.sha256_text(),"payload":payload,"binary":binary,"binary_checksum":binary.sha256_text()}
	var temp:String=path+".tmp"
	var f:FileAccess=FileAccess.open(temp,FileAccess.WRITE)
	if f==null: return "无法写入临时存档："+str(FileAccess.get_open_error())
	f.store_string(JSON.stringify(envelope))
	f.flush()
	f.close()
	if FileAccess.get_file_as_string(temp)!=JSON.stringify(envelope): return "存档回读校验失败，原存档保留"
	var absolute:String=ProjectSettings.globalize_path(path)
	var temporary:String=ProjectSettings.globalize_path(temp)
	var backup:String=absolute+".bak"
	# Same-directory rename provides atomic publish; backup retains last known save.
	if FileAccess.file_exists(path):
		var copied:Error=DirAccess.copy_absolute(absolute,backup)
		if copied!=OK: return "无法保留原存档备份"
	var result:Error=DirAccess.rename_absolute(temporary,absolute)
	if result!=OK: return "存档替换失败，原存档和临时文件保留："+str(result)
	return ""
func load_game(path:String)->String:
	if not FileAccess.file_exists(path): return "存档不存在"
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return "存档格式或版本不兼容"
	if not (parsed.get("version") is int or parsed.get("version") is float): return "存档格式或版本不兼容"
	if float(parsed.version)!=float(int(parsed.version)) or not int(parsed.version) in [1,SAVE_VERSION]: return "存档格式或版本不兼容"
	if not parsed.has("payload") or not parsed.payload is String: return "存档缺少有效负载"
	if parsed.payload.sha256_text()!=parsed.get("checksum",""): return "存档校验失败"
	var candidate:Variant=JSON.parse_string(parsed.payload)
	if parsed.has("binary"):
		if not parsed.binary is String or parsed.binary.sha256_text()!=parsed.get("binary_checksum",""): return "精确状态校验失败"
		candidate=bytes_to_var(Marshalls.base64_to_raw(parsed.binary))
	var legacy:bool=candidate is Dictionary and candidate.get("schema",0)==1
	var error:String=_validate_save(candidate,legacy)
	if error!="": return error
	var old:Dictionary=state
	state=candidate
	if legacy:
		state.schema=SAVE_VERSION
		state.difficulty="normal"
		Research.ensure(self)
		Company.ensure(self)
		Career.ensure(self)
		EventsV2.ensure(self)
	var issues:Array=audit()
	if not issues.is_empty():
		state=old
		return "存档不满足守恒约束："+str(issues)
	return ""
func _validate_save(candidate:Variant,legacy:bool=false)->String:
	if not candidate is Dictionary: return "存档状态无效"
	# Validate nested containers before any property access or audit. GDScript
	# runtime errors do not throw to the caller; a validator error must never be
	# mistaken for an empty success result and replace the current state.
	var shape:Dictionary={"schema":0,"world":{"seed":0,"version":"","size":0,"radius_km":0,"grid_width":0,"grid_height":0,"grid":[{"height":0,"temperature":0,"rainfall":0,"land":false,"river":false,"lake":false}],"regions":[{"id":0,"name":"","lat":0,"lon":0,"elevation":0,"fertility":0,"water":0,"temperature":0,"rainfall":0,"deposits":{"ore":0,"copper":0,"crystal":0},"grade":{"ore":0,"copper":0,"crystal":0},"neighbors":[0],"terrain":"","land_fraction":0,"river":false,"grid_index":0,"development_multiplier":0}],"candidates":[0],"rivers":[[[0]]],"lakes":[{"lat":0,"lon":0,"name":"","elevation":0}]},"day":0,"advantage":"","cash":0,"resident_cash":0,"enterprise_cash":0,"initial_money":0,"external_in":0,"external_out":0,"settlements":[],"shipments":[{"from":0,"to":0,"resource":"","amount":0,"remaining":0,"total_days":0,"expedition":false}],"research":{"current":"","progress":0,"completed":[""],"priority":0},"route":{},"enterprise":{},"events":[""],"event":{},"effects":{},"ledger":[{"day":0,"category":"","amount":0,"from":"","to":"","operating":false}],"log":[{"day":0,"text":""}],"status":"","streak":0,"operating_net":0,"operating_history":[{"day":0,"net":0,"income":0,"expense":0}],"income_daily":0,"expense_daily":0,"debt":0,"arrears":[{"to":"","amount":0,"category":""}],"grace_days":0,"policy":{"tax":0,"food_reserve":0,"private_allowed":false},"exports_total":0,"imports_total":0,"transported_total":0,"company_tax_total":0,"success_day":0,"failure_reason":"","resource_sources":_stock(),"resource_sinks":_stock(),"rng_state":0,"births_total":0,"immigrants_total":0}
	var shape_error:String=_save_shape(candidate,shape,"state")
	if shape_error!="": return shape_error
	if candidate.world.grid_width!=WorldGen.GW or candidate.world.grid_height!=WorldGen.GH or candidate.world.grid.size()!=WorldGen.GW*WorldGen.GH or candidate.world.regions.size()!=6: return "世界网格或地区数量不合法"
	if float(candidate.schema)!=float(int(candidate.schema)) or not int(candidate.schema) in ([1] if legacy else [SAVE_VERSION]) or not candidate.status in ["planning","active","success","failed"] or not config.openings.has(candidate.advantage): return "存档版本或阶段无效"
	if not candidate.route.is_empty():
		shape_error=_save_shape(candidate.route,{"reachable":false,"distance":0,"days":0,"cost":0,"path":[0],"coordinates":[[0]],"mountain":false,"a":0,"b":0,"capacity":0,"blocked_until":0,"sent_today":0},"route")
		if shape_error!="": return shape_error
		if candidate.route.days<1 or candidate.route.a<0 or candidate.route.a>=6 or candidate.route.b<0 or candidate.route.b>=6: return "运输线路无效"
		for pair in candidate.route.coordinates:
			if pair.size()!=2: return "运输坐标无效"
	if not candidate.enterprise.is_empty():
		shape_error=_save_shape(candidate.enterprise,{"name":"","region":0,"industry":"","status":"","remaining":0,"employees":0,"profit":0,"sales_total":0,"wages_total":0,"tax_total":0,"loss_days":0,"reason":"","rent":0},"enterprise")
		if shape_error!="": return shape_error
	if not candidate.event.is_empty():
		shape_error=_save_shape(candidate.event,{"id":"","day":0,"title":"","text":"","duration":0,"expires":0,"choices":[{"id":"","label":""}]},"event")
		if shape_error!="": return shape_error
	for key in candidate.effects:
		shape_error=_save_shape(candidate.effects[key],"" if key=="drought_choice" else 0,"effects."+str(key))
		if shape_error!="": return shape_error
	for key in ["schema","world","day","cash","resident_cash","enterprise_cash","initial_money","external_in","external_out","settlements","shipments","research","route","enterprise","events","event","effects","ledger","log","status","operating_history","debt","arrears","policy","resource_sources","resource_sinks"]:
		if not candidate.has(key): return "存档缺失字段："+key
	if not candidate.world is Dictionary or not candidate.world.has("regions") or not candidate.world.has("version"): return "世界数据不完整"
	if not candidate.world.version in WorldGen.SUPPORTED_VERSIONS: return "世界生成器版本不同"
	if not candidate.settlements is Array or candidate.settlements.size()>2: return "据点数据不合法"
	if not candidate.shipments is Array or not candidate.ledger is Array: return "存档列表字段不合法"
	for s in candidate.settlements:
		if not s is Dictionary: return "据点数据不合法"
		shape_error=_save_shape(s,{"region":0,"name":"","population":0,"children":0,"workers":0,"scientists":0,"stock":_stock(),"stock_delta":_stock(),"buildings":[_building("",0)],"jobs":0,"housing":0,"base_housing":0,"food_days":0,"shortages":[""],"employed":0,"employed_workers":0,"employed_scientists":0,"power_supply":0,"power_demand":0,"water_supply":0,"water_demand":0,"starvation":0,"arrival":0,"cohorts":[{"count":0,"mature_day":0}],"port_used":0,"port_capacity":0,"food_consumed":0},"settlement")
		if shape_error!="": return shape_error
		if s.has("exportable"):
			shape_error=_save_shape(s.exportable,{"materials":0,"parts":0},"settlement.exportable")
			if shape_error!="": return shape_error
		for key in ["population","children","workers","scientists","employed_workers","employed_scientists"]:
			if s[key]<0: return "人口与岗位不能为负数"
		for key in ["region","population","workers","scientists","children","stock","buildings","employed_workers","employed_scientists","arrival","cohorts","base_housing"]:
			if not s.has(key): return "据点缺失字段："+key
		if int(s.region)<0 or int(s.region)>=candidate.world.regions.size(): return "据点位置无效"
		for key in KEYS:
			if not s.stock.has(key): return "本地库存缺失"
		for b in s.buildings:
			if not b is Dictionary or not b.has("kind") or not b.has("remaining") or (b.kind!="service" and not config.buildings.has(b.kind)): return "建筑数据无效"
	for cargo in candidate.shipments:
		if not cargo.resource in KEYS or cargo.amount<0 or cargo.total_days<1 or cargo.remaining<0: return "在途货物数据无效"
		if cargo.from<0 or cargo.from>=6 or cargo.to<0 or cargo.to>=6: return "货物目的地无效"
	shape_error=WorldGen.world_compatibility_error(candidate.world)
	if shape_error!="": return shape_error
	if not legacy:
		shape_error=EventsV2.validate(candidate)
		if shape_error!="": return shape_error
		if not candidate.get("difficulty") is String or not progression.difficulty.has(candidate.difficulty): return "难度配置无效"
		for validator in [Research,Company]:
			shape_error=validator.validate(self,candidate)
			if shape_error!="": return shape_error
		shape_error=Career.validate(candidate)
		if shape_error!="": return shape_error
		for local in candidate.settlements:
			if local.has("targets"):
				if not local.targets is Dictionary: return "库存目标类型无效"
				for resource in local.targets:
					if not resource in KEYS: return "库存目标资源无效"
					shape_error=_save_shape(local.targets[resource],0,"stock_target")
					if shape_error!="": return shape_error
			for field in ["pollution","social_days"]:
				shape_error=_save_shape(local.get(field,0),0,"settlement."+field)
				if shape_error!="": return shape_error
	return ""

func _save_shape(value:Variant,pattern:Variant,path:String)->String:
	if pattern is Dictionary:
		if not value is Dictionary: return "存档字段类型无效："+path
		for key in pattern:
			if not value.has(key): return "存档缺失字段："+path+"."+str(key)
			var error:String=_save_shape(value[key],pattern[key],path+"."+str(key))
			if error!="": return error
	elif pattern is Array:
		if not value is Array: return "存档列表类型无效："+path
		if not pattern.is_empty():
			for item in value:
				var error:String=_save_shape(item,pattern[0],path+"[]")
				if error!="": return error
	elif pattern is int or pattern is float:
		if not (value is int or value is float): return "存档数值类型无效："+path
		if not is_finite(float(value)): return "存档数值无效："+path
	elif typeof(value)!=typeof(pattern): return "存档字段类型无效："+path
	return ""


func _target(s:Dictionary,resource:String)->float:
	if s.get("targets",{}).has(resource): return float(s.targets[resource])
	if resource=="food": return maxf(float(progression.production.food_min_target),float(s.population)*float(config.economy.food_per_person)*float(progression.production.target_days))
	return {"materials":160.0,"parts":40.0}.get(resource,120.0)
func _stock_target(args:Dictionary)->String:
	var s:Dictionary=settlement(int(args.get("region",-1)))
	var resource:String=str(args.get("resource",""))
	var target:float=float(args.get("target",0))
	if s.is_empty() or not resource in KEYS: return "请选择有效据点与物资"
	if not is_finite(target) or target<0 or target>10000: return "目标库存应在 0—10000 之间"
	if not s.has("targets"): s.targets={}
	s.targets[resource]=target
	return ""
func _reserved(s:Dictionary)->Dictionary:
	var reserved:Dictionary=_stock()
	for key in KEYS: reserved[key]=EventsV2.reserved(self,int(s.region),key)
	if state.route.is_empty(): return reserved
	var r:Dictionary=state.route
	if WorldGen.road_blocked(r,int(state.day)): return reserved
	var dest:int=int(r.b) if int(s.region)==int(r.a) else int(r.a)
	var dst:Dictionary=settlement(dest)
	if dst.is_empty() or dst.arrival>0: return reserved
	var cap:float=float(r.capacity)*(1.4 if _has("logistics") else 1.0)
	for key in KEYS:
		var target:float=float(config.economy.export_reserve.get(key,0))
		if key=="food": target=float(dst.population)*float(config.economy.food_per_person)*(float(state.policy.food_reserve)+float(r.days)+2)
		elif key=="materials": target=35.0
		elif key=="parts": target=12.0
		elif dst.port_capacity>0: target=80.0
		reserved[key]+=minf(cap,maxf(0,target-float(dst.stock[key])-_incoming(dest,key)))
	return reserved
func logistics_view(region:int)->Dictionary:
	var s:Dictionary=settlement(region)
	if s.is_empty(): return {}
	var incoming:Dictionary=_stock()
	for key in KEYS: incoming[key]=_incoming(region,key)
	return {"reserved":_reserved(s),"incoming":incoming,"stock":s.stock,"targets":s.get("targets",{})}
func toggle_preview(region:int,index:int)->Dictionary:
	var s:Dictionary=settlement(region)
	if s.is_empty() or index<0 or index>=s.buildings.size(): return {}
	var b:Dictionary=s.buildings[index]
	var housing:int=int(s.housing)
	if b.kind=="habitat" and b.remaining<=0: housing+=int(config.buildings.habitat.housing)*(-1 if b.enabled else 1)
	return {"housing_after":housing,"housing_shortfall":maxi(0,int(s.population)-housing),"enabled_after":not bool(b.enabled)}
func _batch_toggle(args:Dictionary)->String:
	var s:Dictionary=settlement(int(args.get("region",-1)))
	if s.is_empty(): return "请选择已建立的据点"
	var category:String=str(args.get("category","all"))
	for b in s.buildings:
		if b.get("owner","public")=="private": continue
		if category=="all" or category==b.kind or (category=="production" and (b.kind.begins_with("mine_") or b.kind in ["farm","processor","foodworks"])): b.enabled=bool(args.get("enabled",true))
		if not b.enabled:
			b.active=false
			b.status="手动停工"
	_refresh(s)
	Research.rebalance(self,false)
	return ""
func enterprise_preview(region:int)->Dictionary:
	var s:Dictionary=settlement(region)
	if s.is_empty(): return {}
	var wages:float=6*float(config.economy.wage)
	var sales:float=minf(float(s.population)*0.35,25.2)
	return {"region":region,"population":s.population,"workers":maxi(0,int(s.workers)-int(s.employed_workers)),"daily_demand":sales,"daily_cost":wages+5,"estimated_profit":sales-wages-5,"recovery_cost":float(progression.production.enterprise_recovery),"reason":"居民服务需求取决于当地人口与购买力；小型前哨可能亏损，复业可迁至所选据点。"}
func _enterprise_recover(region:int)->String:
	if state.enterprise.is_empty(): return "尚未设立企业"
	var dst:Dictionary=settlement(region)
	if dst.is_empty() or dst.arrival>0: return "需要已经运转的据点"
	var cost:float=float(progression.production.enterprise_recovery)
	if float(state.cash)<cost: return "复业重组需要 %.0f 资金" % cost
	var src:Dictionary=settlement(int(state.enterprise.region))
	var target:Dictionary={}
	for b in src.buildings:
		if b.kind=="service": target=b; break
	if target.is_empty(): return "原企业设施缺失"
	if int(src.region)!=region and dst.buildings.size()>=24: return "目的地设施已满"
	_transfer("public","enterprise",cost,"企业复业重组投资",false)
	if int(src.region)!=region:
		src.buildings.erase(target)
		dst.buildings.append(target)
	target.enabled=true
	target.remaining=3
	target.active=false
	state.enterprise.region=region
	state.enterprise.remaining=3
	state.enterprise.loss_days=0
	state.enterprise.status="装修中"
	state.enterprise.reason="有偿重组或迁址，3 日后重新营业"
	_log("服务社有偿重组完成；公共账户投入 %.0f，3 日后在 %s 复业。" % [cost,dst.name])
	return ""
