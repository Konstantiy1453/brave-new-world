extends RefCounted
const D=preload("res://ui/design.gd")
const Career=preload("res://simulation/career.gd")

static func populate(g,b,page:String):
	match page:
		"research":research(g,b)
		"company":company(g,b)
		"events":events(g,b)
		"career":career(g,b)
		"manage":manage(g,b)

static func research(g,b):
	var v:Dictionary=g.sim.research_view()
	D.label(b,"科研人员 / 有限团队与真实投入",25,D.TEAL)
	D.label(b,"总人员 %d · 调查 %d · 可用 %d · 实验容量 %d"%[v.get("total",0),v.get("investigating",0),v.get("available",0),v.get("capacity",0)],20,D.GOLD)
	D.label(b,"同等条件：5人速度是10人的60%。集中团队更早取得关键技术；分散团队受实验台数量限制，并有额外经费需求。调配保留全部已完成工作。",17,D.MUTED)
	for key in g.sim.config.techs:
		var t:Dictionary=g.sim.config.techs[key]
		var current:Dictionary={}
		for p in v.get("projects",[]):
			if p.get("tech","")==key:current=p
		var c=D.card(b)
		D.label(c,t.name,22,D.TEAL)
		D.label(c,t.description,17)
		D.label(c,"10人基准日经费 %.2f；人员工资另计。最低团队 %d 人，前置：%s"%[float(t.funding)*(0.5 if g.sim.state.advantage=="science" else 1.0),int(t.get("minimum_staff",3)),"无" if t.requires.is_empty() else "、".join(PackedStringArray(t.requires.map(func(k):return g.sim.config.techs[k].name)))],16,D.MUTED)
		if key in g.sim.state.research.completed:
			D.label(c,"研究完成 · 经营效果已启用",18,D.GOLD)
			continue
		D.label(c,"分配 %d 人 / 实投 %d 人 · 速度 %.3f 点/日\n剩余 %.1f 点 · 预计 %s 日后完成"%[current.get("staff",0),current.get("effective",0),current.get("rate",0),current.get("remaining",t.cost),(str(current.eta) if int(current.get("eta",-1))>=0 else "—")],17)
		D.label(c,str(current.get("reason","需要启用的研究所、人员和经费。")),16,D.MUTED)
		var row=D.row(c)
		var count=SpinBox.new()
		count.min_value=0
		count.max_value=maxi(10,int(v.get("total",0)))
		count.value=current.get("staff",0)
		row.add_child(count)
		var tech=key
		D.button(row,"应用团队分配",func():g.act("research_allocate",{"tech":tech,"staff":int(count.value)}))
		D.button(row,"暂停项目（保留进度）",func():g.act("research_allocate",{"tech":tech,"staff":0}))

static func company(g,b):
	var v:Dictionary=g.sim.company_view()
	D.label(b,"公司关系 / 整改与有条件支持",25,D.TEAL)
	var stages={"normal":"正常经营","warning":"关注预警","review":"正式审查","intervention":"有条件介入","recovery":"稳定恢复"}
	D.label(b,"不信任 %.1f / 100 · %s"%[v.get("distrust",0),stages.get(v.get("stage","normal"),v.get("stage",""))],23,D.GOLD)
	D.label(b,str(v.get("summary",v.get("reason","公司根据真实逾期、社会和环境问题评估；投资期亏损本身不等于违约。"))),18)
	for source in v.get("sources",{}).values():
		if float(source.rate)>0:D.label(b,"%s · 持续 %d 日 · 本日 +%.2f"%[source.reason,source.days,source.rate],17,D.MUTED)
	D.label(b,"整改期限：%s · 本日变化 %+.2f"%[(str(v.deadline) if int(v.get("deadline",-1))>=0 else "暂无"),float(v.get("delta",0))],18)
	D.label(b,str(v.get("remedy","优先恢复食品和住房，清偿到期欠款；暂停非必要扩张，调拨库存，必要时接受有条件援助。")),17,D.MUTED)
	for offer in v.get("offers",[]):
		var description="援助现金 %.0f，食品 %.0ft，建材 %.0ft，部件 %.0ft；%d日后抵达。\n期限%d日，偿还%.0f；期间正经营结余追加分成%.0f%%。仅从超过%.0f现金保底的部分分期偿还。每方案一生涯当前星球仅可领取一次。"%[offer.cash,offer.food,offer.materials,offer.parts,offer.arrival_days,offer.duration,offer.repayment,offer.surcharge*100,offer.cash_floor]
		var c=D.card(b)
		D.label(c,str(offer.get("title",offer.get("name","公司援助"))),22,D.TEAL)
		D.label(c,description,17)
		var id=str(offer.get("id",""))
		var bt=D.button(c,"查看并接受条款",func():
			var confirm=ConfirmationDialog.new()
			confirm.dialog_text=description+"\n确认接受上述义务？"
			g.add_child(confirm)
			confirm.confirmed.connect(func():g.act("company",{"operation":"accept","offer":id});confirm.queue_free())
			confirm.popup_centered(Vector2i(700,340)))
		bt.disabled=bool(offer.get("claimed",false)) or v.get("stage","normal")=="normal"
		bt.tooltip_text=str(offer.get("reason",""))
	D.button(b,"治理所选据点污染 · 支出%.0f / 降低%.0f"%[g.sim.progression.production.cleanup_cost,g.sim.progression.production.cleanup_amount],func():g.act("company",{"operation":"cleanup","region":g.selected}))
	for a in v.get("aid",[]):D.label(D.card(b),"%s · %s · 偿还 %.2f / %.2f · 第%d日到期"%[a.name,{"in_transit":"运输中","active":"履行中","fulfilled":"已履行","breached":"待补缴","cancelled":"已取消"}.get(a.status,a.status),a.paid,a.repayment,a.end_day],17,D.GOLD)
	for line in v.get("letters",[]).slice(-12):D.label(b,"第%d日 · %s"%[line.day,line.reason],15,D.MUTED)

static func events(g,b):
	var v:Dictionary=load("res://simulation/events_v2.gd").view(g.sim)
	D.label(b,"殖民通讯 / 选择与后续",25,D.TEAL)
	D.label(b,"决定节点暂停世界；选择“稍后处理”才会继续计时。调查占用科研人员，订单按真实交付结算。",17,D.MUTED)
	for node in v.get("pending",[]):
		var c=D.card(b)
		D.label(c,str(node.get("title","通讯")),22,D.GOLD)
		D.label(c,str(node.get("text","")),18)
		D.label(c,"殖民第 %s 日截止 · 余 %s 日"%[str(node.get("deadline","—")),str(node.get("remaining_days","—"))],16,D.TEAL)
		for choice in node.get("choices",[]):
			var instance=str(node.instance_id)
			var id=str(choice.id)
			D.label(c,str(choice.label),17)
			var bt=D.button(c,"选择此方案",func():g.act("event_v2",{"instance_id":instance,"choice":id}))
			bt.disabled=not bool(choice.get("enabled",true))
			bt.tooltip_text=str(choice.get("reason",""))
	if v.get("pending",[]).is_empty():D.label(b,"目前没有需要答复的节点。",20)
	for node in v.get("active",[]):
		if node.status!="waiting":continue
		var c=D.card(b)
		D.label(c,str(node.title)+" / 进行中",21,D.TEAL)
		var investigation:Dictionary=node.variables.get("investigation",{})
		if not investigation.is_empty():D.label(c,"调查进度 %.1f / %.1f · 已保留科研团队"%[investigation.get("progress",0),investigation.get("work",0)],17)
		if not node.order.is_empty():D.label(c,"订单已发 %.1f / 已到 %.1f · 已付款 %.2f"%[node.order.get("dispatched",0),node.order.get("delivered",0),node.order.get("paid",0)],17)
		for choice in node.choices:
			var instance=str(node.instance_id)
			var id=str(choice.id)
			D.button(c,str(choice.label),func():g.act("event_v2",{"instance_id":instance,"choice":id}))
	for section in ["effects","history"]:
		D.label(b,{"active":"正在进行","effects":"仍生效的影响","history":"事件结局与选择记录"}[section],20,D.TEAL)
		for row in v.get(section,[]).slice(-20 if g.detailed_info else -6):
			if row is Dictionary:D.label(b,str(row.get("title",row.get("definition_id",row.get("kind",""))))+" · "+str(row.get("text",row.get("summary",row.get("ending",row.get("factor",row.get("node","")))))),16,D.MUTED)
			else:D.label(b,str(row),16,D.MUTED)

static func career(g,b):
	Career.ensure(g.sim)
	var c:Dictionary=g.sim.state.career
	D.label(b,"连续生涯 / 旧星代管与新远征",25,D.TEAL)
	D.label(b,"生涯第 %d 日 · 当前第 %d 颗星球 · 登陆第 %d 日\n可用生涯资金 ¥ %.2f"%[c.global_day,c.active_id,g.sim.state.day,c.balance],21,D.GOLD)
	D.label(b,"30日为一个月，360日为一年。暂停时旧星也暂停。分红先进入生涯资金；注资不计入新星球经营利润。",17,D.MUTED)
	var row=D.row(b)
	var amount=SpinBox.new()
	amount.max_value=float(c.balance)
	amount.value=minf(float(c.balance),500)
	row.add_child(amount)
	D.button(row,"注入当前星球",func():g.career_action("invest",{"amount":amount.value}))
	for old in c.managed:
		var card=D.card(b)
		D.label(card,"代管星球 %d · 种子 %s"%[old.id,str(old.seed)],22,D.TEAL)
		D.label(card,"本地周转 ¥ %.2f / 目标 %.2f · 待付 %.2f\n上期玩家分红 %.2f · 累计 %.2f · 代管方累计 %.2f\n公司累计 %.2f · 有限矿业剩余可售价值 %.0f"%[old.reserve,old.reserve_target,old.debt,old.last_dividend,old.player_total,old.manager_total,old.company_total,old.mine_remaining],17)
	if g.sim.state.status=="success":
		var p:Dictionary=Career.preview(g.sim)
		D.label(b,"总督交接预览",23,D.TEAL)
		D.label(b,"参考最近 %d 日；日收入 %.2f / 日成本 %.2f\n周转留存 %.2f · 玩家分成 %.0f%% · 稳态月分红估计 %.2f"%[p.sample_days,p.daily_income,p.daily_cost,p.reserve_target,p.player_share*100,p.monthly_estimate],18,D.GOLD)
		D.label(b,p.warning+" 代管方取得剩余分成，不另收管理费。旧星的救助附加义务保留。",17,D.MUTED)
		var next_seed=LineEdit.new()
		next_seed.text=str(int(g.sim.state.world.seed)+1)
		b.add_child(next_seed)
		D.button(b,"确认交接并前往下一颗星球",func():
			var dialog=ConfirmationDialog.new()
			dialog.dialog_text="保留旧星完整快照并交给代管，开始新星球合同。只有完整生涯存档写入成功才提交交接。"
			g.add_child(dialog)
			dialog.confirmed.connect(func():g.career_action("handover",{"seed":next_seed.text});dialog.queue_free())
			dialog.popup_centered(Vector2i(700,260)))
	else:D.label(b,"取得当前星球总督资格后可移交；现在仍可查看已取得的代管资产。",18,D.MUTED)
	var level=OptionButton.new()
	for label in ["简单","标准","困难"]:level.add_item(label)
	level.select(["easy","normal","hard"].find(g.sim.state.get("difficulty","normal")))
	b.add_child(level)
	D.button(b,"恢复本次登陆检查点 / 按选定难度重开",func():
		var dialog=ConfirmationDialog.new()
		dialog.dialog_text="恢复本星登陆时的完整生涯，包括全局时间、余额、旧星结算账期和随机状态。本次尝试取得的分红与投资一并撤回。"
		g.add_child(dialog)
		dialog.confirmed.connect(func():g.career_action("restart",{"difficulty":["easy","normal","hard"][level.selected]});dialog.queue_free())
		dialog.popup_centered(Vector2i(700,260)))

static func manage(g,b):
	var s:Dictionary=g.settlement()
	if s.is_empty():D.label(b,"请选择已建立的据点。",20);return
	D.label(b,s.name+" / 批量生产与库存目标",24,D.TEAL)
	D.label(b,"停用住区会撤销该设施住房；保留建材和部件供本地建设与跨区调拨，只有真正余量自动出口。",17,D.MUTED)
	for category in ["all","production"]:
		var row=D.row(b)
		var cat=category
		var caption=D.label(row,"全部公共设施" if cat=="all" else "生产设施",18)
		caption.custom_minimum_size.x=150
		caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		D.button(row,"批量启用",func():g.act("batch_toggle",{"region":g.selected,"category":cat,"enabled":true}))
		D.button(row,"批量停用",func():g.act("batch_toggle",{"region":g.selected,"category":cat,"enabled":false}))
	for key in ["food","materials","parts"]:
		var row=D.row(b)
		var caption=D.label(row,{"food":"食品目标（吨）","materials":"建材目标（吨）","parts":"部件目标（吨）"}[key],18)
		caption.custom_minimum_size.x=180
		caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var amount=SpinBox.new()
		amount.max_value=maxf(10000,g.sim._target(s,key))
		amount.step=0.000001
		amount.custom_arrow_step=0.1
		amount.value=g.sim._target(s,key)
		row.add_child(amount)
		var resource=key
		D.button(row,"设置目标",func():g.act("stock_target",{"region":g.selected,"resource":resource,"target":amount.value}))
