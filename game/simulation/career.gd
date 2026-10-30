extends RefCounted
## One active world. Local money remains audited by Sim; career funds are an
## explicit outside investor when transferred into that local ledger.
static var configuration:Dictionary={}
static func cfg()->Dictionary:
	if configuration.is_empty(): configuration=JSON.parse_string(FileAccess.get_file_as_string("res://data/career.json"))
	return configuration

static func ensure(sim)->void:
	if sim.state.has("career"):return
	sim.state.career={"version":1,"id":"career-%s"%str(sim.state.world.seed),"active_id":1,"global_day":int(sim.state.day),"landed_day":0,"last_local_day":int(sim.state.day),"balance":0.0,"invested":0.0,"managed":[],"archives":[],"history":[],"checkpoint":""}

static func capture_checkpoint(sim)->void:
	ensure(sim)
	var copy:Dictionary=sim.state.duplicate(true)
	copy.career.checkpoint=""
	sim.state.career.checkpoint=Marshalls.raw_to_base64(var_to_bytes(copy).compress(FileAccess.COMPRESSION_GZIP))

static func _decode(encoded:String)->Variant:
	if encoded.length()%4!=0:return null
	var format=RegEx.new()
	format.compile("^[A-Za-z0-9+/]*={0,2}$")
	if format.search(encoded)==null:return null
	var bytes:PackedByteArray=Marshalls.base64_to_raw(encoded)
	if bytes.size()<18 or bytes[0]!=31 or bytes[1]!=139:return null
	var raw:PackedByteArray=bytes.decompress_dynamic(128*1024*1024,FileAccess.COMPRESSION_GZIP)
	if raw.size()<4:return null
	return bytes_to_var(raw)

static func preview(sim)->Dictionary:
	ensure(sim)
	var history:Array=sim.state.operating_history
	var count:int=mini(int(cfg().management.history_days),history.size())
	var income:float=0.0
	var expense:float=0.0
	for i in range(history.size()-count,history.size()):
		income+=float(history[i].income)
		expense+=float(history[i].expense)
	if count>0:
		income/=count
		expense/=count
	var mining_capacity:float=0.0
	var remaining:float=0.0
	var streams:Dictionary={}
	var cost_floor:float=float(sim.config.economy.admin)
	var sustainable_capacity:float=0.0
	for s in sim.state.settlements:
		var r:Dictionary=sim.state.world.regions[int(s.region)]
		for b in s.buildings:
			if b.kind=="service":continue
			var d:Dictionary=sim.config.buildings[b.kind]
			# Include idle asset maintenance; temporary shutdown cannot inflate the baseline.
			cost_floor+=float(d.maintenance)
			if b.remaining>0 or not b.get("enabled",true):continue
			cost_floor+=float(b.get("employed",0))*float(sim.config.economy.wage)+float(b.get("specialists",0))*float(sim.config.economy.scientist_wage)
			var eff:float=clampf(float(b.get("efficiency",0.0)),0.0,1.0)
			if str(b.kind).begins_with("mine_"):
				var rate:float=float(d.rate)*float(r.grade.get(d.output,1.0))*float(sim.config.prices[d.output])*eff
				mining_capacity+=rate
				var id:String="%d:%s"%[s.region,d.output]
				if not streams.has(id):streams[id]={"resource":d.output,"region":s.region,"remaining":float(r.deposits[d.output])*float(sim.config.prices[d.output]),"rate":0.0}
				streams[id].rate+=rate
			if b.kind=="processor":
				var margin:float=0.0
				for k in d.outputs:margin+=float(d.outputs[k])*float(sim.config.prices[k])
				for k in d.inputs:margin-=float(d.inputs[k])*float(sim.config.prices[k])*1.04
				sustainable_capacity+=maxf(0.0,margin)*eff
			if b.kind=="foodworks":sustainable_capacity+=float(d.daily_payment)*eff
			if b.kind=="farm":sustainable_capacity+=float(d.rate)*float(r.fertility)*eff*float(sim.config.prices.food)*0.25
	var mining:float=minf(income,mining_capacity)
	for stream in streams.values():
		stream.rate*=mining/maxf(0.001,mining_capacity)
		remaining+=float(stream.remaining)
	var nonmining:float=minf(maxf(0.0,income-mining),sustainable_capacity+8.0)
	# Represent recurring taxes separately; observed expenses already include old governor tax.
	var base_rate:float=float(sim.config.contract.company_tax_rate)
	var tax_in_sample:float=0.0
	var first_day:int=int(history[history.size()-count].day) if count>0 else int(sim.state.day)+1
	for entry in sim.state.ledger:
		if int(entry.day)>=first_day and bool(entry.operating) and entry.from=="public" and (str(entry.category).begins_with("公司总督分成") or str(entry.category).begins_with("援助追加经营分成")):
			tax_in_sample+=float(entry.amount)
	var operating_cost:float=maxf(cost_floor,expense-tax_in_sample/maxi(1,count))
	var extra:float=0.0
	var until:int=0
	if sim.state.has("company"):
		for aid in sim.state.company.get("aid",[]):
			if aid.status in ["in_transit","active","breached"]:
				extra+=float(aid.surcharge)
				until=maxi(until,int(aid.end_day))
	var gross:float=maxf(0.0,mining+nonmining-operating_cost)
	var expected:float=gross*(1.0-base_rate-extra)*30.0*float(cfg().management.player_share)
	return {"sample_days":count,"daily_income":mining+nonmining,"mining_income":mining,"mining_streams":streams.values(),"nonmining_income":nonmining,"daily_cost":operating_cost,"mine_remaining":remaining,"reserve_target":operating_cost*float(cfg().management.reserve_days),"player_share":float(cfg().management.player_share),"monthly_estimate":maxf(0.0,expected),"company_rate":base_rate,"aid_rate":extra,"aid_remaining":maxi(0,until-int(sim.state.day)),"warning":"预测以最近经营和现有产能为限；先偿债并补足30日周转，各矿床独立耗尽，不将未建矿场的资源计入分红。分红可能为零。"}

static func tick(sim)->void:
	ensure(sim)
	var c:Dictionary=sim.state.career
	var delta:int=int(sim.state.day)-int(c.last_local_day)
	if delta<=0:return
	for _i in range(delta):
		c.global_day+=1
		for old in c.managed:
			old.local_day+=1
			for a in old.aid_contracts:
				if a.status=="in_transit" and int(old.local_day)>=int(a.arrival_day):
					old.reserve+=float(a.cash)
					old.financing_total+=float(a.cash)
					for key in ["food","materials","parts"]:old.delivered_supplies[key]+=float(a[key])
					a.status="active"
			var mining:float=0.0
			old.mine_remaining=0.0
			for stream in old.mining_streams:
				var produced:float=minf(float(stream.rate),float(stream.remaining))
				stream.remaining-=produced
				mining+=produced
				old.mine_remaining+=stream.remaining
			var income:float=mining+float(old.nonmining_income)
			var cost:float=float(old.daily_cost)
			old.reserve+=income
			old.income_total+=income
			var paid:float=minf(float(old.reserve),cost+float(old.debt))
			var arrears_repaid:float=maxf(0.0,paid-cost)
			old.reserve-=paid
			old.cost_total+=paid
			old.debt=maxf(0.0,cost+float(old.debt)-paid)
			var extra_tax:float=0.0
			var principal:float=0.0
			for a in old.aid_contracts:
				if not a.status in ["active","breached"]:continue
				var fee:float=minf(float(old.reserve),maxf(0.0,income-cost-extra_tax)*float(a.surcharge)) if int(old.local_day)<int(a.end_day) else 0.0
				old.reserve-=fee
				extra_tax+=fee
				a.surcharge_paid+=fee
				var due:float=maxf(0.0,float(a.repayment)-float(a.paid))
				var part:float=minf(due,float(a.repayment)/float(a.duration)) if a.status!="breached" else due
				part=minf(part,maxf(0.0,float(old.reserve)-float(a.cash_floor)))
				old.reserve-=part
				principal+=part
				a.paid+=part
				if int(old.local_day)>=int(a.end_day):a.status="fulfilled" if a.paid+0.00001>=a.repayment else "breached"
			var tax:float=minf(float(old.reserve),maxf(0.0,income-cost-extra_tax)*float(old.company_rate))
			old.reserve-=tax
			old.company_total+=tax+extra_tax+principal
			old.period_net+=income-cost-tax-extra_tax-principal-arrears_repaid
			if int(c.global_day)%int(cfg().calendar.month_days)==0:settle_month(sim,old,int(c.global_day)/int(cfg().calendar.month_days))
	c.last_local_day=int(sim.state.day)

static func settle_month(sim,old:Dictionary,period:int)->void:
	if period<=int(old.last_period):return
	var available:float=minf(maxf(0.0,float(old.period_net)),maxf(0.0,float(old.reserve)-float(old.reserve_target)))
	if float(old.debt)>0.001:available=0.0
	var player:float=available*float(old.player_share)
	var manager:float=available-player
	old.reserve-=available
	old.player_total+=player
	old.manager_total+=manager
	old.last_dividend=player
	old.last_period=period
	old.period_net=0.0
	sim.state.career.balance+=player
	sim.state.career.history.append({"id":"%s:%d"%[old.id,period],"global_day":sim.state.career.global_day,"world":old.id,"period":period,"player":player,"manager":manager,"local_reserve":old.reserve,"company_total":old.company_total})
	while sim.state.career.history.size()>int(cfg().management.max_reports):sim.state.career.history.pop_front()

static func invest(sim,amount:float)->String:
	ensure(sim)
	if not is_finite(amount) or amount<0:return "注资金额无效"
	if amount>float(sim.state.career.balance)+0.000001:return "生涯可用余额不足"
	if amount<=0:return ""
	sim.state.career.balance-=amount
	sim.state.career.invested+=amount
	sim._transfer("external","public",amount,"生涯资金注资（不计当地经营利润）",false)
	return ""

static func handover(sim,seed_value:Variant,advantage:String,difficulty:String,path:String,size_id:int=-1)->String:
	ensure(sim)
	if sim.state.status!="success":return "先取得本星球总督资格，才可移交代管"
	if path.is_empty():return "需要指定完整生涯存档位置"
	var p:Dictionary=preview(sim)
	var c:Dictionary=sim.state.career.duplicate(true)
	var old_id:int=c.active_id
	for old in c.managed:
		if int(old.id)==old_id:return "这颗星球已经移交"
	var frozen:Dictionary=sim.state.duplicate(true)
	frozen.erase("career")
	c.archives.append({"id":old_id,"seed":sim.state.world.seed,"version":sim.state.world.version,"snapshot":Marshalls.raw_to_base64(var_to_bytes(frozen).compress(FileAccess.COMPRESSION_GZIP))})
	c.managed.append({"id":old_id,"seed":sim.state.world.seed,"handed_day":c.global_day,"sample_days":p.sample_days,"mining_income":p.mining_income,"mining_streams":p.mining_streams,"nonmining_income":p.nonmining_income,"daily_cost":p.daily_cost,"mine_remaining":p.mine_remaining,"reserve":float(sim.state.cash),"initial_reserve":float(sim.state.cash),"reserve_target":p.reserve_target,"debt":float(sim.state.debt),"initial_debt":float(sim.state.debt),"player_share":p.player_share,"company_rate":p.company_rate,"aid_rate":p.aid_rate,"aid_remaining":p.aid_remaining,"company_contract":sim.state.get("company",{}).duplicate(true),"local_day":int(sim.state.day),"aid_contracts":sim.state.get("company",{}).get("aid",[]).duplicate(true),"financing_total":0.0,"delivered_supplies":{"food":0.0,"materials":0.0,"parts":0.0},"last_period":int(c.global_day)/int(cfg().calendar.month_days),"period_net":0.0,"income_total":0.0,"cost_total":0.0,"company_total":0.0,"manager_total":0.0,"player_total":0.0,"last_dividend":0.0})
	c.active_id+=1
	c.landed_day=c.global_day
	c.last_local_day=0
	c.checkpoint=""
	var next=sim.get_script().new()
	next.new_game(seed_value,advantage,int(sim.state.world.size) if size_id<0 else size_id,difficulty)
	next.state.career=c
	capture_checkpoint(next)
	var error:String=next._validate_save(next.state)
	if error!="":return "移交状态校验失败："+error
	error=next.save_game(path)
	if error!="":return "移交未提交，原星球仍可经营："+error
	sim.state=next.state
	sim.config=next.config
	return ""

static func restart(sim,difficulty:String,path:String)->String:
	ensure(sim)
	if sim.state.career.checkpoint=="":return "此旧档没有登陆检查点；可继续经营或从主菜单新建独立生涯"
	var candidate:Variant=_decode(sim.state.career.checkpoint)
	if not candidate is Dictionary:return "登陆检查点损坏"
	var next=sim.get_script().new()
	# Reapply a changed opening from the same pre-attempt career, never stack funding.
	if difficulty!=str(candidate.get("difficulty","normal")):
		var kept:Dictionary=candidate.career.duplicate(true)
		next.new_game(candidate.world.seed,candidate.advantage,int(candidate.world.size),difficulty)
		next.state.career=kept
	else:next.state=candidate
	next.state.career.checkpoint=sim.state.career.checkpoint
	var error:String=next._validate_save(next.state)
	if error!="":return error
	error=next.save_game(path)
	if error!="":return "重开未提交："+error
	sim.state=next.state
	sim.config=next.config
	return ""

static func validate(s:Dictionary)->String:
	if not s.has("career"):return ""
	var c:Variant=s.career
	if not c is Dictionary:return "生涯格式无效"
	for key in ["version","active_id","global_day","landed_day","last_local_day","balance","invested"]:
		if not (c.get(key) is int or c.get(key) is float) or not is_finite(float(c[key])) or float(c[key])<0:return "生涯数值无效："+key
	for key in ["managed","archives","history"]:
		if not c.get(key) is Array:return "生涯列表无效："+key
	if not c.get("checkpoint") is String or not c.get("id") is String:return "生涯身份无效"
	if int(c.global_day)-int(c.landed_day)!=int(s.day) or int(c.last_local_day)!=int(s.day):return "生涯时钟与当地日期不一致"
	var seen:Array=[]
	var paid_total:float=0.0
	for old in c.managed:
		if not old is Dictionary:return "代管状态无效"
		for key in ["id","mining_income","nonmining_income","daily_cost","mine_remaining","reserve","reserve_target","debt","player_share","company_rate","aid_rate","aid_remaining","last_period","period_net","income_total","cost_total","company_total","manager_total","player_total","last_dividend","initial_reserve","local_day","financing_total"]:
			if not (old.get(key) is int or old.get(key) is float) or not is_finite(float(old[key])):return "代管数值无效："+key
			if key!="period_net" and float(old[key])<0:return "代管数值不能为负"
		if old.id in seen or int(old.id)==int(c.active_id) or old.player_share>1:return "代管身份或分成无效"
		seen.append(old.id)
		paid_total+=float(old.player_total)
		if not old.get("aid_contracts") is Array or not old.get("delivered_supplies") is Dictionary:return "代管义务无效"
		for a in old.aid_contracts:
			if not a is Dictionary:return "代管援助无效"
			for key in ["arrival_day","end_day","cash","food","materials","parts","repayment","paid","surcharge","surcharge_paid","duration","cash_floor"]:
				if not (a.get(key) is int or a.get(key) is float) or not is_finite(float(a[key])) or a[key]<0:return "代管援助数值无效"
			if a.duration<=0 or not a.get("status") is String:return "代管援助期限无效"
		if not old.get("mining_streams") is Array:return "代管矿床无效"
		for stream in old.mining_streams:
			if not stream is Dictionary or not stream.get("resource") is String:return "代管矿床记录无效"
			for key in ["rate","remaining"]:
				if not (stream.get(key) is int or stream.get(key) is float) or not is_finite(float(stream[key])) or stream[key]<0:return "代管矿量无效"
		var actual:float=old.reserve+old.company_total+old.manager_total+old.player_total
		var expected:float=old.initial_reserve+old.income_total+old.get("financing_total",0)-old.cost_total
		if absf(actual-expected)>0.001:return "代管账户不守恒"
	if absf(paid_total-float(c.balance)-float(c.invested))>0.001:return "生涯分红转账不守恒"
	var archive_ids:Array=[]
	for a in c.archives:
		if not a is Dictionary or not a.get("snapshot") is String or not a.get("id") in seen or a.id in archive_ids:return "旧星球完整快照无效"
		var archived:Variant=_decode(a.snapshot)
		if not archived is Dictionary or not archived.get("world") is Dictionary or archived.world.get("seed")!=a.get("seed") or archived.world.get("version")!=a.get("version"):return "旧星球快照身份无效"
		archive_ids.append(a.id)
	if archive_ids.size()!=seen.size():return "缺少旧星球完整交接快照"
	if c.checkpoint!="":
		var checkpoint:Variant=_decode(c.checkpoint)
		if not checkpoint is Dictionary or not checkpoint.get("career") is Dictionary or checkpoint.career.get("checkpoint")!="":return "登陆检查点无效"
	for row in c.history:
		if not row is Dictionary or not row.get("id") is String:return "分红记录无效"
	return ""
