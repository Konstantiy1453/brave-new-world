extends SceneTree
const Sim=preload("res://simulation/sim.gd")
func _initialize()->void:
	var s=Sim.new()
	s.new_game(20261029,"capital",1)
	var result:Dictionary={"first_island_settle":s.act("settle",{"region":4}),"second_attempts":[]}
	for region in [0,1,2,3,5]:
		result.second_attempts.append({"region":region,"result":s.act("settle",{"region":region})})
	result.status=s.state.status
	result.settlement_count=s.state.settlements.size()
	FileAccess.open("D:/勇敢新世界/docs/evidence/island_start_review.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	quit(0)
