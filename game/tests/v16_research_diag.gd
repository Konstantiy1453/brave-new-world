extends SceneTree
const Sim=preload("res://simulation/sim.gd")
const Flow=preload("res://tests/v16_flow.gd")
func _init():
	var runner=Flow.new()
	for advantage in ["capital","science"]:
		var s=Sim.new();s.new_game(260129,advantage,1,"normal");runner.opening(s)
		for day in range(180):
			runner.step(s)
			if int(s.state.day) in [5,23,25,60,120,180]:
				print("DIAG ",advantage," ",s.state.day," ",s.research_view()," workers=",s.settlement(0).workers," buildings=",s.settlement(0).buildings)
	runner.free()
	quit()
